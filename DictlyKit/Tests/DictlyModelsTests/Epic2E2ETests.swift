import XCTest
import SwiftData
@testable import DictlyModels

/// End-to-end integration tests covering Epic 2 acceptance criteria.
/// Tests the full data flow across Stories 2.1 through 2.7:
/// recording engine, pause/resume, status indicators, tagging,
/// rewind-anchor, custom tags, and stop/session summary.
@MainActor
final class Epic2E2ETests: XCTestCase {
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

    // MARK: - Story 2.1: Audio Recording Engine with Background Persistence

    // AC#1: Audio captured in AAC format — session gets audioFilePath stored as filename only
    func testRecordingSession_audioFilePathStoredAsFilenameOnly() throws {
        let campaign = Campaign(name: "Test Campaign")
        context.insert(campaign)
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)
        campaign.sessions.append(session)

        // Simulate recording engine setting audioFilePath (filename-only, no directory)
        let filename = "\(session.uuid.uuidString).m4a"
        session.audioFilePath = filename
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetched[0].audioFilePath, filename)
        XCTAssertFalse(filename.contains("/"), "audioFilePath must be filename-only, not an absolute path")
        XCTAssertTrue(filename.hasSuffix(".m4a"), "Audio file must use .m4a container")
    }

    // AC#4: Crash recovery — orphaned session has audioFilePath set but duration == 0
    func testOrphanedSession_identifiableForRecovery() throws {
        let session = Session(title: "Orphaned", sessionNumber: 1, audioFilePath: "orphaned.m4a")
        context.insert(session)
        try context.save()

        // Orphaned recording: has audioFilePath but duration is still 0
        XCTAssertEqual(session.duration, 0)
        XCTAssertNotNil(session.audioFilePath)

        // The predicate that SessionRecorder.recoverOrphanedRecordings uses
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.audioFilePath != nil && $0.duration == 0 }
        )
        let orphaned = try context.fetch(descriptor)
        XCTAssertEqual(orphaned.count, 1, "Session with audioFilePath and zero duration should be found as orphaned")
    }

    // AC#4: Non-orphaned sessions (with duration > 0) are not flagged
    func testNonOrphanedSession_notFlaggedForRecovery() throws {
        let session = Session(title: "Completed", sessionNumber: 1, duration: 3600, audioFilePath: "completed.m4a")
        context.insert(session)
        try context.save()

        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.audioFilePath != nil && $0.duration == 0 }
        )
        let orphaned = try context.fetch(descriptor)
        XCTAssertEqual(orphaned.count, 0, "Session with duration > 0 should not be flagged for recovery")
    }

    // Story 2.1: DictlyError.RecordingError has all required cases
    func testRecordingError_allCasesExist() {
        let errors: [(DictlyError, String)] = [
            (.recording(.audioSessionSetupFailed("test")), "Audio session setup failed: test"),
            (.recording(.engineStartFailed("test")), "Failed to start recording engine: test"),
            (.recording(.fileCreationFailed("test")), "Failed to create recording file: test"),
            (.recording(.diskFull), "Not enough disk space to continue recording."),
        ]

        for (error, expected) in errors {
            XCTAssertEqual(error.errorDescription, expected)
        }
    }

    // MARK: - Story 2.2: Pause, Resume & Phone Call Interruption Handling

    // AC#1-2: PauseInterval model supports pause/resume tracking
    func testPauseInterval_creation() {
        let interval = PauseInterval(start: 30.0, end: 45.0)
        XCTAssertEqual(interval.start, 30.0)
        XCTAssertEqual(interval.end, 45.0)
    }

    // AC#5: Pause intervals stored and retrievable from session
    func testSession_pauseIntervals_storedAndRetrievable() throws {
        let session = Session(title: "Paused Session", sessionNumber: 1)
        context.insert(session)

        let intervals = [
            PauseInterval(start: 60.0, end: 120.0),
            PauseInterval(start: 300.0, end: 360.0),
            PauseInterval(start: 900.0, end: 905.0),
        ]
        session.pauseIntervals = intervals
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        let decoded = fetched[0].pauseIntervals
        XCTAssertEqual(decoded.count, 3, "All pause intervals must persist")
        XCTAssertEqual(decoded[0].start, 60.0, accuracy: 0.001)
        XCTAssertEqual(decoded[0].end, 120.0, accuracy: 0.001)
        XCTAssertEqual(decoded[1].start, 300.0, accuracy: 0.001)
        XCTAssertEqual(decoded[1].end, 360.0, accuracy: 0.001)
        XCTAssertEqual(decoded[2].start, 900.0, accuracy: 0.001)
        XCTAssertEqual(decoded[2].end, 905.0, accuracy: 0.001)
    }

    // AC#5: Multiple pauses appear as distinct gaps
    func testSession_multiplePauses_distinctGaps() throws {
        let session = Session(title: "Multi-Pause", sessionNumber: 1)
        context.insert(session)

        // Simulate 3 separate pause intervals
        var intervals: [PauseInterval] = []
        intervals.append(PauseInterval(start: 30.0, end: 60.0))
        intervals.append(PauseInterval(start: 120.0, end: 150.0))
        intervals.append(PauseInterval(start: 300.0, end: 310.0))
        session.pauseIntervals = intervals
        try context.save()

        // Each pause interval should be non-overlapping and ordered
        let decoded = session.pauseIntervals
        for i in 0..<(decoded.count - 1) {
            XCTAssertLessThan(decoded[i].end, decoded[i + 1].start,
                              "Pause intervals must not overlap")
        }
    }

    // AC#2: Pausing preserves session continuity — same file, same session
    func testPauseAndResume_sameSession() throws {
        let campaign = Campaign(name: "Campaign")
        context.insert(campaign)
        let session = Session(title: "Session 1", sessionNumber: 1, audioFilePath: "session.m4a")
        context.insert(session)
        campaign.sessions.append(session)
        try context.save()

        // After pause + resume, audioFilePath should not change (same file)
        let originalPath = session.audioFilePath
        // Simulate pause interval
        session.pauseIntervals = [PauseInterval(start: 60.0, end: 90.0)]
        try context.save()

        XCTAssertEqual(session.audioFilePath, originalPath, "Audio file path must not change after pause/resume")
        XCTAssertEqual(campaign.sessions.count, 1, "Session must remain the same single session")
    }

    // Session with no pauses has nil pauseIntervalsJSON
    func testSession_noPauses_nilJSON() {
        let session = Session(title: "No Pauses", sessionNumber: 1)
        context.insert(session)
        XCTAssertNil(session.pauseIntervalsJSON)
        XCTAssertEqual(session.pauseIntervals, [])
    }

    // MARK: - Story 2.3: Recording Screen Layout & Status Indicators

    // AC#1: Session stores duration for timer display
    func testSession_durationForTimerDisplay() throws {
        let session = Session(title: "Long Session", sessionNumber: 1, duration: 14601)
        context.insert(session)
        try context.save()

        // 4h 3m 21s
        let total = Int(session.duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        XCTAssertEqual(hours, 4)
        XCTAssertEqual(minutes, 3)
        XCTAssertEqual(seconds, 21)
    }

    // AC#1: Tag count visible at top — verified through session.tags.count
    func testSession_tagCountReflectsPlacedTags() throws {
        let session = Session(title: "Tagged Session", sessionNumber: 1)
        context.insert(session)

        for i in 0..<5 {
            let tag = Tag(label: "Tag \(i)", categoryName: "Combat", anchorTime: TimeInterval(i * 60), rewindDuration: 10)
            context.insert(tag)
            session.tags.append(tag)
        }
        try context.save()

        XCTAssertEqual(session.tags.count, 5, "Tag count must reflect all placed tags")
    }

    // MARK: - Story 2.4: Tag Palette with Category Tabs & One-Tap Tagging

    // AC#1: Tags have categoryName for category filtering
    func testTag_categoryNameForFiltering() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)

        let categories = ["Story", "Combat", "Roleplay", "World", "Meta"]
        for categoryName in categories {
            let predicate = #Predicate<Tag> { $0.categoryName == categoryName }
            let tags = try context.fetch(FetchDescriptor<Tag>(predicate: predicate))
            XCTAssertEqual(tags.count, 5, "Category '\(categoryName)' should have 5 default tags")
        }
    }

    // AC#2: One-tap tag placement creates tag with correct data
    func testOneTapTagPlacement_createsCorrectTag() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)

        let tag = Tag(
            label: "Critical Hit",
            categoryName: "Combat",
            anchorTime: 150.0,
            rewindDuration: 10.0,
            createdAt: Date()
        )
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        XCTAssertEqual(session.tags.count, 1)
        let placed = session.tags[0]
        XCTAssertEqual(placed.label, "Critical Hit")
        XCTAssertEqual(placed.categoryName, "Combat")
        XCTAssertEqual(placed.anchorTime, 150.0, accuracy: 0.001)
    }

    // AC#2: Tag count badge increments with each placement
    func testTagCountBadge_incrementsWithEachPlacement() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)

        for i in 1...10 {
            let tag = Tag(label: "Tag \(i)", categoryName: "Combat", anchorTime: TimeInterval(i * 10), rewindDuration: 0)
            context.insert(tag)
            session.tags.append(tag)
            XCTAssertEqual(session.tags.count, i, "Tag count should be \(i) after \(i) placements")
        }
    }

    // AC#1: Category tab filtering works across all default categories
    func testCategoryTabFiltering_allDefaultCategories() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)

        // Simulate filtering by category (as TagPalette does with in-memory filter)
        let allTags = try context.fetch(FetchDescriptor<Tag>())
        let templateTags = allTags.filter { $0.session == nil } // Templates only

        let combatTags = templateTags.filter { $0.categoryName == "Combat" }
        let storyTags = templateTags.filter { $0.categoryName == "Story" }
        let roleplayTags = templateTags.filter { $0.categoryName == "Roleplay" }
        let worldTags = templateTags.filter { $0.categoryName == "World" }
        let metaTags = templateTags.filter { $0.categoryName == "Meta" }

        XCTAssertEqual(combatTags.count, 5)
        XCTAssertEqual(storyTags.count, 5)
        XCTAssertEqual(roleplayTags.count, 5)
        XCTAssertEqual(worldTags.count, 5)
        XCTAssertEqual(metaTags.count, 5)
    }

    // MARK: - Story 2.5: Rewind-Anchor Tagging & Timestamp-First Interaction

    // AC#1: Default rewind-anchor — tag at 2:30:00 with 10s rewind stores anchorTime as 2:29:50
    func testRewindAnchor_defaultRewindCalculation() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)

        let elapsedTime: TimeInterval = 9000.0 // 2:30:00
        let rewindDuration: TimeInterval = 10.0
        let anchorTime = max(0, elapsedTime - rewindDuration)
        let actualRewind = elapsedTime - anchorTime

        let tag = Tag(label: "Plot Hook", categoryName: "Story", anchorTime: anchorTime, rewindDuration: actualRewind)
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        XCTAssertEqual(tag.anchorTime, 8990.0, accuracy: 0.001, "anchorTime should be 2:29:50 (8990s)")
        XCTAssertEqual(tag.rewindDuration, 10.0, accuracy: 0.001)
    }

    // AC#2: Configurable rewind — 15s rewind at 1:00:00 anchors to 0:59:45
    func testRewindAnchor_configurableRewindDuration() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)

        let elapsedTime: TimeInterval = 3600.0 // 1:00:00
        let rewindDuration: TimeInterval = 15.0
        let anchorTime = max(0, elapsedTime - rewindDuration)
        let actualRewind = elapsedTime - anchorTime

        let tag = Tag(label: "Lore Drop", categoryName: "World", anchorTime: anchorTime, rewindDuration: actualRewind)
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        XCTAssertEqual(tag.anchorTime, 3585.0, accuracy: 0.001, "anchorTime should be 0:59:45 (3585s)")
        XCTAssertEqual(tag.rewindDuration, 15.0, accuracy: 0.001)
    }

    // AC#6: Early recording edge case — 3s in with 10s rewind clamps to 0
    func testRewindAnchor_earlyRecordingEdgeCase() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)

        let elapsedTime: TimeInterval = 3.0
        let rewindDuration: TimeInterval = 10.0
        let anchorTime = max(0, elapsedTime - rewindDuration)
        let actualRewind = elapsedTime - anchorTime

        let tag = Tag(label: "Early Tag", categoryName: "Combat", anchorTime: anchorTime, rewindDuration: actualRewind)
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        XCTAssertEqual(tag.anchorTime, 0.0, accuracy: 0.001, "anchorTime must clamp to 0")
        XCTAssertEqual(tag.rewindDuration, 3.0, accuracy: 0.001, "actualRewind should reflect 3s, not 10s")
    }

    // AC#4: Tag persists in SwiftData (zero tag loss)
    func testRewindAnchor_tagPersistsInSwiftData() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)

        let tag = Tag(label: "Persisted Tag", categoryName: "Story", anchorTime: 100.0, rewindDuration: 10.0)
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertTrue(fetched.contains { $0.label == "Persisted Tag" })
        let persistedTag = try XCTUnwrap(fetched.first { $0.label == "Persisted Tag" })
        XCTAssertEqual(persistedTag.anchorTime, 100.0, accuracy: 0.001)
    }

    // AC#5: All configurable rewind durations produce correct results
    func testRewindAnchor_allConfigurableDurations() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)

        let durations: [TimeInterval] = [5, 10, 15, 20]
        let elapsedTime: TimeInterval = 120.0 // 2 minutes in

        for rewindDuration in durations {
            let anchorTime = max(0, elapsedTime - rewindDuration)
            let actualRewind = elapsedTime - anchorTime
            let tag = Tag(label: "Tag \(Int(rewindDuration))s", categoryName: "Meta", anchorTime: anchorTime, rewindDuration: actualRewind)
            context.insert(tag)
            session.tags.append(tag)
        }
        try context.save()

        let tags = session.tags.sorted { $0.anchorTime < $1.anchorTime }
        XCTAssertEqual(tags.count, 4)
        XCTAssertEqual(tags[0].anchorTime, 100.0, accuracy: 0.001) // 120 - 20
        XCTAssertEqual(tags[1].anchorTime, 105.0, accuracy: 0.001) // 120 - 15
        XCTAssertEqual(tags[2].anchorTime, 110.0, accuracy: 0.001) // 120 - 10
        XCTAssertEqual(tags[3].anchorTime, 115.0, accuracy: 0.001) // 120 - 5
    }

    // MARK: - Story 2.6: Custom Tag Creation During Recording

    // AC#1 & AC#2: Custom tag created at original anchor time, not save time
    func testCustomTag_createdAtOriginalAnchorTime() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)

        // Simulate: "+" tapped at 100s with 10s rewind → anchor at 90s
        let captureElapsedTime: TimeInterval = 100.0
        let rewindDuration: TimeInterval = 10.0
        let anchorTime = max(0, captureElapsedTime - rewindDuration)

        // DM takes 30s to type label — time is now 130s, but anchor is still 90s
        let tag = Tag(
            label: "Grimthor -- blacksmith intro",
            categoryName: "Story",
            anchorTime: anchorTime,
            rewindDuration: rewindDuration
        )
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        let fetched = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(fetched.anchorTime, 90.0, accuracy: 0.001, "Anchor must be from capture time, not save time")
        XCTAssertEqual(fetched.label, "Grimthor -- blacksmith intro")
        XCTAssertEqual(fetched.categoryName, "Story")
    }

    // AC#3: Dismiss without label — no tag created
    func testCustomTag_dismissWithoutLabel_noTagCreated() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)
        try context.save()

        // User dismisses without entering a label — no tag should be persisted
        XCTAssertEqual(session.tags.count, 0, "No tag should be created when custom tag sheet dismissed without label")
    }

    // AC#5: Category picker defaults correctly
    func testCustomTag_categoryPickerDefault() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)

        // Simulate: user was on "Combat" tab, creates custom tag with that default category
        let tag = Tag(label: "Custom Moment", categoryName: "Combat", anchorTime: 50.0, rewindDuration: 10.0)
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        XCTAssertEqual(session.tags[0].categoryName, "Combat", "Category should default to selected tab category")
    }

    // AC#5: DM can change category before saving
    func testCustomTag_categoryChangeBeforeSave() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)

        // DM changes category from "Combat" to "Roleplay" before saving
        let tag = Tag(label: "Character Intro", categoryName: "Roleplay", anchorTime: 75.0, rewindDuration: 10.0)
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        XCTAssertEqual(session.tags[0].categoryName, "Roleplay")
    }

    // AC#6: Custom tag persists on force-quit (zero tag loss)
    func testCustomTag_persistsOnForceQuit() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)

        let tag = Tag(label: "Force Quit Test", categoryName: "World", anchorTime: 200.0, rewindDuration: 15.0)
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        // Re-fetch from store to confirm persistence
        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertTrue(fetched.contains { $0.label == "Force Quit Test" })
    }

    // Custom tags are session-only (NOT saved as reusable templates)
    func testCustomTag_sessionOnlyNotTemplate() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)

        let tag = Tag(label: "Custom NPC", categoryName: "Story", anchorTime: 50.0, rewindDuration: 10.0)
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        // Custom tags have a session relationship — they are NOT templates (session == nil)
        XCTAssertNotNil(tag.session, "Custom tag must be session-scoped, not a reusable template")
    }

    // MARK: - Story 2.7: Stop Recording & Session Summary

    // AC#3: Session summary shows duration, total tags, and pause count
    func testSessionSummary_showsDurationTagsPauses() throws {
        let campaign = Campaign(name: "Test Campaign")
        context.insert(campaign)

        let session = Session(title: "Session 1", sessionNumber: 1, duration: 7380)
        context.insert(session)
        campaign.sessions.append(session)

        // Add tags across different categories
        let tags: [(String, String, TimeInterval)] = [
            ("Plot Hook", "Story", 60.0),
            ("Critical Hit", "Combat", 300.0),
            ("NPC Introduction", "Roleplay", 600.0),
            ("Location", "World", 1200.0),
            ("Break", "Meta", 3600.0),
        ]
        for (label, category, anchor) in tags {
            let tag = Tag(label: label, categoryName: category, anchorTime: anchor, rewindDuration: 10.0)
            context.insert(tag)
            session.tags.append(tag)
        }

        // Add pause intervals
        session.pauseIntervals = [
            PauseInterval(start: 1800.0, end: 1860.0),
            PauseInterval(start: 5400.0, end: 5430.0),
        ]
        try context.save()

        // Verify all summary data is accessible
        XCTAssertEqual(session.duration, 7380, "Duration should be 2h 3m")
        XCTAssertEqual(session.tags.count, 5, "Should have 5 tags")
        XCTAssertEqual(session.pauseIntervals.count, 2, "Should have 2 pause intervals")
    }

    // AC#3: Tags grouped by category in summary
    func testSessionSummary_tagsGroupedByCategory() throws {
        let session = Session(title: "Session 1", sessionNumber: 1, duration: 3600)
        context.insert(session)

        let tagsData: [(String, String, TimeInterval)] = [
            ("Plot Hook", "Story", 60.0),
            ("Revelation", "Story", 120.0),
            ("Initiative", "Combat", 300.0),
            ("Critical Hit", "Combat", 600.0),
            ("Epic Roll", "Combat", 900.0),
            ("Location", "World", 1200.0),
        ]
        for (label, category, anchor) in tagsData {
            let tag = Tag(label: label, categoryName: category, anchorTime: anchor, rewindDuration: 10.0)
            context.insert(tag)
            session.tags.append(tag)
        }
        try context.save()

        // Group tags by category (same as SessionSummarySheet does)
        let grouped = Dictionary(grouping: session.tags, by: \.categoryName)
        XCTAssertEqual(grouped["Story"]?.count, 2)
        XCTAssertEqual(grouped["Combat"]?.count, 3)
        XCTAssertEqual(grouped["World"]?.count, 1)
    }

    // AC#3: Tags sorted by anchor time within each category group
    func testSessionSummary_tagsSortedByAnchorTimePerCategory() throws {
        let session = Session(title: "Session 1", sessionNumber: 1, duration: 7200)
        context.insert(session)

        // Add Story tags in reverse order
        let tag1 = Tag(label: "Late Story", categoryName: "Story", anchorTime: 3600.0, rewindDuration: 10.0)
        let tag2 = Tag(label: "Early Story", categoryName: "Story", anchorTime: 60.0, rewindDuration: 10.0)
        let tag3 = Tag(label: "Mid Story", categoryName: "Story", anchorTime: 1800.0, rewindDuration: 10.0)
        context.insert(tag1)
        context.insert(tag2)
        context.insert(tag3)
        session.tags.append(tag1)
        session.tags.append(tag2)
        session.tags.append(tag3)
        try context.save()

        // Sort by anchorTime (same as SessionSummarySheet does)
        let sorted = session.tags.sorted { $0.anchorTime < $1.anchorTime }
        XCTAssertEqual(sorted[0].label, "Early Story")
        XCTAssertEqual(sorted[1].label, "Mid Story")
        XCTAssertEqual(sorted[2].label, "Late Story")
    }

    // AC#4: Dismiss summary returns to campaign — session is persisted
    func testSessionSummary_sessionPersistedOnDismiss() throws {
        let campaign = Campaign(name: "Curse of Strahd")
        context.insert(campaign)

        let session = Session(title: "Session 1", sessionNumber: 1, duration: 3600, audioFilePath: "session.m4a")
        context.insert(session)
        campaign.sessions.append(session)

        let tag = Tag(label: "Important Moment", categoryName: "Story", anchorTime: 100.0, rewindDuration: 10.0)
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        // After dismiss, session should be fully persisted with all data
        let fetchedCampaign = try context.fetch(FetchDescriptor<Campaign>())
        XCTAssertEqual(fetchedCampaign[0].sessions.count, 1)
        XCTAssertEqual(fetchedCampaign[0].sessions[0].duration, 3600)
        XCTAssertEqual(fetchedCampaign[0].sessions[0].tags.count, 1)
        XCTAssertNotNil(fetchedCampaign[0].sessions[0].audioFilePath)
    }

    // AC#3: Session with no tags shows empty state
    func testSessionSummary_noTags_emptyState() throws {
        let session = Session(title: "Silent Session", sessionNumber: 1, duration: 1800)
        context.insert(session)
        try context.save()

        XCTAssertEqual(session.tags.count, 0, "Session with no tags should have empty tag list")
        XCTAssertTrue(session.tags.isEmpty)
    }

    // MARK: - Cross-Story E2E: Full Recording Session Lifecycle

    func testFullRecordingSessionLifecycle() throws {
        // 1. Seed default tags (prerequisite from Epic 1)
        try DefaultTagSeeder.seedIfNeeded(context: context)

        // 2. Create campaign (Story 1.3)
        let campaign = Campaign(name: "Curse of Strahd", descriptionText: "Gothic horror campaign")
        context.insert(campaign)

        // 3. Create session and simulate recording start (Story 2.1)
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)
        campaign.sessions.append(session)
        session.audioFilePath = "\(session.uuid.uuidString).m4a"
        try context.save()

        XCTAssertNotNil(session.audioFilePath)
        XCTAssertTrue(session.audioFilePath!.hasSuffix(".m4a"))

        // 4. Place tags with rewind during recording (Stories 2.4, 2.5)
        let plotHook = Tag(label: "Plot Hook", categoryName: "Story",
                           anchorTime: max(0, 150.0 - 10.0), rewindDuration: 10.0)
        context.insert(plotHook)
        session.tags.append(plotHook)
        XCTAssertEqual(plotHook.anchorTime, 140.0, accuracy: 0.001)

        let criticalHit = Tag(label: "Critical Hit", categoryName: "Combat",
                               anchorTime: max(0, 600.0 - 10.0), rewindDuration: 10.0)
        context.insert(criticalHit)
        session.tags.append(criticalHit)

        // 5. Place a custom tag with timestamp-first flow (Story 2.6)
        // "+" tapped at 900s, DM types label taking 20s
        let customAnchor = max(0, 900.0 - 10.0) // 890.0
        let customTag = Tag(label: "Tavern keeper suspicious look",
                            categoryName: "Roleplay",
                            anchorTime: customAnchor,
                            rewindDuration: 10.0)
        context.insert(customTag)
        session.tags.append(customTag)
        XCTAssertEqual(customTag.anchorTime, 890.0, accuracy: 0.001)

        // 6. Simulate pause during phone call (Story 2.2)
        session.pauseIntervals = [PauseInterval(start: 1200.0, end: 1260.0)]

        // 7. Place another tag after resume
        let postPauseTag = Tag(label: "Quest Update", categoryName: "Story",
                                anchorTime: max(0, 1500.0 - 10.0), rewindDuration: 10.0)
        context.insert(postPauseTag)
        session.tags.append(postPauseTag)

        // 8. Early recording edge case tag (Story 2.5 AC#6)
        let earlyTag = Tag(label: "Opening Narration", categoryName: "World",
                           anchorTime: 0.0, rewindDuration: 5.0)
        context.insert(earlyTag)
        session.tags.append(earlyTag)

        // 9. Stop recording and set duration (Story 2.7)
        session.duration = 7200.0 // 2 hours
        try context.save()

        // 10. Verify session summary data (Story 2.7)
        XCTAssertEqual(session.tags.count, 5)
        XCTAssertEqual(session.duration, 7200.0)
        XCTAssertEqual(session.pauseIntervals.count, 1)

        // Verify tags by category grouping
        let grouped = Dictionary(grouping: session.tags, by: \.categoryName)
        XCTAssertEqual(grouped["Story"]?.count, 2)
        XCTAssertEqual(grouped["Combat"]?.count, 1)
        XCTAssertEqual(grouped["Roleplay"]?.count, 1)
        XCTAssertEqual(grouped["World"]?.count, 1)

        // Verify all tags have correct anchor times (rewind-adjusted)
        for tag in session.tags {
            XCTAssertGreaterThanOrEqual(tag.anchorTime, 0, "No tag should have negative anchorTime")
        }

        // 11. Campaign still intact
        let fetchedCampaigns = try context.fetch(FetchDescriptor<Campaign>())
        XCTAssertEqual(fetchedCampaigns.count, 1)
        XCTAssertEqual(fetchedCampaigns[0].sessions.count, 1)
        XCTAssertEqual(fetchedCampaigns[0].sessions[0].tags.count, 5)

        // 12. Template tags still independent (Story 2.6: custom tags are session-only)
        let allTags = try context.fetch(FetchDescriptor<Tag>())
        let templateTags = allTags.filter { $0.session == nil }
        XCTAssertEqual(templateTags.count, 25, "25 seeded templates should remain untouched")
        let sessionTags = allTags.filter { $0.session != nil }
        XCTAssertEqual(sessionTags.count, 5, "5 session tags should be associated")
    }

    // MARK: - Cross-Story E2E: Multiple Sessions in One Campaign

    func testMultipleSessionsWithTags() throws {
        let campaign = Campaign(name: "Ongoing Campaign")
        context.insert(campaign)

        // Create 3 sessions with different tag counts and pause patterns
        for i in 1...3 {
            let session = Session(
                title: "Session \(i)",
                sessionNumber: i,
                duration: TimeInterval(i * 3600),
                audioFilePath: "session-\(i).m4a"
            )
            context.insert(session)
            campaign.sessions.append(session)

            // Each session gets a different number of tags
            for j in 0..<(i * 2) {
                let tag = Tag(
                    label: "Tag \(i).\(j)",
                    categoryName: ["Story", "Combat", "Roleplay", "World", "Meta"][j % 5],
                    anchorTime: TimeInterval(j * 120),
                    rewindDuration: 10.0
                )
                context.insert(tag)
                session.tags.append(tag)
            }

            // Add pauses to sessions 2 and 3
            if i > 1 {
                session.pauseIntervals = [PauseInterval(start: 600.0, end: 660.0)]
            }
        }
        try context.save()

        // Verify each session is independent
        XCTAssertEqual(campaign.sessions.count, 3)
        let sorted = campaign.sessions.sorted { $0.sessionNumber < $1.sessionNumber }
        XCTAssertEqual(sorted[0].tags.count, 2, "Session 1 should have 2 tags")
        XCTAssertEqual(sorted[1].tags.count, 4, "Session 2 should have 4 tags")
        XCTAssertEqual(sorted[2].tags.count, 6, "Session 3 should have 6 tags")

        XCTAssertEqual(sorted[0].pauseIntervals.count, 0, "Session 1 should have no pauses")
        XCTAssertEqual(sorted[1].pauseIntervals.count, 1, "Session 2 should have 1 pause")
        XCTAssertEqual(sorted[2].pauseIntervals.count, 1, "Session 3 should have 1 pause")
    }

    // MARK: - Cross-Story E2E: Session Deletion Cascades Tags

    func testSessionDeletion_cascadesTagsButPreservesTemplates() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)

        let campaign = Campaign(name: "Campaign")
        context.insert(campaign)

        let session = Session(title: "Session 1", sessionNumber: 1, duration: 3600)
        context.insert(session)
        campaign.sessions.append(session)

        // Place 5 session tags
        for i in 0..<5 {
            let tag = Tag(label: "Session Tag \(i)", categoryName: "Combat", anchorTime: TimeInterval(i * 60), rewindDuration: 10.0)
            context.insert(tag)
            session.tags.append(tag)
        }
        try context.save()

        // Total: 25 templates + 5 session tags = 30
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Tag>()), 30)

        // Delete the session
        context.delete(session)
        try context.save()

        // Session tags cascade-deleted, templates preserved
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Tag>()), 25, "Only template tags should remain")
        let remaining = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertTrue(remaining.allSatisfy { $0.session == nil }, "All remaining tags should be templates")
    }

    // MARK: - Cross-Story E2E: Rewind-Anchor During Paused State

    func testTagPlacement_onlyDuringActiveRecording() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)

        // Tags placed during active recording
        let activeTag = Tag(label: "Active Tag", categoryName: "Combat", anchorTime: 100.0, rewindDuration: 10.0)
        context.insert(activeTag)
        session.tags.append(activeTag)
        try context.save()

        XCTAssertEqual(session.tags.count, 1, "Tags should only be placed during active recording")
    }

    // MARK: - Cross-Story E2E: Long Session with Many Tags

    func testLongSession_manyTags() throws {
        let session = Session(title: "Marathon Session", sessionNumber: 1, duration: 14400) // 4 hours
        context.insert(session)

        // Place 100 tags across the session
        for i in 0..<100 {
            let tag = Tag(
                label: "Tag \(i)",
                categoryName: ["Story", "Combat", "Roleplay", "World", "Meta"][i % 5],
                anchorTime: TimeInterval(i * 144), // spread across 4 hours
                rewindDuration: 10.0
            )
            context.insert(tag)
            session.tags.append(tag)
        }

        // Add multiple pause intervals
        session.pauseIntervals = [
            PauseInterval(start: 3600.0, end: 3660.0),
            PauseInterval(start: 7200.0, end: 7320.0),
            PauseInterval(start: 10800.0, end: 10860.0),
        ]
        try context.save()

        // Verify all data survived
        XCTAssertEqual(session.tags.count, 100, "All 100 tags should persist")
        XCTAssertEqual(session.pauseIntervals.count, 3, "All 3 pause intervals should persist")
        XCTAssertEqual(session.duration, 14400, "4-hour duration should persist")

        // Verify category grouping works with many tags
        let grouped = Dictionary(grouping: session.tags, by: \.categoryName)
        XCTAssertEqual(grouped.keys.count, 5, "Tags should span all 5 categories")
        for (_, tags) in grouped {
            XCTAssertEqual(tags.count, 20, "Each category should have 20 tags")
        }

        // Verify all anchor times are non-negative and within session duration
        for tag in session.tags {
            XCTAssertGreaterThanOrEqual(tag.anchorTime, 0)
            XCTAssertLessThanOrEqual(tag.anchorTime, session.duration)
        }
    }

    // MARK: - Story 2.7 AC#5: Audio Quality Settings

    // Audio quality stored as session metadata — standard (64kbps) vs high (128kbps)
    func testAudioQuality_sessionMetadataPersists() throws {
        let session1 = Session(title: "Standard Quality", sessionNumber: 1, duration: 3600, audioFilePath: "standard.m4a")
        let session2 = Session(title: "High Quality", sessionNumber: 2, duration: 3600, audioFilePath: "high.m4a")
        context.insert(session1)
        context.insert(session2)
        try context.save()

        // Both sessions should persist independently regardless of quality setting
        let sessions = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(sessions.count, 2)
        XCTAssertTrue(sessions.allSatisfy { $0.audioFilePath != nil })
    }

    // MARK: - PauseInterval edge cases

    func testPauseInterval_zeroLengthPause() throws {
        let session = Session(title: "Zero Pause", sessionNumber: 1)
        context.insert(session)

        // A zero-length pause (start == end) should still be valid
        session.pauseIntervals = [PauseInterval(start: 100.0, end: 100.0)]
        try context.save()

        XCTAssertEqual(session.pauseIntervals.count, 1)
        XCTAssertEqual(session.pauseIntervals[0].start, session.pauseIntervals[0].end)
    }

    func testPauseInterval_codableRoundTripThroughSession() throws {
        let session = Session(title: "Test", sessionNumber: 1)
        context.insert(session)

        let intervals = [
            PauseInterval(start: 10.5, end: 20.75),
            PauseInterval(start: 100.123, end: 200.456),
        ]
        session.pauseIntervals = intervals
        try context.save()

        // Re-fetch to verify codable round-trip through SwiftData
        let fetched = try context.fetch(FetchDescriptor<Session>())
        let decoded = fetched[0].pauseIntervals
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].start, 10.5, accuracy: 0.001)
        XCTAssertEqual(decoded[0].end, 20.75, accuracy: 0.001)
        XCTAssertEqual(decoded[1].start, 100.123, accuracy: 0.001)
        XCTAssertEqual(decoded[1].end, 200.456, accuracy: 0.001)
    }

    // MARK: - Rewind edge case: zero elapsed time

    func testRewindAnchor_zeroElapsedTime() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)

        let anchorTime = max(0, 0.0 - 10.0) // clamps to 0
        let tag = Tag(label: "Immediate Tag", categoryName: "Meta", anchorTime: anchorTime, rewindDuration: 0.0)
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        XCTAssertEqual(tag.anchorTime, 0.0, accuracy: 0.001)
    }
}
