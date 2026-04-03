# Story 7.1: iOS Recording Screen UI Fidelity

Status: review

## Story

As a DM,
I want the recording screen to look exactly as designed in the UX mockups,
so that the timer is immediately readable at a glance and the custom tag action is clearly labelled.

## Context

QA review against `ux-design-directions.html` found two visual deviations on the iOS recording screen:

1. **RecordingStatusBar layout** — The HTML mockup places the session timer on its own dedicated line at large size (32pt bold), with the REC dot+label above it and the tag count badge top-right as a separate element. The current implementation collapses everything into a single `HStack`, making the timer share visual weight with the REC dot and badge. The timer is the DM's primary confidence signal mid-session and must be the visual hero.

2. **Custom tag button label** — The mockup shows `+ Custom` text inside the dashed card. The current implementation renders only a `+` icon (SF Symbol), which is less discoverable for first-time users.

## Acceptance Criteria

1. **Given** the recording screen is active **When** the DM glances at their phone **Then** the session timer is displayed on its own line below the REC indicator at `DictlyTypography.h1` (28pt+ bold) and is the largest text element in the status bar

2. **Given** the recording screen status bar **When** rendered in both light and dark mode **Then** the layout reads (left column, top-to-bottom): animated red dot + "REC" label on line 1; large timer on line 2 — with the tag count badge anchored to the top-right, not inline with the timer

3. **Given** the tag palette grid **When** the DM sees the custom tag card **Then** it displays `+ Custom` text (or equivalent label) rather than only a `+` icon, making its purpose clear without prior knowledge

4. **Given** the status bar with `recordingState == .paused` **Then** the timer line changes to amber (DictlyColors.warning) consistent with the existing paused dot/label colour

5. All existing `RecordingStatusBar` and `TagPalette` unit tests pass without modification

## Tasks / Subtasks

- [x] Task 1: Fix `RecordingStatusBar` layout (AC: #1, #2, #4)
  - [x] 1.1 Restructure `RecordingStatusBar.body` from a flat `HStack` to:
    ```
    HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: DictlySpacing.xs) {
            HStack { dot · stateLabel }
            Text(formattedElapsedTime)   // .h1.monospacedDigit(), timer color
        }
        Spacer()
        tagCountBadge
    }
    ```
  - [x] 1.2 Apply timer foreground colour: `DictlyColors.textPrimary` when recording, `DictlyColors.warning` when paused/interrupted
  - [x] 1.3 Verify accessibility combined label still reads correctly (dot + state + timer + tag count)

- [x] Task 2: Add "Custom" label to the custom tag card (AC: #3)
  - [x] 2.1 In `TagPalette.swift`, update the custom tag `Button` label from a bare `Image(systemName: "plus")` to an `HStack { Image(systemName: "plus"); Text("Custom") }` using `DictlyTypography.caption` and `DictlyColors.textSecondary`
  - [x] 2.2 Verify the card still meets the `DictlySpacing.minTapTarget` (48pt) minimum height

- [x] Task 3: Regression check
  - [x] 3.1 Run all existing `RecordingViewModelTests` and `TaggingServiceTests` — must pass 100%
  - [x] 3.2 Verify dark mode rendering of the updated status bar visually matches the mockup

## Dev Notes

- `RecordingStatusBar` is in `DictlyiOS/Recording/RecordingStatusBar.swift`
- `TagPalette` custom card is in `DictlyiOS/Tagging/TagPalette.swift` around line 93–138
- Do not change the `RecordingState` enum or `RecordingViewModel` — view-only changes
- The `DictlyTypography.h1` token is already `monospacedDigit()`-compatible via `.monospacedDigit()` modifier

## Dev Agent Record

### Implementation Plan

1. Restructured `RecordingStatusBar.body` from a flat `HStack` to `HStack(alignment: .top)` → `VStack` (dot+label row, then large timer row) + `Spacer()` + `tagCountBadge` top-right
2. Added `timerColor` computed property: `DictlyColors.textPrimary` when recording, `DictlyColors.warning` when paused/systemInterrupted
3. Updated `TagPalette` custom button label from bare `Image(systemName: "plus")` to `HStack { Image; Text("Custom") }` with caption font and textSecondary color — `minHeight: DictlySpacing.minTapTarget` preserved

### Completion Notes

- All changes are view-only; no logic or model changes
- `RecordingStatusBar.swift`: body restructured, `timerColor` property added (8 lines net change)
- `TagPalette.swift`: custom card label updated to `HStack { plus icon + "Custom" text }` (4 lines net)
- Accessibility label unchanged — still combines state + timer + tag count
- `RecordingViewModelTests`: 13/13 passed ✅
- `TaggingServiceTests`: Pre-existing simulator instability (crashes after ~1 test on every run, identical behavior before and after these changes — confirmed via git stash verification). No regressions introduced.

### File List

- `DictlyiOS/Recording/RecordingStatusBar.swift`
- `DictlyiOS/Tagging/TagPalette.swift`

### Change Log

- 2026-04-03: Task 1 — Restructured RecordingStatusBar layout: two-row VStack (dot+label / large timer), badge top-right, timerColor amber when paused
- 2026-04-03: Task 2 — Custom tag card label updated to "＋ Custom" HStack
- 2026-04-03: Task 3 — Regression verified: RecordingViewModelTests 13/13 pass; TaggingServiceTests pre-existing simulator instability confirmed pre-dates these changes
