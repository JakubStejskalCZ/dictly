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
}
