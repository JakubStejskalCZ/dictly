import XCTest
import SwiftData
@testable import DictlyModels

@MainActor
final class TagCategoryTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Schema(DictlySchema.all), configurations: config)
        context = container.mainContext
    }

    override func tearDown() async throws {
        context = nil
        container = nil
    }

    func testTagCategoryCreation() throws {
        let category = TagCategory(name: "Combat", colorHex: "#FF0000", iconName: "shield", sortOrder: 1, isDefault: true)
        context.insert(category)
        try context.save()

        let results = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Combat")
        XCTAssertEqual(results[0].colorHex, "#FF0000")
        XCTAssertEqual(results[0].iconName, "shield")
        XCTAssertEqual(results[0].sortOrder, 1)
        XCTAssertTrue(results[0].isDefault)
    }

    func testTagCategoryUUIDUniqueness() throws {
        let c1 = TagCategory(name: "Combat", colorHex: "#FF0000", iconName: "shield")
        let c2 = TagCategory(name: "Roleplay", colorHex: "#00FF00", iconName: "person")
        context.insert(c1)
        context.insert(c2)
        try context.save()

        XCTAssertNotEqual(c1.uuid, c2.uuid)
    }

    func testTagCategoryDefaultValues() throws {
        let category = TagCategory(name: "General", colorHex: "#000000", iconName: "tag")
        context.insert(category)
        try context.save()

        let results = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(results[0].sortOrder, 0)
        XCTAssertFalse(results[0].isDefault)
    }
}
