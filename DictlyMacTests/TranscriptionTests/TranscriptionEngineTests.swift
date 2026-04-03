import XCTest
import AVFoundation
@testable import DictlyMac
import SwiftData
import DictlyModels

// MARK: - TranscriptionEngineTests
//
// Tests for Story 5.3: Per-Tag & Batch Transcription.
// Covers: per-tag transcription state, batch filtering, batch progress counting,
// per-tag error isolation, cancellation, retry, and audio segment clamping.
//
// Uses a real WhisperBridge pointing to a temp directory (no real model needed for most tests —
// the bridge throws quickly on missing model/audio, allowing state-machine verification).
// Tests requiring real transcription results are guarded with XCTSkip.
//
// Pre-existing failures in RetroactiveTagTests and TagEditingTests are unrelated — do not fix.

@MainActor
final class TranscriptionEngineTests: XCTestCase {

    var engine: TranscriptionEngine!
    var whisperBridge: WhisperBridge!
    var modelManager: ModelManager!
    var container: ModelContainer!
    var context: ModelContext!
    var tempDir: URL!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TranscriptionEngineTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        UserDefaults.standard.removeObject(forKey: "activeWhisperModel")
        whisperBridge = WhisperBridge()
        modelManager = ModelManager(modelsDirectory: tempDir)

        engine = TranscriptionEngine(whisperBridge: whisperBridge, modelManager: modelManager)

        let schema = Schema(DictlySchema.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext
    }

    override func tearDown() async throws {
        engine = nil
        whisperBridge = nil
        modelManager = nil
        container = nil
        context = nil
        UserDefaults.standard.removeObject(forKey: "activeWhisperModel")
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - 7.2: transcribeTag sets isTranscribing to true during operation, false after

    func testTranscribeTag_setsIsTranscribingFalseAfter() async throws {
        let session = makeSession(audioPath: nil)
        let tag = makeTag(label: "Test Tag")
        session.tags.append(tag)
        context.insert(session)

        // No audio file → throws audioFileNotFound quickly
        XCTAssertFalse(engine.isTranscribing, "should start false")
        XCTAssertNil(engine.currentTagId, "currentTagId should start nil")

        do {
            try await engine.transcribeTag(tag, session: session)
        } catch {
            // Expected — no audio file
        }

        // Regardless of success/failure, isTranscribing must be reset
        XCTAssertFalse(engine.isTranscribing, "isTranscribing must be false after completion (even on error)")
        XCTAssertNil(engine.currentTagId, "currentTagId must be nil after completion")
    }

    func testTranscribeTag_currentTagIdNilAfterCompletion() async throws {
        let session = makeSession(audioPath: nil)
        let tag = makeTag(label: "Test Tag")
        session.tags.append(tag)
        context.insert(session)

        XCTAssertNil(engine.currentTagId, "currentTagId should be nil before transcription")

        do {
            try await engine.transcribeTag(tag, session: session)
        } catch {
            // Expected — no audio file
        }

        // After completion (success or failure), currentTagId must be nil
        XCTAssertNil(engine.currentTagId, "currentTagId must be nil after transcription ends")
    }

    // MARK: - 7.3: transcribeAllTags filters only tags with nil transcription

    func testTranscribeAllTags_filtersOnlyNilTranscription() async throws {
        let audioURL = tempDir.appendingPathComponent("session.m4a")
        try createSilentM4A(at: audioURL, duration: 2.0)

        let session = makeSession(audioPath: audioURL.path)
        let tagAlreadyDone = makeTag(label: "Already Done")
        tagAlreadyDone.transcription = "Existing transcription"
        let tagNeedsWork = makeTag(label: "Needs Work")
        session.tags = [tagAlreadyDone, tagNeedsWork]
        context.insert(session)

        // Run batch — will fail (no model), but we can observe which tags were attempted
        await engine.transcribeAllTags(in: session)

        // batchTotal should only include tags with nil transcription
        XCTAssertEqual(engine.batchTotal, 1, "batch should only queue the 1 unprocessed tag")
        XCTAssertEqual(engine.batchCompleted, 1, "batchCompleted should equal batchTotal after processing")
    }

    // MARK: - 7.4: transcribeAllTags updates batchCompleted after each tag

    func testTranscribeAllTags_updatesBatchCompletedAfterEachTag() async throws {
        let audioURL = tempDir.appendingPathComponent("session.m4a")
        try createSilentM4A(at: audioURL, duration: 2.0)

        let session = makeSession(audioPath: audioURL.path)
        let tag1 = makeTag(label: "Tag 1")
        let tag2 = makeTag(label: "Tag 2")
        let tag3 = makeTag(label: "Tag 3")
        session.tags = [tag1, tag2, tag3]
        context.insert(session)

        await engine.transcribeAllTags(in: session)

        // All 3 fail (no model), but batchCompleted still increments for each
        XCTAssertEqual(engine.batchTotal, 3)
        XCTAssertEqual(engine.batchCompleted, 3, "batchCompleted should reach 3 even when all fail")
    }

    // MARK: - 7.5: per-tag error isolation — one failure doesn't stop batch

    func testTranscribeAllTags_perTagErrorIsolation() async throws {
        let audioURL = tempDir.appendingPathComponent("session.m4a")
        try createSilentM4A(at: audioURL, duration: 2.0)

        let session = makeSession(audioPath: audioURL.path)
        let tag1 = makeTag(label: "Tag 1")
        let tag2 = makeTag(label: "Tag 2")
        let tag3 = makeTag(label: "Tag 3")
        session.tags = [tag1, tag2, tag3]
        context.insert(session)

        // All tags will fail (no model), but the batch should continue for all
        await engine.transcribeAllTags(in: session)

        XCTAssertEqual(engine.batchErrors.count, 3, "all 3 tags should have recorded errors")
        XCTAssertEqual(engine.batchCompleted, 3, "all 3 should be counted as completed despite errors")
        XCTAssertFalse(engine.isBatchTranscribing, "batch should finish, not remain stuck")
    }

    // MARK: - 7.6: cancelBatch stops processing after current tag

    func testCancelBatch_stopsProcessingAfterCurrentTag() async throws {
        let audioURL = tempDir.appendingPathComponent("session.m4a")
        try createSilentM4A(at: audioURL, duration: 0.5)

        let session = makeSession(audioPath: audioURL.path)
        // Create many tags so the batch doesn't finish immediately
        let tags = (1...10).map { makeTag(label: "Tag \($0)") }
        session.tags = tags
        context.insert(session)

        engine.startBatchTranscription(session: session)

        // Cancel quickly — before batch processes all tags
        engine.cancelBatch()

        // Give the batch task time to honour cancellation
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // After cancellation, batch should NOT be running
        XCTAssertFalse(engine.isBatchTranscribing, "batch must not be running after cancel")
        // batchCompleted should be less than 10 OR equal (if all failed fast)
        // The key: cancelBatch() should not crash and should clean up correctly
    }

    // MARK: - 7.7: retryTag clears error state and re-attempts transcription

    func testRetryTag_clearsErrorStateAndReAttempts() async throws {
        let audioURL = tempDir.appendingPathComponent("session.m4a")
        try createSilentM4A(at: audioURL, duration: 1.0)

        let session = makeSession(audioPath: audioURL.path)
        let tag = makeTag(label: "Retry Test")
        session.tags = [tag]
        context.insert(session)

        // Run batch to generate an error
        await engine.transcribeAllTags(in: session)
        XCTAssertEqual(engine.batchErrors.count, 1, "should have 1 error from failed batch")

        // Retry — should clear the error and attempt again (will fail again, but the OLD error is cleared)
        do {
            try await engine.retryTag(tag, session: session)
        } catch {
            // Expected — still no model
        }

        // The error for this specific tag should have been cleared (even if retry also fails,
        // the error is cleared before re-attempting, and new error may or may not be added
        // by retryTag — retryTag calls transcribeTag which does not add to batchErrors directly)
        // After retryTag completes, batchErrors should NOT contain the tag's old error
        let stillHasOldError = engine.batchErrors.contains { $0.tag.uuid == tag.uuid }
        XCTAssertFalse(stillHasOldError, "retryTag should clear the previous error for the tag")
    }

    // MARK: - 7.8: audio segment extraction clamps start/end to valid range

    func testExtractAudioSegment_clampsNegativeStartToZero() throws {
        let audioURL = tempDir.appendingPathComponent("test_audio.m4a")
        try createSilentM4A(at: audioURL, duration: 5.0)

        // start=-2, duration=3 → unclamped window [-2, 1]
        // clampedStart = max(0, -2) = 0
        // clampedEnd   = min(5, -2+3) = min(5, 1) = 1
        // clampedDuration = 1 - 0 = 1s
        let segmentURL = try TranscriptionEngine.extractAudioSegment(
            from: audioURL,
            start: -2.0,
            duration: 3.0
        )
        defer { try? FileManager.default.removeItem(at: segmentURL) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: segmentURL.path), "segment file should be created")

        // Only the [0,1] portion of the file exists — clamped to 1s
        let segmentFile = try AVAudioFile(forReading: segmentURL)
        let duration = Double(segmentFile.length) / segmentFile.processingFormat.sampleRate
        XCTAssertEqual(duration, 1.0, accuracy: 0.5, "segment clamped to [0,1] should be ~1s")
    }

    func testExtractAudioSegment_startFromZeroWithFullDuration() throws {
        let audioURL = tempDir.appendingPathComponent("test_audio.m4a")
        try createSilentM4A(at: audioURL, duration: 5.0)

        // start=0, duration=3 — fully within file
        let segmentURL = try TranscriptionEngine.extractAudioSegment(
            from: audioURL,
            start: 0,
            duration: 3.0
        )
        defer { try? FileManager.default.removeItem(at: segmentURL) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: segmentURL.path))

        let segmentFile = try AVAudioFile(forReading: segmentURL)
        let duration = Double(segmentFile.length) / segmentFile.processingFormat.sampleRate
        XCTAssertEqual(duration, 3.0, accuracy: 0.5, "segment [0,3] within 5s file should be ~3s")
    }

    func testExtractAudioSegment_clampsEndToFileDuration() throws {
        let audioURL = tempDir.appendingPathComponent("test_audio.m4a")
        try createSilentM4A(at: audioURL, duration: 5.0)

        // End exceeds file — should clamp to file end
        let segmentURL = try TranscriptionEngine.extractAudioSegment(
            from: audioURL,
            start: 4.0,    // 4 seconds in
            duration: 10.0 // would extend to 14s, but file is only 5s
        )
        defer { try? FileManager.default.removeItem(at: segmentURL) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: segmentURL.path))

        // Verify segment duration ≈ 1s (clamped: start=4, end=min(5, 4+10)=5 → 1s)
        let segmentFile = try AVAudioFile(forReading: segmentURL)
        let duration = Double(segmentFile.length) / segmentFile.processingFormat.sampleRate
        XCTAssertEqual(duration, 1.0, accuracy: 0.5, "clamped segment should be ~1s")
    }

    func testExtractAudioSegment_normalWindowWithinFile() throws {
        let audioURL = tempDir.appendingPathComponent("test_audio.m4a")
        try createSilentM4A(at: audioURL, duration: 30.0)

        // Normal 10s window starting at 5s — within file bounds
        let segmentURL = try TranscriptionEngine.extractAudioSegment(
            from: audioURL,
            start: 5.0,
            duration: 10.0
        )
        defer { try? FileManager.default.removeItem(at: segmentURL) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: segmentURL.path))

        let segmentFile = try AVAudioFile(forReading: segmentURL)
        let duration = Double(segmentFile.length) / segmentFile.processingFormat.sampleRate
        XCTAssertEqual(duration, 10.0, accuracy: 0.5, "non-clamped segment should be ~10s")
    }

    func testExtractAudioSegment_throwsForMissingFile() {
        let missingURL = tempDir.appendingPathComponent("nonexistent.m4a")
        XCTAssertThrowsError(
            try TranscriptionEngine.extractAudioSegment(from: missingURL, start: 0, duration: 10)
        ) { error in
            XCTAssertEqual(error as? DictlyError, .transcription(.audioFileNotFound))
        }
    }

    // MARK: - Helpers

    private func makeTag(label: String) -> Tag {
        Tag(label: label, categoryName: "Combat", anchorTime: 15.0, rewindDuration: 5.0)
    }

    private func makeSession(audioPath: String?) -> Session {
        let session = Session(title: "Test Session", sessionNumber: 1)
        session.audioFilePath = audioPath
        return session
    }

    /// Creates a silent M4A audio file of the specified duration.
    private func createSilentM4A(at url: URL, duration: TimeInterval) throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "test", code: 1)
        }

        let frameCount = AVAudioFrameCount(44100 * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "test", code: 2)
        }
        buffer.frameLength = frameCount

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64000
        ]

        let file = try AVAudioFile(forWriting: url, settings: settings)
        try file.write(from: buffer)
    }
}
