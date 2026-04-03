import XCTest
import SwiftData
@testable import DictlyMac
import DictlyModels

// MARK: - CrossSessionBrowsingTests
//
// Tests for Story 6.3: Cross-Session Tag Browsing & Related Tags.
// Covers: cross-session tag fetching, category filtering, chronological sort,
// related tag navigation pattern, and empty state logic.
//
// All tests use an in-memory SwiftData store.

@MainActor
final class CrossSessionBrowsingTests: XCTestCase {

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

    // MARK: - 6.2 Cross-session tag fetching

    func testCrossSessionTags_returnsTagsFromMultipleSessions() throws {
        let (campaign, sessions) = try makeCampaignWithSessions(count: 3)
        _ = campaign

        // Add tags to sessions 1 and 2
        let tag1 = makeTag(label: "Grimthor", categoryName: "story", anchorTime: 10)
        let tag2 = makeTag(label: "Dragon", categoryName: "combat", anchorTime: 20)
        let tag3 = makeTag(label: "Merchant", categoryName: "story", anchorTime: 5)

        sessions[0].tags.append(tag1)
        sessions[1].tags.append(tag2)
        sessions[2].tags.append(tag3)

        try context.save()

        // Verify tags exist in their respective sessions
        XCTAssertEqual(sessions[0].tags.count, 1)
        XCTAssertEqual(sessions[1].tags.count, 1)
        XCTAssertEqual(sessions[2].tags.count, 1)
        XCTAssertEqual(sessions[0].tags[0].label, "Grimthor")
        XCTAssertEqual(sessions[1].tags[0].label, "Dragon")
        XCTAssertEqual(sessions[2].tags[0].label, "Merchant")
    }

    func testCrossSessionTags_campaignContainsAllSessions() throws {
        let (campaign, sessions) = try makeCampaignWithSessions(count: 3)
        XCTAssertEqual(campaign.sessions.count, 3)
        XCTAssertEqual(Set(campaign.sessions.map { $0.uuid }), Set(sessions.map { $0.uuid }))
    }

    // MARK: - 6.3 Category filtering on cross-session results

    func testCrossSessionFilter_categoryFilter_returnsMatchingTagsOnly() throws {
        let (_, sessions) = try makeCampaignWithSessions(count: 2)

        let storyTag = makeTag(label: "Prophecy", categoryName: "story", anchorTime: 10)
        let combatTag = makeTag(label: "Battle", categoryName: "combat", anchorTime: 20)
        let storyTag2 = makeTag(label: "Lore", categoryName: "story", anchorTime: 30)

        sessions[0].tags.append(storyTag)
        sessions[0].tags.append(combatTag)
        sessions[1].tags.append(storyTag2)

        try context.save()

        // Apply category filter "story"
        let allTags = sessions.flatMap { $0.tags }
        let filtered = allTags.filter { $0.categoryName == "story" }

        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.categoryName == "story" })
        XCTAssertFalse(filtered.contains { $0.label == "Battle" })
    }

    func testCrossSessionFilter_multipleCategories_returnsAllMatching() throws {
        let (_, sessions) = try makeCampaignWithSessions(count: 2)

        sessions[0].tags.append(makeTag(label: "Ambush", categoryName: "combat", anchorTime: 5))
        sessions[0].tags.append(makeTag(label: "Tavern", categoryName: "roleplay", anchorTime: 10))
        sessions[1].tags.append(makeTag(label: "Dragon", categoryName: "combat", anchorTime: 15))
        sessions[1].tags.append(makeTag(label: "Riddle", categoryName: "meta", anchorTime: 20))

        try context.save()

        let activeCategories: Set<String> = ["combat", "roleplay"]
        let allTags = sessions.flatMap { $0.tags }
        let filtered = allTags.filter { activeCategories.contains($0.categoryName) }

        XCTAssertEqual(filtered.count, 3)
        XCTAssertFalse(filtered.contains { $0.categoryName == "meta" })
    }

    func testCrossSessionFilter_emptyCategories_returnsAll() throws {
        let (_, sessions) = try makeCampaignWithSessions(count: 2)

        sessions[0].tags.append(makeTag(label: "Alpha", categoryName: "story", anchorTime: 1))
        sessions[1].tags.append(makeTag(label: "Beta", categoryName: "combat", anchorTime: 2))

        try context.save()

        let activeCategories: Set<String> = []
        let allTags = sessions.flatMap { $0.tags }
        let filtered = activeCategories.isEmpty ? allTags : allTags.filter { activeCategories.contains($0.categoryName) }

        XCTAssertEqual(filtered.count, 2)
    }

    // MARK: - 6.4 Chronological sort order

    func testCrossSessionSort_chronologicalBySessionDate() throws {
        let oldDate = Date(timeIntervalSince1970: 1000)
        let midDate = Date(timeIntervalSince1970: 2000)
        let newDate = Date(timeIntervalSince1970: 3000)

        let campaign = Campaign(name: "Test Campaign")
        context.insert(campaign)

        let s1 = Session(title: "Session 3", sessionNumber: 3, date: newDate)
        let s2 = Session(title: "Session 1", sessionNumber: 1, date: oldDate)
        let s3 = Session(title: "Session 2", sessionNumber: 2, date: midDate)

        context.insert(s1); context.insert(s2); context.insert(s3)
        campaign.sessions.append(contentsOf: [s1, s2, s3])

        let tag1 = makeTag(label: "C", categoryName: "story", anchorTime: 1)
        let tag2 = makeTag(label: "A", categoryName: "story", anchorTime: 1)
        let tag3 = makeTag(label: "B", categoryName: "story", anchorTime: 1)

        s1.tags.append(tag1)
        s2.tags.append(tag2)
        s3.tags.append(tag3)

        try context.save()

        // Sort sessions by date ascending (oldest first)
        let sortedSessions = campaign.sessions.sorted { $0.date < $1.date }

        XCTAssertEqual(sortedSessions[0].title, "Session 1") // oldDate
        XCTAssertEqual(sortedSessions[1].title, "Session 2") // midDate
        XCTAssertEqual(sortedSessions[2].title, "Session 3") // newDate
    }

    func testCrossSessionSort_tagsWithinSessionByAnchorTime() throws {
        let (_, sessions) = try makeCampaignWithSessions(count: 1)

        let tagLate = makeTag(label: "Late", categoryName: "story", anchorTime: 300)
        let tagEarly = makeTag(label: "Early", categoryName: "story", anchorTime: 10)
        let tagMid = makeTag(label: "Mid", categoryName: "story", anchorTime: 150)

        sessions[0].tags.append(tagLate)
        sessions[0].tags.append(tagEarly)
        sessions[0].tags.append(tagMid)

        try context.save()

        let sorted = sessions[0].tags.sorted { $0.anchorTime < $1.anchorTime }

        XCTAssertEqual(sorted[0].label, "Early")
        XCTAssertEqual(sorted[1].label, "Mid")
        XCTAssertEqual(sorted[2].label, "Late")
    }

    // MARK: - Related tag navigation (6.6)

    func testRelatedTagNavigation_usesSearchResultTagID() throws {
        // Verify the SearchResult struct contains all fields needed for pendingTagID navigation
        let tagID = UUID()
        let sessionID = UUID()
        let result = SearchResult(
            id: tagID,
            tagID: tagID,
            tagLabel: "Grimthor",
            sessionTitle: "Session One",
            sessionNumber: 1,
            anchorTime: 42.0,
            transcriptionSnippet: nil,
            categoryName: "story",
            sessionID: sessionID,
            sessionDate: Date()
        )

        XCTAssertEqual(result.tagID, tagID)
        XCTAssertEqual(result.sessionID, sessionID)
        XCTAssertEqual(result.tagLabel, "Grimthor")
    }

    func testRelatedTagNavigation_sameSessionTag_isExcluded() throws {
        // Verify that a tag from the same session would be excluded from related tags
        // (mirrors SearchService.performRelatedSearch filter logic)
        let sharedSessionID = UUID()

        let selectedTagResult = SearchResult(
            id: UUID(), tagID: UUID(), tagLabel: "Grimthor",
            sessionTitle: "Session One", sessionNumber: 1, anchorTime: 10,
            transcriptionSnippet: nil, categoryName: "story",
            sessionID: sharedSessionID, sessionDate: Date()
        )

        let sameSessionResult = SearchResult(
            id: UUID(), tagID: UUID(), tagLabel: "Grimthor's Axe",
            sessionTitle: "Session One", sessionNumber: 1, anchorTime: 20,
            transcriptionSnippet: nil, categoryName: "combat",
            sessionID: sharedSessionID, sessionDate: Date()
        )

        let otherSessionResult = SearchResult(
            id: UUID(), tagID: UUID(), tagLabel: "Grimthor Returns",
            sessionTitle: "Session Two", sessionNumber: 2, anchorTime: 5,
            transcriptionSnippet: nil, categoryName: "story",
            sessionID: UUID(), sessionDate: Date()
        )

        let candidates = [sameSessionResult, otherSessionResult]
        let filtered = candidates.filter { $0.sessionID != selectedTagResult.sessionID }

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.tagLabel, "Grimthor Returns")
    }

    // MARK: - 6.7 Empty states

    func testEmptyState_noTagsInCampaign() throws {
        let (campaign, sessions) = try makeCampaignWithSessions(count: 2)
        _ = sessions

        let totalTags = campaign.sessions.reduce(0) { $0 + $1.tags.count }
        XCTAssertEqual(totalTags, 0, "Campaign should have no tags initially")
    }

    func testEmptyState_categoryFilterYieldsNoResults() throws {
        let (_, sessions) = try makeCampaignWithSessions(count: 1)
        sessions[0].tags.append(makeTag(label: "Alpha", categoryName: "story", anchorTime: 1))
        try context.save()

        let activeCategories: Set<String> = ["combat"]
        let allTags = sessions.flatMap { $0.tags }
        let filtered = allTags.filter { activeCategories.contains($0.categoryName) }

        XCTAssertTrue(filtered.isEmpty, "No combat tags exist — filter should yield empty")
    }

    // MARK: - Helpers

    @discardableResult
    private func makeCampaignWithSessions(count: Int) throws -> (Campaign, [Session]) {
        let campaign = Campaign(name: "Test Campaign")
        context.insert(campaign)

        var sessions: [Session] = []
        for i in 1...count {
            let session = Session(
                title: "Session \(i)",
                sessionNumber: i,
                date: Date(timeIntervalSince1970: Double(i) * 86400)
            )
            context.insert(session)
            campaign.sessions.append(session)
            sessions.append(session)
        }

        try context.save()
        return (campaign, sessions)
    }

    private func makeTag(label: String, categoryName: String, anchorTime: TimeInterval) -> Tag {
        Tag(label: label, categoryName: categoryName, anchorTime: anchorTime, rewindDuration: 0)
    }
}
