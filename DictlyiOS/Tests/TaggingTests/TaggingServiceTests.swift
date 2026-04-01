import XCTest
import SwiftData
@testable import DictlyiOS
import DictlyModels

// MARK: - TaggingServiceTests

/// Tests for `TaggingService` tag placement logic (Story 2.4 Task 7).
/// Uses an in-memory SwiftData container to verify tag creation, relationship wiring,
/// and count increments without requiring actual audio recording.
@MainActor
final class TaggingServiceTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var recorder: SessionRecorder!
    var service: TaggingService!
    var session: Session!

    override func setUp() async throws {
        container = try ModelContainer(
            for: Campaign.self, Session.self, Tag.self, TagCategory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
        recorder = SessionRecorder()
        service = TaggingService(sessionRecorder: recorder)
        session = Session(title: "Test Session", sessionNumber: 1)
        context.insert(session)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        recorder = nil
        service = nil
        session = nil
    }

    // MARK: - 7.2 placeTag creates tag with correct properties

    func testPlaceTag_createsTagWithCorrectLabel() throws {
        service.placeTag(label: "Combat Start", categoryName: "Combat", session: session, context: context)

        let tags = session.tags
        XCTAssertEqual(tags.count, 1)
        let tag = try XCTUnwrap(tags.first)
        XCTAssertEqual(tag.label, "Combat Start")
    }

    func testPlaceTag_createsTagWithCorrectCategoryName() throws {
        service.placeTag(label: "Dragon Appears", categoryName: "Story", session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.categoryName, "Story")
    }

    func testPlaceTag_createsTagWithAnchorTimeMatchingRecorderElapsedTime() throws {
        // recorder.elapsedTime is 0 when not recording — verifies we capture elapsedTime at placement
        service.placeTag(label: "Test Tag", categoryName: "Meta", session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.anchorTime, recorder.elapsedTime)
    }

    func testPlaceTag_createsTagWithZeroRewindDuration() throws {
        service.placeTag(label: "Test Tag", categoryName: "World", session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.rewindDuration, 0)
    }

    func testPlaceTag_tagIsAppendedToSession() throws {
        service.placeTag(label: "Roleplay Moment", categoryName: "Roleplay", session: session, context: context)

        XCTAssertTrue(session.tags.contains(where: { $0.label == "Roleplay Moment" }))
    }

    // MARK: - 7.3 tag count increments after placeTag

    func testPlaceTag_incrementsSessionTagCount() {
        let initialCount = session.tags.count
        service.placeTag(label: "Tag One", categoryName: "Story", session: session, context: context)
        XCTAssertEqual(session.tags.count, initialCount + 1)
    }

    func testPlaceTag_eachCallIncrementsCountByOne() {
        XCTAssertEqual(session.tags.count, 0)
        service.placeTag(label: "Tag A", categoryName: "Combat", session: session, context: context)
        XCTAssertEqual(session.tags.count, 1)
        service.placeTag(label: "Tag B", categoryName: "Story", session: session, context: context)
        XCTAssertEqual(session.tags.count, 2)
        service.placeTag(label: "Tag C", categoryName: "Meta", session: session, context: context)
        XCTAssertEqual(session.tags.count, 3)
    }

    // MARK: - 7.4 rapid sequential placements

    func testPlaceTag_rapidSequentialPlacementsAllCreated() {
        for i in 0..<10 {
            service.placeTag(label: "Tag \(i)", categoryName: "Combat", session: session, context: context)
        }
        XCTAssertEqual(session.tags.count, 10)
    }

    func testPlaceTag_rapidSequentialPlacementsDistinctLabels() {
        for i in 0..<5 {
            service.placeTag(label: "Tag \(i)", categoryName: "Story", session: session, context: context)
        }
        let labels = Set(session.tags.map(\.label))
        XCTAssertEqual(labels.count, 5)
    }

    func testPlaceTag_rapidSequentialPlacementsAllHaveCorrectAnchorTime() {
        for i in 0..<3 {
            service.placeTag(label: "Tag \(i)", categoryName: "World", session: session, context: context)
        }
        // All tags should have anchorTime == recorder.elapsedTime (0 when not recording)
        for tag in session.tags {
            XCTAssertEqual(tag.anchorTime, 0)
        }
    }

    // MARK: - Additional: tag is persisted in SwiftData

    func testPlaceTag_tagIsPersistableInContext() throws {
        service.placeTag(label: "Persisted Tag", categoryName: "Meta", session: session, context: context)

        let descriptor = FetchDescriptor<Tag>()
        let fetched = try context.fetch(descriptor)
        XCTAssertTrue(fetched.contains(where: { $0.label == "Persisted Tag" }))
    }
}
