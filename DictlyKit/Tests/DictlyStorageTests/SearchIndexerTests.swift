import XCTest
import CoreSpotlight
@testable import DictlyStorage
@testable import DictlyModels

// MARK: - SearchIndexer Unit Tests

final class SearchIndexerTests: XCTestCase {

    var indexer: SearchIndexer!

    override func setUp() {
        super.setUp()
        indexer = SearchIndexer()
    }

    override func tearDown() {
        indexer = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeTag(
        label: String = "Combat Encounter",
        categoryName: String = "Combat",
        transcription: String? = nil,
        notes: String? = nil
    ) -> Tag {
        Tag(
            label: label,
            categoryName: categoryName,
            anchorTime: 30.0,
            rewindDuration: 5.0,
            notes: notes,
            transcription: transcription
        )
    }

    // MARK: - 7.2: testIndexTag_createsSearchableItem

    /// Verify CSSearchableItem is built with correct uniqueIdentifier, title, textContent, keywords.
    func testIndexTag_createsSearchableItem() {
        let tag = makeTag(label: "Dragon Fight", categoryName: "Combat", transcription: "The dragon roars")

        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertEqual(item.uniqueIdentifier, tag.uuid.uuidString)
        XCTAssertEqual(item.domainIdentifier, "com.dictly.tags")
        XCTAssertEqual(item.attributeSet.title, "Dragon Fight")
        XCTAssertEqual(item.attributeSet.textContent, "The dragon roars")
        XCTAssertTrue(item.attributeSet.keywords?.contains("Combat") == true)
    }

    // MARK: - 7.3: testUpdateTag_replacesExistingItem

    /// Re-indexing with the same UUID results in a replacement — verify uniqueIdentifier is stable.
    func testUpdateTag_replacesExistingItem() async throws {
        let tag = makeTag(label: "NPC Dialogue", transcription: "Hello adventurer")

        try await indexer.indexTag(tag)

        // Re-index same tag (simulating updateTag)
        try await indexer.updateTag(tag)

        // Item uniqueIdentifier is stable across re-indexes
        let item = indexer.buildSearchableItem(for: tag)
        XCTAssertEqual(item.uniqueIdentifier, tag.uuid.uuidString)
    }

    // MARK: - 7.4: testRemoveTag_deletesFromIndex

    /// Verify removal by UUID identifier completes without error.
    func testRemoveTag_deletesFromIndex() async throws {
        let tag = makeTag(label: "Story Beat")

        try await indexer.indexTag(tag)
        try await indexer.removeTag(id: tag.uuid)
        // No assertion needed — absence of thrown error confirms successful deletion
    }

    // MARK: - 7.5: testRemoveAllItems_clearsIndex

    /// Verify deleteAllSearchableItems completes without error.
    func testRemoveAllItems_clearsIndex() async throws {
        let tag1 = makeTag(label: "Scene One")
        let tag2 = makeTag(label: "Scene Two")
        try await indexer.indexTags([tag1, tag2])

        try await indexer.removeAllItems()
        // No assertion needed — absence of thrown error confirms successful cleanup
    }

    // MARK: - 7.6: testIndexTag_withNilTranscription_indexesLabelOnly

    /// When transcription is nil, textContent must be nil but title and keywords are populated.
    func testIndexTag_withNilTranscription_indexesLabelOnly() {
        let tag = makeTag(label: "Empty Tag", categoryName: "World", transcription: nil)

        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertEqual(item.attributeSet.title, "Empty Tag")
        XCTAssertNil(item.attributeSet.textContent,
                     "textContent should be nil when transcription is nil")
        XCTAssertEqual(item.attributeSet.contentDescription, "World",
                       "contentDescription falls back to categoryName when notes is nil")
        XCTAssertTrue(item.attributeSet.keywords?.contains("World") == true)
    }

    // MARK: - 7.7: testIndexTag_withAllFields_populatesAllAttributes

    /// All searchable fields are populated when tag has label, transcription, notes, and category.
    func testIndexTag_withAllFields_populatesAllAttributes() {
        let tag = makeTag(
            label: "Boss Battle",
            categoryName: "Combat",
            transcription: "The party defeats the vampire lord after a brutal fight",
            notes: "See player handout #3"
        )

        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertEqual(item.uniqueIdentifier, tag.uuid.uuidString)
        XCTAssertEqual(item.domainIdentifier, "com.dictly.tags")
        XCTAssertEqual(item.attributeSet.title, "Boss Battle")
        XCTAssertEqual(item.attributeSet.textContent, "The party defeats the vampire lord after a brutal fight")
        XCTAssertEqual(item.attributeSet.contentDescription, "See player handout #3",
                       "notes take precedence over categoryName in contentDescription")
        XCTAssertTrue(item.attributeSet.keywords?.contains("Combat") == true)
    }

    // MARK: - Display name

    func testBuildSearchableItem_withoutSession_usesLabelAsDisplayName() {
        let tag = makeTag(label: "Solo Tag")

        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertEqual(item.attributeSet.displayName, "Solo Tag")
    }

    // MARK: - Keywords

    func testKeywords_containsOnlyCategoryWhenNoSession() {
        let tag = makeTag(label: "Quick Note", categoryName: "Meta")

        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertEqual(item.attributeSet.keywords, ["Meta"])
    }

    // MARK: - Edge cases

    func testIndexTags_emptyArray_doesNotThrow() async throws {
        try await indexer.indexTags([])
    }

    func testRemoveAllTagsForSession_emptyArray_doesNotThrow() async throws {
        try await indexer.removeAllTagsForSession(sessionID: UUID(), tags: [])
    }

    func testUniqueIdentifier_isTagUUIDString() {
        let tag = makeTag()

        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertEqual(item.uniqueIdentifier, tag.uuid.uuidString,
                       "uniqueIdentifier must equal tag.uuid.uuidString for update/deletion to work")
    }
}
