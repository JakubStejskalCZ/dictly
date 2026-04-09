import XCTest
import CoreSpotlight
import SwiftData
@testable import DictlyStorage
@testable import DictlyModels

// MARK: - SearchIndexer E2E Tests (Story 6.1)
//
// End-to-end tests for Core Spotlight Indexing.
// Covers all acceptance criteria:
//   AC1: Tag create/import → CSSearchableItem with correct attributes
//   AC2: Transcription edit → index entry updated
//   AC3: Tag/session delete → index entries removed
//   AC4: macOS Spotlight integration (default index used)
//
// Non-@MainActor tests match SearchIndexerTests pattern for async indexer calls.
// Relationship-dependent tests (AC1 session context) use @MainActor with sync buildSearchableItem.

// MARK: - Indexer Lifecycle Tests (async, non-@MainActor)

@MainActor
final class SearchIndexerE2ETests: XCTestCase {

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
        label: String = "Test Tag",
        categoryName: String = "Story",
        anchorTime: TimeInterval = 30.0,
        transcription: String? = nil,
        notes: String? = nil
    ) -> Tag {
        Tag(
            label: label,
            categoryName: categoryName,
            anchorTime: anchorTime,
            rewindDuration: 5.0,
            notes: notes,
            transcription: transcription
        )
    }

    // MARK: - AC1: Tag create → CSSearchableItem with correct attributes

    func testAC1_tagCreated_searchableItemHasTagLabel() {
        let tag = makeTag(label: "Grimthor's Promise", categoryName: "Story")
        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertEqual(item.attributeSet.title, "Grimthor's Promise",
                       "CSSearchableItem title must match tag label")
    }

    func testAC1_tagCreated_searchableItemHasTranscription() {
        let tag = makeTag(
            label: "Dragon Attack",
            transcription: "The dragon descended from the mountain with a deafening roar"
        )
        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertEqual(item.attributeSet.textContent,
                       "The dragon descended from the mountain with a deafening roar",
                       "CSSearchableItem textContent must contain full transcription")
    }

    func testAC1_tagCreated_searchableItemHasNotes() {
        let tag = makeTag(label: "Plot Hook", notes: "Player handout #3")
        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertEqual(item.attributeSet.contentDescription, "Player handout #3",
                       "Notes should appear in contentDescription")
    }

    func testAC1_tagCreated_searchableItemHasCategory() {
        let tag = makeTag(label: "Ambush", categoryName: "Combat")
        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertTrue(item.attributeSet.keywords?.contains("Combat") == true,
                      "Category must be in keywords")
    }

    func testAC1_tagCreated_uniqueIdentifierIsTagUUID() {
        let tag = makeTag(label: "Quick Note")
        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertEqual(item.uniqueIdentifier, tag.uuid.uuidString)
        XCTAssertEqual(item.domainIdentifier, "com.dictly.tags")
    }

    func testAC1_tagCreated_indexTagDoesNotThrow() async throws {
        let tag = makeTag(label: "Fire-and-Forget", transcription: "Some text")
        try await indexer.indexTag(tag)
    }

    func testAC1_batchImport_indexTagsDoesNotThrow() async throws {
        let tags = (1...5).map { i in
            makeTag(label: "Imported Tag \(i)", categoryName: "Story", transcription: "Text \(i)")
        }
        try await indexer.indexTags(tags)
    }

    func testAC1_tagWithoutSession_indexesLabelOnly() {
        let tag = makeTag(label: "Orphan Tag", categoryName: "Meta")
        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertEqual(item.attributeSet.title, "Orphan Tag")
        XCTAssertEqual(item.attributeSet.displayName, "Orphan Tag",
                       "Without session, displayName should fall back to label")
        XCTAssertEqual(item.attributeSet.keywords, ["Meta"],
                       "Without session, only category in keywords")
    }

    func testAC1_tagWithNilTranscriptionAndNotes_partialIndex() {
        let tag = makeTag(label: "Minimal", categoryName: "Combat", transcription: nil, notes: nil)
        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertEqual(item.attributeSet.title, "Minimal")
        XCTAssertNil(item.attributeSet.textContent)
        XCTAssertEqual(item.attributeSet.contentDescription, "Combat",
                       "Falls back to category when notes is nil")
    }

    func testAC1_tagWithAllFields_populatesEveryAttribute() {
        let tag = makeTag(
            label: "Boss Battle",
            categoryName: "Combat",
            transcription: "The party defeats the vampire lord",
            notes: "See player handout #3"
        )
        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertEqual(item.uniqueIdentifier, tag.uuid.uuidString)
        XCTAssertEqual(item.domainIdentifier, "com.dictly.tags")
        XCTAssertEqual(item.attributeSet.title, "Boss Battle")
        XCTAssertEqual(item.attributeSet.textContent, "The party defeats the vampire lord")
        XCTAssertEqual(item.attributeSet.contentDescription, "See player handout #3")
        XCTAssertTrue(item.attributeSet.keywords?.contains("Combat") == true)
    }

    // MARK: - AC2: Transcription edit → index entry updated

    func testAC2_transcriptionChanged_updateTagDoesNotThrow() async throws {
        let tag = makeTag(label: "Scene One", transcription: "Original text")
        try await indexer.indexTag(tag)

        tag.transcription = "Updated transcription with new content"
        try await indexer.updateTag(tag)
    }

    func testAC2_transcriptionChanged_searchableItemReflectsNewText() {
        let tag = makeTag(label: "Scene One", transcription: "Original text")

        tag.transcription = "Updated transcription content"
        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertEqual(item.attributeSet.textContent, "Updated transcription content",
                       "After edit, textContent must reflect updated transcription")
        XCTAssertEqual(item.uniqueIdentifier, tag.uuid.uuidString,
                       "UUID must remain stable across updates")
    }

    func testAC2_notesEdited_searchableItemReflectsNewNotes() {
        let tag = makeTag(label: "Important", notes: "Old notes")

        tag.notes = "New important notes"
        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertEqual(item.attributeSet.contentDescription, "New important notes")
    }

    func testAC2_labelRenamed_searchableItemReflectsNewLabel() {
        let tag = makeTag(label: "Old Label")

        tag.label = "New Label"
        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertEqual(item.attributeSet.title, "New Label",
                       "After rename, title must reflect new label")
    }

    // MARK: - AC3: Tag/session delete → index entries removed

    func testAC3_tagDeleted_removeTagDoesNotThrow() async throws {
        let tag = makeTag(label: "Doomed Tag")
        try await indexer.indexTag(tag)
        try await indexer.removeTag(id: tag.uuid)
    }

    func testAC3_removeAllItems_clearsEntireIndex() async throws {
        let tags = (1...3).map { i in makeTag(label: "Tag \(i)") }
        try await indexer.indexTags(tags)
        try await indexer.removeAllItems()
    }

    func testAC3_removeAllTagsForSession_emptyTagsList() async throws {
        try await indexer.removeAllTagsForSession(sessionID: UUID(), tags: [])
    }

    // MARK: - AC4: macOS Spotlight integration (default index)

    func testAC4_domainIdentifierIsCorrect() {
        let tag = makeTag(label: "Spotlight Test")
        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertEqual(item.domainIdentifier, "com.dictly.tags",
                       "Domain identifier must be 'com.dictly.tags' for batch operations")
    }

    // MARK: - E2E: Full tag lifecycle (create → update → delete)

    func testE2E_fullTagLifecycle_createUpdateDelete() async throws {
        let tag = makeTag(label: "Boss Fight", categoryName: "Combat", transcription: "Roll initiative!")

        // 1. Create and index
        try await indexer.indexTag(tag)
        var item = indexer.buildSearchableItem(for: tag)
        XCTAssertEqual(item.attributeSet.title, "Boss Fight")
        XCTAssertEqual(item.attributeSet.textContent, "Roll initiative!")

        // 2. Update transcription
        tag.transcription = "The party rolled poorly on initiative. TPK incoming."
        try await indexer.updateTag(tag)
        item = indexer.buildSearchableItem(for: tag)
        XCTAssertEqual(item.attributeSet.textContent, "The party rolled poorly on initiative. TPK incoming.")
        XCTAssertEqual(item.uniqueIdentifier, tag.uuid.uuidString, "UUID stable across updates")

        // 3. Delete
        try await indexer.removeTag(id: tag.uuid)
    }

    func testE2E_batchImportLifecycle() async throws {
        let tags = (1...10).map { i in
            makeTag(label: "Imported \(i)", categoryName: i % 2 == 0 ? "Combat" : "Story",
                    transcription: "Transcription for imported tag \(i)")
        }

        // Batch index (import flow)
        try await indexer.indexTags(tags)

        // Verify all tags produce valid searchable items
        for tag in tags {
            let item = indexer.buildSearchableItem(for: tag)
            XCTAssertEqual(item.uniqueIdentifier, tag.uuid.uuidString)
            XCTAssertNotNil(item.attributeSet.title)
            XCTAssertNotNil(item.attributeSet.textContent)
        }

        // Clean up
        try await indexer.removeAllItems()
    }
}

// MARK: - Relationship-Dependent Tests (sync, @MainActor)

@MainActor
final class SearchIndexerRelationshipE2ETests: XCTestCase {

    var indexer: SearchIndexer!
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        indexer = SearchIndexer()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Schema(DictlySchema.all), configurations: config)
        context = container.mainContext
    }

    override func tearDown() async throws {
        indexer = nil
        container = nil
        context = nil
    }

    func testAC1_tagWithSessionAndCampaign_keywordsIncludeSessionAndCampaign() throws {
        let campaign = Campaign(name: "Ashlands Campaign")
        let session = Session(title: "Into the Ashlands", sessionNumber: 3)
        let tag = Tag(label: "NPC Introduction", categoryName: "Story",
                      anchorTime: 100, rewindDuration: 5)

        context.insert(campaign)
        context.insert(session)
        context.insert(tag)
        campaign.sessions.append(session)
        session.tags.append(tag)
        try context.save()

        let item = indexer.buildSearchableItem(for: tag)

        XCTAssertTrue(item.attributeSet.keywords?.contains("Into the Ashlands") == true,
                      "Session title must be in keywords")
        XCTAssertTrue(item.attributeSet.keywords?.contains("Ashlands Campaign") == true,
                      "Campaign name must be in keywords")
        XCTAssertTrue(item.attributeSet.displayName?.contains("Into the Ashlands") == true,
                      "Display name should include session title")
    }

    func testAC1_multipleSessionsInCampaign_eachTagHasCorrectContext() throws {
        let campaign = Campaign(name: "E2E Campaign")
        context.insert(campaign)

        for i in 1...3 {
            let session = Session(title: "Session \(i)", sessionNumber: i)
            let tag = Tag(label: "Event \(i)", categoryName: "Story",
                          anchorTime: Double(i * 100), rewindDuration: 5,
                          transcription: "Something happened in session \(i)")
            context.insert(session)
            context.insert(tag)
            campaign.sessions.append(session)
            session.tags.append(tag)
        }
        try context.save()

        for session in campaign.sessions {
            for tag in session.tags {
                let item = indexer.buildSearchableItem(for: tag)
                XCTAssertTrue(item.attributeSet.keywords?.contains("E2E Campaign") == true,
                              "All tags should reference campaign name")
                XCTAssertTrue(item.attributeSet.keywords?.contains(session.title) == true,
                              "Tag should reference its own session title")
            }
        }
    }

    func testAC3_sessionTagsForRemoval_allUUIDsAvailable() throws {
        let session = Session(title: "Session to Delete", sessionNumber: 1)
        context.insert(session)

        let tags = (1...5).map { i -> Tag in
            let tag = Tag(label: "Tag \(i)", categoryName: "Story",
                          anchorTime: Double(i * 10), rewindDuration: 0)
            context.insert(tag)
            session.tags.append(tag)
            return tag
        }
        try context.save()

        // Verify all tag UUIDs are accessible for removal
        XCTAssertEqual(session.tags.count, 5)
        for tag in tags {
            XCTAssertFalse(tag.uuid.uuidString.isEmpty)
        }
    }
}
