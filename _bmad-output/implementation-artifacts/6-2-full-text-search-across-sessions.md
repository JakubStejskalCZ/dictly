# Story 6.2: Full-Text Search Across Sessions

Status: ready-for-dev

## Story

As a DM,
I want to search by keyword across all my sessions and see results with transcription snippets,
So that I can find any moment from any session in seconds during prep.

## Acceptance Criteria

1. **Given** the Mac sidebar search bar
   **When** the DM types a query (e.g., "Grimthor")
   **Then** results appear from across all sessions in the campaign
   **And** each result shows: tag label, session number, timestamp, and a highlighted transcription snippet

2. **Given** search results
   **When** the DM clicks a result
   **Then** the corresponding session opens with that tag selected, waveform jumps to position, and detail panel populates

3. **Given** a search with no matches
   **When** the results area displays
   **Then** a message shows "No results for '[query]'. Try a different term or browse by category."
   **And** category filter pills are shown as an alternative

4. **Given** 10+ sessions with transcriptions
   **When** a search is performed
   **Then** results return within acceptable time (< 1 minute, ideally sub-second)

5. **Given** the DM clears the search
   **When** the search bar is emptied
   **Then** the view returns to the current session's tag list

## Tasks / Subtasks

- [ ] Task 1: Create `SearchService.swift` in `DictlyMac/Search/` (AC: #1, #4)
  - [ ] 1.1 Create `SearchService.swift` — `@Observable public final class` with `import CoreSpotlight`
  - [ ] 1.2 Add properties: `var searchText: String = ""`, `var searchResults: [SearchResult] = []`, `var isSearching: Bool = false`, `var isSearchActive: Bool` (computed: `!searchText.trimmingCharacters(in: .whitespaces).isEmpty`)
  - [ ] 1.3 Define `SearchResult` struct: `tagID: UUID`, `tagLabel: String`, `sessionTitle: String`, `sessionNumber: Int`, `anchorTime: TimeInterval`, `transcriptionSnippet: String?`, `categoryName: String`, `sessionID: UUID`
  - [ ] 1.4 Implement `performSearch()` — uses `CSSearchQuery` with query string `textContent == '*QUERY*'c || title == '*QUERY*'c || keywords == '*QUERY*'c` to search the Core Spotlight index built in Story 6.1
  - [ ] 1.5 Use `CSSearchQuery(queryString:queryContext:)` initializer with `CSSearchQueryContext` — set `fetchAttributes` to `["title", "displayName", "textContent", "contentDescription", "keywords"]`
  - [ ] 1.6 Iterate `query.results` async sequence to collect matching `CSSearchableItem` items
  - [ ] 1.7 For each result, extract: `uniqueIdentifier` (tag UUID string), `attributeSet.title` (tag label), `attributeSet.displayName` (contains session info), `attributeSet.textContent` (transcription), `attributeSet.keywords` (contains session title, campaign, category)
  - [ ] 1.8 Build `SearchResult` from Spotlight attributes AND resolve session/tag data from SwiftData using tag UUID — fetch `Tag` with matching UUID to get `session.title`, `session.sessionNumber`, `session.uuid`, `tag.anchorTime`, `tag.categoryName`
  - [ ] 1.9 Generate highlighted `transcriptionSnippet` — extract ~80 characters around the first match of the query term in `textContent`, with the matched term wrapped in a recognizable marker (e.g., prefix/suffix with `**` for bold rendering)
  - [ ] 1.10 Debounce search: use a `Task` with 300ms delay that cancels on new input — store current search `Task` in a property and cancel it before starting a new one
  - [ ] 1.11 Sort results by relevance: exact label matches first, then by session date (most recent first)
  - [ ] 1.12 Add `func clearSearch()` that resets `searchText`, `searchResults`, and `isSearching`
  - [ ] 1.13 Log search operations via `Logger(subsystem: "com.dictly.mac", category: "search")`
  - [ ] 1.14 SearchService needs a `ModelContext` reference to resolve tag UUIDs to full Tag/Session data — accept `modelContext` in init or pass it to `performSearch`

- [ ] Task 2: Create `SearchResultsView.swift` in `DictlyMac/Search/` (AC: #1, #3)
  - [ ] 2.1 Create `SearchResultsView.swift` — SwiftUI view displaying cross-session search results as a scrollable `List`
  - [ ] 2.2 Accept `searchResults: [SearchResult]`, `searchText: String`, `isSearching: Bool`, and `onResultSelected: (SearchResult) -> Void`
  - [ ] 2.3 Show a `ProgressView` while `isSearching` is true
  - [ ] 2.4 When `searchResults` is empty and not searching, show empty state: "No results for '[searchText]'. Try a different term or browse by category."
  - [ ] 2.5 Each row uses `SearchResultRow` (Task 3)
  - [ ] 2.6 Row tap calls `onResultSelected` with the tapped `SearchResult`
  - [ ] 2.7 Use DictlyTheme tokens for all typography, colors, and spacing
  - [ ] 2.8 Add accessibility labels: list summary with result count, each row labeled with tag label + session context

- [ ] Task 3: Create `SearchResultRow.swift` in `DictlyMac/Search/` (AC: #1)
  - [ ] 3.1 Create `SearchResultRow.swift` — SwiftUI view for a single search result row
  - [ ] 3.2 Layout: category color dot + tag label (DictlyTypography.body, bold), session info line ("Session N — HH:MM:SS" in DictlyTypography.caption, textSecondary), transcription snippet line (DictlyTypography.caption, textSecondary, italic, 2-line max)
  - [ ] 3.3 Highlight the matched query term in the transcription snippet using `AttributedString` or `Text` concatenation with a distinct color (DictlyColors.accent or similar)
  - [ ] 3.4 Category color dot uses the same `categoryColor(for:)` helper pattern from `TagSidebar.swift` — extract to a shared utility in `DictlyMac/Extensions/` if not already shared, or inline
  - [ ] 3.5 Add accessibility: label combines tag label, session number, timestamp, and snippet preview

- [ ] Task 4: Integrate search into sidebar (AC: #1, #3, #5)
  - [ ] 4.1 Modify `TagSidebar.swift`: accept `@Environment(SearchService.self)` to access shared search state
  - [ ] 4.2 Bind the existing `searchText` state to `searchService.searchText` (two-way) — when user types, it drives both local filtering AND cross-session Spotlight search
  - [ ] 4.3 When `searchService.isSearchActive` is true, replace the tag list section with `SearchResultsView` showing cross-session results
  - [ ] 4.4 When `searchService.isSearchActive` is false (search cleared), show the normal session tag list as it works today
  - [ ] 4.5 Keep category filter pills visible in both modes — in search mode, they can visually suggest browsing as an alternative (AC #3 empty state)
  - [ ] 4.6 Add `onResultSelected` callback parameter to TagSidebar that bubbles the search result selection up to SessionReviewScreen/ContentView for navigation
  - [ ] 4.7 When search clears (AC #5), the view returns to the current session's tag list — existing behavior, just ensure `searchService.clearSearch()` resets properly

- [ ] Task 5: Wire navigation from search result to session+tag (AC: #2)
  - [ ] 5.1 Modify `ContentView.swift`: create `SearchService()` as `@State`, inject via `.environment(searchService)`
  - [ ] 5.2 Add `@State private var pendingTagID: UUID?` to ContentView — when a search result is clicked, store the tag ID to select after session loads
  - [ ] 5.3 When `onResultSelected` fires from sidebar: (a) set `selectedSession` to the result's session (fetched by `sessionID` from SwiftData), (b) set `pendingTagID` to the result's `tagID`
  - [ ] 5.4 Modify `SessionReviewScreen.swift`: accept an optional `pendingTagID: Binding<UUID?>` — when non-nil and matching a tag in the current session, set `selectedTag` to that tag and clear the binding
  - [ ] 5.5 The existing `.onChange(of: selectedTag)` in SessionReviewScreen already handles seeking audio + playing — no changes needed for waveform jump (AC #2)
  - [ ] 5.6 After navigation completes, call `searchService.clearSearch()` so the sidebar returns to the session's tag list showing the selected tag in context

- [ ] Task 6: Inject SearchService at app level (AC: #1)
  - [ ] 6.1 Modify `DictlyMacApp.swift`: create `SearchService` and inject via `.environment()` on the main window
  - [ ] 6.2 Alternatively, create SearchService in ContentView (simpler, since it's the main view) — choose the approach that matches existing service injection patterns (check how `TranscriptionEngine` is injected)

- [ ] Task 7: Write tests (AC: #1–#5)
  - [ ] 7.1 Create `DictlyMacTests/SearchTests/SearchServiceTests.swift`
  - [ ] 7.2 Test: `testSearchResult_fromSpotlightItem` — verify SearchResult is correctly built from CSSearchableItem attributes
  - [ ] 7.3 Test: `testGenerateSnippet_highlightsMatchedTerm` — verify transcription snippet extraction with ~80 char window around match
  - [ ] 7.4 Test: `testGenerateSnippet_noMatch_returnsPrefix` — when query term not in transcription, return first ~80 chars
  - [ ] 7.5 Test: `testGenerateSnippet_nilTranscription_returnsNil` — verify nil handling
  - [ ] 7.6 Test: `testClearSearch_resetsState` — verify searchText, searchResults, isSearching all reset
  - [ ] 7.7 Test: `testIsSearchActive_emptyText_returnsFalse` — verify computed property
  - [ ] 7.8 Test: `testIsSearchActive_whitespaceOnly_returnsFalse` — verify trimming
  - [ ] 7.9 Test: `testIsSearchActive_withText_returnsTrue` — verify computed property
  - [ ] 7.10 Test: `testSearchResults_sortedByRelevance` — exact label matches before partial matches
  - [ ] 7.11 Ensure all existing tests still pass (0 regressions) — currently 256 tests

## Dev Notes

### Architecture Compliance

- **SearchService.swift** lives in `DictlyMac/Search/` — NOT in DictlyKit. Per architecture: "Search/ owns full-text search — queries Core Spotlight instead of SwiftData predicates for text search" [Source: architecture.md#Gap-1]. This is Mac-only; iOS has no search UI.
- **SearchResultsView.swift** and **SearchResultRow.swift** also in `DictlyMac/Search/` per architecture project structure.
- **@Observable pattern:** SearchService must be `@Observable` (not `ObservableObject`) — this is the project-wide pattern for SwiftUI services (see `TranscriptionEngine`, `AudioPlayer`, `ImportService`).
- **No new DictlyKit changes needed.** The `SearchIndexer` from Story 6.1 already indexes all tags. This story only QUERIES the existing index.

### Critical Implementation Details

#### CSSearchQuery API

- **Query string format:** `textContent == '*term*'c || title == '*term*'c || keywords == '*term*'c` — the `c` suffix makes it case-insensitive, `*` is wildcard
- **Modern initializer:** Use `CSSearchQuery(queryString:queryContext:)` with `CSSearchQueryContext` — set `fetchAttributes = ["title", "displayName", "textContent", "contentDescription", "keywords"]`
- **Async iteration:** Use `for try await result in query.results { }` — no need for `query.start()` with async sequence. Iteration starts the query automatically.
- **Platform:** `CSSearchQuery` async sequence requires macOS 12+. Project targets macOS 14+ so this is safe.
- **Domain filter:** Optionally filter query to domain `"com.dictly.tags"` to avoid matching items from other apps — not strictly needed since the query attributes are Dictly-specific, but cleaner.

#### Tag UUID Resolution

- Core Spotlight results return `uniqueIdentifier` = `tag.uuid.uuidString` (set in Story 6.1)
- To build `SearchResult` with session context (title, number, ID), you must resolve the tag from SwiftData: `FetchDescriptor<Tag>(predicate: #Predicate { $0.uuid == tagUUID })`
- Access `tag.session?.title`, `tag.session?.sessionNumber`, `tag.session?.uuid` for session info
- If tag's session is nil (shouldn't happen), skip the result

#### Debounce Strategy

- Store the current search `Task` in a property: `private var searchTask: Task<Void, Never>?`
- On each search text change: cancel previous task, create new one with `try await Task.sleep(for: .milliseconds(300))` before executing
- If sleep is cancelled (user typed again), the task exits without searching

#### Snippet Generation

- From `textContent` (full transcription), find the first occurrence of the query term (case-insensitive)
- Extract ~40 characters before and ~40 after the match position
- Prefix with "..." if not starting at beginning, suffix with "..." if not ending at end
- The matched term itself should be identifiable for highlighting in the UI

#### Navigation Flow (Search Result → Session + Tag)

1. User clicks search result in `SearchResultsView`
2. `onResultSelected(result)` callback fires up to `ContentView`
3. `ContentView` fetches `Session` by `result.sessionID` from SwiftData
4. Sets `selectedSession` to that session
5. Sets `pendingTagID` to `result.tagID`
6. `SessionReviewScreen` receives the new session, detects `pendingTagID`, finds the tag in `session.tags`, sets `selectedTag`
7. Existing `.onChange(of: selectedTag)` handles audio seek + play
8. Search is cleared, sidebar returns to showing the selected session's tags

### Existing Code Patterns to Follow

- **@Observable services:** See `TranscriptionEngine` — `@Observable final class`, injected via `.environment()`, accessed via `@Environment(TranscriptionEngine.self)`
- **Theme tokens:** ALL colors via `DictlyColors.*`, typography via `DictlyTypography.*`, spacing via `DictlySpacing.*` — never hardcode values
- **Logging:** `Logger(subsystem: "com.dictly.mac", category: "search")` — consistent with `SessionReviewScreen`, `TagDetailPanel`
- **List style:** `.listStyle(.sidebar)` — consistent with `TagSidebar`, `ContentView`
- **Empty states:** Warm, encouraging tone. Always explain why and what to do next. See `TagSidebar.emptyState` and UX spec empty states table.
- **Accessibility:** Every interactive element has `.accessibilityLabel`. Layout changes post `AccessibilityNotification.LayoutChanged()`. Announcements via `AccessibilityNotification.Announcement()`. See `TagSidebar` for patterns.
- **Fire-and-forget async:** Wrap async calls in `Task { }` at call sites. Never block UI.

### What NOT To Do

- Do NOT create a separate search index or SwiftData query — Core Spotlight IS the search index (built in Story 6.1)
- Do NOT modify `SearchIndexer.swift` — indexing is complete from Story 6.1
- Do NOT modify SwiftData models (Tag, Session, Campaign) — no schema changes needed
- Do NOT add search to iOS — search is Mac-only per architecture
- Do NOT use `ObservableObject`/`@Published` — use `@Observable` macro (project convention)
- Do NOT implement cross-session tag browsing or related tags — that's Story 6.3
- Do NOT implement the "related tags" column in TagDetailPanel — that's Story 6.3
- Do NOT use `CSUserQuery` — `CSSearchQuery` is sufficient for programmatic search; `CSUserQuery` adds unnecessary complexity for this use case
- Do NOT hardcode colors, fonts, or spacing — always use DictlyTheme tokens

### Previous Story Intelligence (6-1)

**Key learnings from Story 6.1 implementation:**
- `SearchIndexer.swift` is in `DictlyKit/Sources/DictlyStorage/` — a stateless `final class` with all `async throws` methods
- Domain identifier: `"com.dictly.tags"` — use this if filtering CSSearchQuery by domain
- `uniqueIdentifier` = `tag.uuid.uuidString` — this is how you map Spotlight results back to SwiftData tags
- `CSSearchableItemAttributeSet` fields populated: `title` (tag label), `displayName` ("\(label) — \(session.title)"), `textContent` (transcription), `contentDescription` (notes or category), `keywords` ([category, session title, campaign name])
- `CoreSpotlight` framework already linked in `DictlyKit/Package.swift` via `linkerSettings`
- `DictlyError.search(SearchError)` with `.indexingFailed` and `.deletionFailed` already exists — reuse for search query errors if needed, or add a `.queryFailed(String)` case
- Story 6.1 review found and fixed: category changes and tag-switching inline commits now trigger Spotlight updates — search results will be fresh
- 256 tests pass with 0 regressions after Story 6.1

### Git Intelligence

Recent commits follow conventional commit format: `feat(scope):`, `fix(scope):`, `test(scope):`. The most recent work (Story 6.1) added `SearchIndexer.swift` and integrated it into all tag mutation flows. The codebase is stable with 256 passing tests. Key hook points for this story:
- `TagSidebar.swift` — existing search bar and tag list, needs conditional search results view
- `ContentView.swift` — session navigation, needs search result → session routing
- `SessionReviewScreen.swift` — tag selection, needs pendingTagID support

### Project Structure Notes

```
DictlyMac/Search/           # Currently empty (.gitkeep) — all 3 new files go here
  SearchService.swift       # NEW — @Observable search service
  SearchResultsView.swift   # NEW — cross-session results list
  SearchResultRow.swift     # NEW — individual result row

DictlyMac/Review/
  TagSidebar.swift          # MODIFY — conditional search results
  SessionReviewScreen.swift # MODIFY — pendingTagID support

DictlyMac/App/
  ContentView.swift         # MODIFY — SearchService injection, navigation

DictlyMacTests/SearchTests/
  SearchServiceTests.swift  # NEW — search service tests
```

### References

- [Source: architecture.md#Gap-1-Full-Text-Search-Strategy] — Core Spotlight decision, SearchService.swift location
- [Source: architecture.md#Project-Structure] — DictlyMac/Search/ file listing (SearchService, SearchResultsView, SearchResultRow)
- [Source: architecture.md#Mac-Target-Boundaries] — Search/ owns full-text search
- [Source: epics.md#Story-6.2] — Acceptance criteria, user story, cross-story dependencies
- [Source: prd.md#FR41] — Full-text search across all transcriptions and tag labels
- [Source: prd.md#FR43] — Search results link directly to tagged audio moment
- [Source: prd.md#NFR5] — Performance: < 1 minute for 10+ sessions
- [Source: ux-design-specification.md#Search-and-Filtering-Patterns] — Search bar in sidebar header, results replace tag list, click opens session
- [Source: ux-design-specification.md#Empty-States] — "No results for '[query]'" message with category filter pills
- [Source: ux-design-specification.md#Journey-2-Pre-Session-Prep] — Search-first prep workflow, transcription snippet scanning
- [Source: ux-design-specification.md#TagDetailPanel] — Related tags column populated from full-text search (Story 6.3, not this story)

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
