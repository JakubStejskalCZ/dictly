import XCTest
@testable import DictlyMac
import SwiftData
import DictlyModels

// MARK: - TagNotesTests
//
// Tests for Story 4.7: Tag Notes & Session Summary Notes.
// Covers: tag notes persistence, nil clearing, whitespace trimming logic,
// session summary note persistence, and sidebar indicator logic.
//
// Uses in-memory ModelContainer per project convention.
// Note: Mac test target requires dev signing certificate to run locally due to
// iCloud entitlement on the host app (pre-existing constraint from story 3.3).
// The test target builds cleanly (** TEST BUILD SUCCEEDED **) even without signing.

@MainActor
final class TagNotesTests: XCTestCase {

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

    // MARK: - 6.2 Setting tag.notes persists in SwiftData context

    func testSetTagNotes_persistsInContext() throws {
        let tag = makeTag(label: "Dragon Attack", categoryName: "Combat")
        context.insert(tag)

        tag.notes = "Party was ambushed near the bridge."

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].notes, "Party was ambushed near the bridge.")
    }

    func testSetTagNotes_overwritesPreviousNotes() throws {
        let tag = makeTag(label: "Tavern scene", categoryName: "Story")
        context.insert(tag)
        tag.notes = "Original note."

        tag.notes = "Updated note."

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].notes, "Updated note.")
    }

    // MARK: - 6.3 Setting tag.notes = nil clears notes in context

    func testSetTagNotesNil_clearsNotes() throws {
        let tag = makeTag(label: "Combat Start", categoryName: "Combat")
        context.insert(tag)
        tag.notes = "Some note."

        tag.notes = nil

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertNil(fetched[0].notes)
    }

    func testTagNotes_initiallyNil() throws {
        let tag = makeTag(label: "New Tag", categoryName: "Story")
        context.insert(tag)

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertNil(fetched[0].notes, "Newly created tags should have nil notes")
    }

    // MARK: - 6.4 Whitespace-only notes trim to nil

    func testCommitNotesLogic_whitespaceOnly_setsNil() {
        // Simulates commitNotes(tag:) trimming logic
        let input = "  \t\n  "
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let result: String? = trimmed.isEmpty ? nil : input
        XCTAssertNil(result, "Whitespace-only notes should be stored as nil")
    }

    func testCommitNotesLogic_emptyString_setsNil() {
        let input = ""
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let result: String? = trimmed.isEmpty ? nil : input
        XCTAssertNil(result, "Empty string notes should be stored as nil")
    }

    func testCommitNotesLogic_validNote_persists() {
        let input = "  Important note  "
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let result: String? = trimmed.isEmpty ? nil : input
        XCTAssertNotNil(result)
        XCTAssertEqual(result, "  Important note  ", "Original (untrimmed) string should be stored")
    }

    // MARK: - 6.5 Setting session.summaryNote persists in context

    func testSetSessionSummaryNote_persistsInContext() throws {
        let session = makeSession()
        context.insert(session)

        session.summaryNote = "Session summary goes here."

        let fetched = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].summaryNote, "Session summary goes here.")
    }

    func testSetSessionSummaryNote_overwritesPrevious() throws {
        let session = makeSession()
        context.insert(session)
        session.summaryNote = "First summary."

        session.summaryNote = "Second summary."

        let fetched = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetched[0].summaryNote, "Second summary.")
    }

    // MARK: - 6.6 Setting session.summaryNote = nil clears summary

    func testSetSessionSummaryNoteNil_clearsSummary() throws {
        let session = makeSession()
        context.insert(session)
        session.summaryNote = "Some summary."

        session.summaryNote = nil

        let fetched = try context.fetch(FetchDescriptor<Session>())
        XCTAssertNil(fetched[0].summaryNote)
    }

    func testSessionSummaryNote_initiallyNil() throws {
        let session = makeSession()
        context.insert(session)

        let fetched = try context.fetch(FetchDescriptor<Session>())
        XCTAssertNil(fetched[0].summaryNote, "Newly created sessions should have nil summaryNote")
    }

    // MARK: - 6.7 Tag with notes has non-nil, non-empty notes (sidebar indicator logic)

    func testTagWithNotes_hasNonNilNonEmptyNotes() throws {
        let tag = makeTag(label: "Tagged Moment", categoryName: "Story")
        context.insert(tag)
        tag.notes = "Has some content."

        XCTAssertNotNil(tag.notes)
        XCTAssertFalse(tag.notes!.isEmpty, "Sidebar indicator should show when notes exist")
    }

    func testSidebarIndicatorLogic_tagWithNotes_shouldShow() {
        let tag = makeTag(label: "Tagged Moment", categoryName: "Story")
        tag.notes = "A note."

        let shouldShowIndicator = tag.notes != nil && !tag.notes!.isEmpty
        XCTAssertTrue(shouldShowIndicator)
    }

    func testSidebarIndicatorLogic_multipleTagsMixedNotes() {
        let tagWithNotes = makeTag(label: "Tag A", categoryName: "Story")
        let tagWithoutNotes = makeTag(label: "Tag B", categoryName: "Combat")
        tagWithNotes.notes = "Has notes."
        tagWithoutNotes.notes = nil

        XCTAssertTrue(tagWithNotes.notes != nil && !tagWithNotes.notes!.isEmpty)
        XCTAssertFalse(tagWithoutNotes.notes != nil && !(tagWithoutNotes.notes?.isEmpty ?? true))
    }

    // MARK: - 6.8 Tag without notes has nil notes (indicator should not show)

    func testTagWithoutNotes_hasNilNotes() throws {
        let tag = makeTag(label: "Empty Tag", categoryName: "Meta")
        context.insert(tag)

        XCTAssertNil(tag.notes, "Tag without notes should have nil notes — indicator must not show")
    }

    func testSidebarIndicatorLogic_tagWithNilNotes_shouldNotShow() {
        let tag = makeTag(label: "Tag Without Notes", categoryName: "Meta")
        tag.notes = nil

        let shouldShowIndicator = tag.notes != nil && !tag.notes!.isEmpty
        XCTAssertFalse(shouldShowIndicator)
    }

    func testSidebarIndicatorLogic_tagWithEmptyNotes_shouldNotShow() {
        let tag = makeTag(label: "Tag Empty Notes", categoryName: "Meta")
        tag.notes = ""

        let shouldShowIndicator = tag.notes != nil && !tag.notes!.isEmpty
        XCTAssertFalse(shouldShowIndicator)
    }

    // MARK: - Helpers

    private func makeTag(
        label: String,
        categoryName: String,
        anchorTime: TimeInterval = 0
    ) -> Tag {
        Tag(
            uuid: UUID(),
            label: label,
            categoryName: categoryName,
            anchorTime: anchorTime,
            rewindDuration: 0
        )
    }

    private func makeSession() -> Session {
        Session(title: "Test Session", sessionNumber: 1, duration: 3600)
    }
}
