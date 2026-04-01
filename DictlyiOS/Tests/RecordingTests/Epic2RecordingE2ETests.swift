import XCTest
import SwiftData
@testable import DictlyiOS
import DictlyModels
import DictlyStorage

/// End-to-end integration tests for Epic 2 recording features.
/// Tests the interaction between SessionRecorder, RecordingViewModel,
/// and TaggingService without requiring actual audio hardware.
@MainActor
final class Epic2RecordingE2ETests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var recorder: SessionRecorder!
    var viewModel: RecordingViewModel!
    var taggingService: TaggingService!
    var session: Session!
    var campaign: Campaign!

    override func setUp() async throws {
        container = try ModelContainer(
            for: Campaign.self, Session.self, Tag.self, TagCategory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext

        recorder = SessionRecorder()
        viewModel = RecordingViewModel(sessionRecorder: recorder)
        taggingService = TaggingService(sessionRecorder: recorder)

        campaign = Campaign(name: "Test Campaign")
        context.insert(campaign)
        session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)
        campaign.sessions.append(session)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        recorder = nil
        viewModel = nil
        taggingService = nil
        session = nil
        campaign = nil
    }

    // MARK: - Story 2.1: Recorder Initialization

    // AC#1: Recording starts in correct initial state
    func testRecorder_initialState() {
        XCTAssertFalse(recorder.isRecording)
        XCTAssertFalse(recorder.isPaused)
        XCTAssertEqual(recorder.elapsedTime, 0)
        XCTAssertEqual(recorder.currentAudioLevel, 0)
    }

    // AC#4: DictlyError.RecordingError cases all have localized descriptions
    func testRecordingErrors_haveDescriptions() {
        let cases: [(DictlyError.RecordingError, String)] = [
            (.audioSessionSetupFailed("detail"), "Audio session setup failed: detail"),
            (.engineStartFailed("detail"), "Failed to start recording engine: detail"),
            (.fileCreationFailed("detail"), "Failed to create recording file: detail"),
            (.diskFull, "Not enough disk space to continue recording."),
        ]
        for (error, expected) in cases {
            XCTAssertEqual(DictlyError.recording(error).errorDescription, expected)
        }
    }

    // MARK: - Story 2.2: Pause/Resume State Guards

    // AC#1: Pause is a no-op when not recording
    func testPause_noopWhenNotRecording() {
        recorder.pauseRecording()
        XCTAssertFalse(recorder.isPaused)
        XCTAssertFalse(recorder.isRecording)
    }

    // AC#2: Resume is a no-op when not recording
    func testResume_noopWhenNotRecording() {
        recorder.resumeRecording()
        XCTAssertFalse(recorder.isPaused)
        XCTAssertFalse(recorder.isRecording)
    }

    // AC#3: System interruption flag starts false
    func testSystemInterruption_initiallyFalse() {
        XCTAssertFalse(recorder.wasInterruptedBySystem)
    }

    // Story 2.2: Stop when not recording is a no-op
    func testStop_noopWhenNotRecording() {
        recorder.stopRecording()
        XCTAssertFalse(recorder.isRecording)
        XCTAssertFalse(recorder.isPaused)
        XCTAssertFalse(recorder.wasInterruptedBySystem)
    }

    // MARK: - Story 2.3: RecordingViewModel State Derivation

    // AC#1: Active recording state
    func testDeriveState_activeRecording() {
        let state = RecordingViewModel.deriveState(isPaused: false, wasInterruptedBySystem: false)
        XCTAssertEqual(state, .recording)
    }

    // AC#2: Paused state
    func testDeriveState_paused() {
        let state = RecordingViewModel.deriveState(isPaused: true, wasInterruptedBySystem: false)
        XCTAssertEqual(state, .paused)
    }

    // AC#3: System interrupted state
    func testDeriveState_systemInterrupted() {
        let state = RecordingViewModel.deriveState(isPaused: true, wasInterruptedBySystem: true)
        XCTAssertEqual(state, .systemInterrupted)
    }

    // State derivation: wasInterruptedBySystem alone (without isPaused) yields .recording
    func testDeriveState_interruptedNotPaused_yieldsRecording() {
        let state = RecordingViewModel.deriveState(isPaused: false, wasInterruptedBySystem: true)
        XCTAssertEqual(state, .recording)
    }

    // MARK: - Story 2.3: Duration Formatting

    // AC#1: Timer format H:MM:SS
    func testFormatDuration_variousTimes() {
        XCTAssertEqual(RecordingViewModel.formatDuration(0), "0:00:00")
        XCTAssertEqual(RecordingViewModel.formatDuration(59), "0:00:59")
        XCTAssertEqual(RecordingViewModel.formatDuration(60), "0:01:00")
        XCTAssertEqual(RecordingViewModel.formatDuration(3599), "0:59:59")
        XCTAssertEqual(RecordingViewModel.formatDuration(3600), "1:00:00")
        XCTAssertEqual(RecordingViewModel.formatDuration(14601), "4:03:21")
    }

    // AC#1: Negative duration clamps to zero
    func testFormatDuration_negativeClamps() {
        XCTAssertEqual(RecordingViewModel.formatDuration(-100), "0:00:00")
    }

    // AC#1: Infinity/NaN guard
    func testFormatDuration_infinityGuard() {
        XCTAssertEqual(RecordingViewModel.formatDuration(.infinity), "0:00:00")
        XCTAssertEqual(RecordingViewModel.formatDuration(.nan), "0:00:00")
    }

    // MARK: - Story 2.4: Tag Placement via TaggingService

    // AC#2: One-tap tag placement with correct properties
    func testPlaceTag_correctProperties() throws {
        recorder.elapsedTime = 150.0
        taggingService.placeTag(label: "Critical Hit", categoryName: "Combat", rewindDuration: 0, session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.label, "Critical Hit")
        XCTAssertEqual(tag.categoryName, "Combat")
        XCTAssertEqual(tag.anchorTime, 150.0, accuracy: 0.001)
        XCTAssertEqual(tag.rewindDuration, 0.0, accuracy: 0.001)
    }

    // AC#2: Tag count badge increments
    func testPlaceTag_countIncrements() {
        XCTAssertEqual(session.tags.count, 0)
        for i in 1...5 {
            taggingService.placeTag(label: "Tag \(i)", categoryName: "Story", rewindDuration: 0, session: session, context: context)
            XCTAssertEqual(session.tags.count, i)
        }
    }

    // AC#2: Rapid sequential placements all succeed
    func testPlaceTag_rapidSequential() {
        for i in 0..<20 {
            taggingService.placeTag(label: "Rapid \(i)", categoryName: "Combat", rewindDuration: 0, session: session, context: context)
        }
        XCTAssertEqual(session.tags.count, 20)
        XCTAssertEqual(Set(session.tags.map(\.label)).count, 20, "All labels should be distinct")
    }

    // AC#1: Tags filterable by category
    func testPlaceTag_filterableByCategory() {
        taggingService.placeTag(label: "A", categoryName: "Story", rewindDuration: 0, session: session, context: context)
        taggingService.placeTag(label: "B", categoryName: "Combat", rewindDuration: 0, session: session, context: context)
        taggingService.placeTag(label: "C", categoryName: "Story", rewindDuration: 0, session: session, context: context)

        let storyTags = session.tags.filter { $0.categoryName == "Story" }
        let combatTags = session.tags.filter { $0.categoryName == "Combat" }
        XCTAssertEqual(storyTags.count, 2)
        XCTAssertEqual(combatTags.count, 1)
    }

    // MARK: - Story 2.5: Rewind-Anchor Tagging

    // AC#1: Default rewind-anchor calculation
    func testRewindAnchor_default10sRewind() throws {
        recorder.elapsedTime = 9000.0 // 2:30:00
        taggingService.placeTag(label: "Test", categoryName: "Story", rewindDuration: 10, session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.anchorTime, 8990.0, accuracy: 0.001, "anchorTime should be 2:29:50")
        XCTAssertEqual(tag.rewindDuration, 10.0, accuracy: 0.001)
    }

    // AC#2: Configurable rewind durations
    func testRewindAnchor_allConfigurableDurations() throws {
        let durations: [TimeInterval] = [5, 10, 15, 20]
        recorder.elapsedTime = 120.0

        for rewind in durations {
            taggingService.placeTag(label: "Tag \(Int(rewind))s", categoryName: "Meta", rewindDuration: rewind, session: session, context: context)
        }

        XCTAssertEqual(session.tags.count, 4)
        let sorted = session.tags.sorted { $0.anchorTime < $1.anchorTime }
        XCTAssertEqual(sorted[0].anchorTime, 100.0, accuracy: 0.001) // 120-20
        XCTAssertEqual(sorted[1].anchorTime, 105.0, accuracy: 0.001) // 120-15
        XCTAssertEqual(sorted[2].anchorTime, 110.0, accuracy: 0.001) // 120-10
        XCTAssertEqual(sorted[3].anchorTime, 115.0, accuracy: 0.001) // 120-5
    }

    // AC#6: Early recording edge case — clamp to 0
    func testRewindAnchor_earlyRecordingClamp() throws {
        recorder.elapsedTime = 3.0
        taggingService.placeTag(label: "Early", categoryName: "Combat", rewindDuration: 10, session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.anchorTime, 0.0, accuracy: 0.001, "anchorTime must clamp to 0")
        XCTAssertEqual(tag.rewindDuration, 3.0, accuracy: 0.001, "actualRewind should be 3s")
    }

    // Negative rewind duration clamped to 0
    func testRewindAnchor_negativeRewindClamped() throws {
        recorder.elapsedTime = 50.0
        taggingService.placeTag(label: "Negative", categoryName: "Meta", rewindDuration: -10, session: session, context: context)

        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.anchorTime, 50.0, accuracy: 0.001, "Negative rewind should yield anchor == elapsed")
        XCTAssertEqual(tag.rewindDuration, 0.0, accuracy: 0.001)
    }

    // MARK: - Story 2.6: Custom Tag Creation

    // AC#1: Capture anchor stores correct time
    func testCaptureAnchor_storesCorrectTime() throws {
        recorder.elapsedTime = 120.0
        taggingService.captureAnchor(rewindDuration: 10.0)

        let success = taggingService.placeTagWithCapturedAnchor(
            label: "Custom", categoryName: "Combat", session: session, context: context
        )
        XCTAssertTrue(success)
        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.anchorTime, 110.0, accuracy: 0.001)
    }

    // AC#2: Custom tag uses original anchor time, not current time
    func testCustomTag_usesOriginalAnchorNotCurrentTime() throws {
        recorder.elapsedTime = 100.0
        taggingService.captureAnchor(rewindDuration: 10.0)

        // Simulate 30s of typing
        recorder.elapsedTime = 130.0

        let success = taggingService.placeTagWithCapturedAnchor(
            label: "Late Entry", categoryName: "Story", session: session, context: context
        )
        XCTAssertTrue(success)
        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.anchorTime, 90.0, accuracy: 0.001, "Must use capture-time anchor, not current time")
    }

    // AC#3: Dismiss without label — discard clears anchor
    func testCustomTag_discardClearsAnchor() {
        recorder.elapsedTime = 50.0
        taggingService.captureAnchor(rewindDuration: 5.0)
        taggingService.discardCapturedAnchor()

        let result = taggingService.placeTagWithCapturedAnchor(
            label: "Should Fail", categoryName: "Meta", session: session, context: context
        )
        XCTAssertFalse(result)
        XCTAssertEqual(session.tags.count, 0)
    }

    // AC#3: Anchor cleared after use
    func testCustomTag_anchorClearedAfterUse() {
        recorder.elapsedTime = 60.0
        taggingService.captureAnchor(rewindDuration: 5.0)

        let first = taggingService.placeTagWithCapturedAnchor(
            label: "First", categoryName: "Combat", session: session, context: context
        )
        XCTAssertTrue(first)

        let second = taggingService.placeTagWithCapturedAnchor(
            label: "Second", categoryName: "Combat", session: session, context: context
        )
        XCTAssertFalse(second)
        XCTAssertEqual(session.tags.count, 1, "Only first tag should exist")
    }

    // AC#1: Without prior capture, placeTagWithCapturedAnchor fails
    func testCustomTag_withoutCapture_fails() {
        let result = taggingService.placeTagWithCapturedAnchor(
            label: "No Anchor", categoryName: "Story", session: session, context: context
        )
        XCTAssertFalse(result)
        XCTAssertEqual(session.tags.count, 0)
    }

    // AC#1: Early recording edge case with custom tag
    func testCustomTag_earlyRecordingClamp() throws {
        recorder.elapsedTime = 3.0
        taggingService.captureAnchor(rewindDuration: 10.0)

        let success = taggingService.placeTagWithCapturedAnchor(
            label: "Early Custom", categoryName: "Combat", session: session, context: context
        )
        XCTAssertTrue(success)
        let tag = try XCTUnwrap(session.tags.first)
        XCTAssertEqual(tag.anchorTime, 0.0, accuracy: 0.001)
        XCTAssertEqual(tag.rewindDuration, 3.0, accuracy: 0.001)
    }

    // MARK: - Story 2.7: Stop Recording

    // AC#2: Cancel keeps recording — stop when not recording is safe
    func testStopRecording_safeTwice() {
        recorder.stopRecording()
        recorder.stopRecording()
        XCTAssertFalse(recorder.isRecording)
    }

    // AC#3: ViewModel sets didStopRecording flag
    func testStopRecording_viewModelSetsFlag() {
        XCTAssertFalse(viewModel.didStopRecording)
        viewModel.stopRecording()
        XCTAssertTrue(viewModel.didStopRecording)
    }

    // AC#3: ViewModel isRecording mirrors recorder state
    func testViewModel_isRecording_mirrorsRecorder() {
        XCTAssertEqual(viewModel.isRecording, recorder.isRecording)
        XCTAssertFalse(viewModel.isRecording)
    }

    // AC#5: Audio quality bitrate mapping
    func testAudioQuality_bitrateMapping() {
        XCTAssertEqual(SessionRecorder.bitrate(for: "standard"), 64_000)
        XCTAssertEqual(SessionRecorder.bitrate(for: "high"), 128_000)
        XCTAssertEqual(SessionRecorder.bitrate(for: ""), 64_000, "Empty string defaults to standard")
        XCTAssertEqual(SessionRecorder.bitrate(for: "ultra"), 64_000, "Unknown value defaults to standard")
    }

    // MARK: - Cross-Story E2E: Full Recording Flow (No Audio Hardware)

    func testFullRecordingFlow_modelIntegration() throws {
        // 1. Simulate recording start — set state as startRecording would
        recorder.elapsedTime = 0

        // 2. Place tags during "recording" with rewind (Stories 2.4, 2.5)
        recorder.elapsedTime = 60.0
        taggingService.placeTag(label: "Opening", categoryName: "Story", rewindDuration: 10, session: session, context: context)

        recorder.elapsedTime = 300.0
        taggingService.placeTag(label: "First Combat", categoryName: "Combat", rewindDuration: 10, session: session, context: context)

        // 3. Simulate pause (Story 2.2) — verify viewModel state
        // (Can't actually pause without real engine, but test state derivation)
        let pausedState = RecordingViewModel.deriveState(isPaused: true, wasInterruptedBySystem: false)
        XCTAssertEqual(pausedState, .paused)

        // 4. Simulate system interruption (Story 2.2)
        let interruptedState = RecordingViewModel.deriveState(isPaused: true, wasInterruptedBySystem: true)
        XCTAssertEqual(interruptedState, .systemInterrupted)

        // 5. Place custom tag with timestamp-first (Story 2.6)
        recorder.elapsedTime = 600.0
        taggingService.captureAnchor(rewindDuration: 10.0)

        recorder.elapsedTime = 620.0 // DM typed for 20s
        taggingService.placeTagWithCapturedAnchor(
            label: "NPC Reveal", categoryName: "Roleplay", session: session, context: context
        )

        // 6. Place tag at early recording time to test clamp (Story 2.5 AC#6)
        recorder.elapsedTime = 2.0
        taggingService.placeTag(label: "Very Early", categoryName: "Meta", rewindDuration: 10, session: session, context: context)

        // 7. Simulate stop recording (Story 2.7)
        viewModel.stopRecording()
        XCTAssertTrue(viewModel.didStopRecording)

        // 8. Set session summary data
        session.duration = 1800.0
        session.pauseIntervals = [PauseInterval(start: 400.0, end: 450.0)]
        try context.save()

        // 9. Verify session summary (Story 2.7)
        XCTAssertEqual(session.tags.count, 4)
        XCTAssertEqual(session.duration, 1800.0)
        XCTAssertEqual(session.pauseIntervals.count, 1)

        // Verify tag anchor times
        let tagsByLabel = Dictionary(uniqueKeysWithValues: session.tags.map { ($0.label, $0) })
        let openingTag = try XCTUnwrap(tagsByLabel["Opening"])
        XCTAssertEqual(openingTag.anchorTime, 50.0, accuracy: 0.001) // 60-10
        let combatTag = try XCTUnwrap(tagsByLabel["First Combat"])
        XCTAssertEqual(combatTag.anchorTime, 290.0, accuracy: 0.001) // 300-10
        let npcTag = try XCTUnwrap(tagsByLabel["NPC Reveal"])
        XCTAssertEqual(npcTag.anchorTime, 590.0, accuracy: 0.001) // 600-10 (captured at 600)
        let earlyTag = try XCTUnwrap(tagsByLabel["Very Early"])
        XCTAssertEqual(earlyTag.anchorTime, 0.0, accuracy: 0.001) // clamped

        // Category grouping for summary
        let grouped = Dictionary(grouping: session.tags, by: \.categoryName)
        XCTAssertEqual(grouped.keys.count, 4, "4 categories used")
    }

    // MARK: - Cross-Story: ViewModel togglePause cycles

    func testTogglePause_stateDerivation() {
        // Without actual recording, togglePause has guards.
        // Test that state derivation works correctly for all toggle scenarios.
        let states: [(Bool, Bool, RecordingState)] = [
            (false, false, .recording),
            (true, false, .paused),
            (true, true, .systemInterrupted),
            (false, true, .recording), // not paused overrides interrupted
        ]
        for (isPaused, wasInterrupted, expected) in states {
            XCTAssertEqual(
                RecordingViewModel.deriveState(isPaused: isPaused, wasInterruptedBySystem: wasInterrupted),
                expected
            )
        }
    }

    // MARK: - Cross-Story: PauseInterval Codable through Session

    func testPauseIntervals_codableIntegrity() throws {
        let intervals = [
            PauseInterval(start: 10.0, end: 20.0),
            PauseInterval(start: 50.0, end: 60.0),
            PauseInterval(start: 100.0, end: 110.0),
        ]
        session.pauseIntervals = intervals
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        let decoded = fetched[0].pauseIntervals
        XCTAssertEqual(decoded.count, 3)
        for (original, decoded) in zip(intervals, decoded) {
            XCTAssertEqual(original.start, decoded.start, accuracy: 0.001)
            XCTAssertEqual(original.end, decoded.end, accuracy: 0.001)
        }
    }
}
