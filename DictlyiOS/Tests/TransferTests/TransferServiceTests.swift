import XCTest
import SwiftData
@testable import DictlyiOS
import DictlyModels
import DictlyStorage

// MARK: - TransferServiceTests

/// Unit tests for `TransferService` — state machine and bundle preparation logic.
/// Cannot test `UIActivityViewController` presentation; focuses on:
///   - Bundle creation in temp directory
///   - State transitions
///   - Cleanup behavior
///   - Edge cases (zero tags, missing audio file)
@MainActor
final class TransferServiceTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var service: TransferService!
    var tempAudioURL: URL!

    override func setUp() async throws {
        container = try ModelContainer(
            for: Campaign.self, Session.self, Tag.self, TagCategory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
        service = TransferService()

        // Create a minimal non-empty audio file in the Recordings directory
        let recordingsDir = try AudioFileManager.audioStorageDirectory()
        tempAudioURL = recordingsDir.appendingPathComponent("\(UUID().uuidString).m4a")
        let dummyAudio = Data(repeating: 0xAA, count: 1024)
        try dummyAudio.write(to: tempAudioURL)
    }

    override func tearDown() async throws {
        // Clean up test audio file
        try? FileManager.default.removeItem(at: tempAudioURL)

        // Clean up any leftover temp bundles from service
        service.cleanupTemporaryBundle()

        container = nil
        context = nil
        service = nil
        tempAudioURL = nil
    }

    // MARK: - 6.2 prepareBundle

    func testPrepareBundle_createsDictlyDirectoryWithExpectedFiles() async throws {
        let session = makeSession(audioFilePath: tempAudioURL.path)

        let bundleURL = try await service.prepareBundle(for: session)

        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleURL.path),
                      "Bundle directory should exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("audio.aac").path),
                      "audio.aac should be present in bundle")
        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("session.json").path),
                      "session.json should be present in bundle")

        // Cleanup
        try FileManager.default.removeItem(at: bundleURL)
    }

    func testPrepareBundle_audioAacIsNonEmpty() async throws {
        let session = makeSession(audioFilePath: tempAudioURL.path)

        let bundleURL = try await service.prepareBundle(for: session)
        defer { try? FileManager.default.removeItem(at: bundleURL) }

        let audioData = try Data(contentsOf: bundleURL.appendingPathComponent("audio.aac"))
        XCTAssertFalse(audioData.isEmpty, "audio.aac should contain audio bytes")
    }

    func testPrepareBundle_sessionJsonIsValidJSON() async throws {
        let session = makeSession(audioFilePath: tempAudioURL.path)

        let bundleURL = try await service.prepareBundle(for: session)
        defer { try? FileManager.default.removeItem(at: bundleURL) }

        let jsonData = try Data(contentsOf: bundleURL.appendingPathComponent("session.json"))
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: jsonData), "session.json should be valid JSON")
    }

    // MARK: - 6.3 State: idle → preparing → sharing → completed

    func testStateTransitions_idleToSharingViaShareViaAirDrop() async {
        XCTAssertEqual(service.transferState, .idle, "Initial state should be idle")
        let session = makeSession(audioFilePath: tempAudioURL.path)

        await service.shareViaAirDrop(session: session)

        // shareViaAirDrop sets .sharing after successful bundle preparation
        XCTAssertEqual(service.transferState, .sharing, "State should be .sharing after shareViaAirDrop succeeds")
        service.cleanupTemporaryBundle()
    }

    func testStateTransitions_sharingToCompleted() async {
        let session = makeSession(audioFilePath: tempAudioURL.path)

        await service.shareViaAirDrop(session: session)
        XCTAssertEqual(service.transferState, .sharing, "Precondition: state should be .sharing")

        service.handleShareCompletion(completed: true, error: nil)

        XCTAssertEqual(service.transferState, .completed, "State should be .completed after successful share")
    }

    func testStateTransitions_sharingToIdleOnCancel() async {
        let session = makeSession(audioFilePath: tempAudioURL.path)

        await service.shareViaAirDrop(session: session)

        // completed=false, error=nil means user cancelled
        service.handleShareCompletion(completed: false, error: nil)

        XCTAssertEqual(service.transferState, .idle, "Cancelled share should return to .idle")
    }

    // MARK: - 6.4 State: idle → preparing → failed (missing audio)

    func testStateTransitions_failedWhenAudioFileMissing() async {
        let session = makeSession(audioFilePath: "/nonexistent/path/audio.m4a")

        await service.shareViaAirDrop(session: session)

        if case .failed = service.transferState {
            // expected
        } else {
            XCTFail("State should be .failed for missing audio file, got \(service.transferState)")
        }
    }

    func testStateTransitions_failedWhenSessionHasNoAudioFilePath() async {
        let session = makeSession(audioFilePath: nil)

        await service.shareViaAirDrop(session: session)

        if case .failed = service.transferState {
            // expected
        } else {
            XCTFail("State should be .failed when audioFilePath is nil, got \(service.transferState)")
        }
    }

    func testShareViaAirDrop_setsFailedStateWhenAudioMissing() async {
        let session = makeSession(audioFilePath: "/nonexistent/audio.m4a")

        await service.shareViaAirDrop(session: session)

        if case .failed = service.transferState {
            // expected
        } else {
            XCTFail("Expected .failed state, got \(service.transferState)")
        }
    }

    // MARK: - 6.5 cleanupTemporaryBundle

    func testCleanupTemporaryBundle_removesTempDirectory() async {
        let session = makeSession(audioFilePath: tempAudioURL.path)

        await service.shareViaAirDrop(session: session)
        guard let bundleURL = service.temporaryBundleURL else {
            XCTFail("temporaryBundleURL should be set after shareViaAirDrop")
            return
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleURL.path),
                      "Bundle should exist before cleanup")

        service.cleanupTemporaryBundle()

        XCTAssertFalse(FileManager.default.fileExists(atPath: bundleURL.path),
                       "Bundle should be removed after cleanup")
        XCTAssertNil(service.temporaryBundleURL, "temporaryBundleURL should be nil after cleanup")
    }

    func testCleanupTemporaryBundle_isIdempotent() {
        // Calling cleanup with no bundle set should not throw
        service.cleanupTemporaryBundle()
        service.cleanupTemporaryBundle()
        XCTAssertNil(service.temporaryBundleURL)
    }

    func testHandleShareCompletion_cleansUpBundleOnSuccess() async {
        let session = makeSession(audioFilePath: tempAudioURL.path)

        await service.shareViaAirDrop(session: session)
        guard let bundleURL = service.temporaryBundleURL else {
            XCTFail("temporaryBundleURL should be set after shareViaAirDrop")
            return
        }

        service.handleShareCompletion(completed: true, error: nil)

        XCTAssertNil(service.temporaryBundleURL, "Bundle URL should be cleared after completion")
        XCTAssertFalse(FileManager.default.fileExists(atPath: bundleURL.path),
                       "Bundle directory should be deleted after completion")
    }

    // MARK: - 6.6 Edge case: session with zero tags

    func testPrepareBundle_sessionWithZeroTags() async throws {
        // Session with no tags should serialize successfully
        let session = makeSession(audioFilePath: tempAudioURL.path, tagCount: 0)

        let bundleURL = try await service.prepareBundle(for: session)
        defer { try? FileManager.default.removeItem(at: bundleURL) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleURL.path),
                      "Bundle should be created even with zero tags")

        let jsonData = try Data(contentsOf: bundleURL.appendingPathComponent("session.json"))
        XCTAssertFalse(jsonData.isEmpty, "session.json should not be empty for zero-tag session")
    }

    // MARK: - Reset

    func testReset_returnsToIdle() async throws {
        let session = makeSession(audioFilePath: tempAudioURL.path)

        let bundleURL = try await service.prepareBundle(for: session)
        defer { try? FileManager.default.removeItem(at: bundleURL) }

        service.handleShareCompletion(completed: true, error: nil)
        XCTAssertEqual(service.transferState, .completed)

        service.reset()
        XCTAssertEqual(service.transferState, .idle, "reset() should return to .idle")
    }

    // MARK: - Helpers

    private func makeSession(audioFilePath: String?, tagCount: Int = 2) -> Session {
        let session = Session(
            title: "Test Session",
            sessionNumber: 1,
            audioFilePath: audioFilePath
        )
        context.insert(session)

        for i in 0..<tagCount {
            let tag = Tag(label: "Tag \(i)", categoryName: "Story", anchorTime: Double(i) * 10.0, rewindDuration: 0)
            tag.session = session
            context.insert(tag)
        }

        return session
    }
}
