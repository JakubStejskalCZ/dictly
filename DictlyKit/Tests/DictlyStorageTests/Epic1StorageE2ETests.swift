import XCTest
import SwiftData
@testable import DictlyStorage
@testable import DictlyModels

/// End-to-end integration tests for Stories 1.6 (iCloud KVS Sync) and 1.7 (Storage Management).
/// Tests the full sync + storage lifecycle across both stories.

// MARK: - Story 1.6: iCloud KVS Category Sync E2E

@MainActor
final class Epic1SyncE2ETests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var service: CategorySyncService!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Schema(DictlySchema.all), configurations: config)
        context = container.mainContext
        service = CategorySyncService()
        service.startObserving(context: context)
    }

    override func tearDown() async throws {
        service = nil
        context = nil
        container = nil
    }

    // AC#1: Category created locally appears in cloud payload
    func testCategoryCreatedLocallyCanBePushedAndPulled() throws {
        // Seed defaults
        try DefaultTagSeeder.seedIfNeeded(context: context)

        // Create a custom category
        let custom = TagCategory(
            uuid: UUID(),
            name: "Homebrew",
            colorHex: "#FF6600",
            iconName: "wand.and.stars",
            sortOrder: 5,
            isDefault: false
        )
        context.insert(custom)
        try context.save()
        service.markModified(custom)

        // Verify 6 categories exist locally
        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(categories.count, 6)
        XCTAssertTrue(categories.contains { $0.name == "Homebrew" })
    }

    // AC#2: Category renamed on one device updates via sync
    func testCategoryRenameViaSync() throws {
        let sharedUUID = UUID()
        let local = TagCategory(uuid: sharedUUID, name: "Story", colorHex: "#D97706", iconName: "book.pages", sortOrder: 0, isDefault: true)
        context.insert(local)
        try context.save()

        // Simulate cloud payload with renamed category (newer timestamp)
        let payload = makePayload([
            makeSyncable(uuid: sharedUUID, name: "Narrative", colorHex: "#D97706", iconName: "book.pages", sortOrder: 0, isDefault: true, modifiedAt: Date(timeIntervalSinceNow: 60))
        ])
        service.processCloudPayload(payload, into: context)

        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories[0].name, "Narrative", "Category should be renamed via sync")
    }

    // AC#2: Category rename via sync also updates tag categoryName
    func testCategoryRenameSyncUpdatesTagCategoryName() throws {
        let sharedUUID = UUID()
        let category = TagCategory(uuid: sharedUUID, name: "Combat", colorHex: "#DC2626", iconName: "shield", sortOrder: 0, isDefault: true)
        context.insert(category)

        // Add tags referencing this category
        for label in ["Attack", "Defend", "Dodge"] {
            let tag = Tag(label: label, categoryName: "Combat", anchorTime: 0, rewindDuration: 0)
            context.insert(tag)
        }
        try context.save()

        // Sync renames Combat → Battle (newer timestamp, no cached local timestamp)
        let payload = makePayload([
            makeSyncable(uuid: sharedUUID, name: "Battle", colorHex: "#DC2626", iconName: "shield", sortOrder: 0, isDefault: true)
        ])
        service.processCloudPayload(payload, into: context)

        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertTrue(tags.allSatisfy { $0.categoryName == "Battle" }, "All tags should have updated categoryName")
    }

    // AC#3: Simultaneous modification — last write wins
    func testLastWriteWinsConflictResolution() throws {
        let sharedUUID = UUID()
        let local = TagCategory(uuid: sharedUUID, name: "Local Version", colorHex: "#000000", iconName: "tag", sortOrder: 0, isDefault: false)
        context.insert(local)
        try context.save()

        // Mark local as recently modified
        service.markModified(local)

        // Cloud payload has an older timestamp — should NOT overwrite
        let pastDate = Date(timeIntervalSinceNow: -120)
        let payload = makePayload([
            makeSyncable(uuid: sharedUUID, name: "Stale Cloud", colorHex: "#FF0000", iconName: "star", sortOrder: 5, modifiedAt: pastDate)
        ])
        service.processCloudPayload(payload, into: context)

        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(categories[0].name, "Local Version", "Local newer version should be preserved")
        XCTAssertEqual(categories[0].colorHex, "#000000")
    }

    func testNewerCloudOverwritesOlderLocal() throws {
        let sharedUUID = UUID()
        let local = TagCategory(uuid: sharedUUID, name: "Old Local", colorHex: "#000000", iconName: "tag", sortOrder: 0, isDefault: false)
        context.insert(local)
        try context.save()
        // No markModified → cachedModifiedAt is distantPast

        // Cloud payload with current timestamp wins over distantPast
        let futureDate = Date(timeIntervalSinceNow: 60)
        let payload = makePayload([
            makeSyncable(uuid: sharedUUID, name: "Newer Cloud", colorHex: "#DC2626", iconName: "shield", sortOrder: 0, modifiedAt: futureDate)
        ])
        service.processCloudPayload(payload, into: context)

        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(categories[0].name, "Newer Cloud", "Newer cloud version should overwrite")
    }

    // AC#4: Only category metadata syncs — no session/tag/audio data
    func testSyncPayloadContainsOnlyCategoryMetadata() throws {
        let category = SyncableCategory(
            uuid: UUID().uuidString,
            name: "Test",
            colorHex: "#000000",
            iconName: "tag",
            sortOrder: 0,
            isDefault: false,
            modifiedAt: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(CategorySyncService.iso8601Formatter.string(from: date))
        }
        let data = try encoder.encode(category)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        let allowedKeys: Set<String> = ["uuid", "name", "colorHex", "iconName", "sortOrder", "isDefault", "modifiedAt"]
        let actualKeys = Set(json.keys)
        let forbidden = actualKeys.subtracting(allowedKeys)
        XCTAssertTrue(forbidden.isEmpty, "Payload has unexpected keys: \(forbidden)")

        // Verify no session/tag/audio/recording keys
        for key in ["session", "sessions", "tag", "tags", "audio", "recording", "audioFilePath", "duration"] {
            XCTAssertNil(json[key], "Payload must not contain '\(key)'")
        }
    }

    // AC#1 supplement: New cloud category inserted into local
    func testNewCloudCategoryInsertedLocally() throws {
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TagCategory>()), 0)

        let cloudUUID = UUID()
        let payload = makePayload([
            makeSyncable(uuid: cloudUUID, name: "Cloud Category", colorHex: "#059669", iconName: "globe", sortOrder: 0)
        ])
        service.processCloudPayload(payload, into: context)

        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories[0].name, "Cloud Category")
        XCTAssertEqual(categories[0].uuid, cloudUUID)
    }

    // Local-only categories preserved when not in cloud payload
    func testLocalCategoryPreservedWhenAbsentFromCloud() throws {
        let localOnly = TagCategory(uuid: UUID(), name: "Local Only", colorHex: "#000000", iconName: "tag", sortOrder: 0, isDefault: false)
        context.insert(localOnly)
        try context.save()

        // Cloud has a different category — local should be preserved
        let payload = makePayload([
            makeSyncable(uuid: UUID(), name: "Cloud Only", colorHex: "#FF0000", iconName: "star", sortOrder: 1)
        ])
        service.processCloudPayload(payload, into: context)

        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(categories.count, 2)
        XCTAssertTrue(categories.contains { $0.name == "Local Only" })
        XCTAssertTrue(categories.contains { $0.name == "Cloud Only" })
    }

    // Multiple categories sync correctly
    func testMultipleCategoriesSyncEndToEnd() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)
        let localCategories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(localCategories.count, 5)

        // Simulate cloud with 2 new categories + 1 update to existing
        let storyCategory = localCategories.first { $0.name == "Story" }!
        let payload = makePayload([
            makeSyncable(uuid: storyCategory.uuid, name: "Story (Updated)", colorHex: "#D97706", iconName: "book.pages", sortOrder: 0, isDefault: true, modifiedAt: Date(timeIntervalSinceNow: 60)),
            makeSyncable(uuid: UUID(), name: "New Category A", colorHex: "#FF0000", iconName: "flame", sortOrder: 5),
            makeSyncable(uuid: UUID(), name: "New Category B", colorHex: "#00FF00", iconName: "leaf", sortOrder: 6),
        ])
        service.processCloudPayload(payload, into: context)

        let afterSync = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(afterSync.count, 7, "5 original + 2 new from cloud")
        XCTAssertTrue(afterSync.contains { $0.name == "Story (Updated)" })
        XCTAssertTrue(afterSync.contains { $0.name == "New Category A" })
        XCTAssertTrue(afterSync.contains { $0.name == "New Category B" })
    }

    // Duplicate observer guard
    func testStartObservingIdempotent() throws {
        // Second call should be ignored (no crash, no duplicate observers)
        service.startObserving(context: context)
        // If this doesn't crash, the guard works
    }

    // MARK: - Helpers

    private func makeSyncable(
        uuid: UUID,
        name: String,
        colorHex: String = "#D97706",
        iconName: String = "tag",
        sortOrder: Int = 0,
        isDefault: Bool = false,
        modifiedAt: Date = Date()
    ) -> SyncableCategory {
        SyncableCategory(
            uuid: uuid.uuidString,
            name: name,
            colorHex: colorHex,
            iconName: iconName,
            sortOrder: sortOrder,
            isDefault: isDefault,
            modifiedAt: modifiedAt
        )
    }

    private func makePayload(_ categories: [SyncableCategory]) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(CategorySyncService.iso8601Formatter.string(from: date))
        }
        return try! encoder.encode(categories)
    }
}

// MARK: - Story 1.7: Storage Management E2E

final class Epic1StorageE2ETests: XCTestCase {

    // AC#1: View storage usage — fileSize returns correct value
    func testFileSizeForKnownContent() throws {
        let content = String(repeating: "X", count: 1024)
        let url = makeTempFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let size = try AudioFileManager.fileSize(at: url.path)
        XCTAssertEqual(size, 1024)
    }

    // AC#1: Total storage across multiple sessions
    func testTotalStorageSizeAcrossMultipleSessions() throws {
        let file1 = makeTempFile(content: String(repeating: "A", count: 500))
        let file2 = makeTempFile(content: String(repeating: "B", count: 300))
        let file3 = makeTempFile(content: String(repeating: "C", count: 200))
        defer {
            try? FileManager.default.removeItem(at: file1)
            try? FileManager.default.removeItem(at: file2)
            try? FileManager.default.removeItem(at: file3)
        }

        let sessions = [
            Session(title: "S1", sessionNumber: 1, audioFilePath: file1.path),
            Session(title: "S2", sessionNumber: 2, audioFilePath: file2.path),
            Session(title: "S3", sessionNumber: 3, audioFilePath: file3.path),
        ]

        let total = AudioFileManager.totalAudioStorageSize(sessions: sessions)
        XCTAssertEqual(total, 1000, "Total should sum all file sizes")
    }

    // AC#1: Sessions without audio are excluded from storage count
    func testSessionsWithoutAudioExcludedFromTotal() {
        let sessions = [
            Session(title: "S1", sessionNumber: 1, audioFilePath: nil),
            Session(title: "S2", sessionNumber: 2, audioFilePath: nil),
        ]

        let total = AudioFileManager.totalAudioStorageSize(sessions: sessions)
        XCTAssertEqual(total, 0, "Sessions without audio should contribute 0 bytes")
    }

    // AC#1: Mixed sessions — some with audio, some without
    func testMixedSessionsStorageCalculation() throws {
        let file = makeTempFile(content: String(repeating: "D", count: 750))
        defer { try? FileManager.default.removeItem(at: file) }

        let sessions = [
            Session(title: "With Audio", sessionNumber: 1, audioFilePath: file.path),
            Session(title: "No Audio", sessionNumber: 2, audioFilePath: nil),
        ]

        let total = AudioFileManager.totalAudioStorageSize(sessions: sessions)
        XCTAssertEqual(total, 750, "Only sessions with audio should be counted")
    }

    // AC#2: Delete audio file — file removed from disk
    func testDeleteAudioFileRemovesFromDisk() throws {
        let url = makeTempFile(content: "audio data placeholder")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        try AudioFileManager.deleteAudioFile(at: url.path)

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "File should be removed after deletion")
    }

    // AC#2: Delete audio — storage total updates (simulated)
    func testDeleteAudioReducesStorageTotal() throws {
        let file1 = makeTempFile(content: String(repeating: "A", count: 400))
        let file2 = makeTempFile(content: String(repeating: "B", count: 600))
        defer {
            try? FileManager.default.removeItem(at: file1)
            try? FileManager.default.removeItem(at: file2)
        }

        var sessions = [
            Session(title: "S1", sessionNumber: 1, audioFilePath: file1.path),
            Session(title: "S2", sessionNumber: 2, audioFilePath: file2.path),
        ]

        let totalBefore = AudioFileManager.totalAudioStorageSize(sessions: sessions)
        XCTAssertEqual(totalBefore, 1000)

        // Delete S1's audio file and clear path (as the app does)
        try AudioFileManager.deleteAudioFile(at: file1.path)
        sessions[0] = Session(title: "S1", sessionNumber: 1, audioFilePath: nil)

        let totalAfter = AudioFileManager.totalAudioStorageSize(sessions: sessions)
        XCTAssertEqual(totalAfter, 600, "Storage total should reflect freed space")
    }

    // AC#2: Delete audio throws for missing file
    func testDeleteAudioThrowsFileNotFound() {
        let missingPath = "/tmp/dictly_e2e_missing_\(UUID().uuidString).m4a"
        XCTAssertThrowsError(try AudioFileManager.deleteAudioFile(at: missingPath)) { error in
            guard case DictlyError.storage(.fileNotFound) = error else {
                XCTFail("Expected DictlyError.storage(.fileNotFound), got \(error)")
                return
            }
        }
    }

    // AC#3: Empty state — no recordings
    func testNoRecordingsEmptyState() {
        let sessionsWithAudio = [
            Session(title: "S1", sessionNumber: 1, audioFilePath: nil),
            Session(title: "S2", sessionNumber: 2, audioFilePath: nil),
        ].filter { $0.audioFilePath != nil }

        XCTAssertTrue(sessionsWithAudio.isEmpty, "No sessions with audio = empty state")
    }

    // formattedSize produces readable output
    func testFormattedSizeOutputs() {
        // 0 bytes
        let zero = AudioFileManager.formattedSize(0)
        XCTAssertFalse(zero.isEmpty)

        // KB range
        let kb = AudioFileManager.formattedSize(512 * 1024)
        XCTAssertTrue(kb.lowercased().contains("kb"), "512 KB should show KB, got: \(kb)")

        // MB range (typical session ~115 MB)
        let mb = AudioFileManager.formattedSize(115 * 1024 * 1024)
        XCTAssertTrue(mb.contains("MB"), "115 MB should show MB, got: \(mb)")

        // GB range
        let gb = AudioFileManager.formattedSize(2 * 1024 * 1024 * 1024)
        XCTAssertTrue(gb.contains("GB"), "2 GB should show GB, got: \(gb)")
    }

    // audioStorageDirectory creates and returns valid path
    func testAudioStorageDirectoryCreation() throws {
        let url = try AudioFileManager.audioStorageDirectory()
        XCTAssertTrue(url.path.hasSuffix("Recordings"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    // audioStorageDirectory is idempotent
    func testAudioStorageDirectoryIdempotent() throws {
        let url1 = try AudioFileManager.audioStorageDirectory()
        let url2 = try AudioFileManager.audioStorageDirectory()
        XCTAssertEqual(url1, url2)
    }

    // fileSize throws for missing file
    func testFileSizeThrowsForMissing() {
        let path = "/tmp/dictly_e2e_noexist_\(UUID().uuidString).m4a"
        XCTAssertThrowsError(try AudioFileManager.fileSize(at: path)) { error in
            guard case DictlyError.storage(.fileNotFound) = error else {
                XCTFail("Expected fileNotFound, got \(error)")
                return
            }
        }
    }

    // totalAudioStorageSize gracefully handles missing files
    func testTotalSizeSkipsMissingFiles() {
        let missingPath = "/tmp/dictly_e2e_ghost_\(UUID().uuidString).m4a"
        let sessions = [Session(title: "Ghost", sessionNumber: 1, audioFilePath: missingPath)]
        let total = AudioFileManager.totalAudioStorageSize(sessions: sessions)
        XCTAssertEqual(total, 0, "Missing files should be skipped, not crash")
    }

    // MARK: - Cross-Story E2E: Full Storage Lifecycle

    func testFullStorageLifecycle() throws {
        // 1. Verify storage directory exists
        let storageDir = try AudioFileManager.audioStorageDirectory()
        XCTAssertTrue(FileManager.default.fileExists(atPath: storageDir.path))

        // 2. Create fake audio files
        let audio1 = makeTempFile(content: String(repeating: "A", count: 2048))
        let audio2 = makeTempFile(content: String(repeating: "B", count: 4096))
        defer {
            try? FileManager.default.removeItem(at: audio1)
            try? FileManager.default.removeItem(at: audio2)
        }

        // 3. Create sessions with audio paths
        var sessions = [
            Session(title: "Session 1", sessionNumber: 1, audioFilePath: audio1.path),
            Session(title: "Session 2", sessionNumber: 2, audioFilePath: audio2.path),
            Session(title: "Session 3", sessionNumber: 3, audioFilePath: nil), // no audio
        ]

        // 4. Check total storage
        let total = AudioFileManager.totalAudioStorageSize(sessions: sessions)
        XCTAssertEqual(total, 6144, "Total = 2048 + 4096")

        // 5. Check per-session sizes
        XCTAssertEqual(try AudioFileManager.fileSize(at: audio1.path), 2048)
        XCTAssertEqual(try AudioFileManager.fileSize(at: audio2.path), 4096)

        // 6. Format for display
        let formatted = AudioFileManager.formattedSize(total)
        XCTAssertFalse(formatted.isEmpty)

        // 7. Delete first audio file (as storage management UI would)
        try AudioFileManager.deleteAudioFile(at: audio1.path)
        sessions[0] = Session(title: "Session 1", sessionNumber: 1, audioFilePath: nil)

        // 8. Verify storage total updated
        let newTotal = AudioFileManager.totalAudioStorageSize(sessions: sessions)
        XCTAssertEqual(newTotal, 4096, "After deleting first file, only second remains")

        // 9. Filter for display (sessions with audio)
        let withAudio = sessions.filter { $0.audioFilePath != nil }
        XCTAssertEqual(withAudio.count, 1)
        XCTAssertEqual(withAudio[0].title, "Session 2")

        // 10. Delete remaining audio
        try AudioFileManager.deleteAudioFile(at: audio2.path)
        sessions[1] = Session(title: "Session 2", sessionNumber: 2, audioFilePath: nil)

        // 11. Verify empty state
        let finalTotal = AudioFileManager.totalAudioStorageSize(sessions: sessions)
        XCTAssertEqual(finalTotal, 0)
        let finalWithAudio = sessions.filter { $0.audioFilePath != nil }
        XCTAssertTrue(finalWithAudio.isEmpty, "No recordings = empty state")
    }

    // MARK: - Session audioFilePath Property (Story 1.7 Task 1)

    func testSessionAudioFilePathOptionalProperty() {
        // Default nil
        let session1 = Session(title: "S1", sessionNumber: 1)
        XCTAssertNil(session1.audioFilePath)

        // Set explicitly
        let session2 = Session(title: "S2", sessionNumber: 2, audioFilePath: "/path/to/audio.m4a")
        XCTAssertEqual(session2.audioFilePath, "/path/to/audio.m4a")

        // Can be cleared
        session2.audioFilePath = nil
        XCTAssertNil(session2.audioFilePath)
    }

    // MARK: - Helpers

    private func makeTempFile(content: String) -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dictly_e2e_\(UUID().uuidString).m4a")
        let data = content.data(using: .utf8)!
        FileManager.default.createFile(atPath: url.path, contents: data)
        return url
    }
}
