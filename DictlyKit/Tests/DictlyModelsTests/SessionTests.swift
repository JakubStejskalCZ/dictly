import XCTest
import SwiftData
@testable import DictlyModels

@MainActor
final class SessionTests: XCTestCase {
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

    func testSessionCreation() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)
        try context.save()

        let results = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "Session 1")
        XCTAssertEqual(results[0].sessionNumber, 1)
    }

    func testSessionCampaignRelationship() throws {
        let campaign = Campaign(name: "My Campaign")
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(sessions[0].campaign?.name, "My Campaign")
    }

    func testCascadeDeleteRemovesTags() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        let tag = Tag(label: "Tag 1", categoryName: "Combat", anchorTime: 30, rewindDuration: 10)
        context.insert(session)
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        context.delete(session)
        try context.save()

        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags.count, 0, "Tags should be cascade deleted with Session")
    }
}
