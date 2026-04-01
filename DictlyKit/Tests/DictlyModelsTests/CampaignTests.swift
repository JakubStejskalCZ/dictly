import XCTest
import SwiftData
@testable import DictlyModels

@MainActor
final class CampaignTests: XCTestCase {
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

    func testCampaignCreation() throws {
        let campaign = Campaign(name: "Test Campaign", descriptionText: "A test")
        context.insert(campaign)
        try context.save()

        let results = try context.fetch(FetchDescriptor<Campaign>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Test Campaign")
        XCTAssertEqual(results[0].descriptionText, "A test")
    }

    func testCampaignUUIDUniqueness() throws {
        let c1 = Campaign(name: "Campaign 1")
        let c2 = Campaign(name: "Campaign 2")
        context.insert(c1)
        context.insert(c2)
        try context.save()

        XCTAssertNotEqual(c1.uuid, c2.uuid)
    }

    func testCascadeDeleteRemovesSessions() throws {
        let campaign = Campaign(name: "Campaign")
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)
        try context.save()

        context.delete(campaign)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(sessions.count, 0, "Sessions should be cascade deleted with Campaign")
    }

    func testCascadeDeleteRemovesSessionsAndTags() throws {
        let campaign = Campaign(name: "Campaign")
        let session = Session(title: "Session 1", sessionNumber: 1)
        let tag = Tag(label: "Tag 1", categoryName: "Default", anchorTime: 10, rewindDuration: 5)
        context.insert(campaign)
        context.insert(session)
        context.insert(tag)
        campaign.sessions.append(session)
        session.tags.append(tag)
        try context.save()

        context.delete(campaign)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<Session>())
        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(sessions.count, 0, "Sessions should be cascade deleted with Campaign")
        XCTAssertEqual(tags.count, 0, "Tags should be cascade deleted transitively")
    }
}
