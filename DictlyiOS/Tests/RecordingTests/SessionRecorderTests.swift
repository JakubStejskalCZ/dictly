import XCTest
import AVFoundation
import SwiftData
@testable import DictlyiOS
import DictlyModels
import DictlyStorage

@MainActor
final class SessionRecorderTests: XCTestCase {

    // MARK: - 7.2 Initialization

    func testInitialState() {
        let recorder = SessionRecorder()
        XCTAssertFalse(recorder.isRecording, "isRecording should be false initially")
        XCTAssertFalse(recorder.isPaused, "isPaused should be false initially")
        XCTAssertEqual(recorder.elapsedTime, 0, "elapsedTime should be 0 initially")
        XCTAssertEqual(recorder.currentAudioLevel, 0, "currentAudioLevel should be 0 initially")
    }

    // MARK: - 7.5 Crash Recovery

    func testRecoverOrphanedRecording_updatesSessionDuration() throws {
        // Create an in-memory SwiftData container for testing
        let schema = Schema(DictlySchema.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        // Create a real (minimal) .m4a audio file at the expected location
        let dir = try AudioFileManager.audioStorageDirectory()
        let filename = "\(UUID().uuidString).m4a"
        let fileURL = dir.appendingPathComponent(filename)

        // Write a valid minimal AAC file using AVAudioFile
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64000
        ]
        try writeTestAudioFile(to: fileURL, settings: settings, frameCount: 44100)

        defer { try? FileManager.default.removeItem(at: fileURL) }

        // Insert an orphaned session (audioFilePath set, duration == 0)
        let session = Session(title: "Test", sessionNumber: 1, audioFilePath: filename)
        context.insert(session)
        try context.save()

        // Run recovery
        SessionRecorder.recoverOrphanedRecordings(context: context)

        // Fetch the session back and verify duration was populated
        let descriptor = FetchDescriptor<Session>()
        let sessions = try context.fetch(descriptor)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertGreaterThan(sessions[0].duration, 0, "Duration should be populated after recovery")
    }

    func testRecoverOrphanedRecording_skipsSessionWithNilPath() throws {
        let schema = Schema(DictlySchema.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        let session = Session(title: "No Audio", sessionNumber: 1, audioFilePath: nil)
        context.insert(session)
        try context.save()

        // Should not throw and duration stays 0
        SessionRecorder.recoverOrphanedRecordings(context: context)

        let descriptor = FetchDescriptor<Session>()
        let sessions = try context.fetch(descriptor)
        XCTAssertEqual(sessions[0].duration, 0, "Duration should remain 0 when audioFilePath is nil")
    }

    func testRecoverOrphanedRecording_skipsEmptyFile() throws {
        let schema = Schema(DictlySchema.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        // Create an empty/header-only .m4a file
        let dir = try AudioFileManager.audioStorageDirectory()
        let filename = "\(UUID().uuidString).m4a"
        let fileURL = dir.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64000
        ]
        // Create file but write no buffers (length == 0)
        try writeTestAudioFile(to: fileURL, settings: settings, frameCount: 0)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let session = Session(title: "Empty", sessionNumber: 1, audioFilePath: filename)
        context.insert(session)
        try context.save()

        SessionRecorder.recoverOrphanedRecordings(context: context)

        let descriptor = FetchDescriptor<Session>()
        let sessions = try context.fetch(descriptor)
        XCTAssertEqual(sessions[0].duration, 0, "Duration should remain 0 for a file with no audio frames")
    }

    // MARK: - Helpers

    /// Creates an .m4a file at `url`, writes `frameCount` silent PCM frames, then closes.
    /// Using a helper function ensures the AVAudioFile is deallocated (finalized) before returning.
    private func writeTestAudioFile(to url: URL, settings: [String: Any], frameCount: AVAudioFrameCount) throws {
        let audioFile = try AVAudioFile(forWriting: url, settings: settings)
        if frameCount > 0 {
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
            buffer.frameLength = frameCount
            try audioFile.write(from: buffer)
        }
        // audioFile deallocates here, finalizing the file on disk
    }

    // MARK: - 8.2 Pause state (guard conditions)

    func testPauseRecording_noopWhenNotRecording() {
        let recorder = SessionRecorder()
        recorder.pauseRecording()
        XCTAssertFalse(recorder.isPaused, "pauseRecording() should be a no-op when not recording")
        XCTAssertFalse(recorder.isRecording)
    }

    func testPauseRecording_noopWhenAlreadyPaused() {
        let recorder = SessionRecorder()
        // Both guards fail: isRecording == false
        recorder.pauseRecording()
        recorder.pauseRecording()
        XCTAssertFalse(recorder.isPaused)
    }

    // MARK: - 8.3 Resume state (guard conditions)

    func testResumeRecording_noopWhenNotRecording() {
        let recorder = SessionRecorder()
        recorder.resumeRecording()
        XCTAssertFalse(recorder.isPaused, "resumeRecording() should be a no-op when not recording")
        XCTAssertFalse(recorder.isRecording)
    }

    // MARK: - 8.4 wasInterruptedBySystem state

    func testWasInterruptedBySystem_initiallyFalse() {
        let recorder = SessionRecorder()
        XCTAssertFalse(recorder.wasInterruptedBySystem, "wasInterruptedBySystem should be false initially")
    }

    func testStopRecording_noopWhenNotRecording() {
        let recorder = SessionRecorder()
        // Should not crash or change state unexpectedly
        recorder.stopRecording()
        XCTAssertFalse(recorder.isRecording)
        XCTAssertFalse(recorder.isPaused)
        XCTAssertFalse(recorder.wasInterruptedBySystem)
    }

    // MARK: - 8.5 PauseInterval Codable round-trip

    func testPauseInterval_codableRoundTrip() throws {
        let interval = PauseInterval(start: 12.5, end: 45.0)
        let data = try JSONEncoder().encode(interval)
        let decoded = try JSONDecoder().decode(PauseInterval.self, from: data)
        XCTAssertEqual(decoded.start, 12.5, accuracy: 0.001)
        XCTAssertEqual(decoded.end, 45.0, accuracy: 0.001)
        XCTAssertEqual(decoded, interval)
    }

    func testPauseIntervalArray_codableRoundTrip() throws {
        let intervals = [PauseInterval(start: 0, end: 5.5), PauseInterval(start: 10.0, end: 20.75)]
        let data = try JSONEncoder().encode(intervals)
        let decoded = try JSONDecoder().decode([PauseInterval].self, from: data)
        XCTAssertEqual(decoded, intervals)
    }

    func testPauseInterval_equatable() {
        let a = PauseInterval(start: 1.0, end: 2.0)
        let b = PauseInterval(start: 1.0, end: 2.0)
        let c = PauseInterval(start: 1.0, end: 3.0)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - 8.6 pauseIntervalsJSON on Session

    func testSession_pauseIntervals_emptyWhenNilJSON() throws {
        let schema = Schema(DictlySchema.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        let session = Session(title: "Test", sessionNumber: 1)
        context.insert(session)

        XCTAssertNil(session.pauseIntervalsJSON, "pauseIntervalsJSON should be nil by default")
        XCTAssertEqual(session.pauseIntervals, [], "pauseIntervals should be empty when JSON is nil")
    }

    func testSession_pauseIntervals_encodesAndDecodes() throws {
        let schema = Schema(DictlySchema.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        let session = Session(title: "Test", sessionNumber: 1)
        context.insert(session)

        let intervals = [PauseInterval(start: 5.0, end: 10.0), PauseInterval(start: 30.0, end: 45.0)]
        session.pauseIntervals = intervals
        try context.save()

        let descriptor = FetchDescriptor<Session>()
        let sessions = try context.fetch(descriptor)
        XCTAssertEqual(sessions.count, 1)

        let decoded = sessions[0].pauseIntervals
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].start, 5.0, accuracy: 0.001)
        XCTAssertEqual(decoded[0].end, 10.0, accuracy: 0.001)
        XCTAssertEqual(decoded[1].start, 30.0, accuracy: 0.001)
        XCTAssertEqual(decoded[1].end, 45.0, accuracy: 0.001)
    }

    func testSession_pauseIntervals_clearsWhenSetToEmpty() throws {
        let schema = Schema(DictlySchema.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        let session = Session(title: "Test", sessionNumber: 1)
        context.insert(session)
        session.pauseIntervals = [PauseInterval(start: 1.0, end: 2.0)]
        XCTAssertNotNil(session.pauseIntervalsJSON)

        session.pauseIntervals = []
        // Empty array clears JSON to nil (matching the doc: "Nil when no pauses occurred")
        XCTAssertNil(session.pauseIntervalsJSON)
        XCTAssertEqual(session.pauseIntervals, [])
    }

    // MARK: - 7.6 DictlyError RecordingError cases

    func testRecordingErrorDescriptions() {
        XCTAssertEqual(
            DictlyError.recording(.audioSessionSetupFailed("test")).localizedDescription,
            "Audio session setup failed: test"
        )
        XCTAssertEqual(
            DictlyError.recording(.engineStartFailed("test")).localizedDescription,
            "Failed to start recording engine: test"
        )
        XCTAssertEqual(
            DictlyError.recording(.fileCreationFailed("test")).localizedDescription,
            "Failed to create recording file: test"
        )
        XCTAssertEqual(
            DictlyError.recording(.diskFull).localizedDescription,
            "Not enough disk space to continue recording."
        )
    }

    // MARK: - Story 2.7: Audio quality bitrate mapping

    func testBitrate_standardGives64kbps() {
        XCTAssertEqual(SessionRecorder.bitrate(for: "standard"), 64_000)
    }

    func testBitrate_highGives128kbps() {
        XCTAssertEqual(SessionRecorder.bitrate(for: "high"), 128_000)
    }

    func testBitrate_unknownValueDefaultsToStandard() {
        XCTAssertEqual(SessionRecorder.bitrate(for: ""), 64_000)
        XCTAssertEqual(SessionRecorder.bitrate(for: "ultra"), 64_000)
    }
}
