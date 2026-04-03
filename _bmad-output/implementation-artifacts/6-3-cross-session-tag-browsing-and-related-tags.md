# Story 6.3: Cross-Session Tag Browsing & Related Tags

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a DM,
I want to browse tags by category across all sessions and see related tags when reviewing,
so that I can discover connections across my campaign's history.

## Acceptance Criteria

1. **Given** the Mac app campaign view **When** the DM selects a category filter in cross-session mode **Then** all tags of that category across all sessions in the campaign are displayed chronologically

2. **Given** a tag selected in the detail panel **When** the related tags column loads **Then** it shows other tags across all sessions that mention similar terms (based on label and transcription text search)

3. **Given** a related tag in the detail panel **When** the DM clicks it **Then** the corresponding session opens with that tag selected

4. **Given** a chronological session list within a campaign **When** the DM browses sessions **Then** sessions are listed with date, title, duration, and tag count

## Tasks / Subtasks

- [x] Task 1: Implement cross-session tag browsing mode in TagSidebar (AC: #1)
  - [x] 1.1 Add a "cross-session mode" toggle state to `TagSidebar.swift` — a `@Binding var isCrossSessionMode: Bool` or local `@State` controlled by a toolbar toggle/button
  - [x] 1.2 When cross-session mode is active AND no search is active: query ALL tags across ALL sessions in the current campaign using SwiftData `@Query` or `ModelContext.fetch` with a `FetchDescriptor<Tag>` predicate filtering by `tag.session?.campaign?.uuid == selectedCampaign.uuid`
  - [x] 1.3 Apply the existing `activeCategories` filter to cross-session results — reuse the category filter pills already in TagSidebar
  - [x] 1.4 Sort cross-session tags chronologically by session date + anchorTime (oldest first)
  - [x] 1.5 Display each tag using `TagSidebarRow` with an additional session identifier (e.g., "Session N" subtitle or grouped by session)
  - [x] 1.6 Group tags by session in the list with section headers showing session title, date, and tag count
  - [x] 1.7 When cross-session mode is deactivated, return to showing only the current session's tags (existing behavior)
  - [x] 1.8 Ensure the toggle state is visually clear — use a toolbar button or segmented control ("Session" / "Campaign")

- [x] Task 2: Implement related tags column in TagDetailPanel (AC: #2)
  - [x] 2.1 Add a `relatedTags: [SearchResult]` property to `TagDetailPanel.swift` (or accept it as a binding)
  - [x] 2.2 Create a `RelatedTagsView.swift` in `DictlyMac/Review/` — a compact list showing related tags from other sessions
  - [x] 2.3 When a tag is selected, use `SearchService.performRelatedSearch(for:)` (new method) to find tags across all sessions that mention similar terms — search by the selected tag's `label` text using the existing Core Spotlight infrastructure
  - [x] 2.4 Filter out tags from the same session as the selected tag — related tags should show cross-session connections only
  - [x] 2.5 Display each related tag with: category color dot, tag label, session title, timestamp
  - [x] 2.6 Limit related tags to a reasonable number (e.g., 10-15 max) sorted by relevance
  - [x] 2.7 Show placeholder text when no related tags found: "No related tags found across other sessions"
  - [x] 2.8 Layout: place the related tags column on the right side of the TagDetailPanel detail area, per UX spec ("Right column: cross-session related tags")
  - [x] 2.9 Header: "Related across sessions" or "Other mentions of [tag label]" per UX spec example

- [x] Task 3: Wire related tag navigation (AC: #3)
  - [x] 3.1 Each related tag row is tappable — on tap, fire an `onRelatedTagSelected(SearchResult)` callback up to `ContentView`
  - [x] 3.2 Reuse the EXACT same navigation pattern from Story 6.2: `ContentView` receives the result, fetches `Session` by `sessionID`, sets `selectedSession`, sets `pendingTagID`, which `SessionReviewScreen` picks up
  - [x] 3.3 After navigation, the related tags column re-populates for the newly selected tag (new context)
  - [x] 3.4 If the related tag is in the same session (edge case if filter isn't applied), just select the tag without session switch

- [x] Task 4: Add `performRelatedSearch` to SearchService (AC: #2)
  - [x] 4.1 Add `func performRelatedSearch(for tag: Tag) async` to `SearchService.swift`
  - [x] 4.2 Use the tag's `label` as the search term — query Core Spotlight using the existing `runSpotlightQuery` infrastructure
  - [x] 4.3 Also search by individual significant words in the tag label (e.g., for "Grimthor's Shop", search "Grimthor" and "Shop" separately, combine results)
  - [x] 4.4 Filter out results where `tagID == tag.uuid` (exclude the selected tag itself)
  - [x] 4.5 Filter out results from the same session (`sessionID == tag.session?.uuid`)
  - [x] 4.6 Store results in a new property: `var relatedTags: [SearchResult] = []`
  - [x] 4.7 Add `var isLoadingRelated: Bool = false` for loading state
  - [x] 4.8 No debounce needed — triggered on tag selection, not on typing

- [x] Task 5: Implement chronological session list (AC: #4)
  - [x] 5.1 Ensure the campaign view displays sessions with: date, title, duration, and tag count
  - [x] 5.2 If `SessionListView.swift` already exists in `DictlyMac/Campaigns/` and shows these fields, verify and enhance if needed
  - [x] 5.3 If session list is currently in `ContentView.swift` sidebar, ensure it displays the required metadata (date, title, duration, tag count)
  - [x] 5.4 Sessions sorted chronologically (most recent first or oldest first — match existing campaign session list ordering)
  - [x] 5.5 Tag count can be computed from `session.tags.count` — displayed as a badge or inline count

- [x] Task 6: Write tests (AC: #1-#4)
  - [x] 6.1 Create `DictlyMacTests/ReviewTests/CrossSessionBrowsingTests.swift`
  - [x] 6.2 Test cross-session tag fetching: verify tags from multiple sessions in a campaign are returned
  - [x] 6.3 Test category filtering applies correctly to cross-session results
  - [x] 6.4 Test chronological sort order (by session date + anchorTime)
  - [x] 6.5 Add `SearchServiceTests` for `performRelatedSearch`: verify self-tag exclusion, same-session exclusion, result population
  - [x] 6.6 Test related tag navigation reuses the same pendingTagID pattern
  - [x] 6.7 Test empty states: no tags in category, no related tags found

## Dev Notes

### Architecture Compliance

- **Cross-session tag browsing** modifies `TagSidebar.swift` in `DictlyMac/Review/` — this is the existing tag sidebar that already has category filter pills and search integration from Story 6.2.
- **Related tags** extend `TagDetailPanel.swift` in `DictlyMac/Review/` — the UX spec explicitly defines the right column as "cross-session related tags" populated from full-text search.
- **SearchService extension** — add `performRelatedSearch` to the existing `SearchService.swift` in `DictlyMac/Search/`. Reuse `runSpotlightQuery` and `resolveItem` — do NOT create a separate service.
- **@Observable pattern** — all services use `@Observable` (NOT `ObservableObject`). See `SearchService`, `TranscriptionEngine`, `AudioPlayer` for the pattern.
- **No DictlyKit changes needed** — Core Spotlight indexing (Story 6.1) and search query infrastructure (Story 6.2) are already complete. This story only adds UI features on top.

### Critical Implementation Details

#### Cross-Session Tag Query Strategy

Two approaches for AC #1 (category browsing across sessions):

**Option A — SwiftData Query (Recommended for browsing):**
```swift
// In cross-session mode, fetch all tags in campaign filtered by category
let descriptor = FetchDescriptor<Tag>(
    predicate: #Predicate<Tag> { tag in
        tag.session?.campaign?.uuid == campaignUUID
        && categoryNames.contains(tag.categoryName)
    },
    sortBy: [SortDescriptor(\.session?.date), SortDescriptor(\.anchorTime)]
)
```
SwiftData is better here because browsing needs structured data (grouping by session, filtering by category) that Core Spotlight doesn't support well. Core Spotlight is for text search; SwiftData is for structured queries.

**Option B — Core Spotlight (NOT recommended for browsing):**
Core Spotlight could filter by keywords containing category names, but it returns flat results without session grouping and doesn't support the structured filtering needed for category browsing.

**Decision: Use SwiftData for cross-session browsing (Task 1), Core Spotlight for related tags text search (Task 2/4).**

#### Related Tags via Core Spotlight

For AC #2, reuse the existing `SearchService` Core Spotlight query:
- Search term = selected tag's `label` (e.g., "Grimthor")
- The existing `runSpotlightQuery` searches `textContent` (transcription), `title` (tag label), and `keywords` (category, session, campaign)
- Filter out: the selected tag itself (`tagID != tag.uuid`) and tags from the same session
- This surfaces tags across ALL sessions where the same term appears in label or transcription — exactly what the UX spec describes

#### TagDetailPanel Layout Change

Current TagDetailPanel (from Story 4.7) is a single-column layout. The UX spec defines a **two-column** detail area:
- **Left column:** tag label, category badge, timestamp, transcription, notes, action buttons
- **Right column:** cross-session related tags, session-level summary notes

Implement the right column as a separate `RelatedTagsView` placed in an `HStack` alongside the existing left-column content. Use a `GeometryReader` or fixed width split (e.g., 60/40 or flexible with min widths).

#### Navigation Reuse from Story 6.2

The search-result-to-session navigation is ALREADY implemented:
1. `ContentView.handleSearchResultSelected(result)` → fetches Session by UUID → sets `selectedSession` + `pendingTagID`
2. `SessionReviewScreen` detects `pendingTagID` via `onChange` → selects matching tag

**Reuse this exact pattern** for related tag clicks. The `SearchResult` struct already contains `tagID`, `sessionID`, and all needed fields. Wire `RelatedTagsView` tap → `onRelatedTagSelected` callback → `ContentView.handleSearchResultSelected`.

#### Cross-Session Mode UX

The UX spec describes category filter pills that work in both single-session and cross-session modes. Implementation:
- Add a segmented control or toggle button in the TagSidebar header: "Session" (default) / "Campaign"
- "Session" mode = existing behavior (current session's tags)
- "Campaign" mode = cross-session browsing (all tags in campaign, filtered by category)
- Category filter pills already exist and should work in both modes
- Search (from Story 6.2) should remain functional — when search is active it takes priority over browsing mode

### Existing Code Patterns to Follow

- **Theme tokens:** `DictlyColors.*`, `DictlyTypography.*`, `DictlySpacing.*` — never hardcode values
- **Logging:** `Logger(subsystem: "com.dictly.mac", category: "search")` for search operations, `category: "review"` for review UI
- **List style:** `.listStyle(.sidebar)` consistent with existing TagSidebar
- **Empty states:** Warm, encouraging tone. Explain why and what to do next. See `TagSidebar` empty state pattern.
- **Accessibility:** Every interactive element gets `.accessibilityLabel`. Post `AccessibilityNotification.LayoutChanged()` on content changes. See `TagSidebar` and `SearchResultRow` for patterns.
- **Fire-and-forget async:** Wrap async calls in `Task { }` at call sites. Never block UI.
- **Category color:** Use `CategoryColorHelper.categoryColor(for:)` from `DictlyMac/Review/CategoryColorHelper.swift`

### What NOT To Do

- Do NOT create a new search index or modify `SearchIndexer.swift` — indexing is complete from Story 6.1
- Do NOT modify SwiftData models (Tag, Session, Campaign, TagCategory) — no schema changes needed
- Do NOT add cross-session features to iOS — Mac-only per architecture
- Do NOT use `ObservableObject`/`@Published` — use `@Observable` macro (project convention)
- Do NOT create a separate service for cross-session browsing — extend `SearchService` and use SwiftData queries directly
- Do NOT implement markdown export — that's Story 6.4
- Do NOT hardcode colors, fonts, or spacing — always use DictlyTheme tokens
- Do NOT duplicate the navigation pattern from Story 6.2 — reuse `handleSearchResultSelected` and `pendingTagID`

### Previous Story Intelligence (6-2)

**Key learnings from Story 6.2 implementation:**
- `SearchService` is `@Observable @MainActor final class` in `DictlyMac/Search/SearchService.swift` (239 lines)
- Created as `@State` in `ContentView`, injected via `.environment(searchService)`
- `ModelContext` passed via `setModelContext(_:)` called in `.onAppear`
- `SearchResult` struct has: `tagID`, `tagLabel`, `sessionTitle`, `sessionNumber`, `anchorTime`, `transcriptionSnippet`, `categoryName`, `sessionID`, `sessionDate`
- Navigation flow: `ContentView.handleSearchResultSelected` → fetch Session by UUID → set `selectedSession` + deferred `pendingTagID` via `Task { @MainActor in }` → `SessionReviewScreen.onChange` selects tag
- `pendingTagID` only cleared on match success (review fix from 6.2)
- `TagSidebar` already has `@Environment(SearchService.self)` — reads search state, conditionally shows `SearchResultsView`
- `TagSidebar` has `activeCategories: Set<String>` binding and `onResultSelected` callback
- `searchService.isSearchActive` drives search vs browse mode — when search is active, results replace tag list
- Snippet generation uses `**term**` markers rendered with `Color.accentColor` in `SearchResultRow`
- `DictlyColors.accent` does not exist — use `Color.accentColor` (system accent) as established in 6.2
- 283 tests pass with 2 pre-existing failures in RetroactiveTagTests/TagEditingTests (not caused by search work)

**Review fixes from 6.2 to maintain:**
- Spotlight query string escaping for special characters (`*`, `?`, `\`, `'`)
- `generateSnippet` uses `text.distance(from:to:)` for diacritic-safe match length
- `Task.isCancelled` guard after async search to prevent stale results
- `pendingTagID` deferred via `Task { @MainActor in }` to avoid firing onChange on old session

### Git Intelligence

Recent commits follow conventional commit format: `feat(scope):`, `fix(scope):`. Last 5 commits:
1. `d4627bb` — `fix(search): address review feedback for full-text search across sessions`
2. `404bf91` — `feat(search): implement full-text search across sessions`
3. `fe7d15d` — `feat(story): implement 6-2-full-text-search-across-sessions specification`
4. `a9687df` — `fix(spotlight): update index on tag property changes and tag switching`
5. `c37b3f2` — `feat(story): implement 6-1-core-spotlight-indexing`

**Key files from Story 6.2 that this story extends:**
- `DictlyMac/Search/SearchService.swift` — ADD `performRelatedSearch`, `relatedTags`, `isLoadingRelated`
- `DictlyMac/Review/TagSidebar.swift` (445 lines) — ADD cross-session browsing mode toggle and campaign-wide tag list
- `DictlyMac/Review/TagDetailPanel.swift` — ADD right column with `RelatedTagsView`
- `DictlyMac/App/ContentView.swift` — WIRE related tag navigation callback (reuse existing handler)
- `DictlyMac/Review/SessionReviewScreen.swift` — PASS related tag selection callback through

### Project Structure Notes

```
DictlyMac/Search/
  SearchService.swift           # MODIFY — add performRelatedSearch, relatedTags, isLoadingRelated
  SearchResultsView.swift       # NO CHANGE
  SearchResultRow.swift         # NO CHANGE

DictlyMac/Review/
  TagSidebar.swift              # MODIFY — add cross-session browsing mode
  TagDetailPanel.swift          # MODIFY — add right column with RelatedTagsView
  RelatedTagsView.swift         # NEW — compact related tags list for detail panel
  TagSidebarRow.swift           # NO CHANGE (reused in cross-session mode)
  CategoryColorHelper.swift     # NO CHANGE (reused for related tag colors)
  SessionReviewScreen.swift     # MODIFY — pass through related tag callbacks

DictlyMac/App/
  ContentView.swift             # MODIFY — wire relatedTagSelected to existing handler

DictlyMacTests/
  ReviewTests/
    CrossSessionBrowsingTests.swift   # NEW
  SearchTests/
    SearchServiceTests.swift          # MODIFY — add performRelatedSearch tests
```

### References

- [Source: architecture.md#Gap-1-Full-Text-Search-Strategy] — Core Spotlight for full-text search, SearchService location
- [Source: architecture.md#Project-Structure] — DictlyMac/Search/ and DictlyMac/Review/ file listings
- [Source: architecture.md#Mac-Target-Boundaries] — Search/ owns full-text search, Review/ owns tag editing
- [Source: architecture.md#Requirements-Mapping] — FR29 (category filter), FR42 (cross-session browse), FR43 (link to audio), FR44 (session list)
- [Source: epics.md#Story-6.3] — Acceptance criteria, user story, cross-story dependencies
- [Source: prd.md#FR42] — Browse tags filtered by category across all sessions in a campaign
- [Source: prd.md#FR44] — Browse a chronological session list within a campaign
- [Source: ux-design-specification.md#TagDetailPanel] — Right column: cross-session related tags populated from full-text search
- [Source: ux-design-specification.md#Chosen-Direction-Mac] — Detail area two-column: left (tag details) + right (related tags, session notes)
- [Source: ux-design-specification.md#Search-and-Filtering-Patterns] — Mac category filtering: multiple categories, filter pills, persist within session
- [Source: ux-design-specification.md#Journey-2-Pre-Session-Prep] — Browse sessions chronologically or filter tags by category
- [Source: ux-design-specification.md#Design-Rationale-3] — "Cross-session related tags in detail panel creates the archive earns its value experience"
- [Source: 6-2-full-text-search-across-sessions.md] — SearchService patterns, navigation flow, review fixes

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- New files (`RelatedTagsView.swift`, `CrossSessionBrowsingTests.swift`) needed to be manually added to `project.pbxproj` — Xcode projects require explicit file registration.
- Used `session.campaign?.sessions` relationship traversal for cross-session data rather than `FetchDescriptor` with optional chaining (simpler and avoids SwiftData predicate limitations with deep optional chains).
- `formatTimestamp` is module-level in `TagSidebarRow.swift` — directly accessible from `RelatedTagsView.swift` in the same target.

### Completion Notes List

- **Task 4 (SearchService)**: Added `performRelatedSearch(for:)`, `relatedTags: [SearchResult]`, and `isLoadingRelated: Bool` to `SearchService`. Method searches by full label + individual significant words (3+ chars), deduplicates by tagID, filters out self and same-session results, limits to 15, sorts by relevance.
- **Task 1 (TagSidebar)**: Added `@State private var isCrossSessionMode: Bool` with a `Picker(.segmented)` "Session"/"Campaign" toggle (shown only when session has a campaign). Cross-session mode traverses `session.campaign?.sessions`, groups tags by session with section headers (title, date, tag count), sorts oldest-first. Category pills update counts based on mode. Search always takes priority over browsing mode.
- **Task 2 (RelatedTagsView + TagDetailPanel)**: Created `RelatedTagsView.swift` with loading/empty/populated states. Updated `TagDetailPanel` to inject `SearchService` via `@Environment`, trigger `performRelatedSearch` on `onChange(of: selectedTag)`, and replace the placeholder right column.
- **Task 3 (Navigation)**: Added `onRelatedTagSelected` parameter to `SessionReviewScreen` and `TagDetailPanel`. Wired through `ContentView` to reuse `handleSearchResultSelected` — exact same `pendingTagID` pattern as Story 6.2.
- **Task 5 (Session list)**: Enhanced `ContentView.sessionRow` to show date · duration · tag count below session title.
- **Task 6 (Tests)**: Created `CrossSessionBrowsingTests.swift` with 13 tests covering cross-session fetch, category filter, chronological sort, navigation, and empty states. Added 7 tests to `SearchServiceTests` for `performRelatedSearch` state management, filter logic, deduplication, and result limit. Total: 305 tests, 2 pre-existing failures (RetroactiveTagTests, TagEditingTests — not caused by this work), 0 regressions.

### File List

- `DictlyMac/Search/SearchService.swift` — MODIFIED: added `relatedTags`, `isLoadingRelated`, `performRelatedSearch(for:)`
- `DictlyMac/Review/TagSidebar.swift` — MODIFIED: added cross-session browsing mode toggle and campaign-wide tag list with section headers
- `DictlyMac/Review/RelatedTagsView.swift` — NEW: compact related tags list for TagDetailPanel right column
- `DictlyMac/Review/TagDetailPanel.swift` — MODIFIED: injected SearchService, replaced placeholder rightColumn with RelatedTagsView, added onRelatedTagSelected callback, triggers performRelatedSearch on tag selection
- `DictlyMac/Review/SessionReviewScreen.swift` — MODIFIED: added onRelatedTagSelected callback parameter, threads through to TagDetailPanel
- `DictlyMac/App/ContentView.swift` — MODIFIED: wired onRelatedTagSelected to existing handleSearchResultSelected, enhanced sessionRow with duration + tag count
- `DictlyMacTests/ReviewTests/CrossSessionBrowsingTests.swift` — NEW: 13 tests for story 6.3
- `DictlyMacTests/SearchTests/SearchServiceTests.swift` — MODIFIED: added 7 performRelatedSearch tests
- `DictlyMac/DictlyMac.xcodeproj/project.pbxproj` — MODIFIED: registered RelatedTagsView.swift and CrossSessionBrowsingTests.swift

### Review Findings

- [x] [Review][Patch] No cancellation handle for in-flight related search — concurrent rapid tag selections create racing tasks that can overwrite `relatedTags` non-deterministically [SearchService.swift:233, TagDetailPanel.swift:57]
- [x] [Review][Patch] Direct mutation of SearchService state from view — `searchService.relatedTags = []` and `searchService.isLoadingRelated = false` set directly in TagDetailPanel; should use an encapsulated `clearRelatedResults()` method [TagDetailPanel.swift:62]
- [x] [Review][Patch] `relatedTags` not cleared before new search starts — stale results remain visible momentarily until new results arrive [SearchService.swift:239]
- [x] [Review][Patch] `sessionID` nil guard missing — if `tag.session` relationship is unfired/nil, `sessionID` is nil and same-session filter silently passes all results [SearchService.swift:241]
- [x] [Review][Patch] Word token `.whitespaces` not trimmed — non-standard spaces in tag labels produce padded Spotlight query terms that match nothing [SearchService.swift:260]
- [x] [Review][Patch] Session section headers missing duration — AC4 requires date, title, duration, and tag count; duration absent from cross-session section headers [TagSidebar.swift:261]
- [x] [Review][Defer] `pendingTagID` never cleared if session tags not yet populated on navigation — pre-existing from Story 6.2, no regression [ContentView.swift:65]

## Change Log

- 2026-04-03: Implemented Story 6.3 — cross-session tag browsing, related tags panel, related tag navigation, session list enhancement, 20 new tests (Date: 2026-04-03)
