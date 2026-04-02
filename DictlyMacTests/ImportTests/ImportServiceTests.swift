import XCTest
@testable import DictlyMac
import SwiftData
import DictlyModels
import DictlyStorage

// MARK: - ImportServiceTests
//
// Tests for ImportService: import, deduplication, campaign resolution,
// replace/skip flows, audio storage, and error handling.
//
// Note: Mac test target requires dev signing certificate to run locally due to
// iCloud entitlement on the host app (pre-existing constraint from story 3.3).
// The test target builds cleanly (** TEST BUILD SUCCEEDED **) even without signing.

@MainActor
final class ImportServiceTests: XCTestCase {

    var importService: ImportService!
    var container: ModelContainer!
    var context: ModelContext!
    var tempBundleDir: URL!

    override func setUp() async throws {
        importService = ImportService()

        // In-memory SwiftData container
        let schema = Schema(DictlySchema.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext

        tempBundleDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImportServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempBundleDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        cleanupImportedAudio()
        importService = nil
        container = nil
        context = nil
        try? FileManager.default.removeItem(at: tempBundleDir)
    }

    // MARK: - Bundle Builder

    private func makeBundle(
        uuid: UUID = UUID(),
        title: String = "Test Session",
        sessionNumber: Int = 1,
        tags: [TagDTO] = [],
        campaign: CampaignDTO? = nil,
        audioData: Data = Data(repeating: 0xCC, count: 1024)
    ) throws -> URL {
        let sessionDTO = SessionDTO(
            uuid: uuid,
            title: title,
            sessionNumber: sessionNumber,
            date: Date(),
            duration: 60,
            locationName: nil,
            summaryNote: nil,
            pauseIntervals: []
        )

        let bundle = TransferBundle(version: 1, session: sessionDTO, tags: tags, campaign: campaign)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(bundle)

        let bundleURL = tempBundleDir.appendingPathComponent("\(uuid).dictly", isDirectory: true)
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try jsonData.write(to: bundleURL.appendingPathComponent("session.json"))
        try audioData.write(to: bundleURL.appendingPathComponent("audio.aac"))

        return bundleURL
    }

    // MARK: - 6.2 Successful import: session + tags + campaign written, audio copied, state transitions

    func testImportBundle_success_writesSessionTagsCampaign() async throws {
        let tagDTO = TagDTO(
            uuid: UUID(), label: "Boss Fight", categoryName: "Combat",
            anchorTime: 10, rewindDuration: 5,
            notes: nil, transcription: nil, createdAt: Date()
        )
        let campaignDTO = CampaignDTO(
            uuid: UUID(), name: "Test Campaign", descriptionText: "", createdAt: Date()
        )
        let bundleURL = try makeBundle(tags: [tagDTO], campaign: campaignDTO)

        importService.importBundle(from: bundleURL, context: context)

        // Immediately .importing
        if case .importing = importService.importState { } else {
            XCTFail("State should be .importing immediately; got \(importService.importState)")
        }

        await waitForTerminalState()

        guard case .completed(let title) = importService.importState else {
            XCTFail("Expected .completed, got \(importService.importState)")
            return
        }
        XCTAssertEqual(title, "Test Session")

        let sessions = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].tags.count, 1)
        XCTAssertEqual(sessions[0].tags[0].label, "Boss Fight")
        XCTAssertEqual(sessions[0].campaign?.name, "Test Campaign")
        XCTAssertNotNil(sessions[0].audioFilePath)
    }

    // MARK: - 6.3 Deduplication: second import of same UUID → .duplicate, session count unchanged

    func testImportBundle_duplicate_showsDuplicateStateAndNoExtraSession() async throws {
        let sharedUUID = UUID()

        // First import
        let bundle1 = try makeBundle(uuid: sharedUUID)
        importService.importBundle(from: bundle1, context: context)
        await waitForTerminalState()
        guard case .completed = importService.importState else {
            XCTFail("First import should succeed")
            return
        }
        importService.skipDuplicate()

        // Second import with same UUID
        let bundle2 = try makeBundle(uuid: sharedUUID)
        importService.importBundle(from: bundle2, context: context)
        await waitForTerminalState()

        guard case .duplicate(let title) = importService.importState else {
            XCTFail("Expected .duplicate on second import, got \(importService.importState)")
            return
        }
        XCTAssertEqual(title, "Test Session")

        let sessions = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(sessions.count, 1, "Duplicate import must not create an extra session")
    }

    // MARK: - 6.4 Replace flow: old session deleted, new session created

    func testReplaceExistingDuplicate_deletesOldAndCreatesNew() async throws {
        let sharedUUID = UUID()

        // First import
        let bundle1 = try makeBundle(uuid: sharedUUID)
        importService.importBundle(from: bundle1, context: context)
        await waitForTerminalState()
        guard case .completed = importService.importState else { XCTFail("First import failed"); return }
        importService.skipDuplicate()

        // Second import → duplicate
        let bundle2 = try makeBundle(uuid: sharedUUID)
        importService.importBundle(from: bundle2, context: context)
        await waitForTerminalState()
        guard case .duplicate = importService.importState else { XCTFail("Expected .duplicate"); return }

        // Replace
        importService.replaceExistingDuplicate()
        await waitForTerminalState()

        guard case .completed = importService.importState else {
            XCTFail("Expected .completed after replace, got \(importService.importState)")
            return
        }

        let sessions = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(sessions.count, 1, "Replace should result in exactly 1 session")
        XCTAssertEqual(sessions[0].uuid, sharedUUID)
    }

    // MARK: - 6.5 Skip flow: state → .idle, data unchanged

    func testSkipDuplicate_returnsToIdle_noDataChange() async throws {
        let sharedUUID = UUID()

        // First import
        let bundle1 = try makeBundle(uuid: sharedUUID)
        importService.importBundle(from: bundle1, context: context)
        await waitForTerminalState()
        guard case .completed = importService.importState else { XCTFail("First import failed"); return }
        importService.skipDuplicate()

        // Second import → duplicate
        let bundle2 = try makeBundle(uuid: sharedUUID)
        importService.importBundle(from: bundle2, context: context)
        await waitForTerminalState()
        guard case .duplicate = importService.importState else { XCTFail("Expected .duplicate"); return }

        // Skip
        importService.skipDuplicate()

        XCTAssertEqual(importService.importState, .idle)
        let sessions = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(sessions.count, 1, "Skip must not add or remove sessions")
    }

    // MARK: - 6.6 Campaign auto-creation: bundle campaign UUID not in SwiftData → new campaign

    func testImportBundle_campaignNotInStore_createsCampaign() async throws {
        let campaignDTO = CampaignDTO(
            uuid: UUID(), name: "Brand New Campaign", descriptionText: "New", createdAt: Date()
        )
        let bundleURL = try makeBundle(campaign: campaignDTO)

        importService.importBundle(from: bundleURL, context: context)
        await waitForTerminalState()
        guard case .completed = importService.importState else { XCTFail("Import failed"); return }

        let campaigns = try context.fetch(FetchDescriptor<Campaign>())
        XCTAssertEqual(campaigns.count, 1, "Import should create a new campaign")
        XCTAssertEqual(campaigns[0].name, "Brand New Campaign")
    }

    // MARK: - 6.7 Campaign reuse: matching UUID → existing campaign used

    func testImportBundle_campaignInStore_reusesExistingCampaign() async throws {
        let campaignUUID = UUID()
        let existing = Campaign(uuid: campaignUUID, name: "Existing", descriptionText: "", createdAt: Date())
        context.insert(existing)
        try context.save()

        let campaignDTO = CampaignDTO(uuid: campaignUUID, name: "Existing", descriptionText: "", createdAt: Date())
        let bundleURL = try makeBundle(campaign: campaignDTO)

        importService.importBundle(from: bundleURL, context: context)
        await waitForTerminalState()
        guard case .completed = importService.importState else { XCTFail("Import failed"); return }

        let campaigns = try context.fetch(FetchDescriptor<Campaign>())
        XCTAssertEqual(campaigns.count, 1, "No duplicate campaign should be created")

        let sessions = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(sessions[0].campaign?.uuid, campaignUUID)
    }

    // MARK: - 6.8 Invalid bundle: missing files → .failed

    func testImportBundle_invalidBundle_transitionsToFailed() async throws {
        let invalidURL = tempBundleDir.appendingPathComponent("not-a-bundle", isDirectory: true)
        try FileManager.default.createDirectory(at: invalidURL, withIntermediateDirectories: true)
        // Missing audio.aac and session.json → BundleSerializer throws

        importService.importBundle(from: invalidURL, context: context)
        await waitForTerminalState()

        guard case .failed = importService.importState else {
            XCTFail("Expected .failed for invalid bundle, got \(importService.importState)")
            return
        }
    }

    // MARK: - 6.9 Audio file storage: written to AudioFileManager.audioStorageDirectory()/{uuid}.aac

    func testImportBundle_audioStoredAtCorrectPath() async throws {
        let sessionUUID = UUID()
        let audioData = Data(repeating: 0xAA, count: 2048)
        let bundleURL = try makeBundle(uuid: sessionUUID, audioData: audioData)

        importService.importBundle(from: bundleURL, context: context)
        await waitForTerminalState()
        guard case .completed = importService.importState else { XCTFail("Import failed"); return }

        let sessions = try context.fetch(FetchDescriptor<Session>())
        guard let audioPath = sessions.first?.audioFilePath else {
            XCTFail("Session must have audioFilePath")
            return
        }

        let storageDir = try AudioFileManager.audioStorageDirectory()
        XCTAssertTrue(audioPath.hasPrefix(storageDir.path),
                      "Audio must be in AudioFileManager.audioStorageDirectory()")
        XCTAssertTrue(audioPath.hasSuffix("\(sessionUUID).aac"),
                      "Audio filename must be {uuid}.aac")

        let writtenData = try Data(contentsOf: URL(fileURLWithPath: audioPath))
        XCTAssertEqual(writtenData, audioData, "Audio content must match original")
    }

    // MARK: - ImportError errorDescription coverage

    func testImportErrors_haveNonEmptyDescriptions() {
        let cases: [DictlyError] = [
            .import(.invalidFormat),
            .import(.duplicateDetected),
            .import(.missingData)
        ]
        for error in cases {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty, "errorDescription must not be empty for \(error)")
        }
    }

    // MARK: - Helpers

    /// Polls until ImportState is no longer .importing or .idle-before-start.
    private func waitForTerminalState(timeout: TimeInterval = 5.0) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            switch importService.importState {
            case .completed, .duplicate, .failed:
                return
            case .idle, .importing:
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    /// Removes any audio files created by the import service during the test.
    private func cleanupImportedAudio() {
        guard let sessions = try? context?.fetch(FetchDescriptor<Session>()) else { return }
        for session in sessions {
            if let path = session.audioFilePath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
    }
}

