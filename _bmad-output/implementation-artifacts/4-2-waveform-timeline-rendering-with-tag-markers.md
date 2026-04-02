# Story 4.2: Waveform Timeline Rendering with Tag Markers

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a DM,
I want to see my session as a waveform with color-coded tag markers,
so that I can visually scan where the action happened at a glance.

## Acceptance Criteria

1. **Given** an imported session with audio, **when** the waveform timeline renders, **then** the full session audio is displayed as a waveform using Core Audio / `AVAudioFile` data, **and** a skeleton placeholder is shown during rendering, fading to the waveform when ready.

2. **Given** a session with tags, **when** the waveform displays, **then** each tag appears as a colored circle marker at its anchor position on the waveform, **and** marker colors match their tag category (`Story`=amber, `Combat`=crimson, `Roleplay`=violet, `World`=green, `Meta`=slate blue).

3. **Given** tag markers on the waveform, **when** each default category marker renders, **then** markers use distinct shapes per category (circle, diamond, square, triangle, hexagon) for color-blind accessibility.

4. **Given** the DM hovers over a tag marker, **when** the tooltip appears, **then** it shows the tag label, category, and timestamp.

5. **Given** waveform scrubbing, **when** the DM drags or scrolls the waveform, **then** rendering is smooth at 60fps.

## Tasks / Subtasks

- [ ] Task 1: Create `WaveformDataProvider` — async waveform sample extraction (AC: #1)
  - [ ] 1.1 Create `WaveformDataProvider.swift` in `DictlyMac/Review/`
  - [ ] 1.2 Accept `audioFilePath: String` and `sampleCount: Int` (target number of bars to render)
  - [ ] 1.3 Use `AVAudioFile` to read the audio file and extract amplitude samples
  - [ ] 1.4 Downsample to `sampleCount` bars by taking max amplitude per chunk
  - [ ] 1.5 Normalize amplitudes to 0.0–1.0 range
  - [ ] 1.6 Return `[Float]` array of normalized amplitudes
  - [ ] 1.7 Run extraction on a background thread (use `Task` with `.userInitiated` priority)
  - [ ] 1.8 Handle missing/corrupt audio files gracefully — return empty array, log at `.error` level
  - [ ] 1.9 Use `os.Logger` with subsystem `com.dictly.mac`, category `waveform`

- [ ] Task 2: Create `SessionWaveformTimeline` — the main waveform view (AC: #1, #5)
  - [ ] 2.1 Create `SessionWaveformTimeline.swift` in `DictlyMac/Review/`
  - [ ] 2.2 Accept `session: Session` and `selectedTag: Binding<Tag?>`
  - [ ] 2.3 Use `Canvas` (not `Path` per bar) for 60fps waveform bar rendering
  - [ ] 2.4 Draw vertical bars — width proportional to available width / sample count, height proportional to normalized amplitude
  - [ ] 2.5 Bar color: `DictlyColors.textSecondary.opacity(0.4)` for normal bars
  - [ ] 2.6 Minimum height: 120pt, flexible width (fills available space) — same constraints as the placeholder it replaces
  - [ ] 2.7 Background: `DictlyColors.surface` with `RoundedRectangle(cornerRadius: 8)` clip
  - [ ] 2.8 Use `.task` modifier to trigger `WaveformDataProvider` loading on appear
  - [ ] 2.9 `@State private var waveformSamples: [Float] = []` and `@State private var isLoading: Bool = true`
  - [ ] 2.10 Compute `sampleCount` from view width using `GeometryReader` — target ~2pt bar width with 1pt gap

- [ ] Task 3: Skeleton loading state with fade transition (AC: #1)
  - [ ] 3.1 While `isLoading == true`, show animated skeleton: random-height bars at 30% opacity with shimmer animation
  - [ ] 3.2 When waveform data arrives, transition from skeleton to real waveform with `.opacity` transition (0.3s ease-in-out)
  - [ ] 3.3 If audio file is missing (`audioFilePath == nil` or file doesn't exist), show centered text: "No audio file available" with `DictlyColors.textSecondary`
  - [ ] 3.4 Respect `@Environment(\.accessibilityReduceMotion)` — skip shimmer animation if active

- [ ] Task 4: Tag marker overlay (AC: #2, #3)
  - [ ] 4.1 Overlay tag markers on top of the waveform `Canvas`
  - [ ] 4.2 Position each marker horizontally at `(tag.anchorTime / session.duration) * viewWidth`
  - [ ] 4.3 Markers render as category-specific shapes at the top of the waveform area:
    - Story → circle (8pt)
    - Combat → diamond (8pt, rotated square)
    - Roleplay → square (7pt)
    - World → triangle (8pt)
    - Meta → hexagon (8pt)
    - Unknown → circle (8pt, `DictlyColors.textSecondary`)
  - [ ] 4.4 Each marker has a thin vertical line (1pt width) extending from the marker down to the bottom of the waveform, using the category color at 30% opacity
  - [ ] 4.5 Fill markers with category color from `categoryColor(for:)` (reuse `CategoryColorHelper.swift`)
  - [ ] 4.6 Default state: markers at 75% opacity
  - [ ] 4.7 Selected tag marker: full opacity with a ring highlight (2pt stroke, white + category color)

- [ ] Task 5: Hover tooltips on tag markers (AC: #4)
  - [ ] 5.1 On hover over a tag marker, show a popover/tooltip containing: tag label (bold), category name, formatted timestamp (`formatTimestamp`)
  - [ ] 5.2 Use `.onHover` modifier to track hover state per marker
  - [ ] 5.3 Tooltip background: `DictlyColors.surface` with `DictlyColors.border` stroke, 8pt corner radius
  - [ ] 5.4 Tooltip appears above the marker with a slight offset
  - [ ] 5.5 Use `DictlyTypography.tagLabel` for label, `DictlyTypography.caption` for category and timestamp

- [ ] Task 6: Tag marker click to select (AC: #2)
  - [ ] 6.1 Clicking a tag marker sets `selectedTag` binding to that tag
  - [ ] 6.2 Clicking the selected marker again deselects (`selectedTag = nil`)
  - [ ] 6.3 Selection change animates marker highlight (ring appears/disappears with `.easeInOut(duration: 0.2)`)

- [ ] Task 7: Waveform scrubbing / drag interaction (AC: #5)
  - [ ] 7.1 Add `DragGesture` on the waveform area for horizontal scrubbing
  - [ ] 7.2 During drag, show a vertical cursor line at the drag position (2pt width, `DictlyColors.textPrimary.opacity(0.6)`)
  - [ ] 7.3 Display the timestamp at the cursor position as a floating label above the cursor
  - [ ] 7.4 This is a visual-only scrub cursor for now — audio playback on scrub is story 4.3
  - [ ] 7.5 Ensure 60fps by using `Canvas` redraw only for the cursor overlay, not full waveform re-render

- [ ] Task 8: Replace waveform placeholder in `SessionReviewScreen` (AC: #1)
  - [ ] 8.1 In `SessionReviewScreen.swift`, replace `waveformPlaceholder` with `SessionWaveformTimeline(session: session, selectedTag: $selectedTag)`
  - [ ] 8.2 Remove the old `waveformPlaceholder` computed property entirely
  - [ ] 8.3 Keep the same padding (`DictlySpacing.md`) around the waveform

- [ ] Task 9: Accessibility (AC: #2, #3, #4)
  - [ ] 9.1 Each tag marker is focusable via keyboard (Tab / arrow keys navigate between markers)
  - [ ] 9.2 VoiceOver label per marker: "[Category]: [Label] at [timestamp]"
  - [ ] 9.3 Waveform container label: "Session waveform timeline with [N] tag markers"
  - [ ] 9.4 Scrub cursor position announced: "Timeline position: [timestamp]"
  - [ ] 9.5 Activate (Enter/Space) on focused marker selects it

- [ ] Task 10: Unit tests (AC: #1, #2)
  - [ ] 10.1 Create `WaveformTimelineTests.swift` in `DictlyMacTests/ReviewTests/`
  - [ ] 10.2 Test `WaveformDataProvider` returns correct sample count for a test audio file
  - [ ] 10.3 Test `WaveformDataProvider` returns empty array for missing file path
  - [ ] 10.4 Test tag marker X-position calculation: `(anchorTime / duration) * width` for known values
  - [ ] 10.5 Test marker shape mapping: each category name maps to correct shape type
  - [ ] 10.6 Test edge cases: session with no tags (no markers rendered), session with no audio (error state shown), tag at time 0 and at duration end
  - [ ] 10.7 Use `@MainActor`, in-memory `ModelContainer` with `ModelConfiguration(isStoredInMemoryOnly: true)` (project convention)

## Dev Notes

### Core Architecture

This story replaces the waveform placeholder created in story 4.1 with a real `SessionWaveformTimeline` component. It is purely visual + data extraction — no audio playback (story 4.3), no tag editing (story 4.5), no retroactive tag placement (story 4.6).

The component has two main layers:
1. **Waveform bars** — extracted from the audio file via `AVAudioFile`, rendered as a bar chart in a `Canvas` view
2. **Tag marker overlay** — positioned by `anchorTime / duration`, with category-specific colors and shapes

### Waveform Data Extraction Pattern

Use `AVAudioFile` (from AVFoundation, available on macOS) to read audio samples:

```swift
import AVFoundation

func extractWaveformSamples(from filePath: String, targetSampleCount: Int) async throws -> [Float] {
    let url = URL(fileURLWithPath: filePath)
    let audioFile = try AVAudioFile(forReading: url)
    let format = audioFile.processingFormat
    let frameCount = AVAudioFrameCount(audioFile.length)
    
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
        throw DictlyError.storage(.fileNotFound) // or appropriate error
    }
    try audioFile.read(into: buffer)
    
    guard let channelData = buffer.floatChannelData?[0] else { return [] }
    let totalFrames = Int(buffer.frameLength)
    let framesPerSample = max(1, totalFrames / targetSampleCount)
    
    var samples: [Float] = []
    samples.reserveCapacity(targetSampleCount)
    
    for i in 0..<targetSampleCount {
        let start = i * framesPerSample
        let end = min(start + framesPerSample, totalFrames)
        var maxAmplitude: Float = 0
        for j in start..<end {
            maxAmplitude = max(maxAmplitude, abs(channelData[j]))
        }
        samples.append(maxAmplitude)
    }
    
    // Normalize to 0.0–1.0
    let peak = samples.max() ?? 1.0
    if peak > 0 {
        samples = samples.map { $0 / peak }
    }
    return samples
}
```

**Important:** `AVAudioFile` reads the entire file into memory. For a 4-hour session at 64kbps AAC mono, the compressed file is ~115MB but the uncompressed PCM buffer in memory could be ~1.3GB. To avoid this:
- Read in chunks using `audioFile.read(into: buffer, frameCount: chunkSize)` in a loop
- Process each chunk and extract max amplitudes incrementally
- This keeps memory usage bounded regardless of session length

### Canvas Rendering for 60fps

Use SwiftUI `Canvas` for rendering waveform bars — it renders the entire drawing in a single pass, unlike creating hundreds of individual `Rectangle` views:

```swift
Canvas { context, size in
    let barWidth = max(1, (size.width / CGFloat(samples.count)) - 1)
    let gap: CGFloat = 1
    
    for (index, amplitude) in samples.enumerated() {
        let x = CGFloat(index) * (barWidth + gap)
        let barHeight = CGFloat(amplitude) * size.height
        let y = (size.height - barHeight) / 2  // center vertically
        let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
        context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(barColor))
    }
}
```

### Tag Marker Shape Definitions

Each default category gets a unique shape for color-blind accessibility (UX-DR16):

| Category | Shape | SwiftUI Implementation |
|----------|-------|----------------------|
| Story | Circle | `Circle().frame(width: 8, height: 8)` |
| Combat | Diamond | `Rectangle().frame(width: 7, height: 7).rotationEffect(.degrees(45))` |
| Roleplay | Square | `Rectangle().frame(width: 7, height: 7)` |
| World | Triangle | Custom `Path` with 3 points |
| Meta | Hexagon | Custom `Path` with 6 points |
| Unknown | Circle | Fallback, uses `DictlyColors.textSecondary` |

Markers are SwiftUI views overlaid on the `Canvas` using a `ZStack` or `overlay`. They are NOT drawn inside the Canvas, because they need individual hover/tap/accessibility support.

### Tag Marker Positioning

```swift
// X position of a tag marker on the waveform
func markerXPosition(anchorTime: TimeInterval, duration: TimeInterval, viewWidth: CGFloat) -> CGFloat {
    guard duration > 0 else { return 0 }
    return (anchorTime / duration) * viewWidth
}
```

Tags are sorted by `anchorTime`. If two markers overlap (within 4pt), offset the second vertically to avoid occlusion.

### Existing Code to Reuse

| What | Where | How |
|------|-------|-----|
| `Session` model | `DictlyKit/Sources/DictlyModels/Session.swift` | `audioFilePath`, `duration`, `tags` relationship |
| `Tag` model | `DictlyKit/Sources/DictlyModels/Tag.swift` | `anchorTime`, `categoryName`, `label` |
| `categoryColor(for:)` | `DictlyMac/Review/CategoryColorHelper.swift` | Maps category name to `DictlyColors.TagCategory.*` |
| `formatTimestamp(_:)` | `DictlyMac/Review/TagSidebarRow.swift` | Formats `TimeInterval` to `M:SS` / `H:MM:SS` |
| `DictlyColors` | `DictlyKit/Sources/DictlyTheme/Colors.swift` | `surface`, `textSecondary`, `textPrimary`, `border`, `TagCategory.*` |
| `DictlyTypography` | `DictlyKit/Sources/DictlyTheme/Typography.swift` | `tagLabel`, `caption`, `body` |
| `DictlySpacing` | `DictlyKit/Sources/DictlyTheme/Spacing.swift` | `xs` (4pt), `sm` (8pt), `md` (16pt) |
| `DictlyAnimation` | `DictlyKit/Sources/DictlyTheme/Animation.swift` | Accessibility-aware animation helpers |
| `SessionReviewScreen` | `DictlyMac/Review/SessionReviewScreen.swift` | Replace `waveformPlaceholder` with `SessionWaveformTimeline` |
| `TagSidebar`, `TagDetailPanel` | `DictlyMac/Review/` | Already wired — `selectedTag` binding shared with waveform |

### What NOT to Do

- **Do NOT** implement audio playback — story 4.3 handles `AudioPlayer` and playback on click/scrub. This story renders a visual-only scrub cursor.
- **Do NOT** implement retroactive tag placement — story 4.6 handles right-click tag creation on the waveform.
- **Do NOT** implement tag filtering on the waveform — story 4.4 handles category filter dimming.
- **Do NOT** implement zoom/pinch on the waveform — defer to a future enhancement if needed.
- **Do NOT** use `@StateObject` or `ObservableObject` — use `@Observable` for any service classes, `@State` for view-local state.
- **Do NOT** hardcode colors, fonts, or spacing — use `DictlyTheme` tokens exclusively.
- **Do NOT** use `AnyView` — use `@ViewBuilder` or conditional views.
- **Do NOT** render waveform bars as individual SwiftUI `Rectangle` views — use `Canvas` for performance.
- **Do NOT** load the full audio file into a single `AVAudioPCMBuffer` — read in chunks to bound memory.
- **Do NOT** modify `TagSidebar`, `TagDetailPanel`, `TagSidebarRow`, or `CategoryColorHelper` — they are complete from story 4.1.
- **Do NOT** modify `ImportService`, `ImportProgressView`, or `LocalNetworkReceiver` — they are complete from Epic 3.
- **Do NOT** add `#if os()` in DictlyKit — all waveform code lives in the Mac target.

### Project Structure Notes

New files:

```
DictlyMac/Review/
├── SessionWaveformTimeline.swift   # NEW: Waveform bars + tag markers + scrub cursor
├── WaveformDataProvider.swift      # NEW: AVAudioFile sample extraction
└── TagMarkerShape.swift            # NEW: Category-specific marker shape definitions

DictlyMacTests/ReviewTests/
└── WaveformTimelineTests.swift     # NEW: Waveform data + marker position tests
```

Modified files:
- `DictlyMac/Review/SessionReviewScreen.swift` — replace `waveformPlaceholder` with `SessionWaveformTimeline`
- `DictlyMac/project.yml` — ensure `Review/` source path includes new files (already included from 4.1)

### Testing Standards

- Use `XCTest` with `@MainActor` (project convention)
- In-memory `ModelContainer`: `ModelConfiguration(isStoredInMemoryOnly: true)`
- For `WaveformDataProvider` tests: create a short test audio file programmatically using `AVAudioFile` write, or use a fixture bundled in the test target
- Mac test target may not run locally without signing certificate — verify test target builds cleanly (`** TEST BUILD SUCCEEDED **`)
- Test marker position math independently (pure function, no UI dependency)

### Previous Story (4.1) Learnings

- `HSplitView` is used inside `SessionReviewScreen` (not `NavigationSplitView`) to avoid nested split view issues — new waveform component goes inside the existing `mainContent` VStack
- `CategoryColorHelper.swift` was extracted during code review — reuse `categoryColor(for:)` for marker colors
- Hardcoded fonts were caught in code review — always use `DictlyTypography.*` tokens
- `.accessibilityElement(children: .ignore)` was added to the waveform placeholder — the new `SessionWaveformTimeline` needs more granular accessibility (per-marker focusable elements)
- `formatTimestamp` is a free function in `TagSidebarRow.swift` — can be called from waveform tooltip code
- `GeometryReader` is used in `TagDetailPanel` for responsive breakpoints — same pattern works for computing waveform sample count from view width
- xcodegen must be re-run after adding new source files — `DictlyMac/project.yml` already includes `Review/` path

### Git Intelligence

Recent commits follow `feat(scope):` / `fix(scope):` / `test(scope):` / `docs(bmad):` conventional commit format. Story 4.1 was implemented in two commits: feature implementation (844426e) + code review patches (924f049). The waveform placeholder replaced in this story was created in story 4.1 at `SessionReviewScreen.swift:116-130`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 4, Story 4.2 acceptance criteria]
- [Source: _bmad-output/planning-artifacts/architecture.md — Project Structure: SessionWaveformTimeline.swift in DictlyMac/Review/]
- [Source: _bmad-output/planning-artifacts/architecture.md — Mac Target Boundaries: Review/ owns waveform rendering]
- [Source: _bmad-output/planning-artifacts/architecture.md — FR27 mapping: waveform timeline with markers]
- [Source: _bmad-output/planning-artifacts/architecture.md — SwiftUI Patterns: Canvas for custom rendering, @Observable, @State]
- [Source: _bmad-output/planning-artifacts/architecture.md — Performance: waveform 60fps rendering requirement]
- [Source: _bmad-output/planning-artifacts/architecture.md — Data Flow: Mac Review Flow — SessionWaveformTimeline (Core Audio render)]
- [Source: _bmad-output/planning-artifacts/architecture.md — Async Work: prefer .task modifier on views]
- [Source: _bmad-output/planning-artifacts/architecture.md — Logging: subsystem com.dictly.mac, category per module]
- [Source: _bmad-output/planning-artifacts/prd.md — FR27: DM can view a timeline with audio waveform and color-coded tag markers]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — UX-DR7: SessionWaveformTimeline custom component spec]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — UX-DR16: tag marker shapes per category for color-blind accessibility]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Component 4 (SessionWaveformTimeline): anatomy, states, behavior, accessibility]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Mac Window Adaptation: waveform flexible width, minimum 120pt height]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Color System: tag category hex values, WCAG AA verified]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Accessibility Strategy: markers focusable via Tab/Arrow, VoiceOver labels]
- [Source: DictlyKit/Sources/DictlyModels/Session.swift — audioFilePath, duration, tags relationship]
- [Source: DictlyKit/Sources/DictlyModels/Tag.swift — anchorTime, categoryName, label properties]
- [Source: DictlyKit/Sources/DictlyTheme/Colors.swift — TagCategory color definitions, surface, textSecondary]
- [Source: DictlyKit/Sources/DictlyTheme/Animation.swift — accessibility-aware animation helpers]
- [Source: DictlyMac/Review/SessionReviewScreen.swift — waveformPlaceholder at lines 116-130, to be replaced]
- [Source: DictlyMac/Review/CategoryColorHelper.swift — categoryColor(for:) function for marker coloring]
- [Source: DictlyMac/Review/TagSidebarRow.swift — formatTimestamp() function for tooltip display]
- [Source: _bmad-output/implementation-artifacts/4-1-mac-session-review-layout.md — previous story learnings, review findings, file list]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
