import XCTest
import SwiftData
@testable import DictlyModels

/// Tests for tag category deletion/reassignment and reorder persistence logic.
/// These mirror the operations performed in TagCategoryListScreen.
@MainActor
final class TagManagementTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Schema(DictlySchema.all), configurations: config)
        context = container.mainContext
        try DefaultTagSeeder.seedIfNeeded(context: context)
    }

    override func tearDown() async throws {
        context = nil
        container = nil
    }

    // MARK: - Deletion + Tag Reassignment

    func testDeleteCategoryReassignsTagsToUncategorized() throws {
        // Fetch "Story" category and verify it has 5 tags
        let allCategories = try context.fetch(FetchDescriptor<TagCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
        let storyCategory = try XCTUnwrap(allCategories.first { $0.name == "Story" })
        let storyPredicate = #Predicate<Tag> { $0.categoryName == "Story" }
        let storyTagsBefore = try context.fetch(FetchDescriptor<Tag>(predicate: storyPredicate))
        XCTAssertEqual(storyTagsBefore.count, 5)

        // Simulate deleteCategory: reassign tags then delete
        let categoryName = storyCategory.name
        let tagsPredicate = #Predicate<Tag> { $0.categoryName == categoryName }
        let orphanedTags = try context.fetch(FetchDescriptor<Tag>(predicate: tagsPredicate))
        for tag in orphanedTags {
            tag.categoryName = "Uncategorized"
        }
        context.delete(storyCategory)
        try context.save()

        // Verify tags are now "Uncategorized"
        let uncategorizedPredicate = #Predicate<Tag> { $0.categoryName == "Uncategorized" }
        let reassigned = try context.fetch(FetchDescriptor<Tag>(predicate: uncategorizedPredicate))
        XCTAssertEqual(reassigned.count, 5, "5 Story tags should be reassigned to Uncategorized")

        // Verify Story category is gone
        let remaining = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertFalse(remaining.contains { $0.name == "Story" }, "Story category should be deleted")
        XCTAssertEqual(remaining.count, 4, "Should have 4 categories remaining")
    }

    func testDeleteCategoryDoesNotDeleteTags() throws {
        let allTags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(allTags.count, 25)

        let allCategories = try context.fetch(FetchDescriptor<TagCategory>())
        let combatCategory = try XCTUnwrap(allCategories.first { $0.name == "Combat" })

        // Reassign and delete
        let categoryName = combatCategory.name
        let tagsPredicate = #Predicate<Tag> { $0.categoryName == categoryName }
        let orphanedTags = try context.fetch(FetchDescriptor<Tag>(predicate: tagsPredicate))
        for tag in orphanedTags {
            tag.categoryName = "Uncategorized"
        }
        context.delete(combatCategory)
        try context.save()

        // Tags still exist — they were not deleted
        let remainingTags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(remainingTags.count, 25, "Tags are never deleted by category removal")
    }

    func testDeleteCategoryCreatesUncategorizedIfNeeded() throws {
        let allCategories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertFalse(allCategories.contains { $0.name == "Uncategorized" })

        let storyCategory = try XCTUnwrap(allCategories.first { $0.name == "Story" })

        // Create "Uncategorized" as the deleteCategory logic does
        let uncategorizedExists = allCategories.contains { $0.name == "Uncategorized" }
        if !uncategorizedExists && storyCategory.name != "Uncategorized" {
            let fallback = TagCategory(
                name: "Uncategorized",
                colorHex: "#78716C",
                iconName: "tag",
                sortOrder: allCategories.count,
                isDefault: false
            )
            context.insert(fallback)
        }

        let categoryName = storyCategory.name
        let tagsPredicate = #Predicate<Tag> { $0.categoryName == categoryName }
        let orphanedTags = try context.fetch(FetchDescriptor<Tag>(predicate: tagsPredicate))
        for tag in orphanedTags {
            tag.categoryName = "Uncategorized"
        }
        context.delete(storyCategory)
        try context.save()

        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertTrue(categories.contains { $0.name == "Uncategorized" }, "Uncategorized category should be created")
        XCTAssertFalse(categories[categories.firstIndex { $0.name == "Uncategorized" }!].isDefault,
                       "Uncategorized should have isDefault = false")
    }

    // MARK: - Reorder Persistence

    func testReorderPersistsSortOrder() throws {
        var categories = try context.fetch(FetchDescriptor<TagCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
        XCTAssertEqual(categories.map(\.name), ["Story", "Combat", "Roleplay", "World", "Meta"])

        // Simulate moving "Meta" (index 4) to index 0 by inserting before then removing original
        let moved = categories.remove(at: 4)
        categories.insert(moved, at: 0)
        for (index, cat) in categories.enumerated() {
            cat.sortOrder = index
        }
        try context.save()

        let reloaded = try context.fetch(FetchDescriptor<TagCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
        XCTAssertEqual(reloaded[0].name, "Meta")
        XCTAssertEqual(reloaded[0].sortOrder, 0)
        XCTAssertEqual(reloaded[1].name, "Story")
        XCTAssertEqual(reloaded[1].sortOrder, 1)
    }

    func testReorderAllSortOrdersAreContiguous() throws {
        var categories = try context.fetch(FetchDescriptor<TagCategory>(sortBy: [SortDescriptor(\.sortOrder)]))

        // Move "Combat" (index 1) to index 3
        let moved = categories.remove(at: 1)
        categories.insert(moved, at: 3)
        for (index, cat) in categories.enumerated() {
            cat.sortOrder = index
        }
        try context.save()

        let reloaded = try context.fetch(FetchDescriptor<TagCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
        let orders = reloaded.map(\.sortOrder)
        XCTAssertEqual(orders, [0, 1, 2, 3, 4], "sortOrder values should be contiguous after reorder")
    }
}
