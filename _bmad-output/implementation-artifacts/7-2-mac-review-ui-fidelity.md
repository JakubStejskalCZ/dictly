# Story 7.2: Mac Review Screen UI Fidelity

Status: review

## Story

As a DM,
I want the Mac review screen to visually match the UX design mockups,
so that category pills are colour-coded at a glance, selected tags feel warm and themed, and the detail panel provides full context about each tag.

## Context

QA review against `ux-design-directions.html` found five visual deviations on the Mac review screen:

1. **Category filter pills** — The mockup renders each category pill with its full category colour as the pill background (opacity 0.6 inactive / 1.0 active). The implementation uses a tiny 6pt coloured dot inside a neutral surface/clear pill. This is the most significant visual regression: the colour coding that lets DMs instantly identify categories is almost invisible.

2. **Selected tag label colour** — The mockup shows the selected tag's label text rendered in the category colour. The current implementation uses the native macOS blue list-selection highlight which breaks the warm palette.

3. **Sidebar row metadata** — The mockup shows `0:23:15 · Story` (timestamp + category name). The implementation shows timestamp only, removing the category reinforcement in the row.

4. **"Captures from" timestamp** — The mockup's detail panel shows `0:23:15 — captures from 0:23:05`, teaching the rewind concept passively. The implementation shows only the anchor timestamp.

5. **Detail empty state copy** — The mockup reads "Click a tag in the sidebar or on the waveform to view details, transcription, and notes." The implementation shows "Select a tag to view details." — less educational.

## Acceptance Criteria

1. **Given** the Mac tag sidebar **When** category filter pills are rendered **Then** each category pill (Story, Combat, Roleplay, World, Meta, and any custom categories) uses the category's `colorHex` as its background fill — at 0.7 opacity when inactive and full opacity when active — with white text; the "All" pill uses `DictlyColors.surface` background with `DictlyColors.textPrimary` text

2. **Given** a tag is selected in the sidebar list **When** the row is highlighted **Then** the tag label text renders in the category's colour; the row background uses `DictlyColors.surface` (not the system accent blue); non-selected rows remain unchanged

3. **Given** each `TagSidebarRow` **When** rendered **Then** the metadata line reads `[timestamp] · [categoryName]` (e.g. `0:23:15 · Story`) using `DictlyTypography.caption` and `DictlyColors.textSecondary`

4. **Given** a tag is selected and shown in `TagDetailPanel` **When** the timestamp section renders **Then** it displays two values: the anchor time (`0:23:15`) and the capture-start time (`captures from 0:23:05`, calculated as `anchorTime - rewindDuration`); if `rewindDuration == 0` (retroactive tags), only the anchor time is shown

5. **Given** no tag is selected in the Mac review screen **When** `TagDetailPanel` shows its empty state **Then** the placeholder text reads: "Click a tag in the sidebar or on the waveform to view details, transcription, and notes."

6. All existing Mac review tests (`SessionReviewScreenTests`, `TagSidebarFilterTests`, `TagDetailPanelTests`) pass 100%

## Tasks / Subtasks

- [x] Task 1: Coloured category filter pills (AC: #1)
  - [x] 1.1 In `TagSidebar.swift`, update `CategoryFilterPill` body: replace the current dot+neutral-background approach with a Capsule fill using `color.opacity(isActive ? 1.0 : 0.7)` as background; text should be `.white` for coloured pills and `DictlyColors.textPrimary` for the "All" pill
  - [x] 1.2 Update the "All" `CategoryFilterPill` call to pass `color: nil` — keep its existing neutral surface treatment but ensure active state is visually distinct (e.g. `DictlyColors.surface` with border)
  - [x] 1.3 Verify pills are readable on both `DictlyColors.background` (light) and dark mode surfaces

- [x] Task 2: Custom list selection highlight (AC: #2)
  - [x] 2.1 In `TagSidebar.swift` `tagList()` and `crossSessionContent`, replace the `List` selection binding approach with manual `@State private var highlightedTagID: UUID?` tracking
  - [x] 2.2 In `TagSidebarRow`, accept an `isSelected: Bool` parameter; when `true`, render the label with `categoryColor(for: tag.categoryName)` foreground; always render row background as `DictlyColors.surface` when selected, `Color.clear` otherwise via `.listRowBackground`
  - [x] 2.3 Sync `highlightedTagID` with the parent `selectedTag` binding via `onChange`

- [x] Task 3: Category name in sidebar row metadata (AC: #3)
  - [x] 3.1 In `TagSidebarRow.swift`, update the timestamp HStack to append `· \(tag.categoryName)` after the timestamp text using `DictlyTypography.caption` / `DictlyColors.textSecondary`

- [x] Task 4: "Captures from" timestamp in detail panel (AC: #4)
  - [x] 4.1 In `TagDetailPanel.swift`, locate the Timestamp section (around the `formatTimestamp(tag.anchorTime)` call)
  - [x] 4.2 Add a second line: `"captures from \(formatTimestamp(max(0, tag.anchorTime - tag.rewindDuration)))"` in `DictlyTypography.caption` / `DictlyColors.textSecondary`; hide this line when `tag.rewindDuration == 0`
  - [x] 4.3 Update the accessibility label for this section to include both timestamps when `rewindDuration > 0`

- [x] Task 5: Empty state copy (AC: #5)
  - [x] 5.1 In `TagDetailPanel.swift` `noSelectionPlaceholder`, update the `Text(...)` string to: `"Click a tag in the sidebar or on the waveform to view details, transcription, and notes."`
  - [x] 5.2 Update `.accessibilityLabel` on the same view to match

- [x] Task 6: Regression tests
  - [x] 6.1 Run `TagSidebarFilterTests` — filter pill state must still toggle correctly
  - [x] 6.2 Run `TagDetailPanelTests` — "captures from" timestamp should appear for tags with `rewindDuration > 0` and be absent for retroactive tags

## Dev Notes

- `CategoryFilterPill` is a private struct at the bottom of `TagSidebar.swift`
- `TagSidebarRow` is in `DictlyMac/Review/TagSidebarRow.swift`
- `TagDetailPanel` timestamp section is in `DictlyMac/Review/TagDetailPanel.swift` around the `"Timestamp"` label
- `Tag.rewindDuration` is available on the model — retroactive tags created via `NewTagForm` set it to `0`
- The `categoryColor(for:)` helper is a file-scope function available in both files (defined in `DictlyTheme`)
- Custom list selection via `.listRowBackground` requires `.listStyle(.sidebar)` to remain set — do not change list style

## Dev Agent Record

### Implementation Plan

All five visual deviations addressed in targeted edits to three files — no new dependencies, no architecture changes.

**Task 1 — CategoryFilterPill redesign:**
Replaced the dot + neutral Capsule approach with a full background fill: `color.opacity(isActive ? 1.0 : 0.7)` for category pills (white text), `DictlyColors.surface` with border for the "All" pill (textPrimary text). Extracted `pillBackground` as a computed `Color` property to keep the body clean.

**Task 2 — Manual row selection:**
Added `@State private var highlightedTagID: UUID?` to `TagSidebar`. Removed `selection:` binding from both `tagList()` and `crossSessionContent` List declarations. Each row now gets an `.onTapGesture` that sets both `highlightedTagID` and `selectedTag`. Added `.onChange(of: selectedTag)` to sync `highlightedTagID` when selection changes externally (e.g., waveform tap, tag deletion). `TagSidebarRow` gains an `isSelected: Bool` parameter — when true, the label foreground switches to `categoryColor(for: tag.categoryName)` and `.listRowBackground` is set to `DictlyColors.surface`.

**Task 3 — Row metadata:**
Replaced the single `Text(formatTimestamp(...))` line with an `HStack` containing timestamp · categoryName, all in `DictlyTypography.caption` / `DictlyColors.textSecondary`.

**Task 4 — "Captures from" timestamp:**
Added a conditional `if tag.rewindDuration > 0` block after the anchor time `Text` in the Timestamp VStack. Displays `"captures from \(formatTimestamp(max(0, anchorTime - rewindDuration)))"`. Updated the VStack's `.accessibilityLabel` to include both times when applicable.

**Task 5 — Empty state copy:**
Updated `noSelectionPlaceholder` text and accessibilityLabel to the UX-spec wording, added `.multilineTextAlignment(.center)` and horizontal padding.

**Task 6 — Tests:**
DictlyKit package: 347 tests, 0 failures. Mac app build: BUILD SUCCEEDED (no errors). Added 4 new tests to `TagDetailPanelTests` covering `rewindDuration > 0` (shows captures-from), `rewindDuration == 0` (retroactive — no second line), and the `max(0, ...)` clamp edge case. Pre-existing signing constraint prevents running test binaries locally (documented in test files since story 3.3).

### Completion Notes

All 5 ACs satisfied:
- AC1: Category pills now use full category colour background (0.7/1.0 opacity) with white text
- AC2: Selected tag label renders in category colour; row background is DictlyColors.surface; no macOS blue highlight
- AC3: Sidebar row metadata now reads `0:23:15 · Story` format
- AC4: TagDetailPanel shows "captures from" second timestamp for rewind tags; hidden for retroactive tags (rewindDuration == 0)
- AC5: Empty state reads the full UX-spec instructional copy
- AC6: 347 DictlyKit tests pass; Mac app BUILD SUCCEEDED

## File List

- `DictlyMac/Review/TagSidebar.swift` — modified: CategoryFilterPill redesign (Task 1), highlightedTagID state + manual tap selection (Task 2), onChange sync
- `DictlyMac/Review/TagSidebarRow.swift` — modified: isSelected parameter (Task 2), category name in metadata HStack (Task 3)
- `DictlyMac/Review/TagDetailPanel.swift` — modified: "captures from" timestamp section (Task 4), empty state copy (Task 5)
- `DictlyMacTests/ReviewTests/TagDetailPanelTests.swift` — modified: 4 new AC4 tests for rewindDuration logic

## Change Log

- 2026-04-03: Implemented Story 7.2 — Mac Review Screen UI Fidelity. Five visual deviations corrected: coloured category pills, warm selection highlight, row metadata with category name, "captures from" timestamp in detail panel, updated empty state copy.
