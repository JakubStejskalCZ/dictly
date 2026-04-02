import XCTest
@testable import DictlyMac
import SwiftData
import DictlyModels

// MARK: - TagSidebarFilterTests
//
// Tests for Story 4.4: Tag Sidebar with Category Filtering.
// Covers: category filter logic, search text filtering, combined filters,
// and waveform marker opacity (isFiltered) computation.
//
// Filter logic mirrors TagSidebar.filteredTags and SessionWaveformTimeline.tagMarkersLayer.
// Tested as pure functions per project convention (no UI dependency).
//
// Note: Mac test target requires dev signing certificate to run locally due to
// iCloud entitlement on the host app (pre-existing constraint from story 3.3).
// The test target builds cleanly (** TEST BUILD SUCCEEDED **) even without signing.

@MainActor
final class TagSidebarFilterTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema(DictlySchema.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - 7.2 No active categories → all tags shown

    func testFilterTags_noActiveCategories_returnsAllTags() {
        let tags = [
            makeTag(label: "Dragon Attack", categoryName: "Combat", anchorTime: 10),
            makeTag(label: "Meet the Merchant", categoryName: "Story", anchorTime: 20),
            makeTag(label: "Tavern scene", categoryName: "Roleplay", anchorTime: 30),
        ]

        let result = applyFilter(tags: tags, activeCategories: [], searchText: "")

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.map(\.label), ["Dragon Attack", "Meet the Merchant", "Tavern scene"])
    }

    // MARK: - 7.3 Single category active → only matching tags shown

    func testFilterTags_singleCategoryActive_returnsMatchingTagsOnly() {
        let tags = [
            makeTag(label: "Ambush", categoryName: "Combat", anchorTime: 5),
            makeTag(label: "Travel begins", categoryName: "Story", anchorTime: 15),
            makeTag(label: "Barter", categoryName: "Combat", anchorTime: 25),
        ]

        let result = applyFilter(tags: tags, activeCategories: ["Combat"], searchText: "")

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.categoryName == "Combat" })
    }

    func testFilterTags_singleCategoryActive_noMatchingTags_returnsEmpty() {
        let tags = [
            makeTag(label: "Prophecy", categoryName: "Story", anchorTime: 5),
            makeTag(label: "Flashback", categoryName: "Story", anchorTime: 15),
        ]

        let result = applyFilter(tags: tags, activeCategories: ["Combat"], searchText: "")

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - 7.4 Multiple categories active → tags from all selected categories shown

    func testFilterTags_multipleCategoriesActive_returnsAllMatchingTags() {
        let tags = [
            makeTag(label: "Ambush", categoryName: "Combat", anchorTime: 5),
            makeTag(label: "Tavern scene", categoryName: "Roleplay", anchorTime: 10),
            makeTag(label: "Prophecy", categoryName: "Story", anchorTime: 15),
            makeTag(label: "New city", categoryName: "World", anchorTime: 20),
        ]

        let result = applyFilter(tags: tags, activeCategories: ["Combat", "Roleplay"], searchText: "")

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains(where: { $0.categoryName == "Combat" }))
        XCTAssertTrue(result.contains(where: { $0.categoryName == "Roleplay" }))
        XCTAssertFalse(result.contains(where: { $0.categoryName == "Story" }))
        XCTAssertFalse(result.contains(where: { $0.categoryName == "World" }))
    }

    // MARK: - 7.5 Search text filters by label (case-insensitive)

    func testFilterTags_searchText_caseInsensitiveMatch() {
        let tags = [
            makeTag(label: "Dragon Attack", categoryName: "Combat", anchorTime: 10),
            makeTag(label: "dragon rider", categoryName: "Story", anchorTime: 20),
            makeTag(label: "Tavern Brawl", categoryName: "Roleplay", anchorTime: 30),
        ]

        let result = applyFilter(tags: tags, activeCategories: [], searchText: "dragon")

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.label.localizedCaseInsensitiveContains("dragon") })
    }

    func testFilterTags_searchText_noMatch_returnsEmpty() {
        let tags = [
            makeTag(label: "Dragon Attack", categoryName: "Combat", anchorTime: 10),
        ]

        let result = applyFilter(tags: tags, activeCategories: [], searchText: "goblin")

        XCTAssertTrue(result.isEmpty)
    }

    func testFilterTags_searchTextWhitespaceOnly_treatedAsNoFilter() {
        let tags = [
            makeTag(label: "Something", categoryName: "Story", anchorTime: 10),
        ]

        let result = applyFilter(tags: tags, activeCategories: [], searchText: "   ")

        XCTAssertEqual(result.count, 1)
    }

    // MARK: - 7.6 Combined category + search filter

    func testFilterTags_combinedCategoryAndSearch_bothMustPass() {
        let tags = [
            makeTag(label: "Dragon Attack", categoryName: "Combat", anchorTime: 5),
            makeTag(label: "Dragon Prophecy", categoryName: "Story", anchorTime: 10),
            makeTag(label: "Ambush", categoryName: "Combat", anchorTime: 15),
        ]

        // Only Combat + contains "dragon"
        let result = applyFilter(tags: tags, activeCategories: ["Combat"], searchText: "dragon")

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].label, "Dragon Attack")
    }

    func testFilterTags_combinedFilter_noMatch_returnsEmpty() {
        let tags = [
            makeTag(label: "Ambush", categoryName: "Combat", anchorTime: 5),
            makeTag(label: "Dragon Prophecy", categoryName: "Story", anchorTime: 10),
        ]

        let result = applyFilter(tags: tags, activeCategories: ["Roleplay"], searchText: "dragon")

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - 7.7 Marker opacity — activeCategories non-empty

    func testMarkerIsFiltered_activeCategoriesNonEmpty_tagInSet_returnsFalse() {
        let tag = makeTag(label: "Ambush", categoryName: "Combat", anchorTime: 5)
        let activeCategories: Set<String> = ["Combat", "Story"]

        let isFiltered = computeIsFiltered(tag: tag, activeCategories: activeCategories)

        XCTAssertFalse(isFiltered, "Tag in active set should NOT be filtered (renders at normal opacity)")
    }

    func testMarkerIsFiltered_activeCategoriesNonEmpty_tagNotInSet_returnsTrue() {
        let tag = makeTag(label: "Tavern scene", categoryName: "Roleplay", anchorTime: 10)
        let activeCategories: Set<String> = ["Combat", "Story"]

        let isFiltered = computeIsFiltered(tag: tag, activeCategories: activeCategories)

        XCTAssertTrue(isFiltered, "Tag not in active set should be filtered (renders at 25% opacity)")
    }

    func testMarkerIsFiltered_singleCategoryActive_matchingTag_returnsFalse() {
        let tag = makeTag(label: "Sword fight", categoryName: "Combat", anchorTime: 5)
        let activeCategories: Set<String> = ["Combat"]

        let isFiltered = computeIsFiltered(tag: tag, activeCategories: activeCategories)

        XCTAssertFalse(isFiltered)
    }

    func testMarkerIsFiltered_singleCategoryActive_nonMatchingTag_returnsTrue() {
        let tag = makeTag(label: "City lore", categoryName: "World", anchorTime: 5)
        let activeCategories: Set<String> = ["Combat"]

        let isFiltered = computeIsFiltered(tag: tag, activeCategories: activeCategories)

        XCTAssertTrue(isFiltered)
    }

    // MARK: - 7.8 Marker opacity — activeCategories empty → all normal opacity

    func testMarkerIsFiltered_emptyCategoryFilter_allTagsReturnFalse() {
        let tags = [
            makeTag(label: "Ambush", categoryName: "Combat", anchorTime: 5),
            makeTag(label: "Tavern scene", categoryName: "Roleplay", anchorTime: 10),
            makeTag(label: "Prophecy", categoryName: "Story", anchorTime: 15),
        ]
        let activeCategories: Set<String> = []

        for tag in tags {
            let isFiltered = computeIsFiltered(tag: tag, activeCategories: activeCategories)
            XCTAssertFalse(isFiltered, "\(tag.categoryName) tag should not be filtered when activeCategories is empty")
        }
    }

    // MARK: - Sort order preserved

    func testFilterTags_preservesChronologicalOrder() {
        let tags = [
            makeTag(label: "C", categoryName: "Story", anchorTime: 30),
            makeTag(label: "A", categoryName: "Story", anchorTime: 10),
            makeTag(label: "B", categoryName: "Story", anchorTime: 20),
        ]

        let result = applyFilter(tags: tags, activeCategories: [], searchText: "")

        XCTAssertEqual(result.map(\.label), ["A", "B", "C"])
    }

    // MARK: - Helpers

    /// Mirrors `TagSidebar.filteredTags` logic as a pure function for testing.
    private func applyFilter(
        tags: [Tag],
        activeCategories: Set<String>,
        searchText: String
    ) -> [Tag] {
        var result = tags.sorted { $0.anchorTime < $1.anchorTime }
        if !activeCategories.isEmpty {
            result = result.filter { activeCategories.contains($0.categoryName) }
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            result = result.filter { $0.label.localizedCaseInsensitiveContains(trimmed) }
        }
        return result
    }

    /// Mirrors `SessionWaveformTimeline.tagMarkersLayer` isFiltered computation as a pure function.
    private func computeIsFiltered(tag: Tag, activeCategories: Set<String>) -> Bool {
        !activeCategories.isEmpty && !activeCategories.contains(tag.categoryName)
    }

    private func makeTag(
        label: String,
        categoryName: String,
        anchorTime: TimeInterval
    ) -> Tag {
        Tag(
            uuid: UUID(),
            label: label,
            categoryName: categoryName,
            anchorTime: anchorTime,
            rewindDuration: 0
        )
    }
}
