import XCTest
@testable import DictlyMac
import SwiftData
import DictlyModels

// MARK: - SidebarCampaignGroupingTests
//
// Tests for Story 7.4: Mac Session Sidebar — Campaign Grouping.
// Validates grouping logic: sessions grouped by campaign (newest-first within group),
// uncampaigned sessions appear last, empty state, single-campaign consistency.
//
// Note: Tests the model-layer data that drives groupedSessions in ContentView.
// Since groupedSessions is a private computed property on the view, these tests
// validate correctness of the underlying data relationships and sorting logic.

@MainActor
final class SidebarCampaignGroupingTests: XCTestCase {

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

    // MARK: - AC #1: Sessions grouped by campaign, newest-first within group

    func testGroupedSessions_multipleCampaigns_groupedByName() throws {
        let campaign1 = Campaign(name: "Ashlands", createdAt: Date(timeIntervalSinceNow: -3600))
        let campaign2 = Campaign(name: "Curse of Strahd", createdAt: Date(timeIntervalSinceNow: -1800))
        context.insert(campaign1)
        context.insert(campaign2)

        let s1 = makeSession(title: "Ashlands 1", daysAgo: 10)
        let s2 = makeSession(title: "Ashlands 2", daysAgo: 2)
        campaign1.sessions.append(contentsOf: [s1, s2])

        let s3 = makeSession(title: "Strahd 1", daysAgo: 5)
        campaign2.sessions.append(s3)

        try context.save()

        let campaigns = try context.fetch(FetchDescriptor<Campaign>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
        let groups = groupedSessions(campaigns: campaigns, allSessions: fetchSessions())

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].title, "Ashlands")
        XCTAssertEqual(groups[1].title, "Curse of Strahd")

        // Sessions within Ashlands group sorted newest-first
        XCTAssertEqual(groups[0].sessions.count, 2)
        XCTAssertEqual(groups[0].sessions[0].title, "Ashlands 2", "Newest session should appear first")
        XCTAssertEqual(groups[0].sessions[1].title, "Ashlands 1")
    }

    // MARK: - AC #2: Sessions with no campaign appear under "Uncampaigned"

    func testGroupedSessions_uncampaignedSessions_appearsLast() throws {
        let campaign = Campaign(name: "Ashlands")
        context.insert(campaign)

        let s1 = makeSession(title: "Ashlands 1", daysAgo: 5)
        campaign.sessions.append(s1)

        let s2 = makeSession(title: "Orphan Session", daysAgo: 1)
        context.insert(s2)

        try context.save()

        let campaigns = try context.fetch(FetchDescriptor<Campaign>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
        let groups = groupedSessions(campaigns: campaigns, allSessions: fetchSessions())

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].title, "Ashlands")
        XCTAssertEqual(groups[1].title, "Uncampaigned")
        XCTAssertEqual(groups[1].sessions.count, 1)
        XCTAssertEqual(groups[1].sessions[0].title, "Orphan Session")
    }

    func testGroupedSessions_noUncampaignedSessions_noUncampaignedGroup() throws {
        let campaign = Campaign(name: "One-Shots")
        context.insert(campaign)
        let s1 = makeSession(title: "Session 1", daysAgo: 2)
        campaign.sessions.append(s1)
        try context.save()

        let campaigns = try context.fetch(FetchDescriptor<Campaign>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
        let groups = groupedSessions(campaigns: campaigns, allSessions: fetchSessions())

        XCTAssertFalse(groups.contains { $0.title == "Uncampaigned" })
    }

    // MARK: - AC #3: Single campaign still shows section header

    func testGroupedSessions_singleCampaign_showsOneGroup() throws {
        let campaign = Campaign(name: "Only Campaign")
        context.insert(campaign)
        let s1 = makeSession(title: "Session A", daysAgo: 3)
        campaign.sessions.append(s1)
        try context.save()

        let campaigns = try context.fetch(FetchDescriptor<Campaign>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
        let groups = groupedSessions(campaigns: campaigns, allSessions: fetchSessions())

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].title, "Only Campaign")
    }

    // MARK: - AC #5: Empty state when no sessions exist

    func testGroupedSessions_noSessions_isEmpty() throws {
        let campaigns = try context.fetch(FetchDescriptor<Campaign>())
        let groups = groupedSessions(campaigns: campaigns, allSessions: fetchSessions())

        XCTAssertTrue(groups.isEmpty)
    }

    func testGroupedSessions_campaignsWithNoSessions_notIncluded() throws {
        let campaign = Campaign(name: "Empty Campaign")
        context.insert(campaign)
        try context.save()

        let campaigns = try context.fetch(FetchDescriptor<Campaign>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
        let groups = groupedSessions(campaigns: campaigns, allSessions: fetchSessions())

        XCTAssertTrue(groups.isEmpty, "Campaigns with no sessions should not appear as groups")
    }

    // MARK: - Uncampaigned sorting: newest-first

    func testGroupedSessions_uncampaignedSessions_sortedNewestFirst() throws {
        let s1 = makeSession(title: "Old Orphan", daysAgo: 10)
        let s2 = makeSession(title: "New Orphan", daysAgo: 1)
        context.insert(s1)
        context.insert(s2)
        try context.save()

        let campaigns = try context.fetch(FetchDescriptor<Campaign>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
        let groups = groupedSessions(campaigns: campaigns, allSessions: fetchSessions())

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].title, "Uncampaigned")
        XCTAssertEqual(groups[0].sessions[0].title, "New Orphan", "Newest uncampaigned session first")
        XCTAssertEqual(groups[0].sessions[1].title, "Old Orphan")
    }

    // MARK: - Session.campaign relationship integrity

    func testSession_withNoCampaign_campaignIsNil() throws {
        let session = makeSession(title: "No Campaign Session", daysAgo: 0)
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertNil(fetched[0].campaign)
    }

    func testSession_assignedToCampaign_campaignIsNotNil() throws {
        let campaign = Campaign(name: "Test Campaign")
        context.insert(campaign)
        let session = makeSession(title: "Campaign Session", daysAgo: 0)
        campaign.sessions.append(session)
        try context.save()

        let fetchedSessions = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetchedSessions.count, 1)
        XCTAssertNotNil(fetchedSessions[0].campaign)
        XCTAssertEqual(fetchedSessions[0].campaign?.name, "Test Campaign")
    }

    // MARK: - Helpers

    /// Mirrors the groupedSessions computed property in ContentView for testability.
    private static let uncampaignedGroupID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private func groupedSessions(
        campaigns: [Campaign],
        allSessions: [Session]
    ) -> [(id: UUID, title: String, sessions: [Session])] {
        var groups: [(id: UUID, title: String, sessions: [Session])] = campaigns
            .filter { !$0.sessions.isEmpty }
            .map { ($0.uuid, $0.name, $0.sessions.sorted { $0.date > $1.date }) }
        let uncampaigned = allSessions.filter { $0.campaign == nil }
        if !uncampaigned.isEmpty {
            groups.append((Self.uncampaignedGroupID, "Uncampaigned", uncampaigned.sorted { $0.date > $1.date }))
        }
        return groups
    }

    private func fetchSessions() -> [Session] {
        (try? context.fetch(FetchDescriptor<Session>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
    }

    private func makeSession(title: String, daysAgo: Int) -> Session {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return Session(
            uuid: UUID(),
            title: title,
            sessionNumber: 1,
            date: date,
            duration: 3600
        )
    }
}
