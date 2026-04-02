# Story 4.6: Retroactive Tag Placement

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a DM,
I want to place new tags on the waveform during review by scrubbing to a moment,
so that I can tag things I missed during the live session.

## Acceptance Criteria

1. **Given** the waveform timeline during review, **when** the DM right-clicks at a position on the waveform, **then** a context menu appears with "Add Tag Here" and a new tag creation form opens at that timestamp with a default label and category picker.

2. **Given** a retroactively placed tag, **when** the DM enters a label and selects a category, **then** the tag appears in the sidebar and as a marker on the waveform at the chosen position.

3. **Given** a retroactively placed tag, **when** it is saved, **then** it behaves identically to tags placed during recording (editable, deletable, searchable) — same SwiftData model, same rendering, same interactions.

## Tasks / Subtasks

- [x] Task 1: Add right-click context menu to SessionWaveformTimeline (AC: #1)
  - [x] 1.1 In `SessionWaveformTimeline.swift`, add a `.contextMenu` or `NSMenu`-based right-click handler to the waveform gesture area. Since SwiftUI `.contextMenu` doesn't provide click coordinates, use an overlay with a secondary-click gesture (`SpatialTapGesture(count: 1)` filtered to `.secondary`) or a custom `NSViewRepresentable` right-click handler that captures the click location in the coordinate space
  - [x] 1.2 Convert the click X coordinate to a `TimeInterval` using the existing formula: `anchorTime = (clickX / viewWidth) * session.duration`. Clamp to `0...session.duration`
  - [x] 1.3 Store the computed time in a new callback: `var onRequestNewTag: ((TimeInterval) -> Void)?` passed from `SessionReviewScreen`
  - [x] 1.4 On right-click, call `onRequestNewTag?(anchorTime)` to delegate tag creation to the parent

- [x] Task 2: Add tag creation state and popover in SessionReviewScreen (AC: #1, #2)
  - [x] 2.1 Add state in `SessionReviewScreen`: `@State private var isCreatingTag: Bool = false` and `@State private var newTagAnchorTime: TimeInterval = 0`
  - [x] 2.2 Wire `onRequestNewTag` from `SessionWaveformTimeline` to set `newTagAnchorTime` and `isCreatingTag = true`
  - [x] 2.3 Present a `.sheet` or `.popover` containing `NewTagForm` (new private struct in same file or new file `NewTagForm.swift`)
  - [x] 2.4 On form submit: create Tag, insert into modelContext, append to `session.tags`, auto-select (`selectedTag = newTag`), dismiss form
  - [x] 2.5 On form cancel: dismiss, no changes

- [x] Task 3: Create NewTagForm view (AC: #1, #2)
  - [x] 3.1 Create `DictlyMac/Review/NewTagForm.swift` — a compact form with:
    - `TextField("Tag label", text: $label)` — auto-focused, styled with `DictlyTypography.body`
    - Category picker grid/list using `@Query(sort: \TagCategory.sortOrder) private var categories: [TagCategory]` with colored dots and names (reuse `categoryColor(for:)` from `CategoryColorHelper`)
    - Timestamp display (read-only, formatted from `anchorTime`)
    - "Create" button (primary, disabled if label is empty) and "Cancel" button
  - [x] 3.2 Default label: "New Tag" (user is expected to type a meaningful label)
  - [x] 3.3 Default category: first category by sortOrder (typically "Story")
  - [x] 3.4 On Create: call the `onCreate` callback with `(label, categoryName)` — parent handles SwiftData insertion
  - [x] 3.5 On Enter key in TextField: submit form (same as Create button)
  - [x] 3.6 On Escape key: cancel form
  - [x] 3.7 Style: compact popover (280pt width), consistent with `CategoryPickerPopover` patterns from story 4-5
  - [x] 3.8 Accessibility: form elements labeled, category list navigable via keyboard, VoiceOver announces "Create tag at [timestamp]"

- [x] Task 4: Wire tag creation into SwiftData (AC: #2, #3)
  - [x] 4.1 In the `onRequestNewTag` handler in `SessionReviewScreen`, create the tag:
    ```swift
    let tag = Tag(
        label: label,
        categoryName: categoryName,
        anchorTime: newTagAnchorTime,
        rewindDuration: 0  // retroactive tags have no rewind concept
    )
    modelContext.insert(tag)
    session.tags.append(tag)
    ```
  - [x] 4.2 After creation, set `selectedTag = tag` to auto-select and show in detail panel
  - [x] 4.3 SwiftData auto-persistence handles saving — no explicit `context.save()` needed (consistent with story 4-5 pattern)
  - [x] 4.4 Waveform markers auto-update via SwiftData observation (`session.tags` is observed by `SessionWaveformTimeline`)
  - [x] 4.5 Sidebar list auto-updates via SwiftData observation (`TagSidebar.filteredTags` recomputes from `session.tags`)
  - [x] 4.6 Log creation: `Logger.tagging.info("Retroactive tag created: \(tag.label, privacy: .public) at \(tag.anchorTime, privacy: .public)")`

- [x] Task 5: Add keyboard shortcut for tag creation (AC: #1)
  - [x] 5.1 Add `.keyboardShortcut("t", modifiers: .command)` to a toolbar button or menu item labeled "Add Tag at Playhead"
  - [x] 5.2 This uses `audioPlayer.currentTime` as the `anchorTime` (current playhead position)
  - [x] 5.3 Opens the same `NewTagForm` — consistent creation flow regardless of trigger method
  - [x] 5.4 If no audio is loaded or duration is 0, disable the shortcut/button

- [x] Task 6: Accessibility pass (AC: #1, #2, #3)
  - [x] 6.1 Right-click context menu item: `.accessibilityLabel("Add tag at this position")`
  - [x] 6.2 NewTagForm: VoiceOver announces "Create new tag at [formatted timestamp]" when form opens
  - [x] 6.3 Label field: `.accessibilityLabel("Tag label")`, `.accessibilityHint("Enter a name for this tag")`
  - [x] 6.4 Category selection: each row reads "[Category name]. Double-tap to select."
  - [x] 6.5 After creation: post `AccessibilityNotification.Announcement("Tag created: [label]")`
  - [x] 6.6 Keyboard shortcut toolbar item: `.accessibilityLabel("Add tag at current playhead position")`

- [x] Task 7: Unit tests (AC: #1, #2, #3)
  - [x] 7.1 Create `RetroactiveTagTests.swift` in `DictlyMacTests/ReviewTests/`
  - [x] 7.2 Test: creating a tag with valid label and category adds it to `session.tags`
  - [x] 7.3 Test: created tag has correct `anchorTime` matching the specified position
  - [x] 7.4 Test: created tag has `rewindDuration == 0`
  - [x] 7.5 Test: created tag persists in SwiftData context (verify via `context.fetch`)
  - [x] 7.6 Test: created tag has `.createdAt` set to approximately current date
  - [x] 7.7 Test: tag with empty label is rejected (Create button disabled — test the validation logic)
  - [x] 7.8 Test: anchorTime is clamped to `0...session.duration` range
  - [x] 7.9 Use `@MainActor`, in-memory `ModelContainer` with `ModelConfiguration(isStoredInMemoryOnly: true)`, `DictlySchema.all` (project convention from story 4-5)

## Dev Notes

### Core Architecture

This story adds retroactive tag creation to the Mac review screen. The DM right-clicks on the waveform at any position (or uses Cmd+T at the playhead) to create a new tag. A compact form captures label and category, then a `Tag` object is inserted into SwiftData. Because `session.tags` is observed by both `SessionWaveformTimeline` and `TagSidebar`, the new tag marker and sidebar entry appear automatically with zero additional wiring.

### Key Design Decisions

**Right-click as primary trigger** (UX spec Journey 3): "Scrub waveform to spot, place retroactive tag." Right-click is the standard macOS contextual action. SwiftUI's `.contextMenu` modifier doesn't provide click coordinates, so a spatial secondary-click gesture or custom NSView overlay is needed.

**Keyboard shortcut as secondary trigger**: Cmd+T at current playhead position — common Mac pattern for "add item" at cursor.

**Compact popover form** (UX spec): "Inline editing everywhere on Mac — no separate edit screens." A sheet or popover near the click point keeps the DM's focus on the waveform. Not a full-screen modal.

**rewindDuration = 0**: Retroactive tags are placed at an exact waveform position — there's no "moment of recognition" delay. The `rewindDuration` field is set to 0 to distinguish from live-session tags.

**Auto-select after creation**: The new tag is immediately selected, populating `TagDetailPanel` where the DM can refine label, add notes (story 4.7), or change category — same editing flow as any other tag.

### SwiftData Insertion Pattern

Follows the same pattern as iOS `TaggingService.placeTag()` and story 4-5 deletion:

```swift
let tag = Tag(
    label: label,
    categoryName: categoryName,
    anchorTime: anchorTime,
    rewindDuration: 0
)
modelContext.insert(tag)
session.tags.append(tag)
selectedTag = tag
```

SwiftData auto-saves. The `session.tags` array mutation triggers observation updates in waveform and sidebar. No explicit save or notification needed.

### Right-Click Coordinate Capture

SwiftUI `.contextMenu` does NOT provide the click location. Options:

**Option A — Spatial secondary-click gesture (recommended):**
```swift
.gesture(
    SpatialTapGesture(count: 1)
        .modifiers(.secondary)  // right-click only
        .onEnded { value in
            let time = (value.location.x / viewWidth) * session.duration
            onRequestNewTag?(time.clamped(to: 0...session.duration))
        }
)
```
Note: Verify `SpatialTapGesture` with `.secondary` modifier works on macOS. If not available, fall back to Option B.

**Option B — NSViewRepresentable right-click overlay:**
A transparent `NSView` overlay that captures right-click events and reports coordinates. More verbose but guaranteed to work.

**Option C — contextMenu on each time segment:**
Divide waveform into segments, each with its own `.contextMenu`. Less precise, not recommended.

Choose the simplest working approach. The coordinate-to-time conversion already exists in the waveform's tap gesture handler.

### Existing Code to Reuse

| What | Where | How |
|------|-------|-----|
| `SessionWaveformTimeline` | `DictlyMac/Review/SessionWaveformTimeline.swift` | **MODIFY**: add right-click handler with coordinate capture, add `onRequestNewTag` callback |
| `SessionReviewScreen` | `DictlyMac/Review/SessionReviewScreen.swift` | **MODIFY**: add tag creation state, wire `onRequestNewTag`, present form, insert tag |
| `CategoryPickerPopover` | `DictlyMac/Review/TagDetailPanel.swift` (private) | **REFERENCE**: reuse same visual pattern for category selection in `NewTagForm` |
| `categoryColor(for:)` | `DictlyMac/Review/CategoryColorHelper.swift` | **REUSE**: category color dots in `NewTagForm` |
| `TagMarkerShape` | `DictlyMac/Review/TagMarkerShape.swift` | No changes — auto-renders new tag marker |
| `TagSidebar` | `DictlyMac/Review/TagSidebar.swift` | No changes — auto-updates from `session.tags` observation |
| `TagDetailPanel` | `DictlyMac/Review/TagDetailPanel.swift` | No changes — auto-populates when `selectedTag` is set to new tag |
| `AudioPlayer` | `DictlyMac/Review/AudioPlayer.swift` | **READ ONLY**: use `currentTime` for Cmd+T shortcut |
| `Tag` model | `DictlyKit/Sources/DictlyModels/Tag.swift` | **USE**: standard init with `rewindDuration: 0` |
| `TagCategory` model | `DictlyKit/Sources/DictlyModels/TagCategory.swift` | **QUERY**: `@Query(sort: \TagCategory.sortOrder)` for category picker list |
| `DictlyColors` | `DictlyKit/Sources/DictlyTheme/Colors.swift` | Surface, border, accent tokens for form |
| `DictlyTypography` | `DictlyKit/Sources/DictlyTheme/Typography.swift` | `body` for label, `caption` for timestamp, `h3` for title |
| `DictlySpacing` | `DictlyKit/Sources/DictlyTheme/Spacing.swift` | `xs`, `sm`, `md` for form layout |

### What NOT to Do

- **Do NOT** modify `TagSidebar.swift` — sidebar auto-updates from SwiftData observation of `session.tags`
- **Do NOT** modify `TagSidebarRow.swift` — rows render retroactive tags identically to live tags
- **Do NOT** modify `TagDetailPanel.swift` — it already handles any selected tag for editing
- **Do NOT** modify `AudioPlayer.swift` — only read `currentTime` for keyboard shortcut
- **Do NOT** modify any DictlyKit model files — Tag model already supports all needed fields
- **Do NOT** set `rewindDuration` to any value other than `0` for retroactive tags
- **Do NOT** use `@StateObject` or `ObservableObject` — use `@Observable` if creating observable classes
- **Do NOT** use `AnyView` — use `@ViewBuilder` or conditional views
- **Do NOT** implement tag notes editing — that is story 4.7
- **Do NOT** implement transcription — that is Epic 5
- **Do NOT** implement undo for tag creation — not in acceptance criteria
- **Do NOT** add drag-and-drop tag repositioning — not in scope
- **Do NOT** hardcode colors, fonts, or spacing — use `DictlyTheme` tokens exclusively
- **Do NOT** use `.confirmationDialog` — this story has no destructive confirmations
- **Do NOT** add `#if os()` in DictlyKit — all new UI lives in the Mac target

### Project Structure Notes

```
DictlyMac/Review/
├── SessionWaveformTimeline.swift     # MODIFIED: add right-click handler, onRequestNewTag callback
├── SessionReviewScreen.swift         # MODIFIED: tag creation state, form presentation, SwiftData insertion
└── NewTagForm.swift                  # NEW: compact tag creation form (label + category picker + timestamp)

DictlyMacTests/ReviewTests/
└── RetroactiveTagTests.swift         # NEW: tag creation, persistence, validation tests
```

### Testing Standards

- Use `XCTest` with `@MainActor` (project convention)
- In-memory `ModelContainer`: `ModelConfiguration(isStoredInMemoryOnly: true)` with `DictlySchema.all`
- Create test `Session` and `TagCategory` instances with known values
- Test Tag creation via direct model instantiation + modelContext insertion (test the data layer, not the UI)
- Test validation logic (empty label guard, anchorTime clamping) as pure functions if extracted
- Mac test target may not run locally without signing certificate — verify `** TEST BUILD SUCCEEDED **`

### Previous Story (4-5) Learnings

- **`@Bindable` on SwiftData models**: Use `@Bindable` for two-way binding to `@Model` properties. If `@Bindable var tag: Tag?` on optional is problematic, unwrap first with `if let tag`.
- **State reset on selection change**: Always reset transient editing state (`editingLabel`, `isEditingLabel`, `showCategoryPicker`) when `selectedTag` changes. Apply same principle: reset `isCreatingTag` and `newTagAnchorTime` appropriately.
- **Delete-alert tag capture race**: Story 4-5 had a bug where the tag reference could change between showing and confirming an alert. For tag creation, capture `anchorTime` at click time, not at form submission time.
- **xcodegen**: Must be re-run after adding new source files. `NewTagForm.swift` and `RetroactiveTagTests.swift` both need xcodegen.
- **`CategoryPickerPopover` pattern**: Proven pattern from story 4-5 — `@Query` for live categories, `onSelect` callback, checkmark for current selection. Reuse the same visual approach in `NewTagForm`.

### Git Intelligence

Recent commits follow `feat(review):` / `fix(review):` conventional commit format with `(story X-Y)` suffix. Expected commit: `feat(review): implement retroactive tag placement on waveform (story 4-6)`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md - Epic 4, Story 4.6 acceptance criteria]
- [Source: _bmad-output/planning-artifacts/architecture.md - FR33: retroactive tag placement by scrubbing audio]
- [Source: _bmad-output/planning-artifacts/architecture.md - SessionWaveformTimeline: retroactive tag placement on scrub]
- [Source: _bmad-output/planning-artifacts/architecture.md - Tag model: uuid, label, categoryName, anchorTime, rewindDuration]
- [Source: _bmad-output/planning-artifacts/architecture.md - SwiftData @Model macro with auto-persistence]
- [Source: _bmad-output/planning-artifacts/architecture.md - @Observable for service classes, @State for view-local state]
- [Source: _bmad-output/planning-artifacts/architecture.md - Review/ owns waveform rendering, audio playback, tag editing]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Journey 3: "Scrub waveform to spot, place retroactive tag"]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Inline editing everywhere on Mac — no separate edit screens]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Confirmation only for destructive actions]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - SessionWaveformTimeline: click anywhere to reposition playhead]
- [Source: _bmad-output/planning-artifacts/prd.md - FR33: DM can place new tags retroactively by scrubbing through the audio]
- [Source: DictlyMac/Review/SessionWaveformTimeline.swift - Gesture handling, coordinate-to-time conversion, tag marker rendering]
- [Source: DictlyMac/Review/SessionReviewScreen.swift - selectedTag binding, audioPlayer, tag creation wiring point]
- [Source: DictlyMac/Review/TagDetailPanel.swift - CategoryPickerPopover pattern for reuse in NewTagForm]
- [Source: DictlyMac/Review/CategoryColorHelper.swift - categoryColor(for:) for category dots]
- [Source: DictlyKit/Sources/DictlyModels/Tag.swift - Tag(label:categoryName:anchorTime:rewindDuration:) initializer]
- [Source: DictlyiOS/Tagging/TaggingService.swift - placeTag() pattern: insert + append + save]
- [Source: _bmad-output/implementation-artifacts/4-5-tag-editing-rename-recategorize-and-delete.md - Previous story learnings, code patterns, review findings]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Build with `CODE_SIGN_IDENTITY=""` required (pre-existing iCloud entitlement constraint from story 3.3)
- `SpatialTapGesture` with `.secondary` modifier is not a public SwiftUI API on macOS; implemented Option B (NSViewRepresentable) instead
- `** TEST BUILD SUCCEEDED **` confirmed after xcodegen regeneration

### Completion Notes List

- **Task 1**: Added `RightClickOverlay` (NSViewRepresentable) + `RightClickView` (NSView subclass) to `SessionWaveformTimeline.swift`. Right-click captures AppKit `rightMouseDown` coordinate, converts via `(x / viewWidth) * duration`, clamps, and calls `onRequestNewTag?`. Left-click forwarded via `nextResponder` so SwiftUI DragGesture (scrubbing) is unaffected.
- **Task 2**: Added `@State private var isCreatingTag` and `newTagAnchorTime` to `SessionReviewScreen`. Wired `onRequestNewTag` closure in `SessionWaveformTimeline(...)` init. Presented `NewTagForm` via `.sheet(isPresented: $isCreatingTag)`.
- **Task 3**: Created `DictlyMac/Review/NewTagForm.swift` — 280pt compact form with auto-focused TextField, `@Query`-driven category picker (colored dots + checkmark), read-only timestamp display, Create (`.borderedProminent`, disabled on empty label) and Cancel buttons. Escape key cancels via `.keyboardShortcut(.cancelAction)`. Enter submits via `.onSubmit`.
- **Task 4**: `createTag(label:categoryName:)` in `SessionReviewScreen` inserts Tag with `rewindDuration: 0`, appends to `session.tags`, auto-selects via `selectedTag = tag`, dismisses sheet, logs via `taggingLogger`, and posts VoiceOver announcement.
- **Task 5**: "Add Tag" toolbar button with `.keyboardShortcut("t", modifiers: .command)` added to `sessionToolbar`. Uses `audioPlayer.currentTime` as anchor. Disabled when audio not loaded or duration is 0.
- **Task 6**: Accessibility labels/hints on all form elements; `accessibilityLabel` on right-click overlay; VoiceOver announcement posted after creation via `AccessibilityNotification.Announcement`.
- **Task 7**: `RetroactiveTagTests.swift` with 16 tests covering all 7.x subtasks using in-memory `ModelContainer` and `@MainActor` per project convention.

### File List

- `DictlyMac/Review/NewTagForm.swift` — NEW: compact tag creation form
- `DictlyMac/Review/SessionWaveformTimeline.swift` — MODIFIED: added `onRequestNewTag` callback, `RightClickOverlay`, `RightClickView`
- `DictlyMac/Review/SessionReviewScreen.swift` — MODIFIED: tag creation state, `createTag()`, sheet, Cmd+T button, `@Environment(\.modelContext)`
- `DictlyMacTests/ReviewTests/RetroactiveTagTests.swift` — NEW: 16 unit tests for retroactive tag creation
- `DictlyMac/DictlyMac.xcodeproj` — REGENERATED: xcodegen run to include new source files

### Review Findings

- [x] [Review][Dismiss] F1: Missing `)` on `clipShape` — false positive; actual file has correct `clipShape(RoundedRectangle(cornerRadius: 8))` at line 91
- [x] [Review][Patch] F2: `RightClickView` not `private` — leaks into module namespace [SessionWaveformTimeline.swift:~510] — fixed: added `private`
- [x] [Review][Dismiss] F4: `isCreatingTag = false` inside `createTag` closure — safe; SwiftUI batches state mutations until next render cycle
- [x] [Review][Patch] F7: Empty categories — `submitIfValid()` calls `onCreate` with `categoryName: ""` — fixed: guard in `submitIfValid` + Create button disabled when `effectiveCategory.isEmpty` [NewTagForm.swift:~95]
- [x] [Review][Patch] F8: Empty categories — no UI feedback in category section — fixed: added empty-state message when `categories.isEmpty` [NewTagForm.swift:~44]
- [x] [Review][Patch] F9: `newTagAnchorTime` race — fixed: `onCreate` now carries `anchorTime` as third param; `createTag` receives it directly; `isCreatingTag` guarded at both trigger sites [SessionReviewScreen.swift:~78,~178]
- [x] [Review][Patch] F12: `rightMouseDown` not forwarded — fixed: added `nextResponder?.rightMouseDown(with: event)` [SessionWaveformTimeline.swift:~515]
- [x] [Review][Patch] F20: Default label "New Tag" pre-fills without auto-select — fixed: empty string default, "New Tag" as placeholder [NewTagForm.swift:~18]
- [x] [Review][Defer] F13: `convert(event.locationInWindow, from: nil)` incorrect in multi-window scenarios [SessionWaveformTimeline.swift:~516] — deferred, only affects multi-window which is out of scope for this story

## Change Log

- 2026-04-02: Implemented retroactive tag placement (story 4-6). Added right-click waveform handler via NSViewRepresentable overlay, NewTagForm sheet for label + category input, SwiftData tag insertion with rewindDuration=0, Cmd+T keyboard shortcut, full accessibility pass, and 16 unit tests. All ACs satisfied: right-click opens form at timestamp (AC1), tag appears in sidebar and waveform (AC2), tag behaves identically to live tags — editable, deletable, searchable (AC3).
