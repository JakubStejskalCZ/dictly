import AVFoundation
import os
import DictlyModels

// MARK: - AudioPlayer

/// Core Audio playback service for a session's audio file.
///
/// Uses `AVAudioEngine` + `AVAudioPlayerNode` for precise seeking, scrub preview,
/// and future extensibility (e.g. transcription audio routing).
///
/// - `@Observable`: SwiftUI views observe `isPlaying`, `currentTime`, `duration`, `isLoaded`
///   directly — no need for `@Binding` or `@Published` wrappers.
/// - `@MainActor`: All state mutations happen on the main actor; timer updates are
///   dispatched back via cooperative Task scheduling.
@Observable
@MainActor
final class AudioPlayer {

    // MARK: - Observable State

    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var isLoaded: Bool = false

    // MARK: - Audio Stack

    /// `nonisolated(unsafe)` allows cleanup in `deinit`, which is nonisolated in Swift 6.
    /// All accesses during normal operation are exclusively from `@MainActor` context.
    nonisolated(unsafe) private let engine = AVAudioEngine()
    nonisolated(unsafe) private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?

    /// Path of the last successfully loaded audio file. Guards against redundant re-loads
    /// and enables proper teardown when a different file is requested.
    private var loadedFilePath: String?

    // MARK: - Timing

    /// Task that polls playerNode time at ~30Hz during playback.
    /// `nonisolated(unsafe)` for cancellation in deinit.
    nonisolated(unsafe) private var timerTask: Task<Void, Never>?

    /// File-time offset at which the current scheduled segment began.
    private var playbackStartPosition: TimeInterval = 0

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.dictly.mac", category: "playback")

    // MARK: - Lifecycle

    deinit {
        timerTask?.cancel()
        engine.stop()
    }

    // MARK: - Public API

    /// Opens the audio file, builds engine graph (`playerNode → mainMixerNode → outputNode`),
    /// and starts the engine.
    ///
    /// Throws `DictlyError.storage(.fileNotFound)` if the file is missing or inaccessible.
    func load(filePath: String) async throws {
        // Skip if the same file is already loaded — .task may fire multiple times.
        if loadedFilePath == filePath, isLoaded { return }

        // Tear down previous session if switching to a different file.
        if isLoaded {
            stopUpdateTimer()
            playerNode.stop()
            engine.stop()
            engine.detach(playerNode)
            audioFile = nil
            loadedFilePath = nil
            isLoaded = false
            isPlaying = false
            currentTime = 0
            duration = 0
            playbackStartPosition = 0
        }

        guard FileManager.default.fileExists(atPath: filePath) else {
            logger.error("Audio file not found: \(filePath, privacy: .sensitive)")
            throw DictlyError.storage(.fileNotFound)
        }

        let url = URL(fileURLWithPath: filePath)
        let file = try AVAudioFile(forReading: url)
        audioFile = file
        duration = Double(file.length) / file.processingFormat.sampleRate

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: file.processingFormat)
        try engine.start()
        loadedFilePath = filePath
        isLoaded = true
        logger.info("Audio loaded, duration: \(self.duration, privacy: .public)s")
    }

    /// Starts playback from `currentTime`.
    /// If `currentTime` is at or beyond `duration` (end of file), restarts from the beginning.
    func play() {
        guard isLoaded, audioFile != nil else { return }
        if currentTime >= duration { currentTime = 0 }
        scheduleAndPlay(from: currentTime)
    }

    /// Pauses playback and preserves `currentTime`.
    func pause() {
        guard isPlaying else { return }
        updateCurrentTime()
        playerNode.pause()
        isPlaying = false
        stopUpdateTimer()
        logger.debug("Playback paused at \(self.currentTime, privacy: .public)s")
    }

    /// Seeks to `time` (clamped to `0...duration`). Resumes playback if already playing.
    func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, duration))
        let wasPlaying = isPlaying

        if isPlaying {
            playerNode.stop()
            isPlaying = false
            stopUpdateTimer()
        }

        currentTime = clamped

        if wasPlaying {
            scheduleAndPlay(from: clamped)
        }
    }

    /// Plays a short (~200ms) audio snippet at `time` for drag-scrub preview.
    ///
    /// Pauses any ongoing playback — scrub takes over audio output.
    /// Does **not** set `isPlaying = true`; call `play()` to resume.
    func scrub(to time: TimeInterval) {
        let clamped = max(0, min(time, duration))

        if isPlaying {
            playerNode.stop()
            isPlaying = false
            stopUpdateTimer()
        }

        currentTime = clamped

        guard let file = audioFile, isLoaded else { return }
        playerNode.stop()

        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(clamped * sampleRate)
        guard startFrame < file.length else { return }

        let remaining = AVAudioFrameCount(file.length - startFrame)
        let snippet = AVAudioFrameCount(sampleRate * 0.2) // 200ms preview
        let frameCount = min(snippet, remaining)
        guard frameCount > 0 else { return }

        playerNode.scheduleSegment(file, startingFrame: startFrame,
                                    frameCount: frameCount, at: nil)
        playerNode.play()
    }

    // MARK: - Private

    private func scheduleAndPlay(from startTime: TimeInterval) {
        guard let file = audioFile else { return }
        playerNode.stop()

        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(startTime * sampleRate)
        guard startFrame < file.length else { return }

        let remainingFrames = AVAudioFrameCount(file.length - startFrame)
        guard remainingFrames > 0 else { return }

        playbackStartPosition = startTime
        playerNode.scheduleSegment(file, startingFrame: startFrame,
                                    frameCount: remainingFrames, at: nil)
        playerNode.play()
        isPlaying = true
        startUpdateTimer()
        logger.debug("Playback started from \(startTime, privacy: .public)s")
    }

    /// Starts a cooperative ~30Hz task that polls `playerNode` for the current time.
    private func startUpdateTimer() {
        stopUpdateTimer()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                guard !Task.isCancelled, let self else { break }
                self.updateCurrentTime()
            }
        }
    }

    private func stopUpdateTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func updateCurrentTime() {
        guard isPlaying else { return }

        // Detect end-of-file: node stops playing when scheduled segment is exhausted
        guard playerNode.isPlaying else {
            handlePlaybackFinished()
            return
        }

        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
              playerTime.isSampleTimeValid,
              playerTime.sampleTime >= 0 else { return }

        let elapsed = Double(playerTime.sampleTime) / playerTime.sampleRate
        currentTime = min(playbackStartPosition + elapsed, duration)
    }

    private func handlePlaybackFinished() {
        stopUpdateTimer()
        currentTime = duration
        isPlaying = false
        logger.debug("Playback finished")
    }
}
