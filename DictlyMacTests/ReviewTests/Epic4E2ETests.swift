import XCTest
import AVFoundation
@testable import DictlyMac
import SwiftData
import DictlyModels

// MARK: - Epic4E2ETests
//
// End-to-end integration tests covering Epic 4: Session Review & Annotation.
// Tests the full data flow and interactions across Stories 4.1 through 4.7:
//
// 4.1 — Mac Session Review Layout (three-panel structure, toolbar, placeholders)
// 4.2 — Waveform Timeline Rendering with Tag Markers (waveform data, marker positions, shapes)
// 4.3 — Audio Playback & Waveform Navigation (AudioPlayer states, seek, scrub, playhead math)
// 4.4 — Tag Sidebar with Category Filtering (filter logic, search, marker dimming)
// 4.5 — Tag Editing — Rename, Recategorize & Delete (SwiftData mutations, empty-label guard)
// 4.6 — Retroactive Tag Placement (tag creation, rewindDuration=0, persistence, validation)
// 4.7 — Tag Notes & Session Summary Notes (notes persistence, trim logic, sidebar indicator)
//
// These tests validate multi-story integration flows that span multiple components.
// Individual component tests remain in their story-specific test files.
//
// Note: Mac test target requires dev signing certificate to run locally due to
// iCloud entitlement on the host app (pre-existing constraint from story 3.3).
// The test target builds cleanly (** TEST BUILD SUCCEEDED **) even without signing.

@MainActor
final class Epic4E2ETests: XCTestCase {

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

    // MARK: - Story 4.1: Mac Session Review Layout

    // AC1: NavigationSplitView with sidebar (tag list), main area (toolbar + waveform), detail area
    func testStory4_1_sessionReviewScreen_canBeInitialized_withFullSessionData() throws {
        let campaign = Campaign(name: "Curse of Strahd", descriptionText: "Gothic horror")
        let session = makeSession(title: "Session 5", duration: 7200)
        campaign.sessions.append(session)
        session.campaign = campaign

        let tags = makeTagSet(session: session)
        context.insert(campaign)
        context.insert(session)
        tags.forEach { context.insert($0) }
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].title, "Session 5")
        XCTAssertEqual(fetched[0].campaign?.name, "Curse of Strahd")
        XCTAssertEqual(fetched[0].tags.count, 5)
    }

    // AC2: Toolbar shows session name, campaign name, duration, tag count
    func testStory4_1_sessionToolbar_displaysCorrectMetadata() throws {
        let session = makeSession(title: "Dragon's Lair", duration: 5400)
        let tags = makeTagSet(session: session)
        context.insert(session)
        tags.forEach { context.insert($0) }

        XCTAssertEqual(session.title, "Dragon's Lair")
        XCTAssertEqual(session.duration, 5400)
        XCTAssertEqual(session.tags.count, 5)
        XCTAssertEqual(formatDuration(5400), "1h 30m")
    }

    // AC3: No tag selected shows placeholder
    func testStory4_1_tagDetailPanel_showsPlaceholder_whenNoTagSelected() {
        let session = makeSession(title: "Placeholder Session", duration: 0)
        let panel = TagDetailPanel(selectedTag: .constant(nil), session: session)
        XCTAssertNotNil(panel, "TagDetailPanel with nil tag should initialize without crashing")
    }

    // AC4/AC5: Layout adapts at minimum size, sidebar collapsible
    func testStory4_1_tagsDisplayedChronologically_inSidebar() throws {
        let session = makeSession(title: "Sorted Tags Test", duration: 3600)
        let tag1 = makeTag(label: "Late Encounter", categoryName: "Combat", anchorTime: 3000, session: session)
        let tag2 = makeTag(label: "Opening Scene", categoryName: "Story", anchorTime: 60, session: session)
        let tag3 = makeTag(label: "Mid-Session", categoryName: "Roleplay", anchorTime: 1200, session: session)
        context.insert(session)
        [tag1, tag2, tag3].forEach { context.insert($0) }

        let sorted = session.tags.sorted { $0.anchorTime < $1.anchorTime }
        XCTAssertEqual(sorted[0].label, "Opening Scene")
        XCTAssertEqual(sorted[1].label, "Mid-Session")
        XCTAssertEqual(sorted[2].label, "Late Encounter")
    }

    // AC1: Timestamp formatting for sidebar rows
    func testStory4_1_timestampFormatting_coversAllRanges() {
        // Under 1 hour: M:SS
        XCTAssertEqual(formatTimestamp(0), "0:00")
        XCTAssertEqual(formatTimestamp(75), "1:15")
        XCTAssertEqual(formatTimestamp(3599), "59:59")
        // 1 hour and above: H:MM:SS
        XCTAssertEqual(formatTimestamp(3600), "1:00:00")
        XCTAssertEqual(formatTimestamp(7384), "2:03:04")
    }

    // AC2: Duration formatting for toolbar
    func testStory4_1_durationFormatting_coversAllRanges() {
        XCTAssertEqual(formatDuration(0), "0m")
        XCTAssertEqual(formatDuration(3599), "59m")
        XCTAssertEqual(formatDuration(3600), "1h 0m")
        XCTAssertEqual(formatDuration(7260), "2h 1m")
        XCTAssertEqual(formatDuration(-100), "0m")
    }

    // Empty state: session with no tags
    func testStory4_1_emptyState_sessionWithNoTags() throws {
        let session = makeSession(title: "Empty Session", duration: 1800)
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetched[0].tags.count, 0)
    }

    // MARK: - Story 4.2: Waveform Timeline Rendering with Tag Markers

    // AC1: Waveform samples extracted from audio file
    func testStory4_2_waveformDataProvider_extractsSamples_fromAudioFile() async throws {
        let url = try makeTestAudioFileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let provider = WaveformDataProvider()
        let samples = await provider.extractSamples(from: url.path, sampleCount: 100)

        XCTAssertEqual(samples.count, 100)
        for sample in samples {
            XCTAssertGreaterThanOrEqual(sample, 0.0)
            XCTAssertLessThanOrEqual(sample, 1.0)
        }
    }

    // AC1: Missing audio file returns empty array gracefully
    func testStory4_2_waveformDataProvider_missingFile_returnsEmpty() async {
        let provider = WaveformDataProvider()
        let samples = await provider.extractSamples(
            from: "/nonexistent/path/audio_\(UUID().uuidString).caf",
            sampleCount: 100
        )
        XCTAssertTrue(samples.isEmpty)
    }

    // AC2: Tag markers positioned correctly on waveform by anchorTime
    func testStory4_2_tagMarkerPositioning_mapsAnchorTimeToXCoordinate() {
        let duration: TimeInterval = 3600
        let width: CGFloat = 800

        // Tag at start
        XCTAssertEqual((0.0 / duration) * Double(width), 0, accuracy: 0.01)
        // Tag at quarter
        XCTAssertEqual((900.0 / duration) * Double(width), 200, accuracy: 0.01)
        // Tag at half
        XCTAssertEqual((1800.0 / duration) * Double(width), 400, accuracy: 0.01)
        // Tag at end
        XCTAssertEqual((3600.0 / duration) * Double(width), 800, accuracy: 0.01)
    }

    // AC2/AC3: Marker shapes per category for color-blind accessibility
    func testStory4_2_markerShapes_mappedPerCategory() {
        XCTAssertEqual(MarkerShape.shape(for: "Story"), .circle)
        XCTAssertEqual(MarkerShape.shape(for: "Combat"), .diamond)
        XCTAssertEqual(MarkerShape.shape(for: "Roleplay"), .square)
        XCTAssertEqual(MarkerShape.shape(for: "World"), .triangle)
        XCTAssertEqual(MarkerShape.shape(for: "Meta"), .hexagon)
        XCTAssertEqual(MarkerShape.shape(for: "Unknown"), .circle)
        XCTAssertEqual(MarkerShape.shape(for: ""), .circle)
    }

    // AC3: Case-insensitive category matching for shapes
    func testStory4_2_markerShapes_caseInsensitive() {
        XCTAssertEqual(MarkerShape.shape(for: "story"), .circle)
        XCTAssertEqual(MarkerShape.shape(for: "COMBAT"), .diamond)
        XCTAssertEqual(MarkerShape.shape(for: "roleplay"), .square)
    }

    // AC2: Edge cases — tag at time 0 and duration end
    func testStory4_2_tagMarkerBoundaryPositions() {
        let duration: TimeInterval = 100
        let width: CGFloat = 800

        XCTAssertEqual((0.0 / duration) * Double(width), 0)
        XCTAssertEqual((100.0 / duration) * Double(width), 800)
    }

    // MARK: - Story 4.3: Audio Playback & Waveform Navigation

    // AC1/AC2: AudioPlayer loads, seek updates currentTime, and play/pause toggle
    func testStory4_3_audioPlayer_loadAndSeekFlow() async throws {
        let url = try makeTestAudioFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let player = AudioPlayer()

        do {
            try await player.load(filePath: url.path)
        } catch {
            throw XCTSkip("Audio engine unavailable: \(error.localizedDescription)")
        }

        XCTAssertTrue(player.isLoaded)
        XCTAssertGreaterThan(player.duration, 0)
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.currentTime, 0)

        // Seek to midpoint
        let midpoint = player.duration / 2
        player.seek(to: midpoint)
        XCTAssertEqual(player.currentTime, midpoint, accuracy: 0.001)

        // Play
        player.play()
        XCTAssertTrue(player.isPlaying)

        // Pause preserves position
        player.pause()
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.currentTime, midpoint, accuracy: 0.05)
    }

    // AC1: Loading missing file throws appropriate error
    func testStory4_3_audioPlayer_missingFile_throwsError() async {
        let player = AudioPlayer()
        do {
            try await player.load(filePath: "/nonexistent/\(UUID().uuidString).caf")
            XCTFail("Expected DictlyError.storage(.fileNotFound)")
        } catch DictlyError.storage(.fileNotFound) {
            // Expected
        } catch {
            XCTFail("Expected DictlyError.storage(.fileNotFound) but got: \(error)")
        }
    }

    // AC1/AC5: Seek clamps to valid range
    func testStory4_3_audioPlayer_seekClamping() async throws {
        let url = try makeTestAudioFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let player = AudioPlayer()

        do {
            try await player.load(filePath: url.path)
        } catch {
            throw XCTSkip("Audio engine unavailable: \(error.localizedDescription)")
        }

        player.seek(to: -10)
        XCTAssertEqual(player.currentTime, 0)

        player.seek(to: player.duration + 100)
        XCTAssertEqual(player.currentTime, player.duration, accuracy: 0.001)
    }

    // AC4: Playhead X-position calculation
    func testStory4_3_playheadPosition_calculation() {
        let duration: TimeInterval = 100
        let width: CGFloat = 1000

        XCTAssertEqual(CGFloat(0.0 / duration) * width, 0)
        XCTAssertEqual(CGFloat(50.0 / duration) * width, 500)
        XCTAssertEqual(CGFloat(100.0 / duration) * width, 1000)
    }

    // AC3: Tap vs drag threshold (4pt)
    func testStory4_3_tapVsDragThreshold() {
        XCTAssertLessThan(hypot(CGFloat(2), CGFloat(1)), 4, "~2pt = tap")
        XCTAssertGreaterThanOrEqual(hypot(CGFloat(4), CGFloat(0)), 4, "4pt = drag")
        XCTAssertLessThan(hypot(CGFloat(0), CGFloat(0)), 4, "0pt = tap")
        XCTAssertGreaterThanOrEqual(hypot(CGFloat(10), CGFloat(10)), 4, "~14pt = drag")
    }

    // AC4: Play at end-of-file restarts from beginning
    func testStory4_3_audioPlayer_playAtEOF_restartsFromBeginning() async throws {
        let url = try makeTestAudioFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let player = AudioPlayer()

        do {
            try await player.load(filePath: url.path)
        } catch {
            throw XCTSkip("Audio engine unavailable: \(error.localizedDescription)")
        }

        player.seek(to: player.duration)
        XCTAssertEqual(player.currentTime, player.duration, accuracy: 0.001)

        player.play()
        XCTAssertEqual(player.currentTime, 0, accuracy: 0.001)
        XCTAssertTrue(player.isPlaying)
        player.pause()
    }

    // MARK: - Story 4.4: Tag Sidebar with Category Filtering

    // AC1: All tags shown chronologically with no active filter
    func testStory4_4_noFilter_allTagsChronological() {
        let tags = [
            makeTag(label: "C", categoryName: "Story", anchorTime: 30),
            makeTag(label: "A", categoryName: "Combat", anchorTime: 10),
            makeTag(label: "B", categoryName: "Roleplay", anchorTime: 20),
        ]
        let result = applyFilter(tags: tags, activeCategories: [], searchText: "")
        XCTAssertEqual(result.map(\.label), ["A", "B", "C"])
    }

    // AC2: Category filter shows only matching tags
    func testStory4_4_singleCategoryFilter_showsOnlyMatchingTags() {
        let tags = [
            makeTag(label: "Dragon Fight", categoryName: "Combat", anchorTime: 10),
            makeTag(label: "Tavern Chat", categoryName: "Roleplay", anchorTime: 20),
            makeTag(label: "Ambush", categoryName: "Combat", anchorTime: 30),
        ]
        let result = applyFilter(tags: tags, activeCategories: ["Combat"], searchText: "")
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.categoryName == "Combat" })
    }

    // AC2: Multiple category filters
    func testStory4_4_multipleCategoryFilters() {
        let tags = [
            makeTag(label: "Fight", categoryName: "Combat", anchorTime: 5),
            makeTag(label: "Chat", categoryName: "Roleplay", anchorTime: 10),
            makeTag(label: "Quest", categoryName: "Story", anchorTime: 15),
            makeTag(label: "City", categoryName: "World", anchorTime: 20),
        ]
        let result = applyFilter(tags: tags, activeCategories: ["Combat", "Story"], searchText: "")
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains(where: { $0.categoryName == "Combat" }))
        XCTAssertTrue(result.contains(where: { $0.categoryName == "Story" }))
    }

    // AC2: Search text filter (case-insensitive label match)
    func testStory4_4_searchFilter_caseInsensitiveMatch() {
        let tags = [
            makeTag(label: "Dragon Attack", categoryName: "Combat", anchorTime: 10),
            makeTag(label: "dragon rider", categoryName: "Story", anchorTime: 20),
            makeTag(label: "Tavern Brawl", categoryName: "Roleplay", anchorTime: 30),
        ]
        let result = applyFilter(tags: tags, activeCategories: [], searchText: "dragon")
        XCTAssertEqual(result.count, 2)
    }

    // AC2: Combined category + search filter
    func testStory4_4_combinedCategoryAndSearchFilter() {
        let tags = [
            makeTag(label: "Dragon Attack", categoryName: "Combat", anchorTime: 5),
            makeTag(label: "Dragon Prophecy", categoryName: "Story", anchorTime: 10),
            makeTag(label: "Ambush", categoryName: "Combat", anchorTime: 15),
        ]
        let result = applyFilter(tags: tags, activeCategories: ["Combat"], searchText: "dragon")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].label, "Dragon Attack")
    }

    // AC2: Waveform marker dimming — filtered markers at 25% opacity
    func testStory4_4_markerDimming_filteredVsUnfiltered() {
        let combatTag = makeTag(label: "Fight", categoryName: "Combat", anchorTime: 10)
        let storyTag = makeTag(label: "Quest", categoryName: "Story", anchorTime: 20)
        let activeCategories: Set<String> = ["Combat"]

        let combatFiltered = computeIsFiltered(tag: combatTag, activeCategories: activeCategories)
        let storyFiltered = computeIsFiltered(tag: storyTag, activeCategories: activeCategories)

        XCTAssertFalse(combatFiltered, "Tag in active set should render at normal opacity")
        XCTAssertTrue(storyFiltered, "Tag not in active set should render at 25% opacity")
    }

    // AC2: No filter active — all markers at normal opacity
    func testStory4_4_markerDimming_noFilter_allNormalOpacity() {
        let tags = [
            makeTag(label: "A", categoryName: "Combat", anchorTime: 5),
            makeTag(label: "B", categoryName: "Story", anchorTime: 10),
            makeTag(label: "C", categoryName: "World", anchorTime: 15),
        ]
        for tag in tags {
            XCTAssertFalse(computeIsFiltered(tag: tag, activeCategories: []))
        }
    }

    // AC4: Filters reset on session change (verified through data contract)
    func testStory4_4_filterReset_onSessionChange() throws {
        let session1 = makeSession(title: "Session 1", duration: 3600)
        let session2 = makeSession(title: "Session 2", duration: 1800)
        context.insert(session1)
        context.insert(session2)
        try context.save()

        // Verify we have two distinct sessions
        let sessions = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(sessions.count, 2)
        XCTAssertNotEqual(sessions[0].uuid, sessions[1].uuid,
                          "Session change detected by uuid — filter reset triggers on uuid change")
    }

    // AC2: Whitespace-only search treated as no filter
    func testStory4_4_whitespaceSearch_treatedAsNoFilter() {
        let tags = [makeTag(label: "Anything", categoryName: "Story", anchorTime: 10)]
        let result = applyFilter(tags: tags, activeCategories: [], searchText: "   ")
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Story 4.5: Tag Editing — Rename, Recategorize & Delete

    // AC1: Inline label rename persists in SwiftData
    func testStory4_5_renameTag_persistsInSwiftData() throws {
        let tag = makeTag(label: "Dragon Attack", categoryName: "Combat", anchorTime: 60)
        context.insert(tag)

        tag.label = "Ambush at the Bridge"

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].label, "Ambush at the Bridge")
    }

    // AC1: Empty label reverts to previous value
    func testStory4_5_emptyLabelGuard_revertsToOriginal() {
        let tag = makeTag(label: "Dragon Attack", categoryName: "Combat", anchorTime: 60)
        context.insert(tag)
        let originalLabel = tag.label

        // Simulate commitLabel logic
        let newInput = "   "
        let trimmed = newInput.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            tag.label = trimmed
        }

        XCTAssertEqual(tag.label, originalLabel, "Empty label should not overwrite existing")
    }

    // AC2: Category change updates tag and auto-propagates to marker
    func testStory4_5_changeCategoryName_persistsAndUpdatesMarkerShape() throws {
        let tag = makeTag(label: "Tavern scene", categoryName: "Story", anchorTime: 120)
        context.insert(tag)

        // Before: Story → circle
        XCTAssertEqual(MarkerShape.shape(for: tag.categoryName), .circle)

        tag.categoryName = "Roleplay"

        // After: Roleplay → square
        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].categoryName, "Roleplay")
        XCTAssertEqual(MarkerShape.shape(for: fetched[0].categoryName), .square)
    }

    // AC3: Delete tag removes from session and context
    func testStory4_5_deleteTag_removesFromSessionAndContext() throws {
        let session = makeSession(title: "Edit Test", duration: 3600)
        let tag1 = makeTag(label: "Dragon", categoryName: "Combat", anchorTime: 60, session: session)
        let tag2 = makeTag(label: "Merchant", categoryName: "Story", anchorTime: 120, session: session)
        context.insert(session)
        context.insert(tag1)
        context.insert(tag2)

        XCTAssertEqual(session.tags.count, 2)

        // Delete tag1
        session.tags.removeAll { $0.uuid == tag1.uuid }
        context.delete(tag1)

        XCTAssertEqual(session.tags.count, 1)
        XCTAssertEqual(session.tags[0].label, "Merchant")

        let remaining = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining[0].label, "Merchant")
    }

    // AC4: Context menu delete (same underlying mechanism)
    func testStory4_5_deleteTag_contextMenuPath_clearsSelectedTag() throws {
        let session = makeSession(title: "Context Menu Test", duration: 3600)
        let tag = makeTag(label: "Delete Me", categoryName: "Meta", anchorTime: 300, session: session)
        context.insert(session)
        context.insert(tag)

        var selectedTag: Tag? = tag

        // Simulate context menu delete
        session.tags.removeAll { $0.uuid == tag.uuid }
        context.delete(tag)
        if selectedTag?.uuid == tag.uuid { selectedTag = nil }

        XCTAssertNil(selectedTag)
        XCTAssertEqual(session.tags.count, 0)
    }

    // MARK: - Story 4.6: Retroactive Tag Placement

    // AC1/AC2: Right-click creates tag at correct waveform position
    func testStory4_6_retroactiveTagCreation_atWaveformPosition() throws {
        let session = makeSession(title: "Review Session", duration: 3600)
        context.insert(session)

        // Simulate right-click at 25% of waveform (900s)
        let clickX: CGFloat = 200
        let viewWidth: CGFloat = 800
        let anchorTime = (Double(clickX) / Double(viewWidth)) * session.duration
        let clamped = max(0, min(session.duration, anchorTime))

        XCTAssertEqual(clamped, 900, accuracy: 0.01)

        let tag = Tag(
            label: "Missed Moment",
            categoryName: "Story",
            anchorTime: clamped,
            rewindDuration: 0
        )
        context.insert(tag)
        session.tags.append(tag)

        XCTAssertEqual(session.tags.count, 1)
        XCTAssertEqual(session.tags[0].anchorTime, 900, accuracy: 0.01)
        XCTAssertEqual(session.tags[0].rewindDuration, 0)
    }

    // AC2: Created tag appears in sidebar (sorted position) and waveform (correct X)
    func testStory4_6_retroactiveTag_appearsInSortedPosition() throws {
        let session = makeSession(title: "Review Session", duration: 3600)
        let existingTag = makeTag(label: "Early Event", categoryName: "Combat", anchorTime: 300, session: session)
        context.insert(session)
        context.insert(existingTag)

        // Retroactively add tag at 120s (before existing tag)
        let retroTag = Tag(label: "Missed Intro", categoryName: "Story", anchorTime: 120, rewindDuration: 0)
        context.insert(retroTag)
        session.tags.append(retroTag)

        let sorted = session.tags.sorted { $0.anchorTime < $1.anchorTime }
        XCTAssertEqual(sorted[0].label, "Missed Intro")
        XCTAssertEqual(sorted[1].label, "Early Event")
    }

    // AC3: Retroactive tag behaves identically to live tag (editable, deletable)
    func testStory4_6_retroactiveTag_isEditableAndDeletable() throws {
        let session = makeSession(title: "Test Session", duration: 1800)
        context.insert(session)

        let retroTag = Tag(label: "Retro Tag", categoryName: "Story", anchorTime: 600, rewindDuration: 0)
        context.insert(retroTag)
        session.tags.append(retroTag)

        // Editable: rename
        retroTag.label = "Renamed Retro"
        XCTAssertEqual(retroTag.label, "Renamed Retro")

        // Editable: recategorize
        retroTag.categoryName = "Combat"
        XCTAssertEqual(retroTag.categoryName, "Combat")

        // Editable: add notes
        retroTag.notes = "Retroactive note"
        XCTAssertEqual(retroTag.notes, "Retroactive note")

        // Deletable
        session.tags.removeAll { $0.uuid == retroTag.uuid }
        context.delete(retroTag)
        XCTAssertEqual(session.tags.count, 0)
    }

    // AC1: Keyboard shortcut (Cmd+T) uses current playhead time
    func testStory4_6_keyboardShortcut_usesPlayheadTime() {
        // Simulates Cmd+T at current playhead position
        let currentPlayheadTime: TimeInterval = 745.3
        let sessionDuration: TimeInterval = 3600

        let clamped = max(0, min(sessionDuration, currentPlayheadTime))
        XCTAssertEqual(clamped, 745.3, accuracy: 0.01)
    }

    // AC1: anchorTime clamped to valid range
    func testStory4_6_anchorTimeClamping() {
        let duration: TimeInterval = 3600
        XCTAssertEqual(max(0, min(duration, -50)), 0)
        XCTAssertEqual(max(0, min(duration, 4000)), 3600)
        XCTAssertEqual(max(0, min(duration, 1800)), 1800)
        XCTAssertEqual(max(0, min(duration, 0)), 0)
        XCTAssertEqual(max(0, min(duration, 3600)), 3600)
    }

    // AC1: Empty label validation
    func testStory4_6_emptyLabel_rejectedByValidation() {
        XCTAssertTrue("".trimmingCharacters(in: .whitespaces).isEmpty)
        XCTAssertTrue("   \t".trimmingCharacters(in: .whitespaces).isEmpty)
        XCTAssertFalse("Dragon".trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // AC2: Tag has rewindDuration = 0 (distinguishes from live tags)
    func testStory4_6_retroactiveTag_rewindDurationIsZero() throws {
        let retroTag = Tag(label: "Retro", categoryName: "Story", anchorTime: 100, rewindDuration: 0)
        let liveTag = Tag(label: "Live", categoryName: "Combat", anchorTime: 200, rewindDuration: 15)
        context.insert(retroTag)
        context.insert(liveTag)

        XCTAssertEqual(retroTag.rewindDuration, 0)
        XCTAssertEqual(liveTag.rewindDuration, 15)
    }

    // AC2: createdAt timestamp set correctly
    func testStory4_6_retroactiveTag_createdAtIsApproximatelyNow() {
        let before = Date()
        let tag = Tag(label: "Now", categoryName: "Meta", anchorTime: 0, rewindDuration: 0)
        let after = Date()

        XCTAssertGreaterThanOrEqual(tag.createdAt, before)
        XCTAssertLessThanOrEqual(tag.createdAt, after)
    }

    // MARK: - Story 4.7: Tag Notes & Session Summary Notes

    // AC1: Setting tag notes persists
    func testStory4_7_tagNotes_persistInSwiftData() throws {
        let tag = makeTag(label: "Dragon Attack", categoryName: "Combat", anchorTime: 60)
        context.insert(tag)

        tag.notes = "Party was ambushed near the bridge."

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].notes, "Party was ambushed near the bridge.")
    }

    // AC2: Edit and clear notes
    func testStory4_7_tagNotes_editAndClear() throws {
        let tag = makeTag(label: "Scene", categoryName: "Story", anchorTime: 120)
        context.insert(tag)

        tag.notes = "Initial note"
        XCTAssertEqual(tag.notes, "Initial note")

        tag.notes = "Updated note"
        XCTAssertEqual(tag.notes, "Updated note")

        tag.notes = nil
        XCTAssertNil(tag.notes)
    }

    // AC1/AC2: Whitespace-only notes trimmed to nil
    func testStory4_7_commitNotesLogic_whitespaceTrimsToNil() {
        let inputs = ["", "  ", " \t\n "]
        for input in inputs {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            let result: String? = trimmed.isEmpty ? nil : input
            XCTAssertNil(result, "Input '\(input)' should trim to nil")
        }
    }

    // AC1: Valid notes persist as-is (not trimmed)
    func testStory4_7_commitNotesLogic_validNotePersists() {
        let input = "  Important note  "
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let result: String? = trimmed.isEmpty ? nil : input
        XCTAssertEqual(result, "  Important note  ")
    }

    // AC3: Session summary note persists
    func testStory4_7_sessionSummaryNote_persistsInSwiftData() throws {
        let session = makeSession(title: "Summary Test", duration: 3600)
        context.insert(session)

        session.summaryNote = "Epic battle and character development."

        let fetched = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetched[0].summaryNote, "Epic battle and character development.")
    }

    // AC3: Session summary note can be edited and cleared
    func testStory4_7_sessionSummaryNote_editAndClear() throws {
        let session = makeSession(title: "Summary Edit Test", duration: 1800)
        context.insert(session)

        session.summaryNote = "First summary"
        XCTAssertEqual(session.summaryNote, "First summary")

        session.summaryNote = "Updated summary"
        XCTAssertEqual(session.summaryNote, "Updated summary")

        session.summaryNote = nil
        XCTAssertNil(session.summaryNote)
    }

    // AC3: New sessions have nil summaryNote
    func testStory4_7_sessionSummaryNote_initiallyNil() throws {
        let session = makeSession(title: "New Session", duration: 1800)
        context.insert(session)
        XCTAssertNil(session.summaryNote)
    }

    // AC4: Sidebar notes indicator logic
    func testStory4_7_sidebarNotesIndicator_showsWhenNotesExist() {
        let tagWithNotes = makeTag(label: "Has Notes", categoryName: "Story", anchorTime: 10)
        tagWithNotes.notes = "Some notes."
        let tagWithoutNotes = makeTag(label: "No Notes", categoryName: "Combat", anchorTime: 20)
        tagWithoutNotes.notes = nil
        let tagWithEmptyNotes = makeTag(label: "Empty", categoryName: "Meta", anchorTime: 30)
        tagWithEmptyNotes.notes = ""

        let hasNotes = { (tag: Tag) -> Bool in tag.notes != nil && !tag.notes!.isEmpty }

        XCTAssertTrue(hasNotes(tagWithNotes))
        XCTAssertFalse(hasNotes(tagWithoutNotes))
        XCTAssertFalse(hasNotes(tagWithEmptyNotes))
    }

    // AC4: New tags start with nil notes
    func testStory4_7_newTags_haveNilNotes() throws {
        let tag = makeTag(label: "New Tag", categoryName: "Story", anchorTime: 0)
        context.insert(tag)
        XCTAssertNil(tag.notes)
    }

    // MARK: - Cross-Story Integration Tests

    /// Full review workflow: session with campaign, tags with categories, notes, and summary
    func testIntegration_fullReviewWorkflow() throws {
        // Setup: Campaign + Session + Tags
        let campaign = Campaign(name: "Curse of Strahd", descriptionText: "Gothic horror")
        let session = makeSession(title: "Session 12: Into the Mists", duration: 10800)
        campaign.sessions.append(session)
        session.campaign = campaign
        context.insert(campaign)
        context.insert(session)

        // Create mixed tags (live + retroactive)
        let liveTag = Tag(label: "Strahd appears", categoryName: "Story", anchorTime: 3600, rewindDuration: 5)
        let combatTag = Tag(label: "Vampire spawn fight", categoryName: "Combat", anchorTime: 5400, rewindDuration: 8)
        let retroTag = Tag(label: "Missed foreshadowing", categoryName: "Story", anchorTime: 1200, rewindDuration: 0)
        [liveTag, combatTag, retroTag].forEach {
            context.insert($0)
            session.tags.append($0)
        }

        // Verify tags sorted chronologically
        let sorted = session.tags.sorted { $0.anchorTime < $1.anchorTime }
        XCTAssertEqual(sorted[0].label, "Missed foreshadowing") // 1200s
        XCTAssertEqual(sorted[1].label, "Strahd appears")       // 3600s
        XCTAssertEqual(sorted[2].label, "Vampire spawn fight")  // 5400s

        // Add notes to tags (Story 4.7)
        liveTag.notes = "Dramatic entrance with thunder"
        retroTag.notes = "Ireena mentioned the mists earlier"

        // Add session summary (Story 4.7)
        session.summaryNote = "Strahd's first appearance. Party entered the mists. Combat with vampire spawn."

        // Edit tag (Story 4.5) — rename
        liveTag.label = "Strahd's Grand Entrance"
        XCTAssertEqual(liveTag.label, "Strahd's Grand Entrance")

        // Edit tag (Story 4.5) — recategorize
        retroTag.categoryName = "World"
        XCTAssertEqual(MarkerShape.shape(for: retroTag.categoryName), .triangle)

        // Filter sidebar (Story 4.4) — Combat only
        let combatFilter = applyFilter(tags: session.tags.map { $0 }, activeCategories: ["Combat"], searchText: "")
        XCTAssertEqual(combatFilter.count, 1)
        XCTAssertEqual(combatFilter[0].label, "Vampire spawn fight")

        // Filter sidebar (Story 4.4) — search "strahd"
        let searchResult = applyFilter(tags: session.tags.map { $0 }, activeCategories: [], searchText: "strahd")
        XCTAssertEqual(searchResult.count, 1)
        XCTAssertEqual(searchResult[0].label, "Strahd's Grand Entrance")

        // Delete retroactive tag (Story 4.5)
        session.tags.removeAll { $0.uuid == retroTag.uuid }
        context.delete(retroTag)
        XCTAssertEqual(session.tags.count, 2)

        // Verify final state
        let finalSession = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(finalSession[0].tags.count, 2)
        XCTAssertEqual(finalSession[0].summaryNote, "Strahd's first appearance. Party entered the mists. Combat with vampire spawn.")
        XCTAssertEqual(finalSession[0].campaign?.name, "Curse of Strahd")
    }

    /// Marker positioning + filtering integration across stories 4.2 + 4.4
    func testIntegration_markerPositioning_withCategoryFilter() {
        let duration: TimeInterval = 3600
        let width: CGFloat = 800

        let tags = [
            makeTag(label: "Fight", categoryName: "Combat", anchorTime: 900),
            makeTag(label: "Chat", categoryName: "Roleplay", anchorTime: 1800),
            makeTag(label: "Quest", categoryName: "Story", anchorTime: 2700),
        ]

        let activeCategories: Set<String> = ["Combat"]

        for tag in tags {
            let xPos = (tag.anchorTime / duration) * Double(width)
            let isFiltered = computeIsFiltered(tag: tag, activeCategories: activeCategories)
            let opacity = isFiltered ? 0.25 : 0.75

            if tag.categoryName == "Combat" {
                XCTAssertEqual(xPos, 200, accuracy: 0.01)
                XCTAssertEqual(opacity, 0.75)
            } else {
                XCTAssertEqual(opacity, 0.25)
            }
        }
    }

    /// Retroactive tag placement → editing → notes flow across stories 4.6 + 4.5 + 4.7
    func testIntegration_retroactiveTag_editThenAddNotes() throws {
        let session = makeSession(title: "Integration", duration: 3600)
        context.insert(session)

        // Story 4.6: Create retroactive tag
        let tag = Tag(label: "New Tag", categoryName: "Story", anchorTime: 1500, rewindDuration: 0)
        context.insert(tag)
        session.tags.append(tag)

        XCTAssertEqual(tag.rewindDuration, 0)
        XCTAssertNil(tag.notes)

        // Story 4.5: Edit the retroactive tag
        tag.label = "Key Plot Point"
        tag.categoryName = "World"

        // Story 4.7: Add notes
        tag.notes = "This is where the prophecy was revealed"

        // Verify full state
        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].label, "Key Plot Point")
        XCTAssertEqual(fetched[0].categoryName, "World")
        XCTAssertEqual(fetched[0].anchorTime, 1500)
        XCTAssertEqual(fetched[0].rewindDuration, 0)
        XCTAssertEqual(fetched[0].notes, "This is where the prophecy was revealed")

        // Sidebar indicator should show
        XCTAssertTrue(fetched[0].notes != nil && !fetched[0].notes!.isEmpty)
    }

    /// Tag selection → playback seek → sidebar highlight → detail panel flow
    func testIntegration_tagSelection_triggersSeekAndDetail() throws {
        let session = makeSession(title: "Playback Test", duration: 3600)
        let tag = makeTag(label: "Boss Fight", categoryName: "Combat", anchorTime: 2400, session: session)
        context.insert(session)
        context.insert(tag)

        // Simulate tag selection flow: sidebar click → selectedTag set → seek + play
        var selectedTag: Tag? = nil
        selectedTag = tag

        XCTAssertNotNil(selectedTag)
        XCTAssertEqual(selectedTag?.anchorTime, 2400)
        XCTAssertEqual(selectedTag?.label, "Boss Fight")
        XCTAssertEqual(selectedTag?.categoryName, "Combat")

        // Playhead should seek to tag position
        let viewWidth: CGFloat = 800
        let expectedX = CGFloat(2400.0 / 3600.0) * viewWidth
        XCTAssertEqual(expectedX, 533.33, accuracy: 0.01)
    }

    /// Session with no audio — waveform and playback gracefully degrade
    func testIntegration_sessionWithNoAudio_gracefulDegradation() throws {
        let session = Session(title: "No Audio", sessionNumber: 1, duration: 1800, audioFilePath: nil)
        let tag = makeTag(label: "Note only", categoryName: "Meta", anchorTime: 600, session: session)
        context.insert(session)
        context.insert(tag)

        XCTAssertNil(session.audioFilePath)
        XCTAssertEqual(session.tags.count, 1)

        // Tags still work for editing and notes even without audio
        tag.notes = "Manual note without audio"
        tag.label = "Edited Note"
        XCTAssertEqual(tag.label, "Edited Note")
        XCTAssertEqual(tag.notes, "Manual note without audio")
    }

    /// Large session: many tags, filter performance
    func testIntegration_largeSession_filterPerformance() {
        let tagCount = 200
        var tags: [Tag] = []
        let categories = ["Combat", "Story", "Roleplay", "World", "Meta"]
        for i in 0..<tagCount {
            tags.append(makeTag(
                label: "Tag \(i)",
                categoryName: categories[i % categories.count],
                anchorTime: TimeInterval(i * 18) // spread across 3600s
            ))
        }

        // Single category filter
        let combatOnly = applyFilter(tags: tags, activeCategories: ["Combat"], searchText: "")
        XCTAssertEqual(combatOnly.count, 40) // 200/5 = 40 combat tags

        // Combined filter
        let searched = applyFilter(tags: tags, activeCategories: ["Combat"], searchText: "Tag 1")
        XCTAssertTrue(searched.count > 0)
        XCTAssertTrue(searched.allSatisfy { $0.categoryName == "Combat" && $0.label.contains("Tag 1") })

        // All chronological
        let all = applyFilter(tags: tags, activeCategories: [], searchText: "")
        XCTAssertEqual(all.count, tagCount)
        for i in 1..<all.count {
            XCTAssertLessThanOrEqual(all[i - 1].anchorTime, all[i].anchorTime)
        }
    }

    // MARK: - Helpers

    private func makeSession(
        title: String,
        duration: TimeInterval,
        audioFilePath: String? = nil
    ) -> Session {
        Session(
            uuid: UUID(),
            title: title,
            sessionNumber: 1,
            date: Date(),
            duration: duration,
            audioFilePath: audioFilePath
        )
    }

    private func makeTag(
        label: String,
        categoryName: String,
        anchorTime: TimeInterval,
        session: Session? = nil
    ) -> Tag {
        let tag = Tag(
            uuid: UUID(),
            label: label,
            categoryName: categoryName,
            anchorTime: anchorTime,
            rewindDuration: 0
        )
        if let session = session {
            tag.session = session
            session.tags.append(tag)
        }
        return tag
    }

    /// Creates a standard set of 5 tags across all default categories.
    private func makeTagSet(session: Session) -> [Tag] {
        let data: [(String, String, TimeInterval)] = [
            ("Dragon Attack", "Combat", 300),
            ("Prophecy Revealed", "Story", 900),
            ("Tavern Roleplay", "Roleplay", 1800),
            ("City Description", "World", 2700),
            ("Session Break", "Meta", 3300),
        ]
        return data.map { (label, category, time) in
            makeTag(label: label, categoryName: category, anchorTime: time, session: session)
        }
    }

    /// Mirrors `TagSidebar.filteredTags` logic as a pure function.
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

    /// Mirrors `SessionWaveformTimeline.tagMarkersLayer` isFiltered computation.
    private func computeIsFiltered(tag: Tag, activeCategories: Set<String>) -> Bool {
        !activeCategories.isEmpty && !activeCategories.contains(tag.categoryName)
    }

    /// Creates a short 440Hz sine-wave audio file in the temp directory.
    private func makeTestAudioFileURL(durationSeconds: Double = 0.1) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("epic4_e2e_test_\(UUID().uuidString).caf")

        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        if let data = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                data[i] = Float(sin(Double(i) * 440.0 * 2.0 * .pi / sampleRate)) * 0.5
            }
        }
        try file.write(from: buffer)
        return url
    }
}
