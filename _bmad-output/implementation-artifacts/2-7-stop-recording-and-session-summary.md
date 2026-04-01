# Story 2.7: Stop Recording & Session Summary

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a DM,
I want to stop the recording with a confirmation and see a session summary,
So that I know the session was captured completely before putting my phone away.

## Acceptance Criteria (BDD)

### Scenario 1: Stop Recording Confirmation Dialog

Given an active recording
When the DM taps "Stop Recording"
Then a confirmation dialog appears: "End session?"

### Scenario 2: Cancel Keeps Recording

Given the stop confirmation dialog
When the DM taps "Cancel"
Then recording continues uninterrupted

### Scenario 3: Confirm Stops Recording and Shows Summary

Given the stop confirmation dialog
When the DM confirms
Then recording stops and a session summary is displayed showing duration, total tags, and a tag list grouped by category

### Scenario 4: Dismiss Summary Returns to Campaign

Given the session summary
When the DM dismisses it
Then the session is saved and the DM returns to the campaign detail screen

### Scenario 5: Audio Quality Settings (FR48)

Given iOS Settings
When the DM adjusts audio quality settings
Then the selected quality applies to future recordings

## Tasks / Subtasks

- [ ] Task 1: Add "Stop Recording" bar to RecordingScreen (AC: #1, #2)
  - [ ] 1.1 In `RecordingScreen.swift`, replace the placeholder `Color.clear.frame(height: DictlySpacing.minTapTarget)` at line 63 with a "Stop Recording" `Button`. Style per UX spec: **secondary action** — surface background with `DictlyColors.textSecondary` text, full-width, minimum 48pt height (`DictlySpacing.minTapTarget`). Use `Image(systemName: "stop.circle")` + "Stop Recording" label. Disable when `!viewModel.isRecording` (i.e., don't show stop when not recording).
  - [ ] 1.2 On tap, set `@State private var isShowingStopConfirmation = false` to `true`.
  - [ ] 1.3 Add `.confirmationDialog("End session?", isPresented: $isShowingStopConfirmation, titleVisibility: .visible)` to RecordingScreen. Two buttons: "Stop Recording" with `.destructive` role, and "Cancel" (implicit `.cancel` role). This matches the UX spec: "Stop Recording is the only action requiring confirmation (destructive)" and uses `.confirmationDialog` per UX pattern table.
  - [ ] 1.4 VoiceOver: Button reads "Stop Recording. Double-tap to end session." (accessibilityLabel + accessibilityHint).

- [ ] Task 2: Add `stopRecording()` to RecordingViewModel (AC: #2, #3)
  - [ ] 2.1 In `RecordingViewModel.swift`, add method `func stopRecording()`. This calls `recorder.stopRecording()` which already handles: finalizing pause intervals, removing notification observers, stopping AVAudioEngine, reading authoritative duration from audio file, persisting final duration to Session model, saving context, resetting state flags. No new logic needed in SessionRecorder.
  - [ ] 2.2 Add computed property `var isRecording: Bool { recorder.isRecording }` to RecordingViewModel for the stop button's disabled state.
  - [ ] 2.3 After `recorder.stopRecording()` completes, the ViewModel should set a new `@Observable` property `var didStopRecording = false` to `true`. RecordingScreen observes this to present the session summary.

- [ ] Task 3: Create `SessionSummarySheet.swift` in `DictlyiOS/Recording/` (AC: #3, #4)
  - [ ] 3.1 Create new file `DictlyiOS/Recording/SessionSummarySheet.swift`. This is the ONLY new file in this story.
  - [ ] 3.2 Define `SessionSummarySheet` as a SwiftUI `View` struct. Accept parameters: `session: Session`, `onDismiss: () -> Void`.
  - [ ] 3.3 Layout: `NavigationStack` containing a `ScrollView` with:
    - **Header section:** Session title (e.g., "Session 3"), date formatted as medium date style, campaign name if available.
    - **Stats section:** Three key metrics in a horizontal layout:
      - Duration: formatted as "Xh Ym Zs" from `session.duration` (use `Duration.TimeFormatStyle` or manual formatting matching `RecordingViewModel.formattedElapsedTime` pattern).
      - Tag count: `session.tags.count` with "tags" label.
      - Pause count: `session.pauseIntervals.count` with "pauses" label (only show if > 0).
    - **Tag list section:** Tags grouped by `categoryName`, each group has a header with category name and count, each tag shows label and formatted anchor time. Use `Dictionary(grouping: session.tags, by: \.categoryName)` sorted alphabetically. If no tags, show "No tags placed" placeholder text.
  - [ ] 3.4 Navigation toolbar: "Done" button (`.confirmationAction`) calls `onDismiss()`. Navigation title: "Session Summary", display mode `.inline`.
  - [ ] 3.5 Presentation: `.presentationDetents([.large])` for full-height sheet per UX spec ("Session summary: Full-screen sheet after stop").
  - [ ] 3.6 VoiceOver: Stats section uses `accessibilityElement(children: .combine)` so it reads as a single unit: "Duration [value]. [count] tags. [count] pauses." Tag list items read: "[label], [category], at [timestamp]."
  - [ ] 3.7 Use `DictlyColors` and `DictlySpacing` tokens for all styling. No custom colors or hardcoded values.

- [ ] Task 4: Integrate stop flow in RecordingScreen (AC: #1, #2, #3, #4)
  - [ ] 4.1 In RecordingScreen, when the confirmation dialog's "Stop Recording" action fires: call `viewModel?.stopRecording()`.
  - [ ] 4.2 Add `@State private var isShowingSessionSummary = false`. Observe `viewModel?.didStopRecording` via `.onChange(of:)` — when it becomes `true`, set `isShowingSessionSummary = true`.
  - [ ] 4.3 Add `.sheet(isPresented: $isShowingSessionSummary, onDismiss: { dismiss() })` presenting `SessionSummarySheet(session: session, onDismiss: { isShowingSessionSummary = false })`. When the sheet's onDismiss fires (either from Done button or swipe-down), the RecordingScreen's sheet `onDismiss` calls `dismiss()` to close the full-screen modal back to CampaignDetailScreen.
  - [ ] 4.4 The `session` parameter for SessionSummarySheet comes from `RecordingScreen`'s existing session binding (the Session object passed from CampaignDetailScreen via `.fullScreenCover(item:)`).
  - [ ] 4.5 Ensure TagPalette and pause/resume button are disabled after stop (when `!recorder.isRecording`). TagPalette already has `isInteractive` logic — verify it reads `recorder.isRecording`.

- [ ] Task 5: Audio quality settings (AC: #5)
  - [ ] 5.1 In `DictlyiOS/Settings/SettingsScreen.swift`, verify that audio quality settings exist and are wired to `@AppStorage`. The architecture specifies FR48 in `DictlyiOS/Settings/SettingsScreen.swift`. If audio quality picker already exists, no changes needed. If NOT yet implemented: add an `@AppStorage("audioQuality")` with options (e.g., "Standard" = 64kbps, "High" = 128kbps). Use `Picker` with `.pickerStyle(.menu)` in the settings form.
  - [ ] 5.2 In `SessionRecorder.swift`, verify that the audio quality setting is read at recording start time. If already wired (from Story 2.1), no changes. If not: read `@AppStorage("audioQuality")` value in `startRecording()` to configure the AAC encoder bitrate. This is a minor wiring task — the recorder already configures AAC encoding.
  - [ ] 5.3 If audio quality settings were NOT implemented in prior stories, add a test in `SessionRecorderTests.swift` verifying that the configured bitrate matches the setting.

- [ ] Task 6: Add tests (AC: #1, #2, #3)
  - [ ] 6.1 In `RecordingViewModelTests.swift`, add test: `testStopRecording_callsRecorderStop()` — verify that calling `viewModel.stopRecording()` calls through to the recorder's `stopRecording()`. Use the existing mock/test pattern from RecordingViewModelTests.
  - [ ] 6.2 In `RecordingViewModelTests.swift`, add test: `testStopRecording_setsDidStopRecordingTrue()` — verify that after `stopRecording()`, `viewModel.didStopRecording` is `true`.
  - [ ] 6.3 In `RecordingViewModelTests.swift`, add test: `testIsRecording_reflectsRecorderState()` — verify `viewModel.isRecording` matches `recorder.isRecording`.
  - [ ] 6.4 Verify all existing tests pass unchanged: 27 TaggingServiceTests, 14 RecordingViewModelTests, 16 SessionRecorderTests (57 total iOS tests).

- [ ] Task 7: Build verification (AC: all)
  - [ ] 7.1 Run `xcodegen generate` in `DictlyiOS/` (new file `SessionSummarySheet.swift` auto-discovered in `Recording/` source path).
  - [ ] 7.2 Run `xcodebuild` — verify `** BUILD SUCCEEDED **`.
  - [ ] 7.3 Run full test suite — verify `** TEST SUCCEEDED **`.

## Dev Notes

### Architecture: Stop Recording Flow

The stop recording flow is a 3-step interaction: tap stop → confirm → view summary → dismiss to campaign.

**Flow:**
```
DM taps "Stop Recording" bar
  → .confirmationDialog appears: "End session?"
  → DM taps "Cancel" → dialog closes, recording continues
  → DM taps "Stop Recording" (destructive)
    → RecordingViewModel.stopRecording()
      → SessionRecorder.stopRecording() [ALREADY IMPLEMENTED]
        → Finalizes pause intervals
        → Stops AVAudioEngine
        → Reads authoritative duration from audio file
        → Persists final duration + pauseIntervals to Session
        → Saves ModelContext
        → Resets all state flags
    → viewModel.didStopRecording = true
  → RecordingScreen observes didStopRecording
  → SessionSummarySheet presented as .sheet(.large)
  → DM reviews: duration, tag count, tag list by category
  → DM taps "Done" or swipes down
  → Sheet dismisses → RecordingScreen dismisses (full-screen modal)
  → CampaignDetailScreen.onDismiss fires → resets activeRecordingSession
```

**Why a confirmation dialog?** Per UX spec, "Stop Recording is the only action requiring confirmation (destructive)." Accidentally stopping a recording mid-session would lose the remaining capture opportunity. All other recording actions are instant with no confirmation.

**Why a separate summary sheet (not inline)?** Per UX spec table: "Session summary: Full-screen sheet after stop." The summary provides closure — "I captured everything that mattered" is the target emotion. It also sets up the future transfer prompt (Story 3.2) which will appear after the summary.

[Source: ux-design-specification.md#Emotional-Journey, ux-design-specification.md#Effortless-Interactions, ux-design-specification.md#Button-Hierarchy]

### What to Create vs. Modify

| File | Action | Description |
|------|--------|-------------|
| `DictlyiOS/Recording/SessionSummarySheet.swift` | **CREATE** | New full-height sheet showing session stats and tag list |
| `DictlyiOS/Recording/RecordingScreen.swift` | Modify | Replace stop placeholder with button, add confirmation dialog, add summary sheet presentation |
| `DictlyiOS/Recording/RecordingViewModel.swift` | Modify | Add `stopRecording()`, `isRecording`, `didStopRecording` |
| `DictlyiOS/Tests/RecordingTests/RecordingViewModelTests.swift` | Modify | Add 3 new tests for stop flow |
| `DictlyiOS/Settings/SettingsScreen.swift` | Modify (if needed) | Add audio quality picker if not present |

No model changes. No package changes. No `project.yml` changes (XcodeGen auto-discovers new files in `Recording/` source path).

### Current RecordingScreen Layout (key structure)

```
VStack {
  RecordingStatusBar(...)          // Animated red dot, timer, tag count
  // system interruption banner    // Conditional
  LiveWaveform(...)                // Compact waveform
  // pause/resume button           // Toggle pause
  TagPalette(...)                  // Tag grid with categories
  Color.clear.frame(height: 48)   // ← PLACEHOLDER for stop bar (line 63)
}
```

The stop bar replaces the `Color.clear` placeholder at the bottom of the VStack. It sits below the tag palette, always visible, providing a persistent "exit" affordance.

### Current RecordingViewModel Structure

```swift
@Observable @MainActor
final class RecordingViewModel {
    let recorder: SessionRecorder
    
    var formattedElapsedTime: String { ... }  // "H:MM:SS"
    var recordingState: RecordingState { ... } // .recording/.paused/.systemInterrupted
    
    func togglePause() { ... }
    func resumeFromInterruption() { ... }
    static func deriveState(...) -> RecordingState { ... }
}
```

Add: `var didStopRecording = false`, `var isRecording: Bool`, `func stopRecording()`.

### Current CampaignDetailScreen Navigation

```swift
// Line 57-61
.fullScreenCover(item: $activeRecordingSession, onDismiss: {
    // cleanup when RecordingScreen dismisses
}) {
    RecordingScreen(session: $0)
}
```

When RecordingScreen calls `dismiss()`, the `onDismiss` closure fires and nils out `activeRecordingSession`. No changes needed to CampaignDetailScreen.

### SessionRecorder.stopRecording() — Already Implemented (lines 262-330)

```swift
func stopRecording() {
    guard isRecording else { return }
    // 1. Finalize open pause interval
    // 2. Remove notification observers
    // 3. Cancel timer, set isStopping
    // 4. Stop AVAudioEngine, remove input tap
    // 5. Read authoritative duration from audio file
    // 6. Nil out engine and output file
    // 7. Deactivate audio session
    // 8. Persist final duration to Session, save context
    // 9. Reset state flags (isRecording = false, isPaused = false, etc.)
}
```

Do NOT modify this method. The ViewModel's `stopRecording()` simply calls through to it.

### Session Model Properties Available for Summary

```swift
session.title           // "Session 3"
session.duration        // TimeInterval (set by stopRecording)
session.date            // Date
session.tags            // [Tag] — access .count, group by .categoryName
session.pauseIntervals  // [PauseInterval] — decoded from JSON
session.campaign?.name  // Campaign name for display
```

All values are populated by the time the summary sheet appears (stopRecording persists everything synchronously before returning).

### Duration Formatting

Reuse the same pattern as `RecordingViewModel.formattedElapsedTime` for consistency. Extract to a shared utility if needed, or format inline in SessionSummarySheet:

```swift
let hours = Int(session.duration) / 3600
let minutes = (Int(session.duration) % 3600) / 60
let seconds = Int(session.duration) % 60
// Display: "2h 45m 12s" or "45m 12s" if < 1 hour
```

### Tag Grouping for Summary

```swift
let grouped = Dictionary(grouping: session.tags, by: \.categoryName)
    .sorted { $0.key < $1.key }  // Alphabetical by category

// Each group: (key: "Combat", value: [Tag, Tag, ...])
// Display: category header with count, then tag labels with formatted anchor times
```

### Anchor Time Formatting for Tag List

Tags store `anchorTime` as `TimeInterval` (seconds from recording start). Format as "MM:SS" or "H:MM:SS" for display:

```swift
let minutes = Int(tag.anchorTime) / 60
let seconds = Int(tag.anchorTime) % 60
// "12:34" or "1:12:34" for long sessions
```

### "+" Custom Tag Card After Stop

After `recorder.isRecording` becomes `false`, the TagPalette's `isInteractive` flag (which is derived from `recorder.isRecording`) will disable all tag cards including the "+" card. This is correct — no tags should be placeable after recording stops.

### Audio Quality Settings (AC #5)

The epics include "Given iOS Settings / When the DM adjusts audio quality settings / Then the selected quality applies to future recordings" as part of Story 2.7. This is a minor settings addition:

- `@AppStorage("audioQuality")` with values like `"standard"` (64kbps) and `"high"` (128kbps)
- Read in `SessionRecorder.startRecording()` to configure the AAC encoder
- If this was already wired in Story 2.1 (which implemented the recording engine), verify and move on

Check `SettingsScreen.swift` for existing audio quality UI before implementing. The architecture maps FR48 to `DictlyiOS/Settings/SettingsScreen.swift`.

### Edge Cases

1. **DM taps stop during pause:** The confirmation dialog still appears. `stopRecording()` handles paused state correctly (finalizes the open pause interval before stopping).
2. **DM taps stop during system interruption:** Same flow. The interruption banner and stop are independent interactions.
3. **Double-tap on stop:** `.confirmationDialog` prevents multiple presentations. Second tap is ignored while dialog is open.
4. **App force-quit before summary dismiss:** Session data is already persisted by `stopRecording()`. The summary is view-only — no data loss if skipped. On next launch, crash recovery (`recoverOrphanedRecordings()`) is not needed since recording was properly stopped.
5. **Session with zero tags:** Summary shows "No tags placed" placeholder in the tag list section. Duration and other stats still display normally.
6. **Very long session (4+ hours):** Duration formatting handles hours gracefully. Tag list may be long — ScrollView handles this.
7. **DM swipes down on summary sheet:** Treated as dismissal — same as tapping "Done". RecordingScreen dismisses, returning to CampaignDetailScreen.

### What NOT to Build in This Story

- **Transfer prompt (AirDrop)** — Story 3.2. The summary sheet is the precursor; the transfer UI will be added later.
- **Session notes / summaryNote editing** — The `Session.summaryNote` property exists but is for Mac-side editing (FR35, Mac review). This story does NOT add a text field to the summary sheet.
- **Waveform in summary** — The summary is a simple stats + tag list view, not a mini-review.
- **Delete session from summary** — Not in scope. Session management is in CampaignDetailScreen.
- **Recording screen as NavigationStack destination** — It's a `.fullScreenCover` modal, not pushed onto a navigation stack. Keep this pattern.

### Swift 6 Strict Concurrency Notes

- `RecordingViewModel` is already `@Observable @MainActor` — new properties and methods inherit `@MainActor`
- `SessionSummarySheet` is a SwiftUI View struct — `@MainActor` by default
- `SessionRecorder.stopRecording()` is `@MainActor` — called synchronously from ViewModel
- No new async work introduced

### Logging

- `stopRecording()` already logs in SessionRecorder. No additional logging needed.
- Summary sheet is view-only — no logging needed.

### Testing Strategy

Add 3 new tests to `RecordingViewModelTests.swift` in a new `// MARK: - Story 2.7: Stop recording` section. These test the new ViewModel methods using the same test patterns as existing 14 tests.

No UI tests for `SessionSummarySheet` — it's a read-only display view. Test the ViewModel bridging logic.

All 57 existing iOS tests (27 TaggingServiceTests, 14 RecordingViewModelTests, 16 SessionRecorderTests) must continue to pass unchanged.

[Source: RecordingViewModelTests.swift existing patterns]

### Previous Story Intelligence (from Story 2.6)

Key patterns and learnings from Story 2.6:
- **Sheet presentation pattern:** `.sheet(isPresented:)` with `onDismiss` callback — reuse for session summary
- **`@State` for sheet tracking:** `isShowingCustomTagSheet` pattern — reuse `isShowingSessionSummary` + `isShowingStopConfirmation`
- **CustomTagSheet used `NavigationStack > Form`** — SessionSummarySheet uses `NavigationStack > ScrollView` (display-only, not a form)
- **Build process:** Run `xcodegen generate` in `DictlyiOS/` after adding new file, then `xcodebuild`
- **Test count:** 57 iOS tests currently passing (27 TaggingServiceTests, 14 RecordingViewModelTests, 16 SessionRecorderTests)
- **Review findings from 2.6:** dismiss-with-label auto-save pattern — consider: swiping down on summary sheet should work the same as tapping Done (both dismiss cleanly)

### Git Intelligence

Recent commits follow `feat(recording):` / `fix(recording):` prefix for recording-related stories:
- `76590fe` — fix(tagging): apply review fixes for story 2.6 custom tag creation
- `eb5cf3b` — feat(tagging): implement custom tag creation during recording (story 2.6)

Use commit prefix: `feat(recording): implement stop recording with confirmation and session summary (story 2.7)`

### Project Structure Notes

- 1 new file: `DictlyiOS/Recording/SessionSummarySheet.swift` — auto-discovered by XcodeGen from `Recording/` source path in `project.yml`
- No changes to `project.yml` or `Package.swift`
- No new framework dependencies
- Possible new `@AppStorage` key: `"audioQuality"` (only if not already present from Story 2.1)

### References

- [Source: epics.md#Story-2.7] — AC, user story, stop recording requirements
- [Source: prd.md#FR1] — Recording start/stop within 1 second
- [Source: prd.md#FR5] — Visual indicator that recording is active
- [Source: prd.md#FR48] — Audio quality settings
- [Source: architecture.md#RecordingViewModel] — RecordingViewModel.swift for recording state and interruption handling
- [Source: architecture.md#RecordingScreen] — Recording screen layout: waveform, tag palette, timer
- [Source: architecture.md#FR1-FR6-Mapping] — SessionRecorder owns stop recording logic
- [Source: ux-design-specification.md#Effortless-Interactions] — Stop Recording is the only action requiring confirmation
- [Source: ux-design-specification.md#Button-Hierarchy] — Secondary action style for Stop Recording button, destructive style for confirmation
- [Source: ux-design-specification.md#Modal-Patterns] — Session summary: Full-screen sheet after stop, .confirmationDialog for stop
- [Source: ux-design-specification.md#Emotional-Journey] — End of session: "I captured everything that mattered" = tag summary + confirmation
- [Source: ux-design-specification.md#Recording-Screen-Layout] — Stop Recording bar at bottom of recording screen (item 5)
- [Source: ux-design-specification.md#UX-DR20] — Confirmation dialogs only for destructive actions (Stop Recording, Delete Tag)
- [Source: 2-6-custom-tag-creation-during-recording.md] — Previous story patterns, sheet presentation, build process

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
