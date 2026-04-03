# Story 7.3: Design System Compliance — Fix Hardcoded Colours & Theme Bypasses

Status: ready-for-dev

## Story

As a DM,
I want the entire app to feel visually consistent across every screen,
so that the warm, calm aesthetic holds even in Settings and Preferences.

## Context

QA review found several locations where `DictlyTheme` tokens are bypassed entirely or where hardcoded system colours break the warm palette:

1. **`ModelManagementView`** (Mac) — Zero `DictlyTheme` usage. Uses `.headline`, `.subheadline`, `Color.secondary`, `Color.red`, `Color.accentColor`, and hardcoded spacing (2, 4, 5, 6, 8, 12pt). Completely visually inconsistent with the rest of the app.

2. **`PreferencesWindow` / `StoragePreferencesTab`** (Mac) — Same issue. Uses `Color(nsColor: .controlBackgroundColor)`, system font scales, hardcoded table column widths, and `Color.red` for destructive actions.

3. **Swipe action tints** — `CampaignDetailScreen`, `TagCategoryListScreen`, and `TagListScreen` use `.tint(.indigo)` and `.tint(.blue)` on swipe actions. These are cold system colours that contradict the warm palette.

4. **`TagDetailPanel` category badge** — The `categoryBadge()` function hardcodes `["story", "combat", "roleplay", "world", "meta"]` to decide whether to render a coloured vs. neutral badge. Any user-created custom category will always get a neutral grey badge regardless of its configured `colorHex`.

5. **`ExportSheet` error text** — Uses `Color.red` instead of `DictlyColors.destructive`.

6. **`SearchResultRow` highlight colour** — Uses `Color.accentColor` for transcription snippet highlights instead of a DictlyTheme token.

## Acceptance Criteria

1. **Given** the Mac Preferences window (Whisper model management tab) **When** rendered **Then** all text uses `DictlyTypography` tokens, all colours use `DictlyColors` tokens, and spacing follows `DictlySpacing` — the view is visually indistinguishable in style from the rest of the Mac app

2. **Given** the Mac Preferences window (Storage/Recordings tab) **When** rendered **Then** same as AC #1 — no raw `Color(nsColor:)` or system font modifiers

3. **Given** swipe actions on session rows, tag category rows, and tag rows **When** rendered on iOS **Then** no swipe action uses `.tint(.indigo)`, `.tint(.blue)`, or any hardcoded system colour; AirDrop/transfer actions use a neutral or DictlyTheme-appropriate tint

4. **Given** a tag in `TagDetailPanel` whose category is a user-created custom category (not one of the five defaults) **When** the category badge renders **Then** it uses that category's configured `colorHex` as the badge background with white text — identical treatment to built-in categories

5. **Given** an export error in `ExportSheet` **When** the error message renders **Then** it uses `DictlyColors.destructive` not `Color.red`

6. **Given** a search result with a transcription snippet in `SearchResultRow` **When** the highlighted term renders **Then** it uses `DictlyColors.recordingActive` or `DictlyColors.textPrimary` (not `Color.accentColor`) for the highlight colour — a token-based choice that remains warm in both light and dark mode

7. All existing tests pass 100%

## Tasks / Subtasks

- [ ] Task 1: Migrate `ModelManagementView` to DictlyTheme (AC: #1)
  - [ ] 1.1 Add `import DictlyTheme` to `DictlyMac/Transcription/ModelManagementView.swift`
  - [ ] 1.2 Replace system font calls (`.headline`, `.subheadline`, `.caption`, `.title3`) with `DictlyTypography` equivalents: `.h3`, `.body`, `.caption`, `.h2` respectively
  - [ ] 1.3 Replace `Color.secondary` with `DictlyColors.textSecondary`; `Color.red` with `DictlyColors.destructive`; `Color.accentColor` with `DictlyColors.recordingActive`
  - [ ] 1.4 Replace `Color(nsColor: .controlBackgroundColor)` header background with `DictlyColors.surface`
  - [ ] 1.5 Replace hardcoded padding/spacing values (2, 4, 5, 6, 8, 12pt) with `DictlySpacing` tokens (`.xs`=4, `.sm`=8, `.md`=16)
  - [ ] 1.6 Replace hardcoded widths (24, 80, 100, 200pt) with named constants or `DictlySpacing` multiples where semantically appropriate; leave layout-structural widths (column widths) as-is if no token maps cleanly

- [ ] Task 2: Migrate `PreferencesWindow` / `StoragePreferencesTab` to DictlyTheme (AC: #2)
  - [ ] 2.1 Add `import DictlyTheme` to `DictlyMac/Settings/PreferencesWindow.swift`
  - [ ] 2.2 Replace `Color(nsColor: .controlBackgroundColor)` with `DictlyColors.surface`
  - [ ] 2.3 Replace system fonts (`.headline`, `.subheadline`, `.body`, `.title3`) with `DictlyTypography` equivalents
  - [ ] 2.4 Replace `Color.secondary` with `DictlyColors.textSecondary`; `Color.red` with `DictlyColors.destructive`
  - [ ] 2.5 Replace hardcoded delete column width `60` with `DictlySpacing.minTapTarget` (48pt) — adjust if needed for layout

- [ ] Task 3: Fix swipe action tints (AC: #3)
  - [ ] 3.1 In `CampaignDetailScreen.swift`, change AirDrop swipe action `.tint(.indigo)` to `.tint(DictlyColors.meta)` (slate blue — thematically appropriate for a transfer action)
  - [ ] 3.2 Change Rename swipe action `.tint(.blue)` to `.tint(DictlyColors.textSecondary)` (neutral, non-destructive)
  - [ ] 3.3 Apply the same fix to any `.tint(.blue)` on Rename/Edit swipe actions in `TagCategoryListScreen.swift` and `TagListScreen.swift`

- [ ] Task 4: Fix `categoryBadge()` in `TagDetailPanel` (AC: #4)
  - [ ] 4.1 In `TagDetailPanel.swift`, remove the `isKnownCategory` check against the hardcoded string list
  - [ ] 4.2 Replace with: always use `categoryColor(for: categoryName)` as the badge background (which already handles unknown categories gracefully via `DictlyColors.textSecondary` fallback) with white text
  - [ ] 4.3 The resulting badge will correctly render any category — built-in or custom — using its configured colour

- [ ] Task 5: Fix `ExportSheet` and `SearchResultRow` colours (AC: #5, #6)
  - [ ] 5.1 In `ExportSheet.swift`, replace `Color.red` with `DictlyColors.destructive` on the error text
  - [ ] 5.2 In `SearchResultRow.swift`, replace `Color.accentColor` with `DictlyColors.recordingActive` for transcription snippet highlights

- [ ] Task 6: Regression check
  - [ ] 6.1 Run all Mac tests (`ReviewTests`, `SearchTests`, `TranscriptionTests`) — must pass 100%
  - [ ] 6.2 Visual check: Preferences window in both light and dark mode should feel warm and consistent with the rest of the app

## Dev Notes

- `DictlyColors.meta` = `#4B7BE5` (slate blue) — appropriate for AirDrop/transfer which is a neutral utility action
- `categoryColor(for:)` in `TagDetailPanel` resolves via a `@Query` on `TagCategory` — it already returns `DictlyColors.textSecondary` as a fallback for unrecognised names, but the badge logic was overriding it with the hardcoded list
- The `ModelManagementView` migration is high surface area but mechanically simple — find/replace font and colour calls
- Do not change the functional behaviour of `ModelManagementView` (download, delete, select actions) — styling only
