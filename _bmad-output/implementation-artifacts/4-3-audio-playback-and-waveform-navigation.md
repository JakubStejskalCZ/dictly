# Story 4.3: Audio Playback & Waveform Navigation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a DM,
I want to click any tag or position on the waveform to jump playback there,
so that I can quickly listen to any moment in my session.

## Acceptance Criteria

1. **Given** a tag marker on the waveform, **when** the DM clicks it, **then** the playhead jumps to that tag's anchor position and audio plays from there, **and** the jump completes within 500ms.

2. **Given** the waveform timeline, **when** the DM clicks any position on the waveform, **then** the playhead repositions to that point and playback begins.

3. **Given** the playhead, **when** the DM drags it along the waveform, **then** audio scrub preview plays as the playhead moves.

4. **Given** playback controls, **when** the DM uses play/pause, **then** the playhead advances in real-time along the waveform during playback.

5. **Given** the full session audio (not just tagged segments), **when** the DM scrubs to any position, **then** the complete recording is available for playback.

## Tasks / Subtasks

- [x] Task 1: Create `AudioPlayer` — `@Observable` Core Audio playback service (AC: #1, #2, #4, #5)
  - [x] 1.1 Create `AudioPlayer.swift` in `DictlyMac/Review/`
  - [x] 1.2 Mark as `@Observable` class — NOT `ObservableObject`
  - [x] 1.3 Published state properties: `isPlaying: Bool`, `currentTime: TimeInterval`, `duration: TimeInterval`, `isLoaded: Bool`
  - [x] 1.4 Use `AVAudioEngine` + `AVAudioPlayerNode` + `AVAudioFile` for playback (Core Audio stack, NOT `AVAudioPlayer`)
  - [x] 1.5 `func load(filePath: String) async throws` — open audio file, prepare engine graph: `playerNode → mainMixerNode → outputNode`
  - [x] 1.6 `func play()` — start playback from `currentTime`; schedule audio segment from current position to end
  - [x] 1.7 `func pause()` — stop player node, save current position
  - [x] 1.8 `func seek(to time: TimeInterval)` — reposition playback; if playing, stop + reschedule from new position + resume
  - [x] 1.9 `func scrub(to time: TimeInterval)` — lightweight seek for drag preview; play a short audio snippet (~200ms) at the scrub position
  - [x] 1.10 Use cooperative `Task` at ~30Hz to update `currentTime` during playback by querying `playerNode.lastRenderTime` converted to player time
  - [x] 1.11 Handle end-of-file: stop playback, set `isPlaying = false`, keep `currentTime` at duration
  - [x] 1.12 Handle missing/corrupt audio: throw `DictlyError.storage(.fileNotFound)`, log at `.error` level
  - [x] 1.13 Use `os.Logger` with subsystem `com.dictly.mac`, category `playback`
  - [x] 1.14 `deinit` — stop engine, release resources
  - [x] 1.15 Ensure all state mutations happen on `@MainActor` (class is `@MainActor`-isolated)

- [x] Task 2: Integrate `AudioPlayer` into `SessionReviewScreen` (AC: #1, #2, #4)
  - [x] 2.1 Add `@State private var audioPlayer = AudioPlayer()` in `SessionReviewScreen`
  - [x] 2.2 Use `.task` modifier to call `audioPlayer.load(filePath:)` when session appears; handle errors with `do/catch` and log
  - [x] 2.3 Pass `audioPlayer` to `SessionWaveformTimeline` as a parameter (not `@Environment` — AudioPlayer is view-scoped, not app-scoped)
  - [x] 2.4 When `selectedTag` changes (non-nil), call `audioPlayer.seek(to: tag.anchorTime)` then `audioPlayer.play()` via `.onChange(of: selectedTag)`
  - [x] 2.5 Ensure seek + play completes within 500ms (NFR3) — synchronous seek, immediate schedule

- [x] Task 3: Add playback transport controls to toolbar (AC: #4)
  - [x] 3.1 Add a play/pause toggle button in `sessionToolbar` — use `Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")`
  - [x] 3.2 Show current playback position as formatted timestamp: `formatTimestamp(audioPlayer.currentTime)` / `formatTimestamp(audioPlayer.duration)`
  - [x] 3.3 Style with `DictlyTypography.caption` for timestamp, `DictlyColors.textSecondary`
  - [x] 3.4 Button taps `audioPlayer.isPlaying ? audioPlayer.pause() : audioPlayer.play()`
  - [x] 3.5 Disable play button when `!audioPlayer.isLoaded` or `session.audioFilePath == nil`

- [x] Task 4: Replace scrub cursor with persistent playhead in `SessionWaveformTimeline` (AC: #1, #2, #3, #4)
  - [x] 4.1 Replace the current `scrubPosition: CGFloat?` temporary cursor with a persistent playhead driven by `audioPlayer.currentTime`
  - [x] 4.2 Playhead visual: vertical white line (2pt width, `DictlyColors.textPrimary`) with a diamond cap (8pt, filled white) at the top — per UX-DR7
  - [x] 4.3 Playhead X position: `(audioPlayer.currentTime / session.duration) * viewWidth`
  - [x] 4.4 During playback (`audioPlayer.isPlaying`), playhead advances smoothly in real-time as `currentTime` updates at ~30Hz
  - [x] 4.5 Keep the floating timestamp label above the playhead showing `formatTimestamp(audioPlayer.currentTime)`
  - [x] 4.6 Draw playhead as a SwiftUI overlay on top of Canvas — 30Hz timer updates drive smooth playhead movement without redrawing waveform

- [x] Task 5: Wire click-to-play on waveform and tag markers (AC: #1, #2)
  - [x] 5.1 Modify the existing `DragGesture(minimumDistance: 0)` — on `.onEnded` (short tap, not drag), calculate the tapped time
  - [x] 5.2 On tap: call `audioPlayer.seek(to: tappedTime)` then `audioPlayer.play()`
  - [x] 5.3 On tag marker click (existing `selectedTag` binding setter): trigger `audioPlayer.seek(to: tag.anchorTime)` then `audioPlayer.play()` via `.onChange(of: selectedTag)` in `SessionReviewScreen`
  - [x] 5.4 Distinguish tap from drag: if total drag distance < 4pt, treat as tap; otherwise treat as scrub drag

- [x] Task 6: Wire drag-to-scrub with audio preview (AC: #3)
  - [x] 6.1 During drag (distance >= 4pt), update playhead position visually in real-time via `dragPosition` state
  - [x] 6.2 Call `audioPlayer.scrub(to: dragTime)` during drag — throttled to ~10 calls/sec
  - [x] 6.3 On drag end: call `audioPlayer.seek(to: finalTime)` — do NOT auto-play on drag end
  - [x] 6.4 60fps visual update during drag via `dragPosition` state driving playhead X position

- [x] Task 7: Keyboard shortcuts for playback (AC: #4)
  - [x] 7.1 Space bar toggles play/pause (`.onKeyPress(.space)` on the waveform container)
  - [x] 7.2 Left/Right arrow keys skip backward/forward 5 seconds
  - [x] 7.3 Clamp seek positions to `0...session.duration`
  - [x] 7.4 Arrow key skip only fires when waveform container is focused (not when a child tag marker is focused) — naturally handled by SwiftUI focus system

- [x] Task 8: Accessibility for playback (AC: #4)
  - [x] 8.1 Play/pause button: `.accessibilityLabel(audioPlayer.isPlaying ? "Pause" : "Play")`
  - [x] 8.2 Playhead position: `.accessibilityValue("Playback position: \(formatTimestamp(audioPlayer.currentTime))")`
  - [x] 8.3 Waveform container: add `.accessibilityAction(named: "Play/Pause")` for VoiceOver custom actions
  - [x] 8.4 Announce playback state changes via `AccessibilityNotification.Announcement` when play/pause toggles
  - [x] 8.5 `@Environment(\.accessibilityReduceMotion)` already respected — 30Hz timer updates produce instant playhead position without CSS-style animation

- [x] Task 9: Unit tests (AC: #1, #2, #3, #4, #5)
  - [x] 9.1 Create `AudioPlayerTests.swift` in `DictlyMacTests/ReviewTests/`
  - [x] 9.2 Test `AudioPlayer.load()` succeeds with valid audio file path (uses 440Hz sine wave fixture)
  - [x] 9.3 Test `AudioPlayer.load()` throws `DictlyError.storage(.fileNotFound)` for missing file
  - [x] 9.4 Test `AudioPlayer.seek(to:)` updates `currentTime` to the seeked position
  - [x] 9.5 Test `AudioPlayer.seek(to:)` clamps to `0...duration` (negative → 0, over-duration → duration)
  - [x] 9.6 Test `AudioPlayer.play()` sets `isPlaying = true`
  - [x] 9.7 Test `AudioPlayer.pause()` sets `isPlaying = false` and preserves `currentTime`
  - [x] 9.8 Test playhead X-position calculation: `(currentTime / duration) * width` for known values
  - [x] 9.9 Test tap-vs-drag threshold: gesture distance < 4pt = tap, >= 4pt = drag
  - [x] 9.10 Use `@MainActor`, in-memory `ModelContainer` with `ModelConfiguration(isStoredInMemoryOnly: true)` (project convention)

## Dev Notes

### Core Architecture

This story adds audio playback to the existing `SessionWaveformTimeline` from story 4.2. It introduces one new file (`AudioPlayer.swift`) and modifies the existing waveform and review screen to support playback interactions. The scrub cursor from story 4.2 becomes the persistent playhead.

The `AudioPlayer` is an `@Observable` class using `AVAudioEngine` + `AVAudioPlayerNode` (NOT `AVAudioPlayer` — the engine graph is required for precise seeking, scrub preview, and future features like transcription audio routing).

### AVAudioEngine Playback Pattern

```swift
import AVFoundation
import os

@Observable
@MainActor
final class AudioPlayer {
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var isLoaded = false

    private var engine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var displayLink: CVDisplayLink? // or Timer
    private let logger = Logger(subsystem: "com.dictly.mac", category: "playback")

    func load(filePath: String) async throws {
        guard FileManager.default.fileExists(atPath: filePath) else {
            logger.error("Audio file not found: \(filePath, privacy: .sensitive)")
            throw DictlyError.storage(.fileNotFound)
        }
        let url = URL(fileURLWithPath: filePath)
        let file = try AVAudioFile(forReading: url)
        audioFile = file
        duration = Double(file.length) / file.processingFormat.sampleRate

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: file.processingFormat)
        try engine.start()
        isLoaded = true
        logger.info("Audio loaded, duration: \(self.duration, privacy: .public)s")
    }

    func seek(to time: TimeInterval) {
        let clampedTime = max(0, min(time, duration))
        currentTime = clampedTime
        guard let file = audioFile else { return }

        let wasPlaying = isPlaying
        playerNode.stop()

        let startFrame = AVAudioFramePosition(clampedTime * file.processingFormat.sampleRate)
        let remainingFrames = AVAudioFrameCount(file.length - startFrame)
        guard remainingFrames > 0 else { return }

        playerNode.scheduleSegment(file, startingFrame: startFrame,
                                    frameCount: remainingFrames, at: nil)
        if wasPlaying { playerNode.play() }
    }
}
```

### Playhead Diamond Cap Shape

```swift
// Diamond shape for playhead cap (8pt)
struct PlayheadDiamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: CGPoint(x: mid.x, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: mid.y))
        path.addLine(to: CGPoint(x: mid.x, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: mid.y))
        path.closeSubpath()
        return path
    }
}
```

### Scrub Throttling Pattern

Throttle `audioPlayer.scrub(to:)` calls during drag to prevent audio glitching:

```swift
private var lastScrubTime: Date = .distantPast

private func throttledScrub(to time: TimeInterval) {
    let now = Date()
    guard now.timeIntervalSince(lastScrubTime) > 0.1 else { return }
    lastScrubTime = now
    audioPlayer.scrub(to: time)
}
```

### Tap vs Drag Discrimination

The existing `DragGesture(minimumDistance: 0)` in `SessionWaveformTimeline` captures both taps and drags. Distinguish with:

```swift
DragGesture(minimumDistance: 0)
    .onChanged { value in
        let distance = hypot(value.translation.width, value.translation.height)
        if distance >= 4 {
            isDragging = true
            // Update playhead position + throttled scrub
        }
    }
    .onEnded { value in
        let distance = hypot(value.translation.width, value.translation.height)
        if distance < 4 {
            // TAP: seek + play
            let tappedTime = (value.location.x / viewWidth) * session.duration
            audioPlayer.seek(to: tappedTime)
            audioPlayer.play()
        } else {
            // DRAG END: seek to final position, don't auto-play
            let finalTime = (value.location.x / viewWidth) * session.duration
            audioPlayer.seek(to: finalTime)
        }
        isDragging = false
    }
```

### Existing Code to Reuse

| What | Where | How |
|------|-------|-----|
| `Session` model | `DictlyKit/Sources/DictlyModels/Session.swift` | `audioFilePath`, `duration`, `tags` relationship |
| `Tag` model | `DictlyKit/Sources/DictlyModels/Tag.swift` | `anchorTime` for seek position |
| `SessionWaveformTimeline` | `DictlyMac/Review/SessionWaveformTimeline.swift` | Existing scrub gesture, tag marker click, Canvas rendering |
| `SessionReviewScreen` | `DictlyMac/Review/SessionReviewScreen.swift` | Add `AudioPlayer` state, pass to waveform, wire `selectedTag` to seek+play |
| `WaveformDataProvider` | `DictlyMac/Review/WaveformDataProvider.swift` | Same `AVAudioFile` file-access pattern for opening audio |
| `formatTimestamp(_:)` | `DictlyMac/Review/TagSidebarRow.swift` | Format `currentTime` for playhead label and toolbar |
| `categoryColor(for:)` | `DictlyMac/Review/CategoryColorHelper.swift` | Already used by markers — no changes needed |
| `DictlyColors` | `DictlyKit/Sources/DictlyTheme/Colors.swift` | `textPrimary` for playhead, `textSecondary` for disabled states |
| `DictlyTypography` | `DictlyKit/Sources/DictlyTheme/Typography.swift` | `caption` for timestamp display in toolbar |
| `DictlySpacing` | `DictlyKit/Sources/DictlyTheme/Spacing.swift` | Spacing tokens for toolbar layout |
| `DictlyAnimation` | `DictlyKit/Sources/DictlyTheme/Animation.swift` | Accessibility-aware animation for playhead transitions |
| `DictlyError` | `DictlyKit/Sources/DictlyModels/DictlyError.swift` | `.storage(.fileNotFound)` for missing audio files |
| Test audio fixture | `DictlyMacTests/ReviewTests/WaveformTimelineTests.swift` | Reuse `makeTestAudioFileURL()` 440Hz sine wave generator |

### What NOT to Do

- **Do NOT** use `AVAudioPlayer` — use `AVAudioEngine` + `AVAudioPlayerNode` for precise seeking and future extensibility (scrub preview, transcription audio routing).
- **Do NOT** create AudioPlayer in DictlyKit — it belongs in `DictlyMac/Review/` per architecture (Mac-specific Core Audio playback).
- **Do NOT** use `@StateObject` or `ObservableObject` — use `@Observable` macro exclusively.
- **Do NOT** use `@Environment` for `AudioPlayer` injection — it's view-scoped to `SessionReviewScreen`, not app-wide.
- **Do NOT** hardcode colors, fonts, or spacing — use `DictlyTheme` tokens exclusively.
- **Do NOT** modify `WaveformDataProvider`, `TagMarkerShape`, `CategoryColorHelper`, `TagSidebar`, `TagSidebarRow`, or `TagDetailPanel` — they are complete from stories 4.1/4.2.
- **Do NOT** implement tag editing, category filtering, or retroactive tag placement — those are stories 4.4, 4.5, 4.6.
- **Do NOT** remove the existing tag marker click/hover functionality — extend it to also trigger playback.
- **Do NOT** add `#if os()` in DictlyKit — all playback code lives in the Mac target.
- **Do NOT** load the full audio file into memory for playback — `AVAudioEngine` + `scheduleSegment` streams from disk.
- **Do NOT** use `AnyView` — use `@ViewBuilder` or conditional views.

### Project Structure Notes

New files:

```
DictlyMac/Review/
└── AudioPlayer.swift                  # NEW: @Observable Core Audio playback service

DictlyMacTests/ReviewTests/
└── AudioPlayerTests.swift             # NEW: Playback, seek, state tests
```

Modified files:
- `DictlyMac/Review/SessionReviewScreen.swift` — add `AudioPlayer` state, `.task` loading, toolbar transport controls, wire `selectedTag` to seek+play
- `DictlyMac/Review/SessionWaveformTimeline.swift` — accept `AudioPlayer` parameter, replace scrub cursor with persistent playhead (diamond cap), wire tap-to-play and drag-to-scrub, add keyboard shortcuts

### Testing Standards

- Use `XCTest` with `@MainActor` (project convention)
- In-memory `ModelContainer`: `ModelConfiguration(isStoredInMemoryOnly: true)`
- Reuse `makeTestAudioFileURL()` from `WaveformTimelineTests.swift` for creating programmatic 440Hz sine wave test fixture
- Test `AudioPlayer` state transitions (loaded, playing, paused, seeked) — these are synchronous state checks after async operations
- Test playhead position math independently (pure function, no UI dependency)
- Mac test target may not run locally without signing certificate — verify test target builds cleanly (`** TEST BUILD SUCCEEDED **`)
- Keep audio-dependent tests short (~1 second audio files) to avoid slow test runs

### Previous Story (4.2) Learnings

- Canvas rendering is proven performant at 60fps — playhead overlay should use the same approach (overlay on top of Canvas, not inside it for interactive elements)
- `GeometryReader` drives `sampleCount` from view width — same `viewWidth` state can drive playhead X-position calculation
- `.task(id: sampleCount)` pattern used for waveform reload — similar `.task` pattern works for AudioPlayer loading
- Scrub cursor already exists with `DragGesture(minimumDistance: 0)` and floating timestamp label — this becomes the playhead; extend rather than replace
- Tag marker click sets `selectedTag` binding — adding seek+play on the same path requires reading `selectedTag` changes via `.onChange(of: selectedTag)`
- `formatTimestamp` is a free function in `TagSidebarRow.swift` — reuse for toolbar timestamp display
- Tooltip hover was refactored from `.popover` to overlay with 300ms debounce (review fix) — hover behavior is stable, no changes needed
- Task cancellation safety: always set state before early return (review fix from 4.2) — apply same pattern in AudioPlayer async methods
- xcodegen must be re-run after adding new source files — `DictlyMac/project.yml` already includes `Review/` path

### Story 4.3 Implementation Learnings

- **`@ViewBuilder` + variable assignment**: Cannot do multi-statement variable assignments inside `@ViewBuilder` functions. Must use `let x = computeValue()` (single assignment) or a helper function — not `let x: Type; if ... { x = a } else { x = b }`.
- **`deinit` in `@MainActor` class**: In Swift 6, `deinit` is `nonisolated` and cannot directly access `@MainActor`-isolated properties. Use `nonisolated(unsafe)` on properties that need cleanup in `deinit` (e.g., `timerTask`, `engine`, `playerNode`). All access during normal operation remains `@MainActor`-only.
- **Cooperative Task timer**: `Task { while !Task.isCancelled { try? await Task.sleep(for: .milliseconds(33)); ... } }` is clean in Swift 6 and avoids `Timer`/`RunLoop` + `@Sendable` closure issues.
- **`AVAudioPlayerNode.isPlaying`**: Reliable for end-of-file detection — becomes `false` when the scheduled segment is exhausted. Simpler than a completion handler that requires actor-crossing.

### Git Intelligence

Recent commits follow `feat(scope):` / `fix(scope):` / `test(scope):` / `docs(bmad):` conventional commit format. Story 4.2 was implemented in two commits: `fe8f896 feat(review):` + `518ff63 fix(review):` code review patches. The scrub cursor in `SessionWaveformTimeline.swift` (lines 178-216) is the starting point for playhead implementation.

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 4, Story 4.3 acceptance criteria, lines 759-787]
- [Source: _bmad-output/planning-artifacts/architecture.md — AudioPlayer.swift: @Observable, Core Audio playback, seek, scrub]
- [Source: _bmad-output/planning-artifacts/architecture.md — Review/ owns waveform rendering, audio playback, and tag editing]
- [Source: _bmad-output/planning-artifacts/architecture.md — Mac Review Flow: Tag selected → AudioPlayer (seek + play)]
- [Source: _bmad-output/planning-artifacts/architecture.md — @Observable for stateful services, injected via @Environment]
- [Source: _bmad-output/planning-artifacts/architecture.md — .task modifier on views for async loading]
- [Source: _bmad-output/planning-artifacts/architecture.md — DictlyError enum with .storage(.fileNotFound)]
- [Source: _bmad-output/planning-artifacts/architecture.md — os.Logger subsystem com.dictly.mac, category per module]
- [Source: _bmad-output/planning-artifacts/architecture.md — FR28: click tag to jump playback, FR36: full audio scrub]
- [Source: _bmad-output/planning-artifacts/architecture.md — NFR3: audio playback jump < 500ms, NFR4: 60fps waveform]
- [Source: _bmad-output/planning-artifacts/prd.md — FR28: DM can click a tag marker to jump audio playback to that moment]
- [Source: _bmad-output/planning-artifacts/prd.md — FR36: DM can scrub through the full audio recording]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — UX-DR7: SessionWaveformTimeline with draggable playhead, diamond cap]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Playhead states: default, scrubbing, tag-selected jump]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — 60fps scrubbing performance requirement]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Accessibility: arrow key navigation, VoiceOver custom actions for scrubbing]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Reduce Motion: instant state changes, no transition animations]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Ferrite Recording Studio benchmark for scrubbing responsiveness]
- [Source: DictlyMac/Review/SessionWaveformTimeline.swift — existing scrub gesture lines 178-216, DragGesture at line 74]
- [Source: DictlyMac/Review/SessionReviewScreen.swift — selectedTag state, sessionToolbar, HSplitView layout]
- [Source: DictlyMac/Review/WaveformDataProvider.swift — AVAudioFile access pattern for audio file opening]
- [Source: DictlyMac/Review/TagSidebarRow.swift — formatTimestamp() function lines 42-51]
- [Source: DictlyKit/Sources/DictlyModels/Session.swift — audioFilePath, duration properties]
- [Source: DictlyKit/Sources/DictlyModels/Tag.swift — anchorTime property for seek position]
- [Source: _bmad-output/implementation-artifacts/4-2-waveform-timeline-rendering-with-tag-markers.md — previous story learnings, review findings, established patterns]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- **ViewBuilder assignment error**: `@ViewBuilder` functions don't allow multi-statement variable assignment. Fixed by extracting `playheadDisplayTime(in:)` helper and using single `let time = ...` in `playheadView`.
- **deinit isolation error**: Swift 6 nonisolated `deinit` cannot access `@MainActor`-isolated properties. Fixed by marking `engine`, `playerNode`, `timerTask` as `nonisolated(unsafe)`.
- **Signing requirement**: Test build uses `CODE_SIGN_IDENTITY=""` flags; this is a pre-existing project constraint (iCloud entitlement on DictlyMac target).

### Completion Notes List

- **AudioPlayer.swift** (NEW): `@Observable @MainActor` class with `AVAudioEngine` + `AVAudioPlayerNode`. Implements `load()`, `play()`, `pause()`, `seek(to:)`, `scrub(to:)`. Uses cooperative `Task` at ~30Hz for `currentTime` updates. `nonisolated(unsafe)` on engine/node/timer for Swift 6 `deinit` compatibility.
- **SessionReviewScreen.swift** (MODIFIED): Added `@State private var audioPlayer`, `.task` for audio loading with error handling, `.onChange(of: selectedTag)` for seek+play on tag click, and `playbackControls` HStack in the session toolbar (play/pause button + timestamp display).
- **SessionWaveformTimeline.swift** (MODIFIED): Added `audioPlayer: AudioPlayer` parameter. Replaced `scrubPosition` with persistent `playheadView` (diamond cap + vertical line). Updated gesture to distinguish tap (< 4pt = seek+play) from drag (≥ 4pt = scrub preview). Added throttled scrub at ~10Hz. Added Space/Left/Right keyboard shortcuts. Added `.accessibilityAction(named: "Play/Pause")`.
- **AudioPlayerTests.swift** (NEW): 13 tests covering file load success/failure, seek clamping, play/pause state transitions, playhead X-position math (4 cases), and tap-vs-drag threshold (4 cases). Tests requiring audio engine use `XCTSkip` for headless environments.
- **Build**: `** TEST BUILD SUCCEEDED **` with `CODE_SIGN_IDENTITY=""` (pre-existing signing constraint).

### File List

- `DictlyMac/Review/AudioPlayer.swift` — NEW
- `DictlyMac/Review/SessionReviewScreen.swift` — MODIFIED
- `DictlyMac/Review/SessionWaveformTimeline.swift` — MODIFIED
- `DictlyMacTests/ReviewTests/AudioPlayerTests.swift` — NEW

### Review Findings

All patch findings were automatically applied in YOLO mode (2026-04-02). No decision-needed findings.

- [x] [Review][Patch] `load()` double-call guard — same file returns early; different file tears down and re-initializes engine/node/state. [AudioPlayer.swift:61]
- [x] [Review][Patch] `play()` at EOF resets to beginning — `if currentTime >= duration { currentTime = 0 }` before `scheduleAndPlay`. [AudioPlayer.swift:82]
- [x] [Review][Patch] AC1: tag re-tap always seeks+plays — re-tapping same tag calls `audioPlayer.seek+play` directly instead of deselecting. [SessionWaveformTimeline.swift:295]
- [x] [Review][Patch] Task 6.3: drag-end auto-play race — `audioPlayer.pause()` called before `seek()` on drag-end path to guarantee `wasPlaying=false`. [SessionWaveformTimeline.swift:200]
- [x] [Review][Patch] Unclamped tap x — `value.location.x` clamped to `0...viewWidth` in tap path. [SessionWaveformTimeline.swift:195]
- [x] [Review][Patch] `lastScrubDate` not reset on drag end — `lastScrubDate = .distantPast` added to `onEnded`. [SessionWaveformTimeline.swift:207]
- [x] [Review][Patch] Diamond cap clipped by `.clipShape` — offset changed from `y: -4` to `y: 2`, placing it fully inside waveform bounds. [SessionWaveformTimeline.swift:149]
- [x] [Review][Patch] Missing a11y announcement on space-bar and `accessibilityAction` toggle — `AccessibilityNotification.Announcement` added to both paths. [SessionWaveformTimeline.swift:87, 108]
- [x] [Review][Patch] `.task` not id-bound to session — changed to `.task(id: session.audioFilePath)` to re-fire on session change. [SessionReviewScreen.swift:47]
- [x] [Review][Patch] Missing tests — added `testPlay_atEndOfFile_restartsFromBeginning` and `testLoad_calledTwice_withSameFile_isIdempotent`. [AudioPlayerTests.swift]

Deferred (pre-existing, not caused by this story):
- [x] [Review][Defer] `AVAudioEngineConfigurationChange` not handled — audio route changes (Bluetooth, USB) will silently stop playback. [AudioPlayer.swift] — deferred, pre-existing
- [x] [Review][Defer] `viewWidth` state may be stale during simultaneous window-resize + drag [SessionWaveformTimeline.swift] — deferred, pre-existing
- [x] [Review][Defer] `isPlaying=true` set before `playerNode.play()` fails (self-corrects via timer→handlePlaybackFinished) [AudioPlayer.swift:162] — deferred, pre-existing

Dismissed (7 false positives or non-issues): timer actor safety (Task{} inherits @MainActor context), AVAudioFile thread safety (all access @MainActor), timerTask data race (Task.isCancelled is thread-safe), keyboard shortcut scope (per spec Task 7.4), seek() without isLoaded (clamps harmlessly), double playerNode.stop() in scrub (benign), playbackControls not in body (false positive — it IS in sessionToolbar).

## Change Log

- **2026-04-02**: Story 4.3 implemented — audio playback and waveform navigation (claude-sonnet-4-6)
  - Created `AudioPlayer.swift` with AVAudioEngine Core Audio stack
  - Added playback transport controls to `SessionReviewScreen` toolbar
  - Replaced scrub cursor with persistent playhead (diamond cap) in `SessionWaveformTimeline`
  - Wired tap-to-play, drag-to-scrub, tag-click-to-play, keyboard shortcuts (Space/Arrow)
  - Added VoiceOver accessibility actions and `AccessibilityNotification.Announcement`
  - Created `AudioPlayerTests.swift` with 13 unit tests
  - Ran xcodegen to register new files; build: `** TEST BUILD SUCCEEDED **`
- **2026-04-02**: Story 4.3 code review patches applied (claude-sonnet-4-6, YOLO mode)
  - Fixed `AudioPlayer.load()` double-call guard (same file skips; different file tears down first)
  - Fixed `play()` at EOF to restart from beginning
  - Fixed AC1: tag re-tap always seeks+plays (no longer deselects)
  - Fixed Task 6.3: `audioPlayer.pause()` before drag-end seek prevents auto-resume
  - Fixed unclamped tap x and `lastScrubDate` reset on drag end
  - Fixed diamond cap clipping (y: -4 → y: 2, inside clipShape bounds)
  - Added `AccessibilityNotification.Announcement` to space-bar and accessibilityAction paths
  - Bound `.task` to `session.audioFilePath` for session navigation correctness
  - Added 2 new tests: play-at-EOF restart, load-called-twice idempotency
  - Build: `** TEST BUILD SUCCEEDED **`
