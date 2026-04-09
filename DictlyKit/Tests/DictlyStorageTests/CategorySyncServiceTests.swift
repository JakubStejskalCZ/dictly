import XCTest
import SwiftData
@testable import DictlyStorage
@testable import DictlyModels

// MARK: - SyncableCategory Codable Tests

final class SyncableCategoryTests: XCTestCase {

    // 7.1 — Round-trip encoding/decoding with fractional-second ISO 8601
    func testSyncableCategoryEncodingDecodingRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000.123)
        let original = SyncableCategory(
            uuid: "550e8400-e29b-41d4-a716-446655440000",
            name: "Combat",
            colorHex: "#DC2626",
            iconName: "shield",
            sortOrder: 2,
            isDefault: false,
            modifiedAt: date
        )

        let data = try encode(original)
        let decoded = try decode(SyncableCategory.self, from: data)

        XCTAssertEqual(decoded.uuid, original.uuid)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.colorHex, original.colorHex)
        XCTAssertEqual(decoded.iconName, original.iconName)
        XCTAssertEqual(decoded.sortOrder, original.sortOrder)
        XCTAssertEqual(decoded.isDefault, original.isDefault)
        XCTAssertEqual(decoded.modifiedAt.timeIntervalSince1970, original.modifiedAt.timeIntervalSince1970, accuracy: 0.01)
    }

    // 7.3 — Payload contains ONLY category metadata fields (no session/tag/audio references)
    func testSyncPayloadContainsOnlyCategoryMetadata() throws {
        let category = SyncableCategory(
            uuid: UUID().uuidString,
            name: "Story",
            colorHex: "#D97706",
            iconName: "book.pages",
            sortOrder: 0,
            isDefault: true,
            modifiedAt: Date()
        )

        let data = try encode(category)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let keys = Set(json.keys.map { $0 })

        let allowedKeys: Set<String> = ["uuid", "name", "colorHex", "iconName", "sortOrder", "isDefault", "modifiedAt"]
        let forbiddenKeys = keys.subtracting(allowedKeys)
        XCTAssertTrue(forbiddenKeys.isEmpty, "Payload contains unexpected keys: \(forbiddenKeys)")

        XCTAssertFalse(keys.contains("session"))
        XCTAssertFalse(keys.contains("tag"))
        XCTAssertFalse(keys.contains("audio"))
        XCTAssertFalse(keys.contains("recording"))
    }

    // 7.4 — 200 categories serialized stay well within 1 MB KVS limit
    func testPushSerializationIsWithinKVSLimit() throws {
        let categories: [SyncableCategory] = (0..<200).map { i in
            SyncableCategory(
                uuid: UUID().uuidString,
                name: "Category \(i) — A fairly long name to stress-test size",
                colorHex: "#D97706",
                iconName: "book.pages",
                sortOrder: i,
                isDefault: i == 0,
                modifiedAt: Date()
            )
        }

        let data = try encode(categories)
        let oneMB = 1_048_576
        XCTAssertLessThan(data.count, oneMB, "200 categories exceed 1 MB KVS limit: \(data.count) bytes")
    }

    // 7.4 — camelCase JSON keys (architecture mandate — no custom CodingKeys)
    func testSyncableCategoryUsesCamelCaseKeys() throws {
        let category = SyncableCategory(
            uuid: UUID().uuidString,
            name: "Test",
            colorHex: "#000000",
            iconName: "tag",
            sortOrder: 0,
            isDefault: false,
            modifiedAt: Date()
        )

        let data = try encode(category)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNotNil(json["colorHex"])
        XCTAssertNotNil(json["iconName"])
        XCTAssertNotNil(json["sortOrder"])
        XCTAssertNotNil(json["isDefault"])
        XCTAssertNotNil(json["modifiedAt"])
        XCTAssertNil(json["color_hex"], "Keys must be camelCase, not snake_case")
        XCTAssertNil(json["icon_name"], "Keys must be camelCase, not snake_case")
    }

    // SyncableTag round-trip encoding/decoding
    func testSyncableTagEncodingDecodingRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000.456)
        let original = SyncableTag(
            uuid: "660e8400-e29b-41d4-a716-446655440000",
            label: "Grimthor",
            categoryName: "Story",
            modifiedAt: date
        )

        let data = try encode(original)
        let decoded = try decode(SyncableTag.self, from: data)

        XCTAssertEqual(decoded.uuid, original.uuid)
        XCTAssertEqual(decoded.label, original.label)
        XCTAssertEqual(decoded.categoryName, original.categoryName)
        XCTAssertEqual(decoded.modifiedAt.timeIntervalSince1970, original.modifiedAt.timeIntervalSince1970, accuracy: 0.01)
    }

    // SyncableTag payload contains only expected fields
    func testSyncableTagPayloadContainsOnlyExpectedFields() throws {
        let tag = SyncableTag(
            uuid: UUID().uuidString,
            label: "Test",
            categoryName: "Story",
            modifiedAt: Date()
        )

        let data = try encode(tag)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let keys = Set(json.keys)

        let allowedKeys: Set<String> = ["uuid", "label", "categoryName", "modifiedAt"]
        let unexpectedKeys = keys.subtracting(allowedKeys)
        XCTAssertTrue(unexpectedKeys.isEmpty, "Payload contains unexpected keys: \(unexpectedKeys)")
        XCTAssertEqual(keys.count, 4)
    }

    // MARK: - Helpers

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(CategorySyncService.iso8601Formatter.string(from: date))
        }
        return try encoder.encode(value)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            guard let date = CategorySyncService.iso8601Formatter.date(from: dateString) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(dateString)")
            }
            return date
        }
        return try decoder.decode(type, from: data)
    }
}

// MARK: - Merge Logic Tests

@MainActor
final class CategorySyncMergeTests: XCTestCase {

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

    // 7.2 — Insert new category from cloud payload
    func testMergeInsertsNewCategoryFromCloud() throws {
        let localBefore = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(localBefore.count, 0)

        let cloudUUID = UUID()
        let payload = makePayload([
            makeSyncable(uuid: cloudUUID, name: "Exploration", colorHex: "#059669", iconName: "map", sortOrder: 1)
        ])
        service.processCloudPayload(payload, into: context)

        let localAfter = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(localAfter.count, 1)
        XCTAssertEqual(localAfter[0].name, "Exploration")
        XCTAssertEqual(localAfter[0].colorHex, "#059669")
        XCTAssertEqual(localAfter[0].uuid, cloudUUID)
    }

    // 7.2 — Update existing category when cloud has newer modifiedAt
    func testMergeUpdatesExistingCategoryWhenCloudIsNewer() throws {
        let sharedUUID = UUID()
        let local = TagCategory(uuid: sharedUUID, name: "Old Name", colorHex: "#000000", iconName: "tag", sortOrder: 0, isDefault: false)
        context.insert(local)
        try context.save()

        // Cache a past timestamp for local (simulating a previous push)
        let pastDate = Date(timeIntervalSinceNow: -60)
        service.markModified(local)

        // Cloud payload has a future timestamp — should win
        let futureDate = Date(timeIntervalSinceNow: 60)
        let payload = makePayload([
            makeSyncable(uuid: sharedUUID, name: "New Name", colorHex: "#DC2626", iconName: "shield", sortOrder: 0, modifiedAt: futureDate)
        ])
        service.processCloudPayload(payload, into: context)

        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories[0].name, "New Name")
        XCTAssertEqual(categories[0].colorHex, "#DC2626")
    }

    // 7.2 — Local category NOT updated when cloud has older modifiedAt (last-write-wins)
    func testMergeKeepsLocalWhenCloudIsOlder() throws {
        let sharedUUID = UUID()
        let local = TagCategory(uuid: sharedUUID, name: "Local Name", colorHex: "#DC2626", iconName: "shield", sortOrder: 0, isDefault: false)
        context.insert(local)
        try context.save()

        // Mark local as recently modified (current time)
        service.markModified(local)

        // Cloud payload has a past timestamp — should NOT overwrite local
        let pastDate = Date(timeIntervalSinceNow: -120)
        let payload = makePayload([
            makeSyncable(uuid: sharedUUID, name: "Stale Cloud Name", colorHex: "#000000", iconName: "tag", sortOrder: 5, modifiedAt: pastDate)
        ])
        service.processCloudPayload(payload, into: context)

        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories[0].name, "Local Name", "Local should be preserved when cloud modifiedAt is older")
        XCTAssertEqual(categories[0].colorHex, "#DC2626")
        XCTAssertEqual(categories[0].sortOrder, 0)
    }

    // 7.2 — Local category absent from cloud is preserved (no deletion on pull)
    func testMergeKeepsLocalCategoryAbsentFromCloud() throws {
        let localOnly = TagCategory(uuid: UUID(), name: "Local Only", colorHex: "#4B7BE5", iconName: "star", sortOrder: 0, isDefault: false)
        context.insert(localOnly)
        try context.save()

        let cloudOnlyUUID = UUID()
        let payload = makePayload([
            makeSyncable(uuid: cloudOnlyUUID, name: "Cloud Only", colorHex: "#D97706", iconName: "flame", sortOrder: 1)
        ])
        service.processCloudPayload(payload, into: context)

        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(categories.count, 2, "Both local-only and cloud-only categories must be preserved")
        let names = Set(categories.map(\.name))
        XCTAssertTrue(names.contains("Local Only"))
        XCTAssertTrue(names.contains("Cloud Only"))
    }

    // 7.2 — Cloud update replaces local fields when cloud is newer
    func testMergeAppliesCloudFieldsOnUUIDMatchWhenNewer() throws {
        let sharedUUID = UUID()
        let local = TagCategory(uuid: sharedUUID, name: "Original", colorHex: "#000000", iconName: "tag", sortOrder: 0, isDefault: false)
        context.insert(local)
        try context.save()

        // No cached timestamp = distantPast, so any cloud timestamp wins
        let payload = makePayload([
            makeSyncable(uuid: sharedUUID, name: "Cloud Updated", colorHex: "#7C3AED", iconName: "wand.and.stars", sortOrder: 0, isDefault: true)
        ])
        service.processCloudPayload(payload, into: context)

        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(categories[0].name, "Cloud Updated")
        XCTAssertEqual(categories[0].colorHex, "#7C3AED")
        XCTAssertTrue(categories[0].isDefault)
    }

    // Tag categoryName is updated when a synced category rename arrives
    func testMergeUpdatesTagCategoryNameOnRename() throws {
        let sharedUUID = UUID()
        let category = TagCategory(uuid: sharedUUID, name: "OldCat", colorHex: "#000000", iconName: "tag", sortOrder: 0, isDefault: false)
        context.insert(category)

        let tag = Tag(label: "my tag", categoryName: "OldCat", anchorTime: 0, rewindDuration: 0)
        context.insert(tag)
        try context.save()

        // No cached timestamp — cloud wins
        let payload = makePayload([
            makeSyncable(uuid: sharedUUID, name: "NewCat", colorHex: "#000000", iconName: "tag", sortOrder: 0)
        ])
        service.processCloudPayload(payload, into: context)

        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags[0].categoryName, "NewCat")
    }

    // Multiple categories round-trip through merge without data loss
    func testMergeHandlesMultipleCategoriesCorrectly() throws {
        let uuids = (0..<5).map { _ in UUID() }
        let syncables = uuids.enumerated().map { i, uuid in
            makeSyncable(uuid: uuid, name: "Cat \(i)", colorHex: "#D97706", iconName: "tag", sortOrder: i)
        }
        let payload = makePayload(syncables)
        service.processCloudPayload(payload, into: context)

        let categories = try context.fetch(FetchDescriptor<TagCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
        XCTAssertEqual(categories.count, 5)
        for (i, cat) in categories.enumerated() {
            XCTAssertEqual(cat.name, "Cat \(i)")
        }
    }

    // Duplicate UUIDs in cloud payload do not crash
    func testMergeSurvivesDuplicateUUIDsInCloudPayload() throws {
        let sharedUUID = UUID()
        let payload = makePayload([
            makeSyncable(uuid: sharedUUID, name: "First", colorHex: "#000000", iconName: "tag", sortOrder: 0),
            makeSyncable(uuid: sharedUUID, name: "Second", colorHex: "#DC2626", iconName: "shield", sortOrder: 1)
        ])
        service.processCloudPayload(payload, into: context)

        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(categories.count, 1, "Duplicate UUID should result in a single category")
    }

    // MARK: - Pack ID Sync Tests

    // Pack IDs round-trip through processPackIDsPayload
    func testPackIDsSyncInstallsMissingPacks() throws {
        // No packs installed initially
        let before = try DefaultTagSeeder.installedPackIDs(context: context)
        XCTAssertTrue(before.isEmpty)

        // Simulate cloud payload with "ttrpg" pack
        let data = try JSONEncoder().encode(["ttrpg"])
        service.processPackIDsPayload(data, into: context)

        let after = try DefaultTagSeeder.installedPackIDs(context: context)
        XCTAssertTrue(after.contains("ttrpg"), "Pack should be auto-installed from cloud sync")

        // Verify template tags were created
        let tags = try context.fetch(FetchDescriptor<Tag>()).filter { $0.session == nil }
        XCTAssertFalse(tags.isEmpty, "Template tags should be created for installed pack")
    }

    // Pack IDs sync uninstalls packs removed on other device
    func testPackIDsSyncUninstallsRemovedPacks() throws {
        // Install ttrpg pack locally first
        let sortOrder = try DefaultTagSeeder.nextSortOrder(context: context)
        try DefaultTagSeeder.installPack(TagPackRegistry.ttrpg, startingSortOrder: sortOrder, context: context)
        XCTAssertTrue(try DefaultTagSeeder.installedPackIDs(context: context).contains("ttrpg"))

        // Simulate cloud payload with empty pack list (ttrpg was uninstalled on other device)
        let data = try JSONEncoder().encode([String]())
        service.processPackIDsPayload(data, into: context)

        let after = try DefaultTagSeeder.installedPackIDs(context: context)
        XCTAssertFalse(after.contains("ttrpg"), "Pack should be auto-uninstalled from cloud sync")
    }

    // Re-syncing an already installed pack is idempotent
    func testPackIDsSyncIsIdempotent() throws {
        // Install ttrpg pack locally
        let sortOrder = try DefaultTagSeeder.nextSortOrder(context: context)
        try DefaultTagSeeder.installPack(TagPackRegistry.ttrpg, startingSortOrder: sortOrder, context: context)

        let tagsBefore = try context.fetch(FetchDescriptor<Tag>()).filter { $0.session == nil }.count
        let categoriesBefore = try context.fetch(FetchDescriptor<TagCategory>()).count

        // Simulate cloud payload with same pack — should not duplicate
        let data = try JSONEncoder().encode(["ttrpg"])
        service.processPackIDsPayload(data, into: context)

        let tagsAfter = try context.fetch(FetchDescriptor<Tag>()).filter { $0.session == nil }.count
        let categoriesAfter = try context.fetch(FetchDescriptor<TagCategory>()).count

        XCTAssertEqual(tagsBefore, tagsAfter, "Re-syncing should not duplicate tags")
        XCTAssertEqual(categoriesBefore, categoriesAfter, "Re-syncing should not duplicate categories")
    }

    // Unknown pack IDs in cloud payload are skipped gracefully
    func testPackIDsSyncSkipsUnknownPackIDs() throws {
        let data = try JSONEncoder().encode(["nonexistent_pack"])
        service.processPackIDsPayload(data, into: context)

        let installed = try DefaultTagSeeder.installedPackIDs(context: context)
        XCTAssertTrue(installed.isEmpty, "Unknown pack IDs should not cause any installation")
    }

    // MARK: - Template Tag Sync Tests

    // Insert new template tag from cloud payload
    func testTagMergeInsertsNewTagFromCloud() throws {
        let tagsBefore = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tagsBefore.count, 0)

        let cloudUUID = UUID()
        let payload = makeTagPayload([
            makeSyncableTag(uuid: cloudUUID, label: "Grimthor", categoryName: "Story")
        ])
        service.processTagsPayload(payload, into: context)

        let tagsAfter = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tagsAfter.count, 1)
        XCTAssertEqual(tagsAfter[0].label, "Grimthor")
        XCTAssertEqual(tagsAfter[0].categoryName, "Story")
        XCTAssertEqual(tagsAfter[0].uuid, cloudUUID)
        XCTAssertNil(tagsAfter[0].session, "Synced tag must be a template tag (no session)")
        XCTAssertEqual(tagsAfter[0].anchorTime, 0)
        XCTAssertEqual(tagsAfter[0].rewindDuration, 0)
    }

    // Update existing template tag when cloud has newer modifiedAt
    func testTagMergeUpdatesExistingTagWhenCloudIsNewer() throws {
        let sharedUUID = UUID()
        let tag = Tag(uuid: sharedUUID, label: "Old Label", categoryName: "Story", anchorTime: 0, rewindDuration: 0)
        context.insert(tag)
        try context.save()

        service.markTagModified(tag)

        let futureDate = Date(timeIntervalSinceNow: 60)
        let payload = makeTagPayload([
            makeSyncableTag(uuid: sharedUUID, label: "New Label", categoryName: "Combat", modifiedAt: futureDate)
        ])
        service.processTagsPayload(payload, into: context)

        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags[0].label, "New Label")
        XCTAssertEqual(tags[0].categoryName, "Combat")
    }

    // Local tag NOT updated when cloud has older modifiedAt
    func testTagMergeKeepsLocalWhenCloudIsOlder() throws {
        let sharedUUID = UUID()
        let tag = Tag(uuid: sharedUUID, label: "Local Label", categoryName: "Story", anchorTime: 0, rewindDuration: 0)
        context.insert(tag)
        try context.save()

        service.markTagModified(tag)

        let pastDate = Date(timeIntervalSinceNow: -120)
        let payload = makeTagPayload([
            makeSyncableTag(uuid: sharedUUID, label: "Stale Cloud Label", categoryName: "Combat", modifiedAt: pastDate)
        ])
        service.processTagsPayload(payload, into: context)

        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags[0].label, "Local Label", "Local should be preserved when cloud modifiedAt is older")
        XCTAssertEqual(tags[0].categoryName, "Story")
    }

    // Local template tag absent from cloud is preserved (no deletion on pull)
    func testTagMergeKeepsLocalTagAbsentFromCloud() throws {
        let localOnly = Tag(uuid: UUID(), label: "Local Only", categoryName: "Story", anchorTime: 0, rewindDuration: 0)
        context.insert(localOnly)
        try context.save()

        let cloudOnlyUUID = UUID()
        let payload = makeTagPayload([
            makeSyncableTag(uuid: cloudOnlyUUID, label: "Cloud Only", categoryName: "Combat")
        ])
        service.processTagsPayload(payload, into: context)

        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags.count, 2, "Both local-only and cloud-only tags must be preserved")
        let labels = Set(tags.map(\.label))
        XCTAssertTrue(labels.contains("Local Only"))
        XCTAssertTrue(labels.contains("Cloud Only"))
    }

    // Duplicate UUIDs in cloud tag payload — keeps last occurrence
    func testTagMergeSurvivesDuplicateUUIDsInCloudPayload() throws {
        let sharedUUID = UUID()
        let payload = makeTagPayload([
            makeSyncableTag(uuid: sharedUUID, label: "First", categoryName: "Story"),
            makeSyncableTag(uuid: sharedUUID, label: "Second", categoryName: "Combat")
        ])
        service.processTagsPayload(payload, into: context)

        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags.count, 1, "Duplicate UUID should result in a single tag")
        XCTAssertEqual(tags[0].label, "Second", "Last occurrence in payload should win")
        XCTAssertEqual(tags[0].categoryName, "Combat")
    }

    // Invalid UUID strings in cloud payload are skipped
    func testTagMergeSkipsInvalidUUIDs() throws {
        let validUUID = UUID()
        let payload: Data = {
            let tags = [
                SyncableTag(uuid: "not-a-uuid", label: "Bad", categoryName: "Story", modifiedAt: Date()),
                SyncableTag(uuid: validUUID.uuidString, label: "Good", categoryName: "Story", modifiedAt: Date())
            ]
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .custom { date, encoder in
                var container = encoder.singleValueContainer()
                try container.encode(CategorySyncService.iso8601Formatter.string(from: date))
            }
            return try! encoder.encode(tags)
        }()
        service.processTagsPayload(payload, into: context)

        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags.count, 1, "Invalid UUID tag should be skipped")
        XCTAssertEqual(tags[0].label, "Good")
    }

    // Multiple template tags round-trip through merge without data loss
    func testTagMergeHandlesMultipleTagsCorrectly() throws {
        let uuids = (0..<5).map { _ in UUID() }
        let syncables = uuids.enumerated().map { i, uuid in
            makeSyncableTag(uuid: uuid, label: "Tag \(i)", categoryName: "Story")
        }
        let payload = makeTagPayload(syncables)
        service.processTagsPayload(payload, into: context)

        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags.count, 5)
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

    private func makeSyncableTag(
        uuid: UUID,
        label: String,
        categoryName: String = "Story",
        modifiedAt: Date = Date()
    ) -> SyncableTag {
        SyncableTag(
            uuid: uuid.uuidString,
            label: label,
            categoryName: categoryName,
            modifiedAt: modifiedAt
        )
    }

    private func makeTagPayload(_ tags: [SyncableTag]) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(CategorySyncService.iso8601Formatter.string(from: date))
        }
        return try! encoder.encode(tags)
    }
}
