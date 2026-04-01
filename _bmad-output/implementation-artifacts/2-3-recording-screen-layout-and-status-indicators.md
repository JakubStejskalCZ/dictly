# Story 2.3: Recording Screen Layout & Status Indicators

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a DM,
I want to see that recording is active with a timer, waveform, and tag count,
So that I have confidence the session is being captured without needing to stare at my phone.

## Acceptance Criteria (BDD)

### Scenario 1: Active Recording Visual Indicators

Given an active recording
When the DM glances at the screen
Then a pulsing red dot with "REC", the elapsed timer, and tag count are visible at the top
And a compact live waveform shows real-time audio levels below

### Scenario 2: Paused State Visual Indicators

Given the recording is paused
When the DM views the screen
Then the dot is yellow/static with "PAUSED", the timer is frozen, and the waveform bars are gray

### Scenario 3: Reduce Motion Accessibility

Given Reduce Motion is enabled in iOS settings
When recording is active
Then the red dot is solid (no pulse), waveform updates without animation

### Scenario 4: VoiceOver Accessibility

Given VoiceOver is active
When the status bar is focused
Then it reads "Recording. [Duration]. [Count] tags placed."

## Tasks / Subtasks

- [x] Task 1: Create `RecordingScreen.swift` — main recording UI container (AC: #1, #2, #3, #4)
  - [x] 1.1 Create `RecordingScreen.swift` in `DictlyiOS/Recording/`. This is the full-screen modal presented when recording starts. Layout is a `VStack` top-to-bottom: `RecordingStatusBar`, `LiveWaveform`, placeholder for tag palette (Story 2.4), placeholder for stop bar (Story 2.7).
  - [x] 1.2 Inject `SessionRecorder` via `@Environment(SessionRecorder.self)`. Read `isRecording`, `isPaused`, `elapsedTime`, `currentAudioLevel`, `wasInterruptedBySystem` from it.
  - [x] 1.3 Accept a `Session` parameter and `ModelContext` for starting/managing the recording. On `.task`, call `sessionRecorder.startRecording(session:context:)`. On disappear or when recording stops, handle cleanup.
  - [x] 1.4 Show a system-interruption resume banner when `wasInterruptedBySystem == true && isPaused == true`: a prominent amber/warning-colored bar with "Recording Paused — Phone Call" text and a large "Resume Recording" button. Tapping calls `sessionRecorder.resumeRecording()`.
  - [x] 1.5 Show a standard pause/resume button: when recording is active (not paused), show a pause button; when paused (not system-interrupted), show a resume button. Use SF Symbols `pause.circle.fill` / `play.circle.fill`.
  - [x] 1.6 Use `DictlyColors.background` as the screen background. Apply warm dark appearance via `.preferredColorScheme(.dark)` (UX spec: recording screen auto-suggests dark mode for less table glare).
  - [x] 1.7 Add a tag count display — read `session.tags.count` (SwiftData relationship, auto-updates via `@Query` or observation). Display as a pill badge near the timer.

- [x] Task 2: Create `RecordingStatusBar.swift` — persistent header during recording (AC: #1, #2, #3, #4)
  - [x] 2.1 Create `RecordingStatusBar.swift` in `DictlyiOS/Recording/`. This is a horizontal `HStack` containing: animated dot, state label, elapsed timer, and tag count badge.
  - [x] 2.2 **Recording dot:** A filled circle (10pt diameter) using `DictlyColors.recordingActive` (`#EF4444`). When recording is active (not paused), animate with `DictlyAnimation.recordingBreath` — a 2-second ease-in-out repeating opacity/scale cycle. When paused, show a static yellow dot using `DictlyColors.warning` (`#F59E0B`).
  - [x] 2.3 **State label:** Show "REC" text next to the dot when recording. Show "PAUSED" when paused. Use `DictlyTypography.caption` with appropriate color.
  - [x] 2.4 **Elapsed timer:** Display `elapsedTime` formatted as `H:MM:SS` using `Duration` formatting or manual formatting. Use `DictlyTypography.monospacedDigits` (SF Mono) for tabular alignment. Font size should be `DictlyTypography.h1` (28pt on iOS).
  - [x] 2.5 **Tag count badge:** Pill-shaped badge showing tag count. Use `DictlyTypography.caption` with `DictlyColors.surface` background and `DictlyColors.textPrimary` text.
  - [x] 2.6 **Reduce Motion:** Use `@Environment(\.accessibilityReduceMotion)` to check Reduce Motion. When enabled, show the red dot as solid (no animation — pass `reduceMotion: true` to `DictlyAnimation.recordingBreath(reduceMotion:)` which returns `nil`).
  - [x] 2.7 **VoiceOver:** Add `.accessibilityElement(children: .combine)` on the entire status bar. Add `.accessibilityLabel("Recording. \(formattedDuration). \(tagCount) tags placed.")` when recording, or `"Paused. \(formattedDuration). \(tagCount) tags placed."` when paused. Use `.accessibilityAddTraits(.updatesFrequently)` so VoiceOver re-reads periodically.

- [x] Task 3: Create `LiveWaveform.swift` — compact real-time audio visualization (AC: #1, #2, #3)
  - [x] 3.1 Create `LiveWaveform.swift` in `DictlyiOS/Recording/`. This is a custom SwiftUI view showing a horizontal bar chart of audio levels, 48pt tall.
  - [x] 3.2 Maintain a circular buffer of audio level samples (e.g., `[Float]` with ~60 entries for ~4 seconds at 15fps). On each timer tick (~15fps), read `sessionRecorder.currentAudioLevel` and append to the buffer, shifting old values out.
  - [x] 3.3 Render bars using `Canvas` or a `GeometryReader` + `HStack` of `RoundedRectangle` shapes. Each bar's height is proportional to its audio level value (0.0–1.0 mapped to 0–48pt). Bar width: ~3pt with ~1pt gap. Recent bars (rightmost) use `DictlyColors.recordingActive`; older bars fade to `DictlyColors.textSecondary`.
  - [x] 3.4 **Paused state:** When `isPaused == true`, freeze the bar chart (stop sampling). Change all bar colors to muted gray (`DictlyColors.textSecondary.opacity(0.5)`). Optionally show a centered "PAUSED" label overlay.
  - [x] 3.5 **Reduce Motion:** When `accessibilityReduceMotion` is true, update bar values without animation (use `.animation(nil)`). Bars still update with new levels but without smooth transitions.
  - [x] 3.6 **VoiceOver:** `.accessibilityLabel("Live audio waveform. Recording is active.")` when recording, `"Recording is paused."` when paused. `.accessibilityHidden(false)`.
  - [x] 3.7 Use a `TimelineView(.periodic(every: 1.0/15.0))` or a `Timer` to drive sampling at ~15fps. Ensure the timer stops when paused to save battery.
  - [x] 3.8 Container: rounded surface using `DictlyColors.surface` background, corner radius 12pt, with `DictlySpacing.sm` padding.

- [x] Task 4: Create `RecordingViewModel.swift` — recording UI state management (AC: #1, #2)
  - [x] 4.1 Create `RecordingViewModel.swift` in `DictlyiOS/Recording/`. This is an `@Observable` class that bridges `SessionRecorder` state to UI-specific formatting and logic.
  - [x] 4.2 Computed property `formattedElapsedTime: String` — formats `sessionRecorder.elapsedTime` as `"H:MM:SS"`. Use `Duration.TimeFormatStyle` or manual formatting with `Int(elapsedTime)` → hours/minutes/seconds.
  - [x] 4.3 Computed property `recordingState: RecordingState` — an enum `{ recording, paused, systemInterrupted }` derived from `sessionRecorder.isRecording`, `isPaused`, `wasInterruptedBySystem`.
  - [x] 4.4 Method `togglePause()` — calls `pauseRecording()` or `resumeRecording()` based on current state.
  - [x] 4.5 Method `resumeFromInterruption()` — calls `sessionRecorder.resumeRecording()` for the system-interruption banner.
  - [x] 4.6 Hold a reference to the `SessionRecorder` injected from the environment. The view model should be created in `RecordingScreen` as `@State private var viewModel: RecordingViewModel`.

- [x] Task 5: Wire `RecordingScreen` presentation from `CampaignDetailScreen` (AC: #1)
  - [x] 5.1 In `CampaignDetailScreen.swift`, modify `createSession()` to present `RecordingScreen` as a `.fullScreenCover` after creating the session. Add `@State private var activeRecordingSession: Session?` to track the recording session. Set it in `createSession()`.
  - [x] 5.2 Add `.fullScreenCover(item: $activeRecordingSession)` that presents `RecordingScreen(session: session)`. Architecture mandates recording screen as full-screen modal with no back button — only Stop ends it (Story 2.7).
  - [x] 5.3 Check microphone permission before starting: use `AVAudioApplication.requestRecordPermission()` (iOS 17+). If denied, show an alert directing user to Settings. This was deferred from Story 2.1 review ([Review][Defer]).

- [x] Task 6: Update `project.yml` and verify build (AC: all)
  - [x] 6.1 No new source folders needed — all files go in existing `DictlyiOS/Recording/` which is already in `project.yml` sources.
  - [x] 6.2 Run `xcodegen generate` in `DictlyiOS/` if any project config changes.
  - [x] 6.3 Verify build: `xcodebuild -project DictlyiOS/DictlyiOS.xcodeproj -scheme DictlyiOS -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`

- [x] Task 7: Unit tests (AC: #1, #2, #3, #4)
  - [x] 7.1 Add tests in `DictlyiOS/Tests/RecordingTests/`. Test file: `RecordingViewModelTests.swift`.
  - [x] 7.2 Test `formattedElapsedTime`: verify "0:00:00" at 0, "1:30:45" at 5445, "0:05:09" at 309, etc.
  - [x] 7.3 Test `recordingState` enum derivation: verify `.recording` when `isRecording && !isPaused`, `.paused` when `isPaused && !wasInterruptedBySystem`, `.systemInterrupted` when `isPaused && wasInterruptedBySystem`.
  - [x] 7.4 Verify all existing tests still pass (139 DictlyKit + 16 DictlyiOS tests).
  - [x] 7.5 Verify `xcodebuild` succeeds for the iOS target.

## Dev Notes

### Architecture: Recording Screen as Full-Screen Modal

Per architecture.md: "Recording screen (iOS): presented as full-screen modal — no back button, only Stop". The `RecordingScreen` is shown via `.fullScreenCover` from `CampaignDetailScreen`. It consumes `SessionRecorder` from the environment — the same `@Observable @MainActor` service created in `DictlyiOSApp.swift` and injected via `.environment(sessionRecorder)`. [Source: architecture.md#Navigation, architecture.md#State-Management]

The recording screen layout follows the UX spec's chosen "Hybrid Card Grid + Waveform + Timestamp-First Interaction" direction (Directions B+D):
1. `RecordingStatusBar` — animated red dot + "REC", timer, tag count badge
2. `LiveWaveform` — 48pt compact waveform, visual heartbeat
3. Category tabs + tag grid — Story 2.4 (placeholder in this story)
4. Custom tag "+" card + "Stop Recording" bar — Stories 2.6/2.7 (placeholder)

[Source: ux-design-specification.md#Chosen-Direction, epics.md#Story-2.3]

### RecordingStatusBar Component Specification

The status bar is the persistent header during recording. From UX spec:
- **Anatomy:** Animated red dot + "REC" label, large tabular-nums timer, tag count pill badge
- **States:** Recording (dot pulses 2s cycle, timer increments) → Paused (dot stops, yellow, "PAUSED" label, timer freezes)
- **Accessibility:** VoiceOver reads "Recording. [Duration]. [Count] tags placed." Updates every 30 seconds.
- **Recording dot animation:** Use `DictlyAnimation.recordingBreath` (2-second ease-in-out repeating cycle) from `DictlyKit/Sources/DictlyTheme/Animation.swift`. Call `DictlyAnimation.recordingBreath(reduceMotion:)` with `@Environment(\.accessibilityReduceMotion)` value — returns `nil` when Reduce Motion is enabled.
- **Timer font:** `DictlyTypography.monospacedDigits` (SF Mono) for tabular alignment. Size `DictlyTypography.h1` (28pt on iOS).
- **Recording active color:** `DictlyColors.recordingActive` — `#EF4444`
- **Paused/warning color:** `DictlyColors.warning` — `#F59E0B`

[Source: ux-design-specification.md#RecordingStatusBar, ux-design-specification.md#Animation-&-Motion]

### LiveWaveform Component Specification

From UX spec:
- **Purpose:** Compact real-time waveform visualization confirming recording is active. Confidence signal, not navigation tool.
- **Anatomy:** Horizontal bar chart sampling audio levels, "LIVE" label (right-aligned, subtle), rounded surface container
- **States:** Recording active (bars animate real-time, recent bars in recording-red) → Paused (bars freeze, color shifts to muted gray, "PAUSED" label)
- **Behavior:** Samples `AVAudioEngine` audio levels at ~15fps. Scrolls left as new samples arrive. Height: 48pt.
- **Data source:** Read `sessionRecorder.currentAudioLevel` (Float, 0.0–1.0, RMS value calculated per audio buffer in `SessionRecorder`). The audio engine runs at ~93ms buffer intervals (~11fps effective). Sample at ~15fps — the value updates whenever a new buffer is processed.
- **Reduce Motion:** Bars update without animation. No smooth transitions between values.
- **VoiceOver:** "Live audio waveform. Recording is active." / "Recording is paused."

[Source: ux-design-specification.md#LiveWaveform, ux-design-specification.md#Accessibility-Strategy]

### System Interruption Resume Banner

When `wasInterruptedBySystem == true` and recording is paused, show a prominent resume banner. This is the phone call recovery UX from Journey 4:
- Banner color: `DictlyColors.warning` (`#F59E0B`) background
- Text: "Recording Paused — Phone Call" or similar
- Button: Large "Resume Recording" button — prominent, easy to tap mid-game
- Behavior: tapping resume calls `sessionRecorder.resumeRecording()` which clears `wasInterruptedBySystem`
- Do NOT auto-resume — UX spec explicitly requires user action after phone calls

[Source: ux-design-specification.md#Journey-4, prd.md#FR6, 2-2-pause-resume-and-phone-call-interruption-handling.md#Task-5]

### Microphone Permission Check

Story 2.1 review deferred microphone permission checking to this story ([Review][Defer]). Before starting recording, check permission:

```swift
// iOS 17+
let permission = AVAudioApplication.shared.recordPermission
switch permission {
case .undetermined:
    let granted = await AVAudioApplication.requestRecordPermission()
    if !granted { /* show settings alert */ }
case .denied:
    // Show alert: "Dictly needs microphone access to record sessions"
    // with "Open Settings" button → UIApplication.shared.open(settingsURL)
case .granted:
    // Proceed with recording
@unknown default:
    break
}
```

[Source: 2-1-audio-recording-engine-with-background-persistence.md#Review-Findings]

### Design Tokens Available (DictlyTheme)

All design tokens are already implemented in `DictlyKit/Sources/DictlyTheme/`:

**Colors (`DictlyColors`):**
- `.background` — adaptive warm off-white/dark
- `.surface` — adaptive soft cream/dark gray (use for waveform container, tag count badge)
- `.textPrimary` — adaptive charcoal/warm white
- `.textSecondary` — adaptive warm gray
- `.recordingActive` — `#EF4444` (red dot, active waveform bars)
- `.warning` — `#F59E0B` (paused dot, interruption banner)

**Typography (`DictlyTypography`):**
- `.h1` — 28pt Bold (timer display)
- `.caption` — 13pt Regular (state label "REC"/"PAUSED", tag count)
- `.monospacedDigits` — SF Mono for timer/timestamp alignment

**Spacing (`DictlySpacing`):**
- `.xs` (4pt), `.sm` (8pt), `.md` (16pt), `.lg` (24pt), `.xl` (32pt), `.xxl` (48pt)
- `.minTapTarget` — 48pt (pause/resume buttons)

**Animation (`DictlyAnimation`):**
- `.recordingBreath` — 2s ease-in-out repeating (dot pulse)
- `.recordingBreath(reduceMotion:)` — returns `nil` when Reduce Motion enabled
- `.tagPlacement` — 150ms ease-out (for future tag feedback)
- `.tagPlacementStartScale` — 0.95

[Source: DictlyKit/Sources/DictlyTheme/Colors.swift, Animation.swift, Typography.swift, Spacing.swift]

### What NOT to Build in This Story

- **Tag palette / category tabs** — Story 2.4 builds `TagPalette.swift`, `TagCard.swift`, `CategoryTabBar.swift`
- **Rewind-anchor tagging logic** — Story 2.5 builds `TaggingService.swift`
- **Custom tag creation** — Story 2.6 builds `CustomTagSheet.swift`
- **Stop recording confirmation + session summary** — Story 2.7
- **Haptic feedback on tag** — Story 2.4/2.5
- **Audio playback** — Mac only (Epic 4)

This story builds: **RecordingScreen layout, RecordingStatusBar, LiveWaveform, RecordingViewModel, microphone permission check, and fullScreenCover presentation**. Add placeholder areas for the tag palette and stop bar that Stories 2.4–2.7 will fill in.

### Swift 6 Strict Concurrency Notes

- `RecordingViewModel` should be `@Observable @MainActor` like `SessionRecorder`.
- `AVAudioApplication.requestRecordPermission()` is an async method — call from `.task` or `Task { @MainActor in }`.
- `TimelineView` closures run on the main thread — safe to read `sessionRecorder.currentAudioLevel`.
- All `SessionRecorder` properties are `@MainActor`-isolated — access only from MainActor context.

### Logging

Use existing `os.Logger` with subsystem `"com.dictly.ios"` and category `"recording"`:
- `.info` — "Recording screen presented for session \(sessionId)"
- `.info` — "Microphone permission granted/denied"
- `.error` — "Microphone permission denied — cannot start recording"
- `.info` — "User resumed recording from system interruption"

### File Placement

```
DictlyiOS/Recording/
├── SessionRecorder.swift           # EXISTS — no changes (state already exposed)
├── RecordingScreen.swift           # NEW — main recording UI container
├── RecordingViewModel.swift        # NEW — UI state formatting and logic
├── LiveWaveform.swift              # NEW — real-time audio level visualization
└── RecordingStatusBar.swift        # NEW — animated dot, timer, tag count

DictlyiOS/Campaigns/
└── CampaignDetailScreen.swift      # MODIFY — add fullScreenCover + mic permission
```

### Previous Story Intelligence (from Stories 2.1 and 2.2)

Key patterns and learnings to follow:
- **`SessionRecorder` is @Observable @MainActor:** Access its properties directly in SwiftUI views via `@Environment(SessionRecorder.self)`. No `@StateObject`, no `ObservableObject`. [Source: 2-1 Dev Notes]
- **`currentAudioLevel` is RMS per buffer:** Updated ~11fps (4096 frames at 44100Hz ≈ 93ms). Use as-is for waveform — no additional audio processing needed. [Source: 2-1 Implementation]
- **`isPaused` + `wasInterruptedBySystem` drive UI states:** When `isPaused && wasInterruptedBySystem` → show system interruption banner. When `isPaused && !wasInterruptedBySystem` → show standard paused state. When `!isPaused && isRecording` → show active recording. [Source: 2-2 Dev Notes]
- **Timer is wall-clock-anchored:** `elapsedTime` already accounts for `totalPauseDuration` — display it directly, no client-side adjustment needed. [Source: 2-1/2-2 Review Finding]
- **`setActive(false)` only on stop/error:** Never deactivate AVAudioSession from UI code. [Source: 2-1 Review Finding]
- **Test count:** 139 DictlyKit + 16 DictlyiOS tests currently passing. New tests must not break existing ones.
- **Conventional commits:** `feat(recording): implement recording screen layout and status indicators (story 2.3)`
- **Build cache:** If incremental build shows stale module cache, run `swift package clean`. [Source: 2-1 Debug Log]

### Git Intelligence

Recent commits follow `feat(recording):` / `fix(recording):` prefix for Epic 2 work.

Files modified in Stories 2.1/2.2 that overlap:
- `SessionRecorder.swift` — already has all state properties this story reads. No modifications needed.
- `DictlyiOSApp.swift` — already wires `SessionRecorder` into environment. No changes needed.
- `CampaignDetailScreen.swift` — will be modified to add `.fullScreenCover` presentation.

### Existing Infrastructure to Reuse

- **`SessionRecorder`** — `DictlyiOS/Recording/SessionRecorder.swift` — read `isRecording`, `isPaused`, `elapsedTime`, `currentAudioLevel`, `wasInterruptedBySystem`
- **`DictlyAnimation.recordingBreath`** — `DictlyKit/Sources/DictlyTheme/Animation.swift` — pulsing dot animation with Reduce Motion support
- **`DictlyColors.recordingActive`** — `DictlyKit/Sources/DictlyTheme/Colors.swift` — recording red color
- **`DictlyColors.warning`** — paused/interruption yellow color
- **`DictlyTypography.monospacedDigits`** — SF Mono for timer display
- **`DictlySpacing.minTapTarget`** — 48pt minimum for buttons
- **`Session.tags`** — SwiftData relationship for tag count display

### Project Structure Notes

- All new files go in `DictlyiOS/Recording/` — already listed in `project.yml` sources
- No new dependencies or frameworks needed — SwiftUI, AVFoundation (for `AVAudioApplication`), and DictlyTheme already available
- No `project.yml` changes expected unless XcodeGen needs regeneration for file discovery
- `RecordingViewModel` is iOS-only — stays in the iOS target, not DictlyKit

### References

- [Source: epics.md#Story-2.3] — AC, user story, technical requirements
- [Source: prd.md#FR5] — DM can see a visual indicator that recording is active (timer or waveform)
- [Source: prd.md#FR3] — Pause/resume recording (UI for pause state display)
- [Source: prd.md#FR12] — DM can see a running count of tags placed during the current session
- [Source: architecture.md#Navigation] — Recording screen as full-screen modal
- [Source: architecture.md#State-Management] — @Observable, @Environment for service injection
- [Source: architecture.md#Recording-Files] — RecordingScreen.swift, RecordingViewModel.swift, LiveWaveform.swift, RecordingStatusBar.swift
- [Source: architecture.md#Enforcement-Guidelines] — @Observable, no AnyView, .task modifier, DictlyError
- [Source: ux-design-specification.md#Chosen-Direction] — iOS recording screen layout (B+D hybrid)
- [Source: ux-design-specification.md#LiveWaveform] — Component spec: 48pt, ~15fps, bar chart, paused state
- [Source: ux-design-specification.md#RecordingStatusBar] — Component spec: animated dot, timer, tag count
- [Source: ux-design-specification.md#Accessibility-Strategy] — VoiceOver labels, Dynamic Type, Reduce Motion
- [Source: ux-design-specification.md#Animation-&-Motion] — Recording indicator 2s breathing glow
- [Source: ux-design-specification.md#Journey-4] — Interruption recovery: phone call pause/resume UX
- [Source: 2-1-audio-recording-engine-with-background-persistence.md] — SessionRecorder API, review findings
- [Source: 2-2-pause-resume-and-phone-call-interruption-handling.md] — Pause/resume state properties, wasInterruptedBySystem

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Task 6.2: `xcodegen generate` required after adding new files to `DictlyiOS/Recording/` — the project.yml already listed `Recording/` as a source path, but the xcodeproj must be regenerated for new files to be discovered. Ran `xcodegen generate` before final build/test run.
- RecordingViewModel tests: `SessionRecorder` is `final` so mock subclassing was not possible. Resolved by extracting `deriveState(isPaused:wasInterruptedBySystem:) -> RecordingState` and `formatDuration(_:) -> String` as `static` methods on `RecordingViewModel`, enabling direct unit testing without mocking the recorder.

### Completion Notes List

- Created `RecordingViewModel.swift` — `@Observable @MainActor` class with `formattedElapsedTime`, `recordingState`, `togglePause()`, `resumeFromInterruption()`, and static helpers `formatDuration` and `deriveState` (testable without mocking).
- Created `RecordingStatusBar.swift` — HStack with 10pt animated dot (`DictlyAnimation.recordingBreath` + `@Environment(\.accessibilityReduceMotion)` for Reduce Motion), "REC"/"PAUSED" label, 28pt monospaced timer, tag count Capsule badge. Full VoiceOver accessibility (`children: .combine`, `updatesFrequently` trait).
- Created `LiveWaveform.swift` — 60-sample circular buffer at ~15fps via `TimelineView(.animation(paused:))`. Paused: stops timer, freezes bars gray. Reduce Motion: `.animation(nil)` on bar height. VoiceOver labels provided.
- Created `RecordingScreen.swift` — full-screen modal with `DictlyColors.background`, `.preferredColorScheme(.dark)`. Microphone permission check via `AVAudioApplication.requestRecordPermission()` on `.task`, with Settings alert on denial. System-interruption banner (amber, `DictlyColors.warning`) with "Resume Recording" button. Standard pause/resume button with SF Symbols. Placeholders for Story 2.4 (tag palette) and 2.7 (stop bar).
- Modified `CampaignDetailScreen.swift` — added `@State private var activeRecordingSession: Session?`, `.fullScreenCover(item:)` presenting `RecordingScreen`, and set `activeRecordingSession = session` in `createSession()`.
- All 139 DictlyKit + 30 DictlyiOS tests pass (14 new `RecordingViewModelTests` + 16 existing `SessionRecorderTests`). Build: `BUILD SUCCEEDED`.

### File List

- `DictlyiOS/Recording/RecordingViewModel.swift` — NEW
- `DictlyiOS/Recording/RecordingScreen.swift` — NEW
- `DictlyiOS/Recording/RecordingStatusBar.swift` — NEW
- `DictlyiOS/Recording/LiveWaveform.swift` — NEW
- `DictlyiOS/Campaigns/CampaignDetailScreen.swift` — MODIFIED
- `DictlyiOS/Tests/RecordingTests/RecordingViewModelTests.swift` — NEW

### Change Log

- 2026-04-01: Implemented recording screen layout and status indicators (story 2.3). Added RecordingScreen, RecordingStatusBar, LiveWaveform, RecordingViewModel. Wired fullScreenCover presentation from CampaignDetailScreen. Added microphone permission check. 14 new unit tests added.
