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
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var currentAudioLevel: Float = 0

    // MARK: - Private

    private var audioEngine: AVAudioEngine?
    private var outputFile: AVAudioFile?
    private var timerTask: Task<Void, Never>?
    private var activeSession: Session?
    private var activeContext: ModelContext?

    // MARK: - Start Recording

    /// Configures the audio session, creates the output file, installs the input tap,
    /// starts the engine, and begins updating elapsed time.
    func startRecording(session: Session, context: ModelContext) throws {
        guard !isRecording else { return }

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
            throw DictlyError.recording(.fileCreationFailed(error.localizedDescription))
        }

        // Set up engine and tap
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Buffer size ~4096 frames ≈ 0.093s at 44100 Hz — flushes to disk every tap
        let bufferSize: AVAudioFrameCount = 4096

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            // Write PCM buffer to file (AVAudioFile encodes to AAC on write)
            do {
                try file.write(from: buffer)
            } catch {
                logger.error("Failed to write audio buffer: \(error, privacy: .public)")
            }

            // Calculate RMS audio level for LiveWaveform (Story 2.3)
            let level = Self.calculateRMS(buffer: buffer)
            Task { @MainActor [weak self] in
                self?.currentAudioLevel = level
            }
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            logger.error("Engine start failed: \(error, privacy: .public)")
            throw DictlyError.recording(.engineStartFailed(error.localizedDescription))
        }

        // Store state
        outputFile = file
        audioEngine = engine
        activeSession = session
        activeContext = context
        isRecording = true
        isPaused = false
        elapsedTime = 0

        // Persist audio file path (filename only — resolved to full path at runtime)
        session.audioFilePath = filename
        try? context.save()

        logger.info("Recording started for session \(session.uuid.uuidString, privacy: .private)")

        // Start elapsed time ticker
        timerTask = Task { @MainActor [weak self] in
            while !(self?.timerTask?.isCancelled ?? true) {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                guard let self, self.isRecording, !self.isPaused else { continue }
                self.elapsedTime += 0.1
            }
        }
    }

    // MARK: - Stop Recording

    /// Stops the engine, removes the tap, deactivates the audio session,
    /// and persists the final duration.
    func stopRecording() {
        guard isRecording else { return }

        timerTask?.cancel()
        timerTask = nil

        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
        outputFile = nil

        // Deactivate session — only safe to call after engine stops
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        if let session = activeSession, let context = activeContext {
            session.duration = elapsedTime
            try? context.save()
            logger.info("Recording stopped. Duration: \(self.elapsedTime, privacy: .public)s")
        }

        activeSession = nil
        activeContext = nil
        isRecording = false
        isPaused = false
        currentAudioLevel = 0
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
                guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }

                let audioFile = try AVAudioFile(forReading: fileURL)
                guard audioFile.length > 0 else { continue }

                let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
                session.duration = duration
                try? context.save()
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
}
