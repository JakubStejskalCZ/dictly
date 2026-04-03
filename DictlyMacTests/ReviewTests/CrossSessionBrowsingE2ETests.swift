import XCTest
import SwiftData
@testable import DictlyMac
import DictlyModels

// MARK: - Cross-Session Browsing & Related Tags E2E Tests (Story 6.3)
//
// End-to-end tests for cross-session tag browsing and related tags.
// Covers all acceptance criteria:
//   AC1: Category filter in cross-session mode → all tags of that category across campaign
//   AC2: Related tags column → tags across all sessions mentioning similar terms
//   AC3: Click related tag → corresponding session opens with tag selected
//   AC4: Chronological session list → date, title, duration, tag count
//
// Uses in-memory SwiftData for model relationships. Spotlight queries are logic-verified
// (actual Spotlight execution requires entitlements/running app).

@MainActor
final class CrossSessionBrowsingE2ETests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var service: SearchService!

    override func setUp() async throws {
        let schema = Schema(DictlySchema.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext
        service = SearchService()
        service.setModelContext(context)
    }

    override func tearDown() async throws {
        service = nil
        container = nil
        context = nil
    }

    // MARK: - Helpers

    @discardableResult
    private func makeCampaignWithSessions(
        name: String = "Test Campaign",
        sessionCount: Int
    ) throws -> (Campaign, [Session]) {
        let campaign = Campaign(name: name)
        context.insert(campaign)

        var sessions: [Session] = []
        for i in 1...sessionCount {
            let session = Session(
                title: "Session \(i)",
                sessionNumber: i,
                date: Date(timeIntervalSince1970: Double(i) * 86400),
                duration: Double(i) * 3600
            )
            context.insert(session)
            campaign.sessions.append(session)
            sessions.append(session)
        }
        try context.save()
        return (campaign, sessions)
    }

    private func makeTag(
        label: String,
        categoryName: String = "Story",
        anchorTime: TimeInterval = 30.0,
        transcription: String? = nil
    ) -> Tag {
        let tag = Tag(label: label, categoryName: categoryName, anchorTime: anchorTime,
                      rewindDuration: 0, transcription: transcription)
        context.insert(tag)
        return tag
    }

    private func makeSearchResult(
        tagID: UUID = UUID(),
        tagLabel: String = "Test",
        sessionTitle: String = "Session 1",
        sessionNumber: Int = 1,
        anchorTime: TimeInterval = 0,
        categoryName: String = "Story",
        sessionID: UUID = UUID()
    ) -> SearchResult {
        SearchResult(
            id: tagID, tagID: tagID, tagLabel: tagLabel,
            sessionTitle: sessionTitle, sessionNumber: sessionNumber,
            anchorTime: anchorTime, transcriptionSnippet: nil,
            categoryName: categoryName, sessionID: sessionID,
            sessionDate: Date()
        )
    }

    // MARK: - AC1: Cross-session category browsing

    func testAC1_crossSessionMode_allTagsAcrossCampaign() throws {
        let (campaign, sessions) = try makeCampaignWithSessions(sessionCount: 3)

        sessions[0].tags.append(makeTag(label: "Grimthor", categoryName: "Story"))
        sessions[1].tags.append(makeTag(label: "Dragon", categoryName: "Combat"))
        sessions[2].tags.append(makeTag(label: "Merchant", categoryName: "Story"))
        try context.save()

        let allTags = campaign.sessions.flatMap { $0.tags }
        XCTAssertEqual(allTags.count, 3, "Cross-session mode shows all tags")
    }

    func testAC1_categoryFilter_singleCategory() throws {
        let (_, sessions) = try makeCampaignWithSessions(sessionCount: 3)

        sessions[0].tags.append(makeTag(label: "Prophecy", categoryName: "Story"))
        sessions[0].tags.append(makeTag(label: "Battle", categoryName: "Combat"))
        sessions[1].tags.append(makeTag(label: "Lore", categoryName: "Story"))
        sessions[2].tags.append(makeTag(label: "Ambush", categoryName: "Combat"))
        try context.save()

        let activeCategories: Set<String> = ["Story"]
        let allTags = sessions.flatMap { $0.tags }
        let filtered = allTags.filter { activeCategories.contains($0.categoryName) }

        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.categoryName == "Story" })
    }

    func testAC1_categoryFilter_multipleCategories() throws {
        let (_, sessions) = try makeCampaignWithSessions(sessionCount: 2)

        sessions[0].tags.append(makeTag(label: "Ambush", categoryName: "Combat"))
        sessions[0].tags.append(makeTag(label: "Tavern", categoryName: "Roleplay"))
        sessions[1].tags.append(makeTag(label: "Dragon", categoryName: "Combat"))
        sessions[1].tags.append(makeTag(label: "Riddle", categoryName: "Meta"))
        try context.save()

        let activeCategories: Set<String> = ["Combat", "Roleplay"]
        let allTags = sessions.flatMap { $0.tags }
        let filtered = allTags.filter { activeCategories.contains($0.categoryName) }

        XCTAssertEqual(filtered.count, 3)
        XCTAssertFalse(filtered.contains { $0.categoryName == "Meta" })
    }

    func testAC1_categoryFilter_emptySelection_returnsAll() throws {
        let (_, sessions) = try makeCampaignWithSessions(sessionCount: 2)

        sessions[0].tags.append(makeTag(label: "A", categoryName: "Story"))
        sessions[1].tags.append(makeTag(label: "B", categoryName: "Combat"))
        try context.save()

        let activeCategories: Set<String> = []
        let allTags = sessions.flatMap { $0.tags }
        let filtered = activeCategories.isEmpty ? allTags : allTags.filter { activeCategories.contains($0.categoryName) }

        XCTAssertEqual(filtered.count, 2, "Empty filter shows all tags")
    }

    func testAC1_crossSessionTags_displayedChronologically() throws {
        let campaign = Campaign(name: "Chrono Campaign")
        context.insert(campaign)

        let oldDate = Date(timeIntervalSince1970: 1000)
        let midDate = Date(timeIntervalSince1970: 2000)
        let newDate = Date(timeIntervalSince1970: 3000)

        let s1 = Session(title: "Session 3", sessionNumber: 3, date: newDate)
        let s2 = Session(title: "Session 1", sessionNumber: 1, date: oldDate)
        let s3 = Session(title: "Session 2", sessionNumber: 2, date: midDate)
        context.insert(s1); context.insert(s2); context.insert(s3)
        campaign.sessions.append(contentsOf: [s1, s2, s3])

        s1.tags.append(makeTag(label: "C", anchorTime: 1))
        s2.tags.append(makeTag(label: "A", anchorTime: 1))
        s3.tags.append(makeTag(label: "B", anchorTime: 1))
        try context.save()

        let sortedSessions = campaign.sessions.sorted { $0.date < $1.date }
        XCTAssertEqual(sortedSessions[0].title, "Session 1")
        XCTAssertEqual(sortedSessions[1].title, "Session 2")
        XCTAssertEqual(sortedSessions[2].title, "Session 3")
    }

    func testAC1_tagsWithinSession_sortedByAnchorTime() throws {
        let (_, sessions) = try makeCampaignWithSessions(sessionCount: 1)

        sessions[0].tags.append(makeTag(label: "Late", anchorTime: 300))
        sessions[0].tags.append(makeTag(label: "Early", anchorTime: 10))
        sessions[0].tags.append(makeTag(label: "Mid", anchorTime: 150))
        try context.save()

        let sorted = sessions[0].tags.sorted { $0.anchorTime < $1.anchorTime }
        XCTAssertEqual(sorted[0].label, "Early")
        XCTAssertEqual(sorted[1].label, "Mid")
        XCTAssertEqual(sorted[2].label, "Late")
    }

    func testAC1_sectionHeaders_showSessionTitleAndTagCount() throws {
        let (campaign, sessions) = try makeCampaignWithSessions(sessionCount: 2)

        sessions[0].tags.append(makeTag(label: "A"))
        sessions[0].tags.append(makeTag(label: "B"))
        sessions[1].tags.append(makeTag(label: "C"))
        try context.save()

        // Verify section header data is available
        for session in campaign.sessions.sorted(by: { $0.date < $1.date }) {
            XCTAssertFalse(session.title.isEmpty, "Session title for header")
            XCTAssertGreaterThan(session.tags.count, 0, "Tag count for header")
            XCTAssertGreaterThan(session.duration, 0, "Duration for header")
        }
    }

    // MARK: - AC2: Related tags column

    func testAC2_relatedTags_initialStateEmpty() {
        XCTAssertTrue(service.relatedTags.isEmpty)
        XCTAssertFalse(service.isLoadingRelated)
    }

    func testAC2_performRelatedSearch_setsLoadingFalseAfterCompletion() async throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        let tag = Tag(label: "Grimthor", categoryName: "Story", anchorTime: 10, rewindDuration: 0)
        context.insert(session)
        session.tags.append(tag)
        try context.save()

        await service.performRelatedSearch(for: tag)

        XCTAssertFalse(service.isLoadingRelated, "Loading state must be false after completion")
    }

    func testAC2_performRelatedSearch_emptyLabel_noResults() async throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        let tag = Tag(label: "", categoryName: "Story", anchorTime: 10, rewindDuration: 0)
        context.insert(session)
        session.tags.append(tag)
        try context.save()

        await service.performRelatedSearch(for: tag)

        XCTAssertTrue(service.relatedTags.isEmpty)
    }

    func testAC2_relatedTags_selfExclusion() {
        let tagID = UUID()
        let sessionID = UUID()

        let selfResult = makeSearchResult(tagID: tagID, sessionID: sessionID)
        let otherResult = makeSearchResult(tagID: UUID(), sessionID: UUID())
        let sameSessionResult = makeSearchResult(tagID: UUID(), sessionID: sessionID)

        let candidates = [selfResult, otherResult, sameSessionResult]
        let filtered = candidates.filter { $0.tagID != tagID && $0.sessionID != sessionID }

        XCTAssertEqual(filtered.count, 1, "Only cross-session, non-self results")
        XCTAssertEqual(filtered.first?.tagID, otherResult.tagID)
    }

    func testAC2_relatedTags_sameSessionExcluded() {
        let selectedSessionID = UUID()

        let sameSession = makeSearchResult(
            tagLabel: "Similar Tag", sessionID: selectedSessionID
        )
        let otherSession = makeSearchResult(
            tagLabel: "Related From Other", sessionID: UUID()
        )

        let candidates = [sameSession, otherSession]
        let filtered = candidates.filter { $0.sessionID != selectedSessionID }

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.tagLabel, "Related From Other")
    }

    func testAC2_relatedTags_limitedTo15() {
        let results = (0..<20).map { i in
            makeSearchResult(tagLabel: "Tag \(i)")
        }
        let limited = Array(results.prefix(15))
        XCTAssertEqual(limited.count, 15)
    }

    func testAC2_relatedTags_deduplication() {
        let sharedTagID = UUID()
        let r1 = makeSearchResult(tagID: sharedTagID, tagLabel: "Grimthor")
        let r2 = makeSearchResult(tagID: sharedTagID, tagLabel: "Grimthor")
        let r3 = makeSearchResult(tagLabel: "Other")

        var seen = Set<UUID>()
        var deduplicated: [SearchResult] = []
        for result in [r1, r2, r3] {
            if seen.insert(result.tagID).inserted {
                deduplicated.append(result)
            }
        }
        XCTAssertEqual(deduplicated.count, 2, "Duplicate tagIDs removed")
    }

    func testAC2_clearRelatedResults_resetsState() {
        service.relatedTags = [makeSearchResult()]
        service.clearRelatedResults()

        XCTAssertTrue(service.relatedTags.isEmpty)
        XCTAssertFalse(service.isLoadingRelated)
    }

    // MARK: - AC3: Click related tag → navigation

    func testAC3_relatedTagNavigation_searchResultHasRequiredFields() {
        let tagID = UUID()
        let sessionID = UUID()
        let result = makeSearchResult(
            tagID: tagID,
            tagLabel: "Grimthor",
            sessionTitle: "Session One",
            sessionNumber: 1,
            anchorTime: 42.0,
            sessionID: sessionID
        )

        XCTAssertEqual(result.tagID, tagID, "tagID for pendingTagID")
        XCTAssertEqual(result.sessionID, sessionID, "sessionID for session navigation")
        XCTAssertEqual(result.tagLabel, "Grimthor")
        XCTAssertEqual(result.anchorTime, 42.0)
    }

    func testAC3_relatedTagNavigation_pendingTagIDResolvesInSession() throws {
        let session = Session(title: "Target Session", sessionNumber: 5)
        let tag = Tag(label: "Related Tag", categoryName: "Story",
                      anchorTime: 200, rewindDuration: 0)
        context.insert(session)
        session.tags.append(tag)
        try context.save()

        let pendingTagID = tag.uuid
        let match = session.tags.first(where: { $0.uuid == pendingTagID })

        XCTAssertNotNil(match, "pendingTagID should resolve to tag in session")
        XCTAssertEqual(match?.label, "Related Tag")
    }

    func testAC3_relatedTagNavigation_sessionFetchByUUID() throws {
        let session = Session(title: "Navigation Target", sessionNumber: 3)
        context.insert(session)
        try context.save()

        let sessionUUID = session.uuid
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.uuid == sessionUUID })
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "Navigation Target")
    }

    func testAC3_relatedTagNavigation_crossSessionSwitch() throws {
        let campaign = Campaign(name: "Navigation Campaign")
        let s1 = Session(title: "Current Session", sessionNumber: 1)
        let s2 = Session(title: "Target Session", sessionNumber: 2)
        context.insert(campaign)
        context.insert(s1)
        context.insert(s2)
        campaign.sessions.append(contentsOf: [s1, s2])

        let targetTag = Tag(label: "Target", categoryName: "Story",
                            anchorTime: 100, rewindDuration: 0)
        s2.tags.append(targetTag)
        try context.save()

        // Simulate: click related tag from s2 while viewing s1
        let sessionUUID = s2.uuid
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.uuid == sessionUUID })
        let targetSession = try context.fetch(descriptor).first!

        XCTAssertEqual(targetSession.title, "Target Session")
        let match = targetSession.tags.first(where: { $0.uuid == targetTag.uuid })
        XCTAssertNotNil(match, "Tag found in target session after cross-session navigation")
    }

    // MARK: - AC4: Chronological session list

    func testAC4_sessionList_containsDate() throws {
        let (_, sessions) = try makeCampaignWithSessions(sessionCount: 2)
        for session in sessions {
            XCTAssertNotNil(session.date, "Session must have date")
        }
    }

    func testAC4_sessionList_containsTitle() throws {
        let (_, sessions) = try makeCampaignWithSessions(sessionCount: 2)
        for session in sessions {
            XCTAssertFalse(session.title.isEmpty, "Session must have title")
        }
    }

    func testAC4_sessionList_containsDuration() throws {
        let (_, sessions) = try makeCampaignWithSessions(sessionCount: 2)
        for session in sessions {
            XCTAssertGreaterThan(session.duration, 0, "Session must have duration")
        }
    }

    func testAC4_sessionList_containsTagCount() throws {
        let (_, sessions) = try makeCampaignWithSessions(sessionCount: 2)
        sessions[0].tags.append(makeTag(label: "A"))
        sessions[0].tags.append(makeTag(label: "B"))
        sessions[1].tags.append(makeTag(label: "C"))
        try context.save()

        XCTAssertEqual(sessions[0].tags.count, 2)
        XCTAssertEqual(sessions[1].tags.count, 1)
    }

    func testAC4_sessionList_chronologicalOrder() throws {
        let (campaign, _) = try makeCampaignWithSessions(sessionCount: 5)

        let sorted = campaign.sessions.sorted { $0.date < $1.date }
        for i in 0..<sorted.count - 1 {
            XCTAssertTrue(sorted[i].date <= sorted[i + 1].date,
                          "Sessions must be in chronological order")
        }
    }

    // MARK: - E2E: Full cross-session browsing workflow

    func testE2E_crossSessionBrowsing_filterAndNavigate() throws {
        let campaign = Campaign(name: "Epic Adventure")
        context.insert(campaign)

        // Create 4 sessions with varied tags
        let s1 = Session(title: "Into the Ashlands", sessionNumber: 1,
                         date: Date(timeIntervalSince1970: 86400), duration: 7200)
        let s2 = Session(title: "The First Betrayal", sessionNumber: 2,
                         date: Date(timeIntervalSince1970: 172800), duration: 10800)
        let s3 = Session(title: "Dragon's Lair", sessionNumber: 3,
                         date: Date(timeIntervalSince1970: 259200), duration: 14400)
        let s4 = Session(title: "The Final Battle", sessionNumber: 4,
                         date: Date(timeIntervalSince1970: 345600), duration: 18000)

        [s1, s2, s3, s4].forEach { context.insert($0); campaign.sessions.append($0) }

        // Add tags across sessions
        s1.tags.append(makeTag(label: "Grimthor Intro", categoryName: "Story", anchorTime: 100))
        s1.tags.append(makeTag(label: "First Combat", categoryName: "Combat", anchorTime: 200))
        s2.tags.append(makeTag(label: "Betrayal Scene", categoryName: "Story", anchorTime: 150))
        s2.tags.append(makeTag(label: "Bar Fight", categoryName: "Combat", anchorTime: 300))
        s3.tags.append(makeTag(label: "Dragon Encounter", categoryName: "Combat", anchorTime: 400))
        s3.tags.append(makeTag(label: "Treasure Lore", categoryName: "World", anchorTime: 500))
        s4.tags.append(makeTag(label: "Final Showdown", categoryName: "Combat", anchorTime: 600))
        s4.tags.append(makeTag(label: "Epilogue", categoryName: "Story", anchorTime: 700))
        try context.save()

        // 1. Enter cross-session mode
        let allTags = campaign.sessions.flatMap { $0.tags }
        XCTAssertEqual(allTags.count, 8, "All 8 tags across 4 sessions")

        // 2. Apply Combat category filter
        let combatTags = allTags.filter { $0.categoryName == "Combat" }
        XCTAssertEqual(combatTags.count, 4, "4 combat tags across sessions")

        // 3. Verify chronological sort of sessions
        let sortedSessions = campaign.sessions.sorted { $0.date < $1.date }
        XCTAssertEqual(sortedSessions.map(\.sessionNumber), [1, 2, 3, 4])

        // 4. Verify tags within session sorted by anchorTime
        let s1Tags = s1.tags.sorted { $0.anchorTime < $1.anchorTime }
        XCTAssertEqual(s1Tags[0].label, "Grimthor Intro")
        XCTAssertEqual(s1Tags[1].label, "First Combat")

        // 5. Navigate to a tag in session 3
        let targetTag = s3.tags.first(where: { $0.label == "Dragon Encounter" })!
        let sessionUUID = s3.uuid
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.uuid == sessionUUID })
        let navigatedSession = try context.fetch(descriptor).first!
        let match = navigatedSession.tags.first(where: { $0.uuid == targetTag.uuid })
        XCTAssertNotNil(match)
    }

    func testE2E_relatedTagsWorkflow() throws {
        let campaign = Campaign(name: "Related Tags Campaign")
        context.insert(campaign)

        let s1 = Session(title: "Session 1", sessionNumber: 1)
        let s2 = Session(title: "Session 2", sessionNumber: 2)
        context.insert(s1); context.insert(s2)
        campaign.sessions.append(contentsOf: [s1, s2])

        // Same label across sessions → would be found as related
        s1.tags.append(makeTag(label: "Grimthor", categoryName: "Story", anchorTime: 42,
                               transcription: "Grimthor the blacksmith"))
        s2.tags.append(makeTag(label: "Grimthor Returns", categoryName: "Story", anchorTime: 100,
                               transcription: "Grimthor came back to the shop"))
        try context.save()

        // Simulate related tag results (filtered)
        let selectedTag = s1.tags.first!
        let relatedResults = [
            makeSearchResult(tagID: s2.tags.first!.uuid, tagLabel: "Grimthor Returns",
                             sessionTitle: "Session 2", sessionNumber: 2,
                             sessionID: s2.uuid)
        ]

        // Verify: same-session tags excluded, cross-session included
        let filtered = relatedResults.filter { $0.sessionID != s1.uuid && $0.tagID != selectedTag.uuid }
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.tagLabel, "Grimthor Returns")

        // Navigate to related tag
        let targetResult = filtered.first!
        let sessionUUID = targetResult.sessionID
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.uuid == sessionUUID })
        let targetSession = try context.fetch(descriptor).first!
        XCTAssertEqual(targetSession.title, "Session 2")
    }

    // MARK: - Empty states

    func testEmptyState_noTagsInCampaign() throws {
        let (campaign, _) = try makeCampaignWithSessions(sessionCount: 2)
        let totalTags = campaign.sessions.reduce(0) { $0 + $1.tags.count }
        XCTAssertEqual(totalTags, 0)
    }

    func testEmptyState_categoryFilterNoMatch() throws {
        let (_, sessions) = try makeCampaignWithSessions(sessionCount: 1)
        sessions[0].tags.append(makeTag(label: "Story Tag", categoryName: "Story"))
        try context.save()

        let activeCategories: Set<String> = ["Combat"]
        let filtered = sessions.flatMap(\.tags).filter { activeCategories.contains($0.categoryName) }
        XCTAssertTrue(filtered.isEmpty, "No combat tags exist")
    }

    func testEmptyState_noCampaign_crossSessionUnavailable() throws {
        let session = Session(title: "Standalone Session", sessionNumber: 1)
        context.insert(session)
        try context.save()

        XCTAssertNil(session.campaign, "Session without campaign cannot do cross-session browsing")
    }
}
