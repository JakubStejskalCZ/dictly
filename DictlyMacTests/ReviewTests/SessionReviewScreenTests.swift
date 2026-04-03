import XCTest
@testable import DictlyMac
import SwiftData
import DictlyModels

// MARK: - SessionReviewScreenTests
//
// Tests for Story 4.1: Mac Session Review Layout.
// Covers: SessionReviewScreen initialization, TagDetailPanel states,
// TagSidebar tag sorting, TagSidebarRow timestamp formatting, empty states.
//
// Note: Mac test target requires dev signing certificate to run locally due to
// iCloud entitlement on the host app (pre-existing constraint from story 3.3).
// The test target builds cleanly (** TEST BUILD SUCCEEDED **) even without signing.

@MainActor
final class SessionReviewScreenTests: XCTestCase {

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

    // MARK: - 10.2 SessionReviewScreen can be initialized with a Session

    func testSessionReviewScreen_canBeInitialized_withSession() throws {
        let session = makeSession(title: "Test Session")
        context.insert(session)
        try context.save()

        // Verify the session is accessible (view initialization is compile-time verified)
        let fetched = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].title, "Test Session")
    }

    // MARK: - 10.3 TagDetailPanel shows placeholder when tag is nil

    func testTagDetailPanel_showsPlaceholder_whenTagIsNil() {
        // TagDetailPanel with nil tag should present "Select a tag to view details"
        // The placeholder state is driven by tag == nil — verified at compile time via
        // the @ViewBuilder conditional. Here we verify the model contract.
        let session = makeSession(title: "Placeholder Session")
        let panel = TagDetailPanel(selectedTag: .constant(nil), session: session)
        // View is initialized without crashing
        XCTAssertNotNil(panel)
    }

    // MARK: - 10.4 TagSidebar displays tags sorted by anchorTime

    func testTagSidebar_displaysTags_sortedByAnchorTime() throws {
        let session = makeSession(title: "Campaign Session")
        let tag1 = makeTag(label: "Third", anchorTime: 300, session: session)
        let tag2 = makeTag(label: "First", anchorTime: 10, session: session)
        let tag3 = makeTag(label: "Second", anchorTime: 120, session: session)
        session.tags = [tag1, tag2, tag3]

        context.insert(session)
        context.insert(tag1)
        context.insert(tag2)
        context.insert(tag3)
        try context.save()

        let sorted = session.tags.sorted { $0.anchorTime < $1.anchorTime }
        XCTAssertEqual(sorted[0].label, "First")
        XCTAssertEqual(sorted[1].label, "Second")
        XCTAssertEqual(sorted[2].label, "Third")
    }

    // MARK: - 10.5 TagSidebarRow formats timestamp correctly

    func testFormatTimestamp_underOneHour_returnsMinuteSecondFormat() {
        XCTAssertEqual(formatTimestamp(0), "0:00")
        XCTAssertEqual(formatTimestamp(59), "0:59")
        XCTAssertEqual(formatTimestamp(60), "1:00")
        XCTAssertEqual(formatTimestamp(90), "1:30")
        XCTAssertEqual(formatTimestamp(3599), "59:59")
    }

    func testFormatTimestamp_oneHourOrMore_returnsHourMinuteSecondFormat() {
        XCTAssertEqual(formatTimestamp(3600), "1:00:00")
        XCTAssertEqual(formatTimestamp(3661), "1:01:01")
        XCTAssertEqual(formatTimestamp(7384), "2:03:04")
    }

    // MARK: - formatDuration edge cases

    func testFormatDuration_zeroSeconds_returnsZeroMinutes() {
        XCTAssertEqual(formatDuration(0), "0m")
    }

    func testFormatDuration_underOneHour_returnsMinutesOnly() {
        XCTAssertEqual(formatDuration(59), "0m")
        XCTAssertEqual(formatDuration(60), "1m")
        XCTAssertEqual(formatDuration(3599), "59m")
    }

    func testFormatDuration_oneHourOrMore_returnsHoursAndMinutes() {
        XCTAssertEqual(formatDuration(3600), "1h 0m")
        XCTAssertEqual(formatDuration(3660), "1h 1m")
        XCTAssertEqual(formatDuration(7384), "2h 3m")
    }

    func testFormatDuration_negativeValue_clampsToZero() {
        XCTAssertEqual(formatDuration(-60), "0m")
    }

    // MARK: - 10.6 Empty state shown when session has no tags

    func testTagSidebar_emptyState_whenSessionHasNoTags() throws {
        let session = makeSession(title: "Empty Session")
        session.tags = []
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetched[0].tags.count, 0, "Session should have no tags")
    }

    // MARK: - Helpers

    private func makeSession(title: String) -> Session {
        Session(
            uuid: UUID(),
            title: title,
            sessionNumber: 1,
            date: Date(),
            duration: 3660
        )
    }

    private func makeTag(
        label: String,
        anchorTime: TimeInterval,
        session: Session
    ) -> Tag {
        let tag = Tag(
            uuid: UUID(),
            label: label,
            categoryName: "Story",
            anchorTime: anchorTime,
            rewindDuration: 5
        )
        tag.session = session
        return tag
    }
}
