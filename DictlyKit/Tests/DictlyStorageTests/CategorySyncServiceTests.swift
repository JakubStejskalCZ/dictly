import XCTest
import SwiftData
@testable import DictlyStorage
@testable import DictlyModels

// MARK: - SyncableCategory Codable Tests

final class SyncableCategoryTests: XCTestCase {

    // 7.1 — Round-trip encoding/decoding
    func testSyncableCategoryEncodingDecodingRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
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
        XCTAssertEqual(decoded.modifiedAt.timeIntervalSince1970, original.modifiedAt.timeIntervalSince1970, accuracy: 1.0)
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

    // MARK: - Helpers

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
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

    // 7.2 — Update existing category when cloud has same UUID
    func testMergeUpdatesExistingCategory() throws {
        let sharedUUID = UUID()
        let local = TagCategory(uuid: sharedUUID, name: "Old Name", colorHex: "#000000", iconName: "tag", sortOrder: 0, isDefault: false)
        context.insert(local)
        try context.save()

        let payload = makePayload([
            makeSyncable(uuid: sharedUUID, name: "New Name", colorHex: "#DC2626", iconName: "shield", sortOrder: 0)
        ])
        service.processCloudPayload(payload, into: context)

        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories[0].name, "New Name")
        XCTAssertEqual(categories[0].colorHex, "#DC2626")
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

    // 7.2 — Last-write-wins: cloud update replaces local fields
    func testMergeAppliesCloudFieldsOnUUIDMatch() throws {
        let sharedUUID = UUID()
        let local = TagCategory(uuid: sharedUUID, name: "Original", colorHex: "#000000", iconName: "tag", sortOrder: 0, isDefault: false)
        context.insert(local)
        try context.save()

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

    // MARK: - Helpers

    private func makeSyncable(
        uuid: UUID,
        name: String,
        colorHex: String = "#D97706",
        iconName: String = "tag",
        sortOrder: Int = 0,
        isDefault: Bool = false
    ) -> SyncableCategory {
        SyncableCategory(
            uuid: uuid.uuidString,
            name: name,
            colorHex: colorHex,
            iconName: iconName,
            sortOrder: sortOrder,
            isDefault: isDefault,
            modifiedAt: Date()
        )
    }

    private func makePayload(_ categories: [SyncableCategory]) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try! encoder.encode(categories)
    }
}
