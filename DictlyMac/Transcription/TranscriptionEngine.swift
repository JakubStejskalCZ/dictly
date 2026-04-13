import Foundation
import AVFoundation
import Observation
import os.log
import DictlyModels
import DictlyStorage

private let logger = Logger(subsystem: "com.dictly.mac", category: "transcription")

/// Orchestrates per-tag and batch transcription using WhisperBridge and ModelManager.
///
/// - Owns `WhisperBridge` (the whisper.cpp interop layer) and `ModelManager`
///   (model selection & download). These are exposed as `let` properties so
///   other views can inject them into the environment via the app root.
/// - All public state is `@MainActor`-isolated and observed by SwiftUI via `@Observable`.
/// - CPU-intensive whisper work runs off the main thread via `Task.detached`.
/// - Batch processing is sequential (one tag at a time) to avoid GPU resource contention.
@Observable
@MainActor
final class TranscriptionEngine {

    // MARK: - Owned Dependencies

    /// The whisper.cpp C-interop bridge. Thread-safe via NSLock.
    let whisperBridge: WhisperBridge

    /// Manages model selection, download, and active model URL.
    let modelManager: ModelManager

    // MARK: - Single-tag progress state

    private(set) var isTranscribing: Bool = false
    private(set) var currentTagId: UUID? = nil

    // MARK: - Batch progress state

    private(set) var isBatchTranscribing: Bool = false
    private(set) var batchTotal: Int = 0
    private(set) var batchCompleted: Int = 0
    private(set) var batchErrors: [(tag: Tag, error: Error)] = []

    // MARK: - Per-tag error state (single-tag transcription failures)

    /// Stores errors from standalone (non-batch) transcription calls so the UI can show
    /// the error badge and Retry button for single-tag transcription failures.
    private(set) var tagErrors: [UUID: Error] = [:]

    // MARK: - Private

    private var batchTask: Task<Void, Never>?

    // MARK: - Init

    /// Production init — creates WhisperBridge and ModelManager with standard directories.
    init() {
        self.whisperBridge = WhisperBridge()
        self.modelManager = ModelManager()
        logger.debug("TranscriptionEngine initialized")
    }

    /// Test/injection init — accepts pre-created dependencies for isolation.
    init(whisperBridge: WhisperBridge, modelManager: ModelManager) {
        self.whisperBridge = whisperBridge
        self.modelManager = modelManager
        logger.debug("TranscriptionEngine initialized (injected)")
    }

    // MARK: - Per-Tag Transcription (AC: #1, #4)

    /// Transcribes the ~30-second audio segment around `tag.anchorTime`.
    ///
    /// Sets `isTranscribing = true` and `currentTagId` for the duration of the call.
    /// On success, writes the result to `tag.transcription` (SwiftData auto-saves).
    /// On failure, propagates the error (caller is responsible for error display/retry).
    func transcribeTag(_ tag: Tag, session: Session) async throws {
        logger.info("TranscriptionEngine: transcribing tag '\(tag.label)' (\(tag.uuid))")
        tagErrors.removeValue(forKey: tag.uuid)
        isTranscribing = true
        currentTagId = tag.uuid

        defer {
            isTranscribing = false
            currentTagId = nil
        }

        do {
            let text = try await runTranscription(tag: tag, session: session)
            tag.transcription = text
            logger.info("TranscriptionEngine: done '\(tag.label)' — \(text.count) chars")
            let tagForIndex = tag
            Task {
                do {
                    try await SearchIndexer().updateTag(tagForIndex)
                } catch {
                    logger.error("TranscriptionEngine: spotlight update failed for '\(tagForIndex.label)' — \(error)")
                }
            }
        } catch {
            tagErrors[tag.uuid] = error
            throw error
        }
    }

    // MARK: - Batch Transcription (AC: #2, #3)

    /// Starts background batch transcription for all unprocessed tags in `session`.
    /// No-op if a batch is already running.
    /// Call `cancelBatch()` to stop early.
    func startBatchTranscription(session: Session) {
        guard !isBatchTranscribing, !isTranscribing else {
            logger.info("TranscriptionEngine: transcription already in progress — ignoring batch start request")
            return
        }
        logger.info("TranscriptionEngine: starting batch for session '\(session.title)'")
        batchTask = Task {
            await self.transcribeAllTags(in: session)
        }
    }

    /// Processes all tags in `session` with `transcription == nil` one at a time.
    ///
    /// Updates `batchCompleted` after every tag (success or failure).
    /// Per-tag failures are recorded in `batchErrors`; other tags continue processing.
    /// Stops early when the enclosing task is cancelled.
    func transcribeAllTags(in session: Session) async {
        let unprocessedTags = session.tags.filter { $0.transcription == nil }
        guard !unprocessedTags.isEmpty else {
            logger.info("TranscriptionEngine: all tags already transcribed in '\(session.title)'")
            return
        }

        logger.info("TranscriptionEngine: batch — \(unprocessedTags.count) tags in '\(session.title)'")
        isBatchTranscribing = true
        batchTotal = unprocessedTags.count
        batchCompleted = 0
        batchErrors = []

        defer {
            isBatchTranscribing = false
            batchTask = nil
            logger.info("TranscriptionEngine: batch done — \(self.batchCompleted)/\(self.batchTotal), \(self.batchErrors.count) errors")
        }

        for tag in unprocessedTags {
            // Check for cancellation between tags — stops after current tag completes
            if Task.isCancelled {
                logger.info("TranscriptionEngine: batch cancelled before '\(tag.label)'")
                break
            }

            do {
                try await transcribeTag(tag, session: session)
                batchCompleted += 1
            } catch is CancellationError {
                logger.info("TranscriptionEngine: batch cancelled during '\(tag.label)'")
                break
            } catch {
                // Per-tag error isolation (AC: #4) — record failure, continue batch
                logger.error("TranscriptionEngine: batch error for '\(tag.label)' — \(error.localizedDescription)")
                batchErrors.append((tag: tag, error: error))
                batchCompleted += 1
            }
        }
    }

    // MARK: - Retry (AC: #4)

    /// Clears any previously recorded errors for `tag` and re-attempts transcription.
    func retryTag(_ tag: Tag, session: Session) async throws {
        batchErrors.removeAll { $0.tag.uuid == tag.uuid }
        // tagErrors is cleared automatically at the start of transcribeTag
        try await transcribeTag(tag, session: session)
    }

    // MARK: - Cancel Batch (AC: #3)

    /// Cancels the running batch after the current tag finishes.
    func cancelBatch() {
        batchTask?.cancel()
        batchTask = nil
        logger.info("TranscriptionEngine: batch cancellation requested")
    }

    // MARK: - Private: Run Transcription Off Main Thread

    private func runTranscription(tag: Tag, session: Session) async throws -> String {
        // Validate audio path on @MainActor before hopping off
        guard let rawAudioPath = session.audioFilePath else {
            logger.error("TranscriptionEngine: session '\(session.title)' has no audioFilePath")
            throw DictlyError.transcription(.audioFileNotFound)
        }
        let audioPath = AudioFileManager.resolvedAudioPath(rawAudioPath)
        guard FileManager.default.fileExists(atPath: audioPath) else {
            logger.error("TranscriptionEngine: audio file missing at \(audioPath)")
            throw DictlyError.transcription(.audioFileNotFound)
        }

        // Capture value types before crossing actor boundary
        let anchorTime = tag.anchorTime
        let rewindDuration = tag.rewindDuration
        let modelURL = modelManager.activeModelURL
        let language = modelManager.selectedLanguage
        let bridge = whisperBridge   // WhisperBridge is @unchecked Sendable

        logger.debug("TranscriptionEngine: dispatch transcription off main — anchor=\(anchorTime), rewind=\(rewindDuration)")

        return try await Task.detached(priority: .userInitiated) {
            let audioURL = URL(fileURLWithPath: audioPath)

            // Segment window: (anchorTime - rewindDuration) → (anchorTime + remaining) ≈ 30 s total
            let start = max(0, anchorTime - rewindDuration)
            let remainingAfterAnchor = 30.0 - (anchorTime - start)
            let segmentDuration = max(0, remainingAfterAnchor + (anchorTime - start))

            let segmentURL = try TranscriptionEngine.extractAudioSegment(
                from: audioURL,
                start: start,
                duration: segmentDuration
            )
            defer {
                try? FileManager.default.removeItem(at: segmentURL)
                logger.debug("TranscriptionEngine: cleaned up segment \(segmentURL.lastPathComponent)")
            }

            return try await bridge.transcribe(audioURL: segmentURL, modelURL: modelURL, language: language)
        }.value
    }

    // MARK: - Audio Segment Extraction (Tasks 2.1–2.5)

    /// Extracts a time-windowed audio segment into a temporary CAF file.
    ///
    /// `start` is clamped to 0 if negative. `start + duration` is clamped to the file length.
    /// Caller is responsible for deleting the returned temp file after use.
    ///
    /// - Parameters:
    ///   - audioURL: Source session audio file.
    ///   - start: Start time in seconds (may be clamped to 0).
    ///   - duration: Desired duration in seconds (end will be clamped to file length).
    /// - Returns: URL of a temporary CAF file containing the segment.
    /// - Throws: `DictlyError.transcription(.audioFileNotFound)` if audio cannot be opened or segment is empty.
    ///           `DictlyError.transcription(.audioConversionFailed)` if extraction fails.
    nonisolated static func extractAudioSegment(from audioURL: URL, start: TimeInterval, duration: TimeInterval) throws -> URL {
        logger.debug("TranscriptionEngine: extractAudioSegment start=\(start) duration=\(duration)")

        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: audioURL)
        } catch {
            logger.error("TranscriptionEngine: cannot open audio file — \(error.localizedDescription)")
            throw DictlyError.transcription(.audioFileNotFound)
        }

        let format = audioFile.processingFormat
        let sampleRate = format.sampleRate
        let totalFrames = audioFile.length
        let totalDuration = Double(totalFrames) / sampleRate

        // Clamp segment to [0, totalDuration]
        let clampedStart = max(0, start)
        let clampedEnd = min(totalDuration, start + duration)
        let clampedDuration = max(0, clampedEnd - clampedStart)

        logger.debug("TranscriptionEngine: clamped segment [\(clampedStart), \(clampedEnd)] (file=\(totalDuration)s)")

        let startFrame = AVAudioFramePosition(clampedStart * sampleRate)
        let frameCount = AVAudioFrameCount(clampedDuration * sampleRate)

        guard frameCount > 0 else {
            logger.error("TranscriptionEngine: zero frames after clamping — segment window is outside file bounds (start=\(clampedStart), end=\(clampedEnd))")
            throw DictlyError.transcription(.audioConversionFailed)
        }

        audioFile.framePosition = startFrame

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            logger.error("TranscriptionEngine: failed to allocate PCM buffer (\(frameCount) frames)")
            throw DictlyError.transcription(.audioConversionFailed)
        }

        do {
            try audioFile.read(into: buffer, frameCount: frameCount)
        } catch {
            logger.error("TranscriptionEngine: read failed — \(error.localizedDescription)")
            throw DictlyError.transcription(.audioConversionFailed)
        }

        // Write extracted segment to a temp CAF file
        let segmentURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictly_segment_\(UUID().uuidString).caf")

        let writeSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: true
        ]

        do {
            let outputFile = try AVAudioFile(forWriting: segmentURL, settings: writeSettings)
            try outputFile.write(from: buffer)
        } catch {
            logger.error("TranscriptionEngine: write segment failed — \(error.localizedDescription)")
            throw DictlyError.transcription(.audioConversionFailed)
        }

        logger.debug("TranscriptionEngine: segment written to \(segmentURL.lastPathComponent)")
        return segmentURL
    }
}
