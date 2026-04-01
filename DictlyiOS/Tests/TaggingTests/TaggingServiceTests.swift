import XCTest
import SwiftData
@testable import DictlyiOS
import DictlyModels

// MARK: - TaggingServiceTests

/// Tests for `TaggingService` tag placement logic (Story 2.4 Task 7, Story 2.5 Task 4).
/// Uses an in-memory SwiftData container to verify tag creation, relationship wiring,
/// rewind-anchor calculations, and count increments without requiring actual audio recording.
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
        service.placeTag(label: "Combat Start", categoryName: "Combat", rewindDuration: 0, session: session, context: context)

        let tags = session.tags
        XCTAssertEqual(tags.count, 1)
        let tag = try XCTUnwrap(tags.first)
        XCTAssertEqual(tag.label, "Combat Start")
    }

    func testPlaceTag_createsTagWithCorrectCategoryName() throws {
        service.placeTag(label: "Dragon Appears", categoryName: "Story", rewindDuration: 0, session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.categoryName, "Story")
    }

    func testPlaceTag_createsTagWithAnchorTimeMatchingRecorderElapsedTime() throws {
        // recorder.elapsedTime is 0 when not recording — with rewindDuration: 0, anchorTime == elapsedTime
        service.placeTag(label: "Test Tag", categoryName: "Meta", rewindDuration: 0, session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.anchorTime, recorder.elapsedTime)
    }

    func testPlaceTag_createsTagWithZeroRewindDuration() throws {
        service.placeTag(label: "Test Tag", categoryName: "World", rewindDuration: 0, session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.rewindDuration, 0)
    }

    func testPlaceTag_tagIsAppendedToSession() throws {
        service.placeTag(label: "Roleplay Moment", categoryName: "Roleplay", rewindDuration: 0, session: session, context: context)

        XCTAssertTrue(session.tags.contains(where: { $0.label == "Roleplay Moment" }))
    }

    // MARK: - 7.3 tag count increments after placeTag

    func testPlaceTag_incrementsSessionTagCount() {
        let initialCount = session.tags.count
        service.placeTag(label: "Tag One", categoryName: "Story", rewindDuration: 0, session: session, context: context)
        XCTAssertEqual(session.tags.count, initialCount + 1)
    }

    func testPlaceTag_eachCallIncrementsCountByOne() {
        XCTAssertEqual(session.tags.count, 0)
        service.placeTag(label: "Tag A", categoryName: "Combat", rewindDuration: 0, session: session, context: context)
        XCTAssertEqual(session.tags.count, 1)
        service.placeTag(label: "Tag B", categoryName: "Story", rewindDuration: 0, session: session, context: context)
        XCTAssertEqual(session.tags.count, 2)
        service.placeTag(label: "Tag C", categoryName: "Meta", rewindDuration: 0, session: session, context: context)
        XCTAssertEqual(session.tags.count, 3)
    }

    // MARK: - 7.4 rapid sequential placements

    func testPlaceTag_rapidSequentialPlacementsAllCreated() {
        for i in 0..<10 {
            service.placeTag(label: "Tag \(i)", categoryName: "Combat", rewindDuration: 0, session: session, context: context)
        }
        XCTAssertEqual(session.tags.count, 10)
    }

    func testPlaceTag_rapidSequentialPlacementsDistinctLabels() {
        for i in 0..<5 {
            service.placeTag(label: "Tag \(i)", categoryName: "Story", rewindDuration: 0, session: session, context: context)
        }
        let labels = Set(session.tags.map(\.label))
        XCTAssertEqual(labels.count, 5)
    }

    func testPlaceTag_rapidSequentialPlacementsAllHaveCorrectAnchorTime() {
        for i in 0..<3 {
            service.placeTag(label: "Tag \(i)", categoryName: "World", rewindDuration: 0, session: session, context: context)
        }
        // All tags should have anchorTime == recorder.elapsedTime (0 when not recording)
        for tag in session.tags {
            XCTAssertEqual(tag.anchorTime, 0)
        }
    }

    // MARK: - Additional: tag is persisted in SwiftData

    func testPlaceTag_tagIsPersistableInContext() throws {
        service.placeTag(label: "Persisted Tag", categoryName: "Meta", rewindDuration: 0, session: session, context: context)

        let descriptor = FetchDescriptor<Tag>()
        let fetched = try context.fetch(descriptor)
        XCTAssertTrue(fetched.contains(where: { $0.label == "Persisted Tag" }))
    }

    // MARK: - Story 2.5: Rewind-anchor tests

    func testPlaceTag_withRewindDuration_calculatesCorrectAnchorTime() throws {
        // Set elapsed time to simulate mid-recording state
        recorder.elapsedTime = 150.0 // 2:30 into recording
        service.placeTag(label: "Mid Recording Tag", categoryName: "Meta", rewindDuration: 10, session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.anchorTime, 140.0, accuracy: 0.001) // 150 - 10 = 140
        XCTAssertEqual(tag.rewindDuration, 10.0, accuracy: 0.001)
    }

    func testPlaceTag_withRewindDuration_storesActualRewind() throws {
        recorder.elapsedTime = 60.0
        service.placeTag(label: "Test Tag", categoryName: "Story", rewindDuration: 10, session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        // actualRewind = elapsedTime - anchorTime = 60 - 50 = 10
        XCTAssertEqual(tag.rewindDuration, 10.0, accuracy: 0.001)
        XCTAssertEqual(tag.anchorTime, 50.0, accuracy: 0.001)
    }

    func testPlaceTag_earlyRecording_clampsAnchorTimeToZero() throws {
        // elapsedTime is 3, rewindDuration is 10 → anchorTime must clamp to 0 (not negative)
        recorder.elapsedTime = 3.0
        service.placeTag(label: "Early Tag", categoryName: "Combat", rewindDuration: 10, session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.anchorTime, 0.0, accuracy: 0.001, "anchorTime must clamp to 0")
        XCTAssertEqual(tag.rewindDuration, 3.0, accuracy: 0.001, "actualRewind should be 3s, not 10s")
    }

    func testPlaceTag_rewindDuration15s_calculatesCorrectly() throws {
        recorder.elapsedTime = 60.0 // 1 minute into recording
        service.placeTag(label: "15s Rewind Tag", categoryName: "Story", rewindDuration: 15, session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.anchorTime, 45.0, accuracy: 0.001) // 60 - 15 = 45
        XCTAssertEqual(tag.rewindDuration, 15.0, accuracy: 0.001)
    }

    func testPlaceTag_rewindDuration5s_calculatesCorrectly() throws {
        recorder.elapsedTime = 30.0
        service.placeTag(label: "5s Rewind Tag", categoryName: "Story", rewindDuration: 5, session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.anchorTime, 25.0, accuracy: 0.001) // 30 - 5 = 25
        XCTAssertEqual(tag.rewindDuration, 5.0, accuracy: 0.001)
    }

    func testPlaceTag_rewindDuration20s_calculatesCorrectly() throws {
        recorder.elapsedTime = 9000.0 // 2:30:00 into recording
        service.placeTag(label: "20s Rewind Tag", categoryName: "Story", rewindDuration: 20, session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.anchorTime, 8980.0, accuracy: 0.001) // 9000 - 20 = 8980
        XCTAssertEqual(tag.rewindDuration, 20.0, accuracy: 0.001)
    }

    func testPlaceTag_zeroRewindDuration_anchorEqualsElapsedTime() throws {
        recorder.elapsedTime = 42.0
        service.placeTag(label: "No Rewind Tag", categoryName: "Meta", rewindDuration: 0, session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.anchorTime, 42.0, accuracy: 0.001)
        XCTAssertEqual(tag.rewindDuration, 0.0, accuracy: 0.001)
    }

    func testPlaceTag_negativeRewindDuration_clampedToZero() throws {
        recorder.elapsedTime = 30.0
        service.placeTag(label: "Negative Rewind Tag", categoryName: "Meta", rewindDuration: -5, session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        // Negative rewind should be clamped to 0, so anchorTime == elapsedTime
        XCTAssertEqual(tag.anchorTime, 30.0, accuracy: 0.001)
        XCTAssertEqual(tag.rewindDuration, 0.0, accuracy: 0.001)
    }
}
