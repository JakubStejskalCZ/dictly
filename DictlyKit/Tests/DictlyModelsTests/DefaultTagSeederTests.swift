import XCTest
import SwiftData
@testable import DictlyModels

@MainActor
final class DefaultTagSeederTests: XCTestCase {
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

    // MARK: - Category count

    func testSeedCreates5Categories() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)
        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(categories.count, 5, "Expected exactly 5 default categories")
    }

    func testSeedCategoryNames() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)
        let categories = try context.fetch(FetchDescriptor<TagCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
        let names = categories.map(\.name)
        XCTAssertEqual(names, ["Story", "Combat", "Roleplay", "World", "Meta"])
    }

    func testSeedCategoryColors() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)
        let categories = try context.fetch(FetchDescriptor<TagCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
        XCTAssertEqual(categories[0].colorHex, "#D97706") // Story
        XCTAssertEqual(categories[1].colorHex, "#DC2626") // Combat
        XCTAssertEqual(categories[2].colorHex, "#7C3AED") // Roleplay
        XCTAssertEqual(categories[3].colorHex, "#059669") // World
        XCTAssertEqual(categories[4].colorHex, "#4B7BE5") // Meta
    }

    func testSeedCategoryIsDefault() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)
        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertTrue(categories.allSatisfy(\.isDefault), "All seeded categories should have isDefault = true")
    }

    func testSeedCategorySortOrder() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)
        let categories = try context.fetch(FetchDescriptor<TagCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
        for (index, cat) in categories.enumerated() {
            XCTAssertEqual(cat.sortOrder, index)
        }
    }

    // MARK: - Tag count

    func testSeedCreates25Tags() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)
        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags.count, 25, "Expected 5 tags per category × 5 categories = 25 tags")
    }

    func testSeedTagsPerCategory() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)
        for categoryName in ["Story", "Combat", "Roleplay", "World", "Meta"] {
            let predicate = #Predicate<Tag> { $0.categoryName == categoryName }
            let tags = try context.fetch(FetchDescriptor<Tag>(predicate: predicate))
            XCTAssertEqual(tags.count, 5, "Expected 5 tags for category \(categoryName)")
        }
    }

    func testSeedTagsHaveNoSession() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)
        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertTrue(tags.allSatisfy { $0.session == nil }, "Seeded template tags should have no session")
    }

    func testSeedStoryTags() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)
        let predicate = #Predicate<Tag> { $0.categoryName == "Story" }
        let tags = try context.fetch(FetchDescriptor<Tag>(predicate: predicate))
        let labels = Set(tags.map(\.label))
        let expected: Set<String> = ["Plot Hook", "Lore Drop", "Quest Update", "Foreshadowing", "Revelation"]
        XCTAssertEqual(labels, expected)
    }

    func testSeedCombatTags() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)
        let predicate = #Predicate<Tag> { $0.categoryName == "Combat" }
        let tags = try context.fetch(FetchDescriptor<Tag>(predicate: predicate))
        let labels = Set(tags.map(\.label))
        let expected: Set<String> = ["Initiative", "Epic Roll", "Critical Hit", "Encounter Start", "Encounter End"]
        XCTAssertEqual(labels, expected)
    }

    // MARK: - Idempotency

    func testSeedIdempotencyDoesNotDuplicate() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)
        try DefaultTagSeeder.seedIfNeeded(context: context) // second call
        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(categories.count, 5, "Second seed call should not create more categories")
        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags.count, 25, "Second seed call should not create more tags")
    }

    func testSeedIdempotencyWhenCategoryExists() throws {
        // Pre-insert one category so seeder is skipped
        let existing = TagCategory(name: "Custom", colorHex: "#000000", iconName: "tag")
        context.insert(existing)
        try context.save()

        try DefaultTagSeeder.seedIfNeeded(context: context)
        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(categories.count, 1, "Seeder should not run when categories already exist")
        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags.count, 0, "Seeder should not add tags when skipped")
    }
}
