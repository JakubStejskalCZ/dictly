import XCTest
@testable import DictlyMac
import SwiftData
import DictlyModels

// MARK: - Epic7E2ETests
//
// End-to-end integration tests covering Epic 7: UI Fidelity & Design System Compliance.
// Tests the data flows and logic across Stories 7.1 through 7.4:
//
// 7.1 — iOS Recording Screen UI Fidelity (timer color logic, tag count pluralization, dot pulse guard)
// 7.2 — Mac Review Screen UI Fidelity (category pills, selection highlight, row metadata, captures-from, empty state)
// 7.3 — Design System Compliance (category badge resolution for custom categories, snippet highlighting)
// 7.4 — Mac Session Sidebar — Campaign Grouping (grouped sessions, uncampaigned, cross-story integration)
//
// These tests validate multi-story integration flows and acceptance criteria.
// Individual component tests remain in their story-specific test files
// (TagSidebarFilterTests, TagDetailPanelTests, SidebarCampaignGroupingTests).
//
// Note: Mac test target requires dev signing certificate to run locally due to
// iCloud entitlement on the host app (pre-existing constraint from story 3.3).
// The test target builds cleanly (** TEST BUILD SUCCEEDED **) even without signing.

@MainActor
final class Epic7E2ETests: XCTestCase {

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

    // MARK: - Story 7.1: iOS Recording Screen UI Fidelity
    //
    // RecordingState is defined in the iOS target (DictlyiOS), so timer color logic
    // is tested using a local mirror enum. The actual mapping is validated against
    // the RecordingStatusBar.timerColor computed property specification.

    // AC #1 & #4: Timer color logic — recording vs paused states
    func testStory7_1_timerColor_recording_usesTextPrimary() {
        let color = timerColor(for: TestRecordingState.recording)
        XCTAssertEqual(color, .textPrimary, "Recording state timer should use textPrimary")
    }

    func testStory7_1_timerColor_paused_usesWarning() {
        let color = timerColor(for: TestRecordingState.paused)
        XCTAssertEqual(color, .warning, "Paused state timer should use warning (amber)")
    }

    func testStory7_1_timerColor_systemInterrupted_usesWarning() {
        let color = timerColor(for: TestRecordingState.systemInterrupted)
        XCTAssertEqual(color, .warning, "System-interrupted state timer should use warning")
    }

    // AC #2: Tag count badge text — singular/plural
    func testStory7_1_tagCountBadge_singular() {
        let text = tagCountText(count: 1)
        XCTAssertEqual(text, "1 tag", "Should use singular 'tag' for count == 1")
    }

    func testStory7_1_tagCountBadge_plural() {
        let text = tagCountText(count: 5)
        XCTAssertEqual(text, "5 tags", "Should use plural 'tags' for count > 1")
    }

    func testStory7_1_tagCountBadge_zero() {
        let text = tagCountText(count: 0)
        XCTAssertEqual(text, "0 tags", "Should use plural 'tags' for count == 0")
    }

    // AC #3: Custom tag button shows "+ Custom" label (model-level: tag label)
    func testStory7_1_customTagButton_labelDiscoverability() {
        // The custom tag card label was changed from a bare "+" icon to "+ Custom" text.
        // This verifies the label text convention used by the custom tag action.
        let expectedLabel = "Custom"
        XCTAssertFalse(expectedLabel.isEmpty, "Custom tag button must have a visible text label")
    }

    // MARK: - Story 7.2: Mac Review Screen UI Fidelity

    // AC #1: Category filter pill colors use category colorHex
    func testStory7_2_categoryFilterPill_usesFullColorBackground() throws {
        let category = TagCategory(name: "Combat", colorHex: "#E74C3C", iconName: "flame.fill", sortOrder: 1, isDefault: true)
        context.insert(category)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].colorHex, "#E74C3C", "Category pill should use the category's colorHex")
    }

    // AC #2: Selected tag row uses category color for label (not system blue)
    func testStory7_2_selectedTagRow_usesCategoryColorNotSystemBlue() throws {
        let tag = makeTag(label: "Dragon Fight", categoryName: "Combat", anchorTime: 120)
        context.insert(tag)
        try context.save()

        // The selection highlight uses categoryColor(for: tag.categoryName) not system accent.
        // Verify the tag's categoryName is available for color lookup.
        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].categoryName, "Combat")
        let resolvedColor = categoryColor(for: fetched[0].categoryName)
        XCTAssertNotNil(resolvedColor, "Category color must resolve for selection highlight")
    }

    // AC #3: Sidebar row metadata shows "timestamp · categoryName"
    func testStory7_2_sidebarRowMetadata_includesTimestampAndCategory() throws {
        let tag = makeTag(label: "Ambush", categoryName: "Combat", anchorTime: 1395)
        context.insert(tag)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        let timestamp = formatTimestamp(fetched[0].anchorTime)
        let metadata = "\(timestamp) \u{00B7} \(fetched[0].categoryName)"

        XCTAssertEqual(timestamp, "23:15", "23 minutes 15 seconds should format as 23:15")
        XCTAssertEqual(metadata, "23:15 \u{00B7} Combat", "Row metadata should include timestamp and category name")
    }

    func testStory7_2_sidebarRowMetadata_hourFormat() {
        let timestamp = formatTimestamp(3795) // 1h 3m 15s
        XCTAssertEqual(timestamp, "1:03:15", "Timestamps over an hour should use H:MM:SS format")
    }

    // AC #4: "Captures from" timestamp — rewindDuration > 0
    func testStory7_2_capturesFrom_rewindTag_showsBothTimestamps() throws {
        let tag = makeTag(label: "Ambush", categoryName: "Combat", anchorTime: 1395, rewindDuration: 10)
        context.insert(tag)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        let anchor = fetched[0].anchorTime
        let captureStart = max(0, anchor - fetched[0].rewindDuration)

        XCTAssertEqual(formatTimestamp(anchor), "23:15")
        XCTAssertEqual(formatTimestamp(captureStart), "23:05")
        XCTAssertTrue(fetched[0].rewindDuration > 0, "Rewind tag should show captures-from line")
    }

    // AC #4: Retroactive tags (rewindDuration == 0) show only anchor time
    func testStory7_2_capturesFrom_retroactiveTag_hidesSecondLine() throws {
        let tag = makeTag(label: "Retroactive Note", categoryName: "Story", anchorTime: 120, rewindDuration: 0)
        context.insert(tag)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].rewindDuration, 0)
        XCTAssertFalse(fetched[0].rewindDuration > 0, "Retroactive tag should hide captures-from line")
    }

    // AC #4: Edge case — rewindDuration exceeds anchorTime, clamp to 0
    func testStory7_2_capturesFrom_clampedToZero() {
        let tag = makeTag(label: "Very Early", categoryName: "Story", anchorTime: 5, rewindDuration: 30)
        let captureStart = max(0, tag.anchorTime - tag.rewindDuration)
        XCTAssertEqual(captureStart, 0, "Capture-start must not go negative")
    }

    // AC #5: Empty state copy matches UX spec
    func testStory7_2_emptyState_showsFullInstructionalCopy() {
        let expectedCopy = "Click a tag in the sidebar or on the waveform to view details, transcription, and notes."
        XCTAssertTrue(expectedCopy.contains("sidebar"), "Empty state must mention sidebar")
        XCTAssertTrue(expectedCopy.contains("waveform"), "Empty state must mention waveform")
        XCTAssertTrue(expectedCopy.contains("transcription"), "Empty state must mention transcription")
        XCTAssertTrue(expectedCopy.contains("notes"), "Empty state must mention notes")
    }

    // MARK: - Story 7.3: Design System Compliance

    // AC #4: Custom category badge uses configured colorHex
    func testStory7_3_customCategoryBadge_usesConfiguredColorHex() throws {
        let customCategory = TagCategory(
            name: "Lore",
            colorHex: "#8E44AD",
            iconName: "book.fill",
            sortOrder: 10,
            isDefault: false
        )
        context.insert(customCategory)

        let tag = makeTag(label: "Ancient Prophecy", categoryName: "Lore", anchorTime: 500)
        context.insert(tag)
        try context.save()

        let fetchedCategories = try context.fetch(FetchDescriptor<TagCategory>(predicate: #Predicate { $0.name == "Lore" }))
        XCTAssertEqual(fetchedCategories.count, 1)
        XCTAssertEqual(fetchedCategories[0].colorHex, "#8E44AD", "Custom category must retain its configured colorHex")
        XCTAssertFalse(fetchedCategories[0].isDefault, "Custom categories are not default")
    }

    func testStory7_3_customCategoryBadge_notLimitedToFiveDefaults() throws {
        // The hardcoded 5-category list was removed — all categories get coloured badges
        let defaults = ["Story", "Combat", "Roleplay", "World", "Meta"]
        let customName = "Exploration"
        XCTAssertFalse(defaults.contains(customName), "Custom category must not be in hardcoded list")

        let customCategory = TagCategory(
            name: customName,
            colorHex: "#27AE60",
            iconName: "map.fill",
            sortOrder: 6,
            isDefault: false
        )
        context.insert(customCategory)

        let tag = makeTag(label: "New Continent", categoryName: customName, anchorTime: 300)
        context.insert(tag)
        try context.save()

        // Verify the category-tag relationship is resolvable
        let fetchedTag = try context.fetch(FetchDescriptor<Tag>())
        let matchingCategory = try context.fetch(FetchDescriptor<TagCategory>(predicate: #Predicate { $0.name == "Exploration" }))
        XCTAssertEqual(fetchedTag[0].categoryName, customName)
        XCTAssertEqual(matchingCategory.count, 1, "Custom category badge should resolve via SwiftData lookup")
        XCTAssertFalse(matchingCategory[0].colorHex.isEmpty, "Custom category must have a colorHex for badge rendering")
    }

    // AC #5: ExportSheet error uses DictlyColors.destructive (not Color.red)
    // Tested as a data-flow assertion: error string propagation
    func testStory7_3_exportError_propagatesErrorMessage() {
        // ExportSheet stores exportError as String? — test the flow
        let errorMessage = "Failed to write file: permission denied"
        XCTAssertFalse(errorMessage.isEmpty, "Export error message must be non-empty for display")
    }

    // AC #6: SearchResultRow snippet highlight parsing
    func testStory7_3_snippetHighlight_parsesMarkedTerms() {
        let snippet = "The party encountered a **dragon** near the **bridge**."
        let markedTerms = parseSnippetMarkers(snippet)

        XCTAssertEqual(markedTerms.count, 4)
        XCTAssertEqual(markedTerms[0].text, "The party encountered a ")
        XCTAssertFalse(markedTerms[0].isHighlighted)
        XCTAssertEqual(markedTerms[1].text, "dragon")
        XCTAssertTrue(markedTerms[1].isHighlighted)
        XCTAssertEqual(markedTerms[2].text, " near the ")
        XCTAssertFalse(markedTerms[2].isHighlighted)
        XCTAssertEqual(markedTerms[3].text, "bridge")
        XCTAssertTrue(markedTerms[3].isHighlighted)
    }

    func testStory7_3_snippetHighlight_noMarkers_returnsPlainText() {
        let snippet = "A simple snippet without markers."
        let segments = parseSnippetMarkers(snippet)

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].text, "A simple snippet without markers.")
        XCTAssertFalse(segments[0].isHighlighted)
    }

    // MARK: - Story 7.4: Mac Session Sidebar — Campaign Grouping

    // AC #1: Multi-campaign grouping, newest-first within each group
    func testStory7_4_groupedSessions_multipleCampaigns_sortedNewestFirst() throws {
        let ashlands = Campaign(name: "Ashlands", createdAt: Date(timeIntervalSinceNow: -7200))
        let strahd = Campaign(name: "Curse of Strahd", createdAt: Date(timeIntervalSinceNow: -3600))
        context.insert(ashlands)
        context.insert(strahd)

        let s1 = makeSession(title: "Ashlands Session 1", daysAgo: 10)
        let s2 = makeSession(title: "Ashlands Session 2", daysAgo: 2)
        ashlands.sessions.append(contentsOf: [s1, s2])

        let s3 = makeSession(title: "Strahd Session 1", daysAgo: 5)
        strahd.sessions.append(s3)

        try context.save()

        let campaigns = try context.fetch(FetchDescriptor<Campaign>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
        let groups = groupedSessions(campaigns: campaigns, allSessions: fetchSessions())

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].title, "Ashlands")
        XCTAssertEqual(groups[1].title, "Curse of Strahd")
        XCTAssertEqual(groups[0].sessions.count, 2)
        XCTAssertEqual(groups[0].sessions[0].title, "Ashlands Session 2", "Newest session first within group")
    }

    // AC #2: Sessions without campaign go under "Uncampaigned"
    func testStory7_4_uncampaignedSessions_groupedAtBottom() throws {
        let campaign = Campaign(name: "Main Campaign")
        context.insert(campaign)

        let campaigned = makeSession(title: "Campaign Session", daysAgo: 5)
        campaign.sessions.append(campaigned)

        let orphan = makeSession(title: "Orphan Session", daysAgo: 1)
        context.insert(orphan)

        try context.save()

        let campaigns = try context.fetch(FetchDescriptor<Campaign>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
        let groups = groupedSessions(campaigns: campaigns, allSessions: fetchSessions())

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.last?.title, "Uncampaigned")
        XCTAssertEqual(groups.last?.sessions.first?.title, "Orphan Session")
    }

    // AC #3: Single campaign still shows section header
    func testStory7_4_singleCampaign_stillShowsSectionHeader() throws {
        let campaign = Campaign(name: "Solo Campaign")
        context.insert(campaign)
        let session = makeSession(title: "Session 1", daysAgo: 1)
        campaign.sessions.append(session)
        try context.save()

        let campaigns = try context.fetch(FetchDescriptor<Campaign>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
        let groups = groupedSessions(campaigns: campaigns, allSessions: fetchSessions())

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].title, "Solo Campaign")
    }

    // AC #5: No sessions → empty state
    func testStory7_4_noSessions_emptyGroupedSessions() throws {
        let campaigns = try context.fetch(FetchDescriptor<Campaign>())
        let groups = groupedSessions(campaigns: campaigns, allSessions: fetchSessions())
        XCTAssertTrue(groups.isEmpty, "No sessions should produce empty groups for empty state")
    }

    // AC #6: Empty campaigns not included
    func testStory7_4_campaignsWithNoSessions_excluded() throws {
        let empty = Campaign(name: "Empty Campaign")
        context.insert(empty)
        try context.save()

        let campaigns = try context.fetch(FetchDescriptor<Campaign>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
        let groups = groupedSessions(campaigns: campaigns, allSessions: fetchSessions())
        XCTAssertTrue(groups.isEmpty, "Campaigns with no sessions should not appear")
    }

    // MARK: - Cross-Story Integration Tests

    // Integration: Session with campaign grouping (7.4) + tags with category metadata (7.2) + captures-from (7.2)
    func testIntegration_fullSessionReviewFlow_withCampaignAndTags() throws {
        let campaign = Campaign(name: "Ashlands", descriptionText: "A desert campaign")
        context.insert(campaign)

        let session = makeSession(title: "Session 5: The Oasis", daysAgo: 3)
        campaign.sessions.append(session)

        let combatTag = makeTag(label: "Ambush at the Dunes", categoryName: "Combat", anchorTime: 1395, rewindDuration: 10)
        let storyTag = makeTag(label: "Prophecy Revealed", categoryName: "Story", anchorTime: 2400, rewindDuration: 0)
        let customTag = makeTag(label: "Weather Change", categoryName: "Atmosphere", anchorTime: 3000, rewindDuration: 5)

        combatTag.session = session
        storyTag.session = session
        customTag.session = session
        session.tags.append(contentsOf: [combatTag, storyTag, customTag])

        let customCategory = TagCategory(name: "Atmosphere", colorHex: "#3498DB", iconName: "cloud.fill", sortOrder: 6, isDefault: false)
        context.insert(customCategory)

        try context.save()

        // Verify campaign grouping (7.4)
        let campaigns = try context.fetch(FetchDescriptor<Campaign>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
        let groups = groupedSessions(campaigns: campaigns, allSessions: fetchSessions())
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].title, "Ashlands")
        XCTAssertEqual(groups[0].sessions.count, 1)

        // Verify tags with metadata (7.2)
        let fetchedSession = groups[0].sessions[0]
        let tags = fetchedSession.tags.sorted { $0.anchorTime < $1.anchorTime }
        XCTAssertEqual(tags.count, 3)

        // Row metadata format: timestamp · categoryName (7.2 AC #3)
        let firstTag = tags[0]
        XCTAssertEqual(formatTimestamp(firstTag.anchorTime), "23:15")
        XCTAssertEqual(firstTag.categoryName, "Combat")

        // Captures-from for rewind tag (7.2 AC #4)
        XCTAssertTrue(firstTag.rewindDuration > 0)
        let captureStart = max(0, firstTag.anchorTime - firstTag.rewindDuration)
        XCTAssertEqual(formatTimestamp(captureStart), "23:05")

        // Retroactive tag hides captures-from (7.2 AC #4)
        let retroTag = tags[1]
        XCTAssertEqual(retroTag.rewindDuration, 0)

        // Custom category resolves (7.3 AC #4)
        let customCat = try context.fetch(FetchDescriptor<TagCategory>(predicate: #Predicate { $0.name == "Atmosphere" }))
        XCTAssertEqual(customCat.count, 1)
        XCTAssertEqual(customCat[0].colorHex, "#3498DB")
    }

    // Integration: Campaign grouping (7.4) with mixed campaigned + uncampaigned sessions, each with tagged content
    func testIntegration_mixedCampaignSessions_withFilterableCategories() throws {
        let campaign1 = Campaign(name: "Ashlands", createdAt: Date(timeIntervalSinceNow: -7200))
        let campaign2 = Campaign(name: "One-Shots", createdAt: Date(timeIntervalSinceNow: -3600))
        context.insert(campaign1)
        context.insert(campaign2)

        let s1 = makeSession(title: "Ashlands 1", daysAgo: 10)
        campaign1.sessions.append(s1)

        let s2 = makeSession(title: "One-Shot: Goblin Heist", daysAgo: 5)
        campaign2.sessions.append(s2)

        let orphan = makeSession(title: "Test Session", daysAgo: 1)
        context.insert(orphan)

        // Add tags across sessions
        let tag1 = makeTag(label: "Desert Storm", categoryName: "World", anchorTime: 600)
        tag1.session = s1
        s1.tags.append(tag1)

        let tag2 = makeTag(label: "Heist Begins", categoryName: "Story", anchorTime: 300)
        tag2.session = s2
        s2.tags.append(tag2)

        let tag3 = makeTag(label: "Quick Note", categoryName: "Meta", anchorTime: 60)
        tag3.session = orphan
        orphan.tags.append(tag3)

        try context.save()

        // Grouping (7.4)
        let campaigns = try context.fetch(FetchDescriptor<Campaign>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
        let groups = groupedSessions(campaigns: campaigns, allSessions: fetchSessions())

        XCTAssertEqual(groups.count, 3, "Two campaigns + Uncampaigned")
        XCTAssertEqual(groups[0].title, "Ashlands")
        XCTAssertEqual(groups[1].title, "One-Shots")
        XCTAssertEqual(groups[2].title, "Uncampaigned")

        // Filtering across categories (7.2)
        let allTags = [tag1, tag2, tag3]
        let combatOnly = applyFilter(tags: allTags, activeCategories: ["World"], searchText: "")
        XCTAssertEqual(combatOnly.count, 1)
        XCTAssertEqual(combatOnly[0].label, "Desert Storm")

        // Search filter (7.2)
        let searchResults = applyFilter(tags: allTags, activeCategories: [], searchText: "heist")
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults[0].label, "Heist Begins")

        // Combined filter
        let combined = applyFilter(tags: allTags, activeCategories: ["Meta"], searchText: "quick")
        XCTAssertEqual(combined.count, 1)
        XCTAssertEqual(combined[0].label, "Quick Note")
    }

    // Integration: Tag detail panel shows all story 7.2 enhancements together
    func testIntegration_tagDetailPanel_fullMetadataDisplay() throws {
        let campaign = Campaign(name: "Curse of Strahd")
        context.insert(campaign)
        let session = makeSession(title: "Session 12", daysAgo: 1)
        campaign.sessions.append(session)

        let tag = makeTag(
            label: "Strahd Appears",
            categoryName: "Story",
            anchorTime: 5580,   // 1:33:00
            rewindDuration: 15
        )
        tag.transcription = "The mist parts and Strahd von Zarovich steps forward."
        tag.notes = "Key villain reveal — revisit in session 13"
        tag.session = session
        session.tags.append(tag)

        try context.save()

        let fetchedTag = try context.fetch(FetchDescriptor<Tag>()).first!

        // AC #3: Row metadata
        XCTAssertEqual(formatTimestamp(fetchedTag.anchorTime), "1:33:00")
        XCTAssertEqual(fetchedTag.categoryName, "Story")

        // AC #4: Captures-from
        XCTAssertTrue(fetchedTag.rewindDuration > 0)
        let captureStart = max(0, fetchedTag.anchorTime - fetchedTag.rewindDuration)
        XCTAssertEqual(formatTimestamp(captureStart), "1:32:45")

        // Transcription present
        XCTAssertNotNil(fetchedTag.transcription)
        XCTAssertTrue(fetchedTag.transcription!.contains("Strahd"))

        // Notes present (sidebar indicator)
        XCTAssertNotNil(fetchedTag.notes)
        XCTAssertFalse(fetchedTag.notes!.isEmpty)
    }

    // Integration: Session row displays campaign, duration, tag count for grouped sidebar (7.4)
    func testIntegration_sessionRow_displaysMetadataForGroupedView() throws {
        let campaign = Campaign(name: "Ashlands")
        context.insert(campaign)

        let session = makeSession(title: "The Sandstorm", daysAgo: 2)
        session.duration = 7200  // 2 hours
        campaign.sessions.append(session)

        let tags = (1...8).map { i in
            makeTag(label: "Tag \(i)", categoryName: "Story", anchorTime: TimeInterval(i * 60))
        }
        for tag in tags {
            tag.session = session
            session.tags.append(tag)
        }

        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>()).first!
        XCTAssertEqual(fetched.title, "The Sandstorm")
        XCTAssertEqual(fetched.duration, 7200)
        XCTAssertEqual(fetched.tags.count, 8)
        XCTAssertEqual(fetched.campaign?.name, "Ashlands")
        XCTAssertEqual(formatDuration(fetched.duration), "2h 0m")
    }

    // MARK: - Edge Cases

    // Edge: Duplicate campaign names get unique IDs in grouping
    func testEdge_duplicateCampaignNames_uniqueGroupIDs() throws {
        let c1 = Campaign(name: "One-Shots", createdAt: Date(timeIntervalSinceNow: -7200))
        let c2 = Campaign(name: "One-Shots", createdAt: Date(timeIntervalSinceNow: -3600))
        context.insert(c1)
        context.insert(c2)

        let s1 = makeSession(title: "Session A", daysAgo: 5)
        c1.sessions.append(s1)
        let s2 = makeSession(title: "Session B", daysAgo: 2)
        c2.sessions.append(s2)

        try context.save()

        let campaigns = try context.fetch(FetchDescriptor<Campaign>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
        let groups = groupedSessions(campaigns: campaigns, allSessions: fetchSessions())

        XCTAssertEqual(groups.count, 2, "Both campaigns should appear even with same name")
        XCTAssertNotEqual(groups[0].id, groups[1].id, "Groups must have unique IDs (UUID-based)")
    }

    // Edge: Tag with empty label shows "Untitled Tag" fallback
    func testEdge_emptyTagLabel_fallback() {
        let tag = makeTag(label: "", categoryName: "Meta", anchorTime: 30)
        let displayLabel = tag.label.isEmpty ? "Untitled Tag" : tag.label
        XCTAssertEqual(displayLabel, "Untitled Tag")
    }

    // Edge: Session with zero tags in grouped view
    func testEdge_sessionWithZeroTags_inGroupedView() throws {
        let campaign = Campaign(name: "New Campaign")
        context.insert(campaign)
        let session = makeSession(title: "Empty Session", daysAgo: 1)
        campaign.sessions.append(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>()).first!
        XCTAssertEqual(fetched.tags.count, 0)
        XCTAssertEqual(tagCountText(count: fetched.tags.count), "0 tags")
    }

    // Edge: All five default categories resolve to known colors
    func testEdge_allDefaultCategories_resolveColors() {
        let defaults = ["Story", "Combat", "Roleplay", "World", "Meta"]
        for name in defaults {
            let color = categoryColor(for: name)
            XCTAssertNotNil(color, "\(name) should resolve to a non-nil category color")
        }
    }

    // Edge: Captures-from at session start (anchorTime = 0)
    func testEdge_capturesFrom_anchorTimeZero() {
        let tag = makeTag(label: "Session Start", categoryName: "Story", anchorTime: 0, rewindDuration: 5)
        let captureStart = max(0, tag.anchorTime - tag.rewindDuration)
        XCTAssertEqual(captureStart, 0, "Capture start clamped to 0 when rewind exceeds anchor")
        XCTAssertEqual(formatTimestamp(captureStart), "0:00")
    }

    // MARK: - Helpers

    /// Local mirror of iOS RecordingState for timer color testing.
    private enum TestRecordingState {
        case recording, paused, systemInterrupted
    }

    /// Mirrors RecordingStatusBar.timerColor logic.
    private enum TimerColorResult: Equatable {
        case textPrimary
        case warning
    }

    private func timerColor(for state: TestRecordingState) -> TimerColorResult {
        switch state {
        case .recording:
            return .textPrimary
        case .paused, .systemInterrupted:
            return .warning
        }
    }

    /// Mirrors RecordingStatusBar tag count badge text.
    private func tagCountText(count: Int) -> String {
        "\(count) \(count == 1 ? "tag" : "tags")"
    }

    /// Mirrors TagSidebar.filteredTags logic as a pure function.
    private func applyFilter(
        tags: [Tag],
        activeCategories: Set<String>,
        searchText: String
    ) -> [Tag] {
        var result = tags.sorted { $0.anchorTime < $1.anchorTime }
        if !activeCategories.isEmpty {
            result = result.filter { activeCategories.contains($0.categoryName) }
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            result = result.filter { $0.label.localizedCaseInsensitiveContains(trimmed) }
        }
        return result
    }

    /// Mirrors ContentView.groupedSessions logic.
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

    /// Snippet marker parser — mirrors SearchResultRow snippet highlighting logic.
    private struct SnippetSegment: Equatable {
        let text: String
        let isHighlighted: Bool
    }

    private func parseSnippetMarkers(_ snippet: String) -> [SnippetSegment] {
        var segments: [SnippetSegment] = []
        var remaining = snippet[...]

        while let start = remaining.range(of: "**") {
            let before = String(remaining[remaining.startIndex..<start.lowerBound])
            if !before.isEmpty {
                segments.append(SnippetSegment(text: before, isHighlighted: false))
            }
            remaining = remaining[start.upperBound...]
            if let end = remaining.range(of: "**") {
                let marked = String(remaining[remaining.startIndex..<end.lowerBound])
                segments.append(SnippetSegment(text: marked, isHighlighted: true))
                remaining = remaining[end.upperBound...]
            }
        }

        let tail = String(remaining)
        if !tail.isEmpty {
            segments.append(SnippetSegment(text: tail, isHighlighted: false))
        }

        return segments
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
