# Story 4.4: Tag Sidebar with Category Filtering

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a DM,
I want a scrollable tag list in the sidebar with category filters,
so that I can quickly find and navigate to specific tags.

## Acceptance Criteria

1. **Given** an imported session with tags, **when** the sidebar displays, **then** all tags are listed chronologically with category color dot, label, and timestamp.

2. **Given** category filter pills below the search bar, **when** the DM activates one or more category filters, **then** the sidebar list shows only tags matching the selected categories, **and** waveform markers for unselected categories dim to reduced opacity.

3. **Given** a tag in the sidebar, **when** the DM clicks it, **then** the waveform jumps to that tag's position, the tag marker highlights, and the detail panel populates.

4. **Given** filter state, **when** the DM switches to a different session, **then** filters reset to show all categories.

## Tasks / Subtasks

- [x] Task 1: Replace placeholder search bar with functional search field and category filter pills (AC: #1, #2)
  - [x] 1.1 In `TagSidebar.swift`, replace the static placeholder `HStack` (lines 16-30) with a real `TextField("Search tags", text: $searchText)` bound to new `@State private var searchText: String = ""`
  - [x] 1.2 Add `@Query(sort: \TagCategory.sortOrder) private var categories: [TagCategory]` to fetch all tag categories from SwiftData
  - [x] 1.3 Below the search field, add a horizontally scrollable row of category filter pills using `ScrollView(.horizontal)` + `HStack`
  - [x] 1.4 Each pill: colored dot (6pt circle using `categoryColor(for:)`) + category name (`DictlyTypography.caption`), wrapped in `Button`
  - [x] 1.5 Use `@State private var activeCategories: Set<String> = []` — empty means "show all" (no filter), non-empty means filter to selected
  - [x] 1.6 Tapping a pill toggles its category name in `activeCategories`; re-tapping removes it
  - [x] 1.7 Add an "All" pill at the start that clears `activeCategories` to `[]`; highlight it when set is empty
  - [x] 1.8 Style active pills with `DictlyColors.surface` background and `DictlyColors.textPrimary` text; inactive pills with `Color.clear` background and `DictlyColors.textSecondary` text; use `Capsule()` clipShape
  - [x] 1.9 Accessibility: each pill reads "[Category] filter. [count] tags." with `.accessibilityAddTraits(isSelected ? .isSelected : [])` for active state

- [x] Task 2: Filter sidebar tag list by active categories and search text (AC: #1, #2)
  - [x] 2.1 Update `sortedTags` computed property: start with `session.tags.sorted { $0.anchorTime < $1.anchorTime }`
  - [x] 2.2 If `activeCategories` is non-empty, filter to tags where `activeCategories.contains(tag.categoryName)`
  - [x] 2.3 If `searchText` is non-empty (trimmed), further filter to tags where `tag.label.localizedCaseInsensitiveContains(searchText)`
  - [x] 2.4 Update the tag count displayed per category pill: count of `session.tags` (unfiltered) matching each category
  - [x] 2.5 Update empty state: if filters/search produce no results but session has tags, show "No matching tags. Try adjusting your filters." instead of the retroactive-tag prompt

- [x] Task 3: Expose active filter state to `SessionWaveformTimeline` for marker dimming (AC: #2)
  - [x] 3.1 Add `activeCategories: Set<String>` parameter to `TagSidebar` initializer (binding from parent) — change from `@State` to `@Binding var activeCategories: Set<String>`
  - [x] 3.2 In `SessionReviewScreen`, add `@State private var activeCategories: Set<String> = []` and pass as binding to `TagSidebar`
  - [x] 3.3 Pass `activeCategories` to `SessionWaveformTimeline` as a new `let activeCategories: Set<String>` parameter
  - [x] 3.4 In `SessionWaveformTimeline.tagMarkersLayer`, when `activeCategories` is non-empty: markers whose `tag.categoryName` is NOT in `activeCategories` render at 25% opacity; markers in `activeCategories` render at full (75% default / 100% selected) opacity
  - [x] 3.5 When `activeCategories` is empty (no filter), all markers render at normal opacity (existing behavior)

- [x] Task 4: Reset filters on session change (AC: #4)
  - [x] 4.1 In `SessionReviewScreen`, add `.onChange(of: session)` (or key off `session.uuid`) to reset `activeCategories = []` and propagate to sidebar
  - [x] 4.2 Also reset `searchText` in `TagSidebar` — add `let sessionID: UUID` parameter and use `.onChange(of: sessionID)` to reset `searchText = ""` and clear filters

- [x] Task 5: Tag sidebar click triggers waveform jump, marker highlight, and detail panel (AC: #3)
  - [x] 5.1 Verify existing behavior: `selectedTag` binding already wires sidebar selection to `SessionReviewScreen.selectedTag`, which triggers `.onChange(of: selectedTag)` → `audioPlayer.seek(to:)` + `audioPlayer.play()` (story 4.3), marker highlight in `SessionWaveformTimeline`, and `TagDetailPanel(tag: selectedTag)`. **No new code needed if existing wiring works.**
  - [x] 5.2 If tag is filtered out (not visible in sidebar), clicking a waveform marker should still select it and show detail — filtering is sidebar-only, waveform markers remain clickable at reduced opacity

- [x] Task 6: Accessibility for filter interactions (AC: #2)
  - [x] 6.1 Filter pill row: wrap in `.accessibilityElement(children: .contain)` with label "Category filters"
  - [x] 6.2 Each pill: `.accessibilityLabel("[Category] filter. [count] tags.")` and `.accessibilityAddTraits(isActive ? .isSelected : [])`
  - [x] 6.3 "All" pill: `.accessibilityLabel("All categories. \(session.tags.count) tags total.")`
  - [x] 6.4 Search field: `.accessibilityLabel("Search tags by name")`
  - [x] 6.5 When filter changes, consider posting `AccessibilityNotification.LayoutChanged` so VoiceOver re-reads the updated list
  - [x] 6.6 Sidebar tag count summary: add `.accessibilityLabel("Showing \(filteredCount) of \(totalCount) tags")` to the list container

- [x] Task 7: Unit tests (AC: #1, #2, #3, #4)
  - [x] 7.1 Create `TagSidebarFilterTests.swift` in `DictlyMacTests/ReviewTests/`
  - [x] 7.2 Test: no active categories → all tags shown (default state)
  - [x] 7.3 Test: single category active → only matching tags shown
  - [x] 7.4 Test: multiple categories active → tags from all selected categories shown
  - [x] 7.5 Test: search text filters by label (case-insensitive)
  - [x] 7.6 Test: combined category + search filter works correctly
  - [x] 7.7 Test: marker opacity logic — `activeCategories` non-empty, tag in set → normal opacity; tag not in set → 0.25
  - [x] 7.8 Test: marker opacity logic — `activeCategories` empty → all normal opacity
  - [x] 7.9 Use `@MainActor`, in-memory `ModelContainer` with `ModelConfiguration(isStoredInMemoryOnly: true)` (project convention)

## Dev Notes

### Core Architecture

This story transforms the existing placeholder `TagSidebar` into a functional filtering component. The main changes are:

1. **TagSidebar.swift** — Major rewrite: replace placeholder search with real `TextField`, add category filter pills, filter logic
2. **SessionReviewScreen.swift** — Minor: add `activeCategories` state, pass to sidebar and waveform, reset on session change
3. **SessionWaveformTimeline.swift** — Minor: accept `activeCategories` parameter, dim unfiltered markers

The sidebar click → waveform jump → detail panel flow is **already fully wired** from stories 4.1-4.3. AC #3 should work without new code — verify during implementation.

### Filter State Design

```
activeCategories: Set<String>  — empty = show all (no filter), non-empty = whitelist
searchText: String             — empty = no text filter, non-empty = label substring match
```

Both filters compose: a tag must pass BOTH category filter AND search text to appear in the sidebar. Waveform markers only respond to category filter (not search text).

### Category Filter Pills Pattern

Mac category filtering uses **multi-select pills** (not single-select like iOS `CategoryTabBar`). Multiple categories can be active simultaneously. Spec reference: "Filter pills below search. Multiple categories active simultaneously."

```swift
// Pill layout inside TagSidebar
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: DictlySpacing.sm) {
        // "All" pill
        CategoryFilterPill(
            label: "All",
            color: nil,
            isActive: activeCategories.isEmpty,
            onTap: { activeCategories = [] }
        )
        // Category pills from SwiftData
        ForEach(categories) { category in
            CategoryFilterPill(
                label: category.name,
                color: categoryColor(for: category.name),
                isActive: activeCategories.contains(category.name),
                onTap: { toggleCategory(category.name) }
            )
        }
    }
    .padding(.horizontal, DictlySpacing.md)
    .padding(.vertical, DictlySpacing.xs)
}
```

### Toggle Logic

```swift
private func toggleCategory(_ name: String) {
    if activeCategories.contains(name) {
        activeCategories.remove(name)
    } else {
        activeCategories.insert(name)
    }
}
```

### Waveform Marker Dimming

In `SessionWaveformTimeline.tagMarkersLayer`, modify the existing `TagMarkerColumn` opacity:

```swift
let isFiltered = !activeCategories.isEmpty && !activeCategories.contains(tag.categoryName)
// Existing opacity: isSelected ? 1.0 : 0.75
// With filter dimming: isFiltered ? 0.25 : (isSelected ? 1.0 : 0.75)
```

Pass `isFiltered` to `TagMarkerColumn` and apply to the overall column opacity. The vertical indicator line should also dim.

### Existing Code to Reuse

| What | Where | How |
|------|-------|-----|
| `TagSidebar` | `DictlyMac/Review/TagSidebar.swift` | Rewrite: replace placeholder, add filter pills and logic |
| `TagSidebarRow` | `DictlyMac/Review/TagSidebarRow.swift` | No changes — row display is already correct (color dot, label, timestamp) |
| `SessionReviewScreen` | `DictlyMac/Review/SessionReviewScreen.swift` | Add `activeCategories` state, pass to sidebar + waveform, reset on session change |
| `SessionWaveformTimeline` | `DictlyMac/Review/SessionWaveformTimeline.swift` | Add `activeCategories` param, dim markers not in filter set |
| `CategoryColorHelper` | `DictlyMac/Review/CategoryColorHelper.swift` | `categoryColor(for:)` — already used by sidebar rows and markers, reuse for pill dots |
| `formatTimestamp(_:)` | `DictlyMac/Review/TagSidebarRow.swift` | Already used — no changes |
| `DictlyColors` | `DictlyKit/Sources/DictlyTheme/Colors.swift` | `surface`, `background`, `textPrimary`, `textSecondary`, `border`, `TagCategory.*` |
| `DictlyTypography` | `DictlyKit/Sources/DictlyTheme/Typography.swift` | `caption` for pill labels, `tagLabel` for tag rows |
| `DictlySpacing` | `DictlyKit/Sources/DictlyTheme/Spacing.swift` | `xs`, `sm`, `md` for pill/search spacing |
| `Tag` model | `DictlyKit/Sources/DictlyModels/Tag.swift` | `categoryName`, `label`, `anchorTime` for filtering and display |
| `TagCategory` model | `DictlyKit/Sources/DictlyModels/TagCategory.swift` | `@Query` to fetch categories for filter pills; `name`, `sortOrder`, `colorHex` |
| `CategoryTabBar` (iOS) | `DictlyiOS/Tagging/CategoryTabBar.swift` | Reference pattern for pill styling — but Mac version is multi-select, not single-select |
| `AudioPlayer` | `DictlyMac/Review/AudioPlayer.swift` | Already wired via `selectedTag` → seek+play in `SessionReviewScreen` — no changes needed |

### What NOT to Do

- **Do NOT** modify `TagSidebarRow.swift` — the row display is already correct from story 4.1
- **Do NOT** modify `TagDetailPanel.swift` — detail panel is complete from story 4.1
- **Do NOT** modify `AudioPlayer.swift` — playback is complete from story 4.3
- **Do NOT** create a separate ViewModel file — the filter logic is simple enough to live in `TagSidebar` as computed properties and state
- **Do NOT** use `@StateObject` or `ObservableObject` — use `@Observable` macro exclusively if creating new observable classes (not needed here)
- **Do NOT** use `@Environment` to pass `activeCategories` — pass as explicit binding/parameter (view-scoped state, not app-wide)
- **Do NOT** hardcode colors, fonts, or spacing — use `DictlyTheme` tokens exclusively
- **Do NOT** add `#if os()` in DictlyKit — all filtering UI lives in the Mac target
- **Do NOT** implement tag editing, renaming, or deletion — those are story 4.5
- **Do NOT** implement retroactive tag placement — that is story 4.6
- **Do NOT** implement cross-session search — that is Epic 6. The search field here filters tags within the current session only
- **Do NOT** use `AnyView` — use `@ViewBuilder` or conditional views
- **Do NOT** change the `HSplitView` layout or sidebar width constraints — those are correct from story 4.1
- **Do NOT** implement search for transcription text or notes — search is tag label only for this story. Full-text cross-session search is story 6.2

### Project Structure Notes

Modified files only — no new production files:

```
DictlyMac/Review/
├── TagSidebar.swift                    # MODIFIED: real search, category filter pills, filter logic
├── SessionReviewScreen.swift           # MODIFIED: activeCategories state, pass to children, reset on session change
└── SessionWaveformTimeline.swift       # MODIFIED: accept activeCategories, dim unfiltered markers

DictlyMacTests/ReviewTests/
└── TagSidebarFilterTests.swift         # NEW: filter logic tests
```

### Testing Standards

- Use `XCTest` with `@MainActor` (project convention)
- In-memory `ModelContainer`: `ModelConfiguration(isStoredInMemoryOnly: true)`
- Create test helpers that build `Tag` and `TagCategory` instances with known values
- Test filter logic as pure functions where possible (sorted + filtered tag arrays)
- Test marker opacity computation independently (pure function, no UI dependency)
- Mac test target may not run locally without signing certificate — verify test target builds cleanly (`** TEST BUILD SUCCEEDED **`)

### Previous Story (4.3) Learnings

- **`@ViewBuilder` + variable assignment**: Cannot do multi-statement variable assignments inside `@ViewBuilder` functions. Must use `let x = computeValue()` (single assignment) or a helper function.
- **`deinit` in `@MainActor` class**: In Swift 6, `deinit` is `nonisolated` and cannot directly access `@MainActor`-isolated properties.
- **Task cancellation safety**: Always set state before early return (review fix from 4.2) — apply to any `.task` modifiers.
- **xcodegen**: Must be re-run after adding new source files — `DictlyMac/project.yml` already includes `Review/` path. New test file in `DictlyMacTests/ReviewTests/` also needs xcodegen.
- **Tap-vs-drag threshold**: 4pt threshold established in `SessionWaveformTimeline` — no changes needed.
- **`.task(id:)` pattern**: Used for reloading on parameter change — can use `.onChange(of: session.uuid)` for filter reset.

### Git Intelligence

Recent commits follow `feat(scope):` / `fix(scope):` conventional commit format. Stories 4.1-4.3 each had implementation + review-patch commits. Expected commit pattern: `feat(review): implement tag sidebar category filtering (story 4-4)`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md - Epic 4, Story 4.4 acceptance criteria]
- [Source: _bmad-output/planning-artifacts/architecture.md - TagSidebar.swift: Scrollable tag list with category filters]
- [Source: _bmad-output/planning-artifacts/architecture.md - Review/ owns waveform rendering, audio playback, and tag editing]
- [Source: _bmad-output/planning-artifacts/architecture.md - @Query for SwiftData-driven lists and detail views]
- [Source: _bmad-output/planning-artifacts/architecture.md - @State for view-local state only]
- [Source: _bmad-output/planning-artifacts/architecture.md - Mac Category Filtering: filter pills below search, multiple active simultaneously]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Mac sidebar: search input + category filter pills + scrollable tag list]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Filters apply to both sidebar list and waveform markers (unselected dim)]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Filter state persists within session, resets on session switch]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Sidebar: 260pt default, collapsible]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Tag category colors: Story=#D97706, Combat=#DC2626, Roleplay=#7C3AED, World=#059669, Meta=#4B7BE5]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Accessibility: category filter reads "[Category] filter. [Count] tags available"]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Mac tag sidebar row height increases at larger Dynamic Type sizes]
- [Source: DictlyMac/Review/TagSidebar.swift - Current placeholder implementation to be replaced]
- [Source: DictlyMac/Review/TagSidebarRow.swift - Existing row component (no changes needed)]
- [Source: DictlyMac/Review/SessionReviewScreen.swift - Parent view wiring selectedTag, audioPlayer, sidebar toggle]
- [Source: DictlyMac/Review/SessionWaveformTimeline.swift - Tag markers layer with opacity logic to extend]
- [Source: DictlyMac/Review/CategoryColorHelper.swift - categoryColor(for:) shared lookup]
- [Source: DictlyiOS/Tagging/CategoryTabBar.swift - iOS filter pill reference pattern (single-select; Mac is multi-select)]
- [Source: DictlyKit/Sources/DictlyModels/Tag.swift - categoryName, label, anchorTime properties]
- [Source: DictlyKit/Sources/DictlyModels/TagCategory.swift - name, sortOrder, colorHex for filter pills]
- [Source: _bmad-output/implementation-artifacts/4-3-audio-playback-and-waveform-navigation.md - Previous story learnings and patterns]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- `** TEST BUILD SUCCEEDED **` — test target builds cleanly. Runtime test execution blocked by pre-existing iCloud entitlement signing constraint (consistent with stories 4.2, 4.3).

### Completion Notes List

- Rewrote `TagSidebar.swift`: replaced placeholder search `HStack` with real `TextField`, added `@Query`-driven category filter pills using `CategoryFilterPill` private component, implemented `filteredTags` computed property composing both category and search filters.
- `activeCategories` lifted to `@Binding` in `TagSidebar` and owned as `@State` in `SessionReviewScreen`; passed as `let` to `SessionWaveformTimeline`.
- `SessionWaveformTimeline.tagMarkersLayer`: added `isFiltered` flag per marker (`!activeCategories.isEmpty && !activeCategories.contains(tag.categoryName)`); `TagMarkerColumn` dims to 25% opacity when filtered.
- Filter reset: `SessionReviewScreen.onChange(of: session.uuid)` clears `activeCategories`; `TagSidebar.onChange(of: sessionID)` clears `searchText`.
- Task 5 (AC #3): verified existing `List(selection:)` → `onChange(of: selectedTag)` → seek+play wiring works with no code changes.
- Accessibility: pill row labeled "Category filters", each pill has count + selected trait, "All" pill labeled with total count, search field labeled, `AccessibilityNotification.LayoutChanged` posted on filter/search change, list container labeled with filtered/total counts.
- Created `TagSidebarFilterTests.swift` with 14 tests covering filter logic and marker opacity as pure functions. Build verified: `** TEST BUILD SUCCEEDED **`.

### File List

- DictlyMac/Review/TagSidebar.swift
- DictlyMac/Review/SessionReviewScreen.swift
- DictlyMac/Review/SessionWaveformTimeline.swift
- DictlyMacTests/ReviewTests/TagSidebarFilterTests.swift

### Review Findings

- [x] [Review][Patch] Marker column opacity incorrect — 18.75% not 25% for unselected filtered markers [SessionWaveformTimeline.swift:416,430] — Fixed: removed inner `.opacity(isSelected ? 1.0 : 0.75)` from shape view, folded into single outer `.opacity(isFiltered ? 0.25 : (isSelected ? 1.0 : 0.75))` on the ZStack.
- [x] [Review][Patch] Session change does not clear `selectedTag` — stale tag from old session shown in detail panel [SessionReviewScreen.swift:59] — Fixed: added `selectedTag = nil` to `.onChange(of: session.uuid)` handler.
- [x] [Review][Patch] `CategoryFilterPill.tagCount` dead parameter — accepted but never referenced in body [TagSidebar.swift] — Fixed: removed `tagCount: Int` parameter and all call-site arguments; accessibility labels already applied externally.
- [x] [Review][Patch] Magic number `HStack(spacing: 4)` in `CategoryFilterPill` [TagSidebar.swift] — Fixed: replaced with `DictlySpacing.xs` (4pt token).
- [x] [Review][Defer] `AccessibilityNotification.LayoutChanged` posted on every keystroke — consider debounce [TagSidebar.swift] — deferred, pre-existing accessibility UX concern
- [x] [Review][Defer] O(n) tag count scan per category pill on every render [TagSidebar.swift] — deferred, micro-optimization for large sessions
- [x] [Review][Defer] `sessionID` parameter redundant — could be derived as `session.uuid` internally [TagSidebar.swift] — deferred, design smell only
- [x] [Review][Defer] Test `container`/`context` infrastructure unused by pure-function tests [TagSidebarFilterTests.swift] — deferred, dead test setup

## Change Log

- 2026-04-02: Implemented story 4-4 tag sidebar with category filtering — functional search field, multi-select category filter pills, waveform marker dimming, filter reset on session change, accessibility notifications, and unit tests.
- 2026-04-02: Code review patches — corrected marker opacity calculation (18.75%→25%), cleared selectedTag on session change, removed dead tagCount parameter from CategoryFilterPill, replaced magic spacing with DictlySpacing.xs.
