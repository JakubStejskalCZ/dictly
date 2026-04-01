import XCTest
import SwiftData
@testable import DictlyModels

@MainActor
final class TagTests: XCTestCase {
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

    func testTagCreation() throws {
        let tag = Tag(label: "Critical Hit", categoryName: "Combat", anchorTime: 45.0, rewindDuration: 10.0)
        context.insert(tag)
        try context.save()

        let results = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].label, "Critical Hit")
        XCTAssertEqual(results[0].categoryName, "Combat")
        XCTAssertEqual(results[0].anchorTime, 45.0)
    }

    func testTagSessionRelationship() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        let tag = Tag(label: "Tag 1", categoryName: "General", anchorTime: 10, rewindDuration: 5)
        context.insert(session)
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags[0].session?.title, "Session 1")
    }

    func testTagCategoryIsIndependent() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        let category = TagCategory(name: "Combat", colorHex: "#FF0000", iconName: "shield")
        let tag = Tag(label: "Attack", categoryName: "Combat", anchorTime: 20, rewindDuration: 5)
        context.insert(session)
        context.insert(category)
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        // Deleting TagCategory should NOT cascade delete tags
        context.delete(category)
        try context.save()

        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags.count, 1, "Tags should NOT be deleted when TagCategory is deleted")
    }
}
