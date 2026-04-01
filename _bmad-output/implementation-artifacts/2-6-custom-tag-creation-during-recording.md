# Story 2.6: Custom Tag Creation During Recording

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a DM,
I want to create a quick custom tag with a short label during recording,
So that I can tag unique moments that don't fit my preset categories.

## Acceptance Criteria (BDD)

### Scenario 1: Custom Tag Card Opens Sheet with Locked Timestamp

Given an active recording
When the DM taps the "+" custom tag card in the tag palette
Then a partial-height `.sheet` appears with a text field and a category picker
And the rewind-anchor timestamp is already locked from the initial "+" tap (timestamp-first)

### Scenario 2: Custom Tag Created at Original Anchor Time

Given the custom tag sheet is open
When the DM types "Grimthor -- blacksmith intro" and taps Save
Then a tag is created with that label at the originally captured anchor time (not the save time)
And the tag's `categoryName` matches the selected category
And haptic feedback fires on placement
And the tag count increments

### Scenario 3: Dismiss Without Label Discards Tag

Given the custom tag sheet is open
When the DM taps Cancel, taps outside the sheet, or swipes down without entering a label
Then the sheet closes
And no tag is created (the pre-captured anchor is discarded)

### Scenario 4: Dismiss With Label Saves Tag

Given the custom tag sheet is open with a non-empty label
When the DM swipes down or taps outside the sheet
Then the tag is saved with the entered label at the originally captured anchor time

### Scenario 5: Category Picker Defaults to Selected Category

Given the tag palette has "Combat" category tab selected
When the DM taps the "+" custom tag card
Then the category picker in the sheet defaults to "Combat"
And the DM can change the category before saving

### Scenario 6: Custom Tag Persists on Force-Quit

Given a custom tag has been saved
When the app is force-quit immediately after
Then the tag is persisted in SwiftData (zero tag loss)

## Tasks / Subtasks

- [ ] Task 1: Create `CustomTagSheet.swift` in `DictlyiOS/Tagging/` (AC: #1, #2, #3, #4, #5)
  - [ ] 1.1 Create new file `DictlyiOS/Tagging/CustomTagSheet.swift`. This is the ONLY new file in this story.
  - [ ] 1.2 Define `CustomTagSheet` as a SwiftUI `View` struct. Accept parameters: `selectedCategoryName: String` (default from TagPalette), `categories: [TagCategory]` (for the picker), `onSave: (String, String) -> Void` closure (passes `label`, `categoryName` back to TagPalette for placement). The sheet does NOT call `taggingService.placeTag()` directly -- the caller handles placement with the pre-captured anchor time.
  - [ ] 1.3 Layout: `NavigationStack` containing a `Form` with two sections:
    - Section 1: `TextField("Tag Name", text: $label)` with `.focused($isLabelFocused)` and auto-focus on appear via `.onAppear { isLabelFocused = true }`.
    - Section 2: `Picker("Category", selection: $categoryName)` iterating over `categories` array. Use `.pickerStyle(.menu)`. Each option shows the category name.
  - [ ] 1.4 Toolbar: Cancel button (`.cancellationAction`) calls `dismiss()`. Save button (`.confirmationAction`) calls `onSave(trimmedLabel, categoryName)` then `dismiss()`. Save disabled when `label.trimmingCharacters(in: .whitespaces).isEmpty`.
  - [ ] 1.5 Navigation title: "Custom Tag", display mode `.inline`.
  - [ ] 1.6 Use `@Environment(\.dismiss)` for sheet dismissal. Use `@FocusState` for keyboard auto-focus.
  - [ ] 1.7 VoiceOver: text field reads "Tag name. Enter a short label for this moment." Category picker reads "Category, [current value]."
  - [ ] 1.8 Presentation detents: `.presentationDetents([.medium])` for partial-height sheet.

- [ ] Task 2: Add "+" custom tag card and sheet integration to `TagPalette.swift` (AC: #1, #2, #3, #4, #5)
  - [ ] 2.1 Add `@State private var isShowingCustomTagSheet = false` to TagPalette.
  - [ ] 2.2 Add `@State private var capturedAnchorTime: TimeInterval?` to store the pre-captured rewind-anchor timestamp from the "+" tap.
  - [ ] 2.3 After the `ForEach(filteredTags)` block inside the `LazyVGrid` (after line 89), add a custom tag card `Button`. Style: dashed border (`RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))` in `DictlyColors.textSecondary`), "+" icon (`Image(systemName: "plus")`) centered, minimum 48pt height. Disable when `!isInteractive`.
  - [ ] 2.4 On "+" tap: (a) capture `capturedAnchorTime` using the same rewind formula as `placeTag` -- `max(0, taggingService.sessionRecorder.elapsedTime - rewindDuration)` -- but this requires the elapsed time. **Instead:** store `capturedRewindDuration = rewindDuration` and `capturedElapsedTime = Date()` -- NO. **Correct approach:** The `placeTag()` method reads `sessionRecorder.elapsedTime` internally. To achieve timestamp-first, we need `TaggingService` to expose a method to capture the current anchor. See Task 3.
  - [ ] 2.5 On "+" tap: call `taggingService.captureAnchor(rewindDuration: rewindDuration)` to lock the anchor time, then set `isShowingCustomTagSheet = true`.
  - [ ] 2.6 Add `.sheet(isPresented: $isShowingCustomTagSheet)` presenting `CustomTagSheet` with `selectedCategoryName: selectedCategory?.name ?? "Uncategorized"`, `categories: Array(categories)`, and `onSave` closure.
  - [ ] 2.7 In the `onSave` closure: call `taggingService.placeTagWithCapturedAnchor(label:, categoryName:, session:, context:)`. If success, post VoiceOver announcement: "Tag placed. \(count) tags total." On sheet dismiss without save, call `taggingService.discardCapturedAnchor()`.
  - [ ] 2.8 VoiceOver for "+" card: "Create custom tag. Double-tap to open tag creator."
  - [ ] 2.9 Add `.onDisappear` on the sheet to reset `capturedAnchorTime` to nil (cleanup).

- [ ] Task 3: Add anchor capture methods to `TaggingService.swift` (AC: #1, #2, #3)
  - [ ] 3.1 Add a private stored property: `private var capturedAnchor: (anchorTime: TimeInterval, actualRewind: TimeInterval)?`
  - [ ] 3.2 Add method `captureAnchor(rewindDuration: TimeInterval)`: calculates `anchorTime = max(0, sessionRecorder.elapsedTime - max(0, rewindDuration))` and `actualRewind = sessionRecorder.elapsedTime - anchorTime`, stores in `capturedAnchor`. Fires haptic immediately (the "+" tap IS the moment). Logs: `"Anchor captured at \(anchorTime) (rewound \(actualRewind)s) for custom tag"`.
  - [ ] 3.3 Add method `placeTagWithCapturedAnchor(label: String, categoryName: String, session: Session, context: ModelContext) -> Bool`: uses `capturedAnchor` values instead of reading `sessionRecorder.elapsedTime`. Creates `Tag` with stored `anchorTime` and `actualRewind`. Inserts, saves, logs, returns Bool. Clears `capturedAnchor` after use. Does NOT fire haptic again (already fired on capture).
  - [ ] 3.4 Add method `discardCapturedAnchor()`: sets `capturedAnchor = nil`. Logs: `"Captured anchor discarded (custom tag cancelled)"`.
  - [ ] 3.5 Guard in `placeTagWithCapturedAnchor`: if `capturedAnchor` is nil, log error and return false.

- [ ] Task 4: Add tests for custom tag anchor capture flow (AC: #1, #2, #3)
  - [ ] 4.1 Test: `testCaptureAnchor_storesCorrectAnchorTime()` -- set `recorder.elapsedTime = 120`, call `captureAnchor(rewindDuration: 10)`, verify stored anchor via `placeTagWithCapturedAnchor`.
  - [ ] 4.2 Test: `testPlaceTagWithCapturedAnchor_usesStoredAnchorNotCurrentTime()` -- capture anchor at elapsed 100, then change `recorder.elapsedTime = 200` (simulating time passing while typing), call `placeTagWithCapturedAnchor`. Verify tag's `anchorTime` is 90 (100-10), NOT 190 (200-10). This is the CRITICAL timestamp-first test.
  - [ ] 4.3 Test: `testPlaceTagWithCapturedAnchor_clearsCapturedAnchorAfterUse()` -- capture, place, then call `placeTagWithCapturedAnchor` again. Second call should return false (no anchor).
  - [ ] 4.4 Test: `testDiscardCapturedAnchor_clearsStoredAnchor()` -- capture, discard, then `placeTagWithCapturedAnchor` should return false.
  - [ ] 4.5 Test: `testPlaceTagWithCapturedAnchor_withoutCapture_returnsFalse()` -- call `placeTagWithCapturedAnchor` without prior capture. Should return false.
  - [ ] 4.6 Test: `testCaptureAnchor_earlyRecording_clampsToZero()` -- set `recorder.elapsedTime = 3`, `captureAnchor(rewindDuration: 10)`, verify anchorTime is 0 and actualRewind is 3.
  - [ ] 4.7 Test: `testPlaceTagWithCapturedAnchor_createsTagWithCorrectProperties()` -- verify label, categoryName, anchorTime, rewindDuration are all correct on the created tag.
  - [ ] 4.8 Test: `testPlaceTagWithCapturedAnchor_appendsTagToSession()` -- verify `session.tags` contains the new tag.
  - [ ] 4.9 Verify all existing tests (18 TaggingServiceTests + 139 DictlyKit) still pass.

- [ ] Task 5: Build verification (AC: all)
  - [ ] 5.1 Run `xcodegen generate` in `DictlyiOS/`.
  - [ ] 5.2 Run `xcodebuild` -- verify `** BUILD SUCCEEDED **`.
  - [ ] 5.3 Run full test suite -- verify `** TEST SUCCEEDED **`.

## Dev Notes

### Architecture: Timestamp-First Custom Tag Flow

The custom tag flow is Dictly's **2-tap interaction** (vs. 1-tap for preset tags). The critical insight is **timestamp-first**: the rewind-anchor is captured on the FIRST tap ("+"), not when the user finishes typing. This separates the time-critical action (capturing the moment) from the non-critical action (labeling it).

**Flow:**
```
DM taps "+" card
  → TaggingService.captureAnchor() fires immediately
    → anchorTime = max(0, elapsedTime - rewindDuration)
    → haptic fires (.medium impact)
  → CustomTagSheet presented as .sheet(.medium detent)
  → DM types label, selects category (takes as long as needed)
  → DM taps Save
    → TaggingService.placeTagWithCapturedAnchor(label, category)
    → Tag created with ORIGINAL anchorTime (not current time)
    → Sheet dismisses
  OR DM cancels/dismisses without label
    → TaggingService.discardCapturedAnchor()
    → No tag created
```

**Why not just call `placeTag()` when the sheet dismisses?** Because `placeTag()` reads `sessionRecorder.elapsedTime` at call time. If the DM takes 30 seconds to type a label, the anchor would be 30 seconds too late. The capture-then-place pattern preserves the moment.

[Source: ux-design-specification.md#Chosen-Direction, epics.md#Story-2.6]

### What to Create vs. Modify

| File | Action | Description |
|------|--------|-------------|
| `DictlyiOS/Tagging/CustomTagSheet.swift` | **CREATE** | New partial-height sheet with label field + category picker |
| `DictlyiOS/Tagging/TagPalette.swift` | Modify | Add "+" card to grid, sheet state, anchor capture flow |
| `DictlyiOS/Tagging/TaggingService.swift` | Modify | Add `captureAnchor`, `placeTagWithCapturedAnchor`, `discardCapturedAnchor` |
| `DictlyiOS/Tests/TaggingTests/TaggingServiceTests.swift` | Modify | Add 9 new tests for anchor capture flow |

No model changes. No package changes. No `project.yml` changes (XcodeGen auto-discovers new files in `Tagging/` source path).

### Current `TaggingService.placeTag()` Signature (unchanged)

```swift
@discardableResult
func placeTag(label: String, categoryName: String, rewindDuration: TimeInterval, session: Session, context: ModelContext) -> Bool
```

This method is NOT changed. The new `placeTagWithCapturedAnchor()` method handles the custom tag flow separately, reusing the same tag creation and persistence logic.

### New `TaggingService` Methods to Add

```swift
// Capture anchor time at the moment of "+" tap (timestamp-first)
func captureAnchor(rewindDuration: TimeInterval) { ... }

// Place tag using previously captured anchor (called from sheet's onSave)
@discardableResult
func placeTagWithCapturedAnchor(label: String, categoryName: String, session: Session, context: ModelContext) -> Bool { ... }

// Discard captured anchor (called on sheet cancel/dismiss-without-label)
func discardCapturedAnchor() { ... }
```

### Current `TagPalette.swift` Structure (key lines)

```swift
// Line 12: struct TagPalette: View
// Line 18: @Query ... allTags
// Line 23: @AppStorage("rewindDuration") private var rewindDuration: Double = 10.0
// Line 54: var body — VStack with CategoryTabBar + ScrollView > LazyVGrid
// Line 65-89: LazyVGrid with ForEach(filteredTags) { tag in TagCard(...) }
// Line 91: .padding(.bottom, ...)
```

The "+" custom tag card goes AFTER the `ForEach` block inside the `LazyVGrid` (after line 89, before line 90 closing brace of LazyVGrid). It appears as the last card in the grid regardless of selected category.

### "+" Card Visual Design

Per UX spec, the custom tag card uses:
- **Dashed border** (`StrokeStyle(lineWidth: 1.5, dash: [6])`) in `DictlyColors.textSecondary`
- **"+" icon** (`Image(systemName: "plus")`) centered, `DictlyColors.textSecondary`
- **No color stripe** (unlike standard TagCards)
- **Same height** as standard TagCards (`minHeight: DictlySpacing.minTapTarget` = 48pt)
- **Same grid cell size** (fills one grid column)
- **Ghost button style** per UX spec button hierarchy

[Source: ux-design-specification.md#TagCard-Variants, ux-design-specification.md#Button-Hierarchy]

### CustomTagSheet Design

- **Presentation:** `.sheet` with `.presentationDetents([.medium])` for partial-height
- **Form layout:** `NavigationStack > Form` — consistent with `TagFormSheet` pattern
- **Text field:** Auto-focused on appear. Short label, not a text editor.
- **Category picker:** `Picker` with `.menu` style, iterating over available `TagCategory` items. Defaults to currently selected category tab from TagPalette.
- **No "save as template" option** — custom tags during recording are one-time. Template management is in the Campaigns flow (Tag Category management). The tag is created as a session tag, NOT a template tag.
- **Keyboard:** auto-dismisses on tap outside via standard SwiftUI `.sheet` behavior

[Source: ux-design-specification.md#Modal-Patterns, architecture.md#CustomTagSheet]

### TagFormSheet as Reference (NOT to be reused directly)

`TagFormSheet.swift` (lines 1-63) handles template tag creation/editing in the Campaigns flow. It creates tags with `anchorTime: 0, rewindDuration: 0` and `session == nil` (templates). The custom tag sheet during recording is a DIFFERENT flow:
- Uses `onSave` callback instead of direct SwiftData insertion
- Does NOT create template tags
- Has a category picker (TagFormSheet does not)
- Called from recording screen, not campaigns

Do NOT import or extend `TagFormSheet`. Create `CustomTagSheet` as a separate, purpose-built component.

### Existing Infrastructure to Reuse

- **`TaggingService`** — `DictlyiOS/Tagging/TaggingService.swift` — extend with capture/place/discard methods
- **`Tag` model** — `DictlyKit/Sources/DictlyModels/Tag.swift` — no changes needed, `label`, `categoryName`, `anchorTime`, `rewindDuration` all present
- **`TagCategory` model** — `DictlyKit/Sources/DictlyModels/TagCategory.swift` — `name`, `colorHex`, `sortOrder` for picker display
- **`@AppStorage("rewindDuration")`** — already in `TagPalette`, reads configured rewind duration at tap time
- **`DictlyTheme`** — `DictlyColors.textSecondary` for dashed border, `DictlySpacing.minTapTarget` for height, `DictlySpacing.sm` for grid spacing
- **`UIImpactFeedbackGenerator(.medium)`** — already in `TaggingService`, fires on `captureAnchor()`
- **`os.Logger`** — existing logger in `TaggingService` with category `"tagging"`
- **`categories: [TagCategory]`** — already queried in `TagPalette` via `@Query(sort: \TagCategory.sortOrder)`

### What NOT to Build in This Story

- **Template tag creation** — custom tags during recording are session-only, not saved as reusable templates
- **Tag editing/deletion** — Mac-only (Epic 4)
- **Stop recording bar** — Story 2.7
- **Custom category creation from within the sheet** — out of scope, category management is in Campaigns flow
- **Rich text or multiline notes** — label is a simple single-line `TextField`
- **Tag card animation for custom tags** — the "+" card has no pressed scale/glow since it opens a sheet, not places a tag directly

### Swift 6 Strict Concurrency Notes

- `TaggingService` is already `@Observable @MainActor` — new methods inherit `@MainActor` isolation
- `capturedAnchor` is a private stored property on a `@MainActor` class — thread-safe
- `CustomTagSheet` is a SwiftUI View struct — `@MainActor` by default via SwiftUI
- No new async work introduced

### Edge Cases

1. **DM opens "+" during pause:** `isInteractive` is false when paused, so the "+" card is disabled (same as preset tags). No custom tag sheet during pause.
2. **DM opens "+" then recording stops externally:** The anchor is already captured. If the DM saves, the tag is created at the captured anchor. This is correct behavior — the moment was real.
3. **DM taps "+" multiple times rapidly:** The sheet is `.sheet(isPresented:)` — SwiftUI prevents multiple presentations. Second tap is ignored while sheet is open.
4. **Empty label on dismiss:** `onSave` is NOT called. `discardCapturedAnchor()` fires via `.onDismiss` of the sheet if no save occurred.
5. **Very long label:** `TextField` has no character limit. Labels can be any length. The `TagCard` in review will truncate with `lineLimit(2)`. This is acceptable.
6. **No categories exist:** The picker shows no options. Fall back to `"Uncategorized"` as the category name. This matches the architecture's "deleting a category does not delete its tags — reassign to Uncategorized" pattern.

### Logging

- `captureAnchor()`: `.info` — `"Anchor captured at \(anchorTime) (rewound \(actualRewind)s) for custom tag"`
- `placeTagWithCapturedAnchor()` success: `.info` — `"Custom tag placed: \(label) in \(categoryName) at \(anchorTime) (rewound \(actualRewind)s)"`
- `placeTagWithCapturedAnchor()` failure (save): `.error` — `"Failed to place custom tag: \(error)"`
- `placeTagWithCapturedAnchor()` failure (no anchor): `.error` — `"placeTagWithCapturedAnchor called without captured anchor"`
- `discardCapturedAnchor()`: `.info` — `"Captured anchor discarded (custom tag cancelled)"`

### Testing Strategy

Add 9 new tests to `TaggingServiceTests.swift` in a new `// MARK: - Story 2.6: Custom tag anchor capture` section. These test the 3 new `TaggingService` methods using the same in-memory SwiftData pattern as existing tests.

The **critical test** is `testPlaceTagWithCapturedAnchor_usesStoredAnchorNotCurrentTime` — it verifies that the tag's anchor reflects the capture moment, not the placement moment. This validates the entire timestamp-first design.

No UI tests for `CustomTagSheet` — the sheet is standard SwiftUI Form. Test the service logic.

All 18 existing `TaggingServiceTests` must continue to pass unchanged.

[Source: TaggingServiceTests.swift, Story 2.5 testing patterns]

### Previous Story Intelligence (from Story 2.5)

Key patterns and learnings from Story 2.5:
- **`TaggingService` is `@Observable @MainActor final class`** — new methods inherit this
- **`placeTag()` returns `Bool`** — `true` on success, `false` on save failure. Rolls back on failure. Follow same pattern for `placeTagWithCapturedAnchor()`.
- **`@AppStorage("rewindDuration")`** reads at tap time — already established in `TagPalette`
- **Haptic fires immediately on tag action** — for custom tags, haptic fires on `captureAnchor()` (the "+" tap), NOT on `placeTagWithCapturedAnchor()` (the Save tap)
- **Rewind formula:** `anchorTime = max(0, elapsedTime - max(0, rewindDuration))` — reuse same formula in `captureAnchor()`
- **Review finding from 2.5:** "Story 2.6 API gap: placeTag reads elapsedTime internally, custom tag sheet needs pre-captured timestamp" — this story resolves this gap with `captureAnchor()`/`placeTagWithCapturedAnchor()`
- **Build process:** Run `xcodegen generate` in `DictlyiOS/` after adding new file, then `xcodebuild`
- **Test count:** 18 TaggingServiceTests + 139 DictlyKit currently passing

### Git Intelligence

Recent commits follow `feat(tagging):` / `fix(tagging):` prefix:
- `d1270c1` — fix(tagging): apply review fixes for story 2.5 rewind-anchor tagging
- `39c44f8` — feat(tagging): implement rewind-anchor tag placement with configurable duration (story 2.5)

Use commit prefix: `feat(tagging): implement custom tag creation during recording with timestamp-first flow (story 2.6)`

### Project Structure Notes

- 1 new file: `DictlyiOS/Tagging/CustomTagSheet.swift` — auto-discovered by XcodeGen from `Tagging/` source path in `project.yml`
- No changes to `project.yml` or `Package.swift`
- No new framework dependencies
- `@AppStorage` key `"rewindDuration"` already exists (Story 2.5) — no new UserDefaults keys

### References

- [Source: epics.md#Story-2.6] — AC, user story, custom tag requirements
- [Source: prd.md#FR10] — DM can create a custom tag with short text input during recording
- [Source: architecture.md#CustomTagSheet] — CustomTagSheet.swift in Tagging/ folder, maps to FR10
- [Source: architecture.md#FR7-FR13-Mapping] — TaggingService owns FR7 (single tap), FR8 (rewind anchor), FR10 (custom tag via CustomTagSheet), FR11 (haptic)
- [Source: ux-design-specification.md#Chosen-Direction] — Timestamp-first interaction model, custom tag = 2 taps
- [Source: ux-design-specification.md#Experience-Mechanics] — Custom path: tap "+", type label, dismiss (5-10s)
- [Source: ux-design-specification.md#TagCard-Variants] — Custom tag card: dashed border, "+" icon
- [Source: ux-design-specification.md#Modal-Patterns] — Custom tag input: .sheet (partial height) on iOS
- [Source: ux-design-specification.md#Button-Hierarchy] — Ghost style: dashed border, muted for additive actions
- [Source: ux-design-specification.md#Accessibility] — 48pt min tap targets, VoiceOver labels, Dynamic Type
- [Source: 2-5-rewind-anchor-tagging-and-timestamp-first-interaction.md] — Previous story patterns, TaggingService API, review finding about Story 2.6 API gap

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
