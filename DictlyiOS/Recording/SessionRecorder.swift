import AVFoundation
import OSLog
import Observation
import SwiftData
import DictlyModels
import DictlyStorage

private let logger = Logger(subsystem: "com.dictly.ios", category: "recording")

/// Core recording engine. An `@Observable @MainActor` service injected via `.environment()`.
/// Owns the `AVAudioEngine` lifecycle and exposes reactive state for UI consumption.
@Observable @MainActor
final class SessionRecorder {

    // MARK: - Public State

    private(set) var isRecording = false
    private(set) var isPaused = false
    internal(set) var elapsedTime: TimeInterval = 0
    private(set) var currentAudioLevel: Float = 0
    /// True only when the session was interrupted by the system (phone call, alarm, etc.).
    /// Drives the UI to show a prominent "Resume Recording" banner (Story 2.3).
    private(set) var wasInterruptedBySystem = false

    // MARK: - Private

    private var audioEngine: AVAudioEngine?
    private var outputFile: AVAudioFile?
    private var timerTask: Task<Void, Never>?
    private var activeSession: Session?
    private var activeContext: ModelContext?
    private var recordingStartDate: Date?
    private nonisolated(unsafe) var isStopping = false
    private var consecutiveWriteFailures = 0

    // Pause tracking
    private var totalPauseDuration: TimeInterval = 0
    private var pauseStartDate: Date?
    private var pauseIntervalStart: TimeInterval = 0

    // Notification observers
    private var interruptionObserver: (any NSObjectProtocol)?
    private var configChangeObserver: (any NSObjectProtocol)?

    // MARK: - Start Recording

    /// Configures the audio session, creates the output file, installs the input tap,
    /// starts the engine, and begins updating elapsed time.
    func startRecording(session: Session, context: ModelContext) throws {
        guard !isRecording else {
            logger.warning("startRecording called while already recording session \(self.activeSession?.uuid.uuidString ?? "unknown", privacy: .private)")
            return
        }

        // Configure AVAudioSession
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .default, options: [.allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            logger.error("Audio session setup failed: \(error, privacy: .public)")
            throw DictlyError.recording(.audioSessionSetupFailed(error.localizedDescription))
        }

        // Log the active input port
        if let portName = audioSession.currentRoute.inputs.first?.portName {
            logger.info("Audio input: \(portName, privacy: .public)")
        }

        // Create output file
        let filename = "\(session.uuid.uuidString).m4a"
        let outputURL: URL
        do {
            let dir = try AudioFileManager.audioStorageDirectory()
            outputURL = dir.appendingPathComponent(filename)
        } catch {
            logger.error("Failed to get audio storage directory: \(error, privacy: .public)")
            deactivateAudioSession()
            throw DictlyError.recording(.fileCreationFailed(error.localizedDescription))
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64000
        ]

        let file: AVAudioFile
        do {
            file = try AVAudioFile(forWriting: outputURL, settings: settings)
        } catch {
            logger.error("Failed to create output file: \(error, privacy: .public)")
            deactivateAudioSession()
            throw DictlyError.recording(.fileCreationFailed(error.localizedDescription))
        }

        // Set up engine and tap
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Validate input format
        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            logger.error("Invalid audio input format: channels=\(inputFormat.channelCount), sampleRate=\(inputFormat.sampleRate, privacy: .public)")
            deactivateAudioSession()
            throw DictlyError.recording(.audioSessionSetupFailed("No valid audio input available"))
        }

        // Buffer size ~4096 frames ≈ 0.093s at 44100 Hz — flushes to disk every tap
        let bufferSize: AVAudioFrameCount = 4096

        isStopping = false
        consecutiveWriteFailures = 0
        totalPauseDuration = 0
        pauseStartDate = nil
        pauseIntervalStart = 0

        installInputTap(on: inputNode, bufferSize: bufferSize, file: file)

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            logger.error("Engine start failed: \(error, privacy: .public)")
            deactivateAudioSession()
            throw DictlyError.recording(.engineStartFailed(error.localizedDescription))
        }

        // Store state
        outputFile = file
        audioEngine = engine
        activeSession = session
        activeContext = context
        isRecording = true
        isPaused = false
        wasInterruptedBySystem = false
        elapsedTime = 0
        recordingStartDate = Date()

        // Persist audio file path (filename only — resolved to full path at runtime)
        session.audioFilePath = filename
        do {
            try context.save()
        } catch {
            logger.error("Failed to save audio file path: \(error, privacy: .public)")
        }

        logger.info("Recording started for session \(session.uuid.uuidString, privacy: .private)")

        // Remove any stale observers from a prior session that did not fully clean up
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            configChangeObserver = nil
        }

        // Register for AVAudioSession interruption notifications (phone calls, alarms, Siri)
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] notification in
            // Extract Sendable values before crossing to MainActor
            guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let interruptionType = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            Task { @MainActor [weak self] in
                self?.handleInterruption(type: interruptionType)
            }
        }

        // Register for engine configuration change (e.g. Bluetooth mic disconnect)
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleConfigChange()
            }
        }

        // Start elapsed time ticker (anchored to wall clock for drift-free 4+ hour recordings)
        let startDate = Date()
        timerTask = Task { @MainActor [weak self] in
            while !(self?.timerTask?.isCancelled ?? true) {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                guard let self, self.isRecording, !self.isPaused else { continue }
                self.elapsedTime = Date().timeIntervalSince(startDate) - self.totalPauseDuration
            }
        }
    }

    // MARK: - Pause Recording

    /// Stops audio capture without deactivating the AVAudioSession, keeping background mode alive.
    /// Does NOT close the output file — recording continues into the same file on resume.
    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.pause()
        isPaused = true
        pauseStartDate = Date()
        pauseIntervalStart = Date().timeIntervalSince(recordingStartDate!)
        currentAudioLevel = 0
        wasInterruptedBySystem = false
        logger.info("Recording paused at \(self.elapsedTime, privacy: .public)s")
    }

    // MARK: - Resume Recording

    /// Reinstalls the input tap, restarts the engine, and accumulates the pause duration.
    func resumeRecording() {
        guard isRecording, isPaused, let engine = audioEngine, let file = outputFile else { return }

        // Accumulate wall-clock pause duration for elapsed-time correction
        if let pauseStart = pauseStartDate {
            totalPauseDuration += Date().timeIntervalSince(pauseStart)
        }

        // Record pause interval for Mac timeline gap rendering (Story 4.2)
        // Uses wall-clock offsets from recordingStartDate so the Mac timeline can render actual gap durations
        if let session = activeSession, let context = activeContext {
            let pauseIntervalEnd = Date().timeIntervalSince(recordingStartDate!)
            var intervals = session.pauseIntervals
            intervals.append(PauseInterval(start: pauseIntervalStart, end: pauseIntervalEnd))
            session.pauseIntervals = intervals
            do {
                try context.save()
            } catch {
                logger.error("Failed to save pause interval: \(error, privacy: .public)")
            }
        }

        // Reinstall tap using the current input format (may have changed during pause)
        let inputNode = engine.inputNode
        let bufferSize: AVAudioFrameCount = 4096
        installInputTap(on: inputNode, bufferSize: bufferSize, file: file)

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            logger.error("Failed to resume recording: \(error, privacy: .public)")
            return
        }

        consecutiveWriteFailures = 0
        isPaused = false
        pauseStartDate = nil
        wasInterruptedBySystem = false
        logger.info("Recording resumed at \(self.elapsedTime, privacy: .public)s")
    }

    // MARK: - Stop Recording

    /// Stops the engine, removes the tap, deactivates the audio session,
    /// and persists the final duration.
    func stopRecording() {
        guard isRecording else { return }

        // Finalize open pause interval if we are currently paused
        if isPaused {
            if let session = activeSession, let context = activeContext, let startDate = recordingStartDate {
                let pauseIntervalEnd = Date().timeIntervalSince(startDate)
                var intervals = session.pauseIntervals
                intervals.append(PauseInterval(start: pauseIntervalStart, end: pauseIntervalEnd))
                session.pauseIntervals = intervals
                do {
                    try context.save()
                } catch {
                    logger.error("Failed to save final pause interval: \(error, privacy: .public)")
                }
            }
        }

        // Remove notification observers
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            configChangeObserver = nil
        }

        isStopping = true
        timerTask?.cancel()
        timerTask = nil

        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }

        // Read authoritative duration from the audio file before releasing it
        let fileDuration: TimeInterval? = {
            guard let file = outputFile else { return nil }
            let sampleRate = file.processingFormat.sampleRate
            guard sampleRate > 0 else { return nil }
            return Double(file.length) / sampleRate
        }()

        audioEngine = nil
        outputFile = nil

        deactivateAudioSession()

        if let session = activeSession, let context = activeContext {
            session.duration = fileDuration ?? elapsedTime
            do {
                try context.save()
            } catch {
                logger.error("Failed to save session duration: \(error, privacy: .public)")
            }
            logger.info("Recording stopped. Duration: \(session.duration, privacy: .public)s")
        }

        activeSession = nil
        activeContext = nil
        isRecording = false
        isPaused = false
        wasInterruptedBySystem = false
        currentAudioLevel = 0
        totalPauseDuration = 0
        pauseStartDate = nil
    }

    // MARK: - Crash Recovery

    /// Scans for sessions with an audio file path but zero duration (orphaned from a crash),
    /// reads the recovered file duration from disk, and updates the session's duration.
    /// Called on app launch from `DictlyiOSApp`.
    static func recoverOrphanedRecordings(context: ModelContext) {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { session in
                session.audioFilePath != nil && session.duration == 0
            }
        )
        guard let sessions = try? context.fetch(descriptor) else { return }

        for session in sessions {
            guard let filename = session.audioFilePath else { continue }
            do {
                let dir = try AudioFileManager.audioStorageDirectory()
                let fileURL = dir.appendingPathComponent(filename)

                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    // File missing — clear the stale reference so we don't re-process every launch
                    session.audioFilePath = nil
                    if let err = Result(catching: { try context.save() }).failure {
                        logger.error("Failed to clear stale audioFilePath: \(err, privacy: .public)")
                    }
                    continue
                }

                let audioFile = try AVAudioFile(forReading: fileURL)
                let sampleRate = audioFile.processingFormat.sampleRate
                guard audioFile.length > 0, sampleRate > 0 else {
                    // Empty or corrupt file — clean up
                    session.audioFilePath = nil
                    try? FileManager.default.removeItem(at: fileURL)
                    if let err = Result(catching: { try context.save() }).failure {
                        logger.error("Failed to save after cleaning orphan: \(err, privacy: .public)")
                    }
                    logger.info("Cleaned up empty orphaned recording file: \(filename, privacy: .public)")
                    continue
                }

                let duration = Double(audioFile.length) / sampleRate
                session.duration = duration
                do {
                    try context.save()
                } catch {
                    logger.error("Failed to save recovered duration: \(error, privacy: .public)")
                }
                logger.info("Recovered orphaned recording: \(session.uuid.uuidString, privacy: .private), duration: \(duration, privacy: .public)s")
            } catch {
                logger.error("Failed to recover orphaned recording: \(error, privacy: .public)")
            }
        }
    }

    // MARK: - Audio Level Metering

    private static func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }
        return sqrt(sum / Float(frameLength))
    }

    // MARK: - Interruption Handling

    private func handleInterruption(type: AVAudioSession.InterruptionType) {
        switch type {
        case .began:
            guard isRecording, !isPaused else { return }
            pauseRecording()
            wasInterruptedBySystem = true  // Override the false set by pauseRecording()
            logger.info("Recording interrupted by system (phone call/alarm)")
        case .ended:
            // Per UX spec, phone call resume always requires user action — do NOT auto-resume.
            logger.info("System interruption ended. Awaiting user resume.")
        @unknown default:
            break
        }
    }

    // MARK: - Configuration Change Handling

    private func handleConfigChange() {
        guard isRecording, !isPaused, let engine = audioEngine, let file = outputFile else { return }

        let audioSession = AVAudioSession.sharedInstance()
        if let portName = audioSession.currentRoute.inputs.first?.portName {
            logger.info("Audio route changed: \(portName, privacy: .public)")
        }

        // Re-install tap with potentially updated input format and restart
        let inputNode = engine.inputNode
        inputNode.removeTap(onBus: 0)
        let bufferSize: AVAudioFrameCount = 4096
        installInputTap(on: inputNode, bufferSize: bufferSize, file: file)

        do {
            try engine.start()
        } catch {
            logger.error("Failed to restart engine after config change: \(error, privacy: .public)")
        }
    }

    // MARK: - Helpers

    /// Installs the audio input tap on `inputNode`, writing captured buffers to `file`.
    /// Shared by `startRecording()`, `resumeRecording()`, and `handleConfigChange()`.
    private func installInputTap(on inputNode: AVAudioInputNode, bufferSize: AVAudioFrameCount, file: AVAudioFile) {
        let inputFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self, !self.isStopping else { return }

            // Write PCM buffer to file (AVAudioFile encodes to AAC on write)
            do {
                try file.write(from: buffer)
                self.consecutiveWriteFailures = 0
            } catch {
                logger.error("Failed to write audio buffer: \(error, privacy: .public)")
                self.consecutiveWriteFailures += 1
                if self.consecutiveWriteFailures >= 10 {
                    logger.error("Too many consecutive write failures — stopping recording (possible disk full)")
                    Task { @MainActor [weak self] in
                        self?.stopRecording()
                    }
                    return
                }
            }

            // Calculate RMS audio level for LiveWaveform (Story 2.3)
            let level = Self.calculateRMS(buffer: buffer)
            Task { @MainActor [weak self] in
                self?.currentAudioLevel = level
            }
        }
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.warning("Failed to deactivate audio session: \(error, privacy: .public)")
        }
    }
}

// MARK: - Result convenience for logging try? failures

private extension Result where Failure == any Error {
    init(catching body: () throws -> Success) {
        do {
            self = .success(try body())
        } catch {
            self = .failure(error)
        }
    }

    var failure: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
