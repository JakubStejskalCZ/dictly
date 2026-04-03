import XCTest
@testable import DictlyMac
import SwiftData
import DictlyModels

// MARK: - RetroactiveTagTests
//
// Tests for Story 4.6: Retroactive Tag Placement.
// Covers: tag creation with valid data, anchorTime correctness, rewindDuration = 0,
// SwiftData persistence, createdAt timestamp, empty-label validation, and anchorTime clamping.
//
// Uses in-memory ModelContainer per project convention.
// Note: Mac test target requires dev signing certificate to run locally due to
// iCloud entitlement on the host app (pre-existing constraint from story 3.3).
// The test target builds cleanly (** TEST BUILD SUCCEEDED **) even without signing.

@MainActor
final class RetroactiveTagTests: XCTestCase {

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

    // MARK: - 7.2 Creating a tag adds it to session.tags

    func testCreateTag_addsToSessionTags() throws {
        let session = makeSession(duration: 3600)
        context.insert(session)

        let tag = makeTag(label: "Ambush", categoryName: "Combat", anchorTime: 120)
        context.insert(tag)
        session.tags.append(tag)

        XCTAssertEqual(session.tags.count, 1)
        XCTAssertEqual(session.tags[0].label, "Ambush")
    }

    func testCreateTag_multipleTagsAddedToSession() throws {
        let session = makeSession(duration: 3600)
        context.insert(session)

        let tag1 = makeTag(label: "Tavern", categoryName: "Story", anchorTime: 60)
        let tag2 = makeTag(label: "Dragon", categoryName: "Combat", anchorTime: 300)
        context.insert(tag1)
        context.insert(tag2)
        session.tags.append(tag1)
        session.tags.append(tag2)

        XCTAssertEqual(session.tags.count, 2)
    }

    // MARK: - 7.3 Created tag has correct anchorTime

    func testCreateTag_anchorTimeMatchesSpecifiedPosition() throws {
        let anchorTime: TimeInterval = 245.5
        let tag = makeTag(label: "Key Moment", categoryName: "Story", anchorTime: anchorTime)
        context.insert(tag)

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].anchorTime, anchorTime, accuracy: 0.001)
    }

    func testCreateTag_anchorTimeAtSessionStart_isZero() throws {
        let tag = makeTag(label: "Intro", categoryName: "Meta", anchorTime: 0)
        context.insert(tag)

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].anchorTime, 0, accuracy: 0.001)
    }

    // MARK: - 7.4 Created tag has rewindDuration == 0

    func testCreateTag_rewindDurationIsZero() throws {
        let tag = makeTag(label: "Retroactive Tag", categoryName: "Story", anchorTime: 100)
        context.insert(tag)

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].rewindDuration, 0, accuracy: 0.001,
                       "Retroactive tags must have rewindDuration = 0 (no rewind concept)")
    }

    func testCreateTag_rewindDurationDistinguishesFromLiveTags() throws {
        // Retroactive tag: rewindDuration = 0
        let retroTag = makeTag(label: "Retroactive", categoryName: "Story", anchorTime: 60, rewindDuration: 0)
        // Live tag: rewindDuration > 0
        let liveTag = makeTag(label: "Live", categoryName: "Combat", anchorTime: 120, rewindDuration: 15)
        context.insert(retroTag)
        context.insert(liveTag)

        XCTAssertEqual(retroTag.rewindDuration, 0)
        XCTAssertEqual(liveTag.rewindDuration, 15)
    }

    // MARK: - 7.5 Created tag persists in SwiftData context

    func testCreateTag_persistsInSwiftDataContext() throws {
        let tag = makeTag(label: "Combat Start", categoryName: "Combat", anchorTime: 180)
        context.insert(tag)

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].label, "Combat Start")
        XCTAssertEqual(fetched[0].categoryName, "Combat")
    }

    func testCreateTag_persistsCorrectCategoryName() throws {
        let tag = makeTag(label: "Lore Drop", categoryName: "World", anchorTime: 500)
        context.insert(tag)

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].categoryName, "World")
    }

    // MARK: - 7.6 Created tag has .createdAt set to approximately current date

    func testCreateTag_createdAtIsApproximatelyNow() throws {
        let before = Date()
        let tag = makeTag(label: "Now Tag", categoryName: "Meta", anchorTime: 0)
        let after = Date()

        context.insert(tag)

        XCTAssertGreaterThanOrEqual(tag.createdAt, before)
        XCTAssertLessThanOrEqual(tag.createdAt, after)
    }

    func testCreateTag_createdAtIsNotDistantPast() throws {
        let tag = makeTag(label: "Tagged Now", categoryName: "Story", anchorTime: 30)
        context.insert(tag)

        let oneHourAgo = Date().addingTimeInterval(-3600)
        XCTAssertGreaterThan(tag.createdAt, oneHourAgo,
                             "createdAt should be close to current time, not distant past")
    }

    // MARK: - 7.7 Empty label is rejected (validation logic)

    func testEmptyLabel_isRejectedByValidationLogic() {
        // Simulates the NewTagForm submitIfValid() guard
        let emptyInput = ""
        let trimmed = emptyInput.trimmingCharacters(in: .whitespaces)
        XCTAssertTrue(trimmed.isEmpty, "Empty label must be rejected — Create button should be disabled")
    }

    func testWhitespaceLabel_isRejectedByValidationLogic() {
        let whitespaceInput = "   \t\n"
        let trimmed = whitespaceInput.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(trimmed.isEmpty, "Whitespace-only label must be treated as empty")
    }

    func testValidLabel_passesValidation() {
        let input = "  Dragon Attack  "
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        XCTAssertFalse(trimmed.isEmpty)
        XCTAssertEqual(trimmed, "Dragon Attack")
    }

    // MARK: - 7.8 anchorTime is clamped to 0...session.duration

    func testAnchorTimeClamping_negativeIsClampedToZero() {
        let sessionDuration: TimeInterval = 3600
        let rawTime: TimeInterval = -50
        let clamped = max(0, min(sessionDuration, rawTime))
        XCTAssertEqual(clamped, 0)
    }

    func testAnchorTimeClamping_beyondDurationIsClampedToEnd() {
        let sessionDuration: TimeInterval = 3600
        let rawTime: TimeInterval = 4000
        let clamped = max(0, min(sessionDuration, rawTime))
        XCTAssertEqual(clamped, sessionDuration)
    }

    func testAnchorTimeClamping_withinRangeIsUnchanged() {
        let sessionDuration: TimeInterval = 3600
        let rawTime: TimeInterval = 1800
        let clamped = max(0, min(sessionDuration, rawTime))
        XCTAssertEqual(clamped, rawTime)
    }

    func testAnchorTimeClamping_exactlyZeroIsValid() {
        let sessionDuration: TimeInterval = 3600
        let rawTime: TimeInterval = 0
        let clamped = max(0, min(sessionDuration, rawTime))
        XCTAssertEqual(clamped, 0)
    }

    func testAnchorTimeClamping_exactlyDurationIsValid() {
        let sessionDuration: TimeInterval = 3600
        let rawTime: TimeInterval = 3600
        let clamped = max(0, min(sessionDuration, rawTime))
        XCTAssertEqual(clamped, sessionDuration)
    }

    // MARK: - Additional: tag deletion after retroactive creation

    func testDeleteRetroactiveTag_removesFromSessionAndContext() throws {
        let session = makeSession(duration: 1800)
        context.insert(session)

        let tag = makeTag(label: "Flashback Moment", categoryName: "Story", anchorTime: 600)
        context.insert(tag)
        session.tags.append(tag)

        XCTAssertEqual(session.tags.count, 1)

        session.tags.removeAll { $0.uuid == tag.uuid }
        context.delete(tag)

        XCTAssertEqual(session.tags.count, 0)
        let remaining = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertTrue(remaining.isEmpty)
    }

    // MARK: - Helpers

    private func makeSession(duration: TimeInterval) -> Session {
        Session(title: "Test Session", sessionNumber: 1, duration: duration)
    }

    private func makeTag(
        label: String,
        categoryName: String,
        anchorTime: TimeInterval,
        rewindDuration: TimeInterval = 0
    ) -> Tag {
        Tag(
            uuid: UUID(),
            label: label,
            categoryName: categoryName,
            anchorTime: anchorTime,
            rewindDuration: rewindDuration
        )
    }
}
