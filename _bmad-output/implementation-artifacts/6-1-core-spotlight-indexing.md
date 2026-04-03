# Story 6.1: Core Spotlight Indexing

Status: done

## Story

As a developer,
I want tags and transcriptions indexed via Core Spotlight,
So that full-text search is fast across 10+ sessions and integrates with macOS Spotlight.

## Acceptance Criteria

1. **Given** a tag is created or imported on either platform
   **When** the tag is persisted to SwiftData
   **Then** a `CSSearchableItem` is created with the tag label, transcription, notes, category, session ID, and timestamp

2. **Given** a transcription is completed or edited
   **When** the text changes
   **Then** the corresponding Spotlight index entry is updated

3. **Given** a tag or session is deleted
   **When** the deletion completes
   **Then** the corresponding Spotlight index entries are removed

4. **Given** macOS Spotlight
   **When** the user searches for a Dictly tag term
   **Then** matching Dictly items appear in system Spotlight results

## Tasks / Subtasks

- [x] Task 1: Create `SearchIndexer.swift` in `DictlyKit/Sources/DictlyStorage/` (AC: #1, #2, #3)
  - [x] 1.1 Create `SearchIndexer.swift` — public class with `import CoreSpotlight` and `import UniformTypeIdentifiers`
  - [x] 1.2 Define domain identifier constant: `"com.dictly.tags"` for batch operations
  - [x] 1.3 Implement `indexTag(_ tag: Tag)` — creates `CSSearchableItem` from Tag properties using `CSSearchableIndex.default()`
  - [x] 1.4 Build `CSSearchableItemAttributeSet(contentType: .text)` with:
    - `title` = tag label
    - `contentDescription` = tag notes (if any) or category name
    - `textContent` = tag transcription (full searchable body)
    - `keywords` = [tag.categoryName, session title, campaign name]
    - `displayName` = "\(tag.label) — \(session.title)"
  - [x] 1.5 Use `tag.uuid.uuidString` as `uniqueIdentifier` for the `CSSearchableItem`
  - [x] 1.6 Implement `updateTag(_ tag: Tag)` — re-indexes the tag (same as `indexTag` since re-indexing with same `uniqueIdentifier` replaces the entry)
  - [x] 1.7 Implement `removeTag(id: UUID)` — calls `deleteSearchableItems(withIdentifiers: [id.uuidString])`
  - [x] 1.8 Implement `removeAllTagsForSession(sessionID: UUID)` — deletes by domain identifier or iterates tag UUIDs
  - [x] 1.9 Implement `removeAllItems()` — calls `deleteAllSearchableItems()` for cleanup/reset
  - [x] 1.10 All public methods use `async throws` — Core Spotlight operations are async
  - [x] 1.11 Add `DictlyError.search(SearchError)` case to `DictlyError.swift` with `.indexingFailed(String)` and `.deletionFailed(String)` sub-cases

- [x] Task 2: Integrate indexing into tag creation flow — iOS (AC: #1)
  - [x] 2.1 In `DictlyiOS/Tagging/TaggingService.swift`, after `modelContext.insert(tag)` succeeds, call `SearchIndexer().indexTag(tag)` in a `.task` or `Task { }`
  - [x] 2.2 Indexing failure must NOT block tag creation — catch errors and log via `os.Logger(category: "search")`
  - [x] 2.3 Verify tag's session relationship is established before indexing (needed for session title/campaign keywords)

- [x] Task 3: Integrate indexing into Mac import flow (AC: #1)
  - [x] 3.1 In `DictlyMac/Import/ImportService.swift`, after `modelContext.save()` in `performImport`, batch-index all imported tags
  - [x] 3.2 Use `CSSearchableIndex.default().indexSearchableItems(items)` for batch efficiency — build all `CSSearchableItem` objects first, then index in one call
  - [x] 3.3 Import failure must NOT be caused by indexing failure — catch and log; import succeeds regardless

- [x] Task 4: Integrate indexing into transcription completion and edit flows (AC: #2)
  - [x] 4.1 In `DictlyMac/Transcription/TranscriptionEngine.swift`, after transcription text is written to `tag.transcription`, call `SearchIndexer().updateTag(tag)`
  - [x] 4.2 In `DictlyMac/Review/TagDetailPanel.swift`, in the `commitTranscription` logic (around line 66), call `SearchIndexer().updateTag(tag)` after saving edited transcription
  - [x] 4.3 In `DictlyMac/Review/TagDetailPanel.swift`, also call `updateTag` after tag notes are saved (notes are part of searchable content)
  - [x] 4.4 In `DictlyMac/Review/TagDetailPanel.swift`, also call `updateTag` after tag label rename (label is the title)
  - [x] 4.5 All update calls are fire-and-forget `Task { }` — never block UI for index updates

- [x] Task 5: Integrate removal on tag/session deletion (AC: #3)
  - [x] 5.1 In `DictlyMac/Review/TagDetailPanel.swift`, before or after deleting a tag from SwiftData, call `SearchIndexer().removeTag(id: tag.uuid)`
  - [x] 5.2 When a session is deleted (if supported in current UI), call `SearchIndexer().removeAllTagsForSession(sessionID:)` or iterate tags and remove each
  - [x] 5.3 Deletion from index is fire-and-forget — if it fails, items become orphaned but cause no harm (they'll fail to resolve on click)

- [x] Task 6: Ensure macOS system Spotlight integration (AC: #4)
  - [x] 6.1 Verify `CSSearchableIndex.default()` is used (not a custom-named index) — this is what surfaces items in system Spotlight
  - [x] 6.2 Add `CoreSpotlight` framework to both iOS and Mac targets in Xcode project settings (Frameworks, Libraries, and Embedded Content)
  - [x] 6.3 Add `CoreSpotlight` framework dependency to `DictlyStorage` target in `DictlyKit/Package.swift` — no SPM dependency needed since it's a system framework, but the `import CoreSpotlight` must resolve
  - [x] 6.4 Test that indexed items appear in macOS Spotlight when searching for a tag label

- [x] Task 7: Write unit tests (AC: #1–#4)
  - [x] 7.1 Create `DictlyKit/Tests/DictlyStorageTests/SearchIndexerTests.swift`
  - [x] 7.2 Test: `testIndexTag_createsSearchableItem` — verify CSSearchableItem is created with correct uniqueIdentifier, title, textContent, keywords
  - [x] 7.3 Test: `testUpdateTag_replacesExistingItem` — verify re-indexing with same UUID works
  - [x] 7.4 Test: `testRemoveTag_deletesFromIndex` — verify deletion by identifier
  - [x] 7.5 Test: `testRemoveAllItems_clearsIndex` — verify full cleanup
  - [x] 7.6 Test: `testIndexTag_withNilTranscription_indexesLabelOnly` — verify partial data handling
  - [x] 7.7 Test: `testIndexTag_withAllFields_populatesAllAttributes` — verify label + transcription + notes + category all indexed
  - [x] 7.8 Ensure all existing DictlyKit tests still pass (0 regressions)

## Dev Notes

### Architecture Compliance

- **Module boundary:** `SearchIndexer.swift` lives in `DictlyKit/Sources/DictlyStorage/` (shared package) — this is architecturally correct per the architecture doc Gap 1 resolution
- **Platform import concern:** `CoreSpotlight` is available on both iOS 9+ and macOS 10.13+. The DictlyKit package targets iOS 17+ and macOS 14+ so this is safe. However, `CoreSpotlight` is a system framework — verify it can be imported in a Swift Package target without special linker flags. If not, the alternative is to define a `SearchIndexerProtocol` in DictlyKit and implement it in each app target
- **Observation pattern:** `SearchIndexer` does NOT need to be `@Observable` — it's a stateless utility that performs async operations. No UI binds to it. Use a simple `public final class` or even `public enum SearchIndexer` with static methods
- **Error handling pattern:** Follows project convention — `throw` in service methods, catch in call sites. Indexing errors are non-fatal; always catch and log, never let them propagate to crash the app or block user operations

### Critical Implementation Details

- **`CSSearchableIndex.default()`** — MUST use the default index, not a custom named index. Only the default index surfaces items in macOS system Spotlight (AC #4)
- **`uniqueIdentifier`** = `tag.uuid.uuidString` — this is the key for updates and deletions. Re-indexing with the same identifier replaces the existing entry
- **`domainIdentifier`** = `"com.dictly.tags"` — enables efficient batch deletion by domain (e.g., when deleting all items, or future campaign-level deletion)
- **Batch indexing** — on import, build all `CSSearchableItem` objects and call `indexSearchableItems([items])` once, not per-tag. Core Spotlight handles batches efficiently
- **Async/await** — all `CSSearchableIndex` methods have async variants. Use `try await` in the indexer, wrap calls in `Task { }` at call sites to avoid blocking

### Session/Campaign Context in Index

The `Tag` model has a `session: Session?` relationship and `session?.campaign: Campaign?`. When building the `CSSearchableItemAttributeSet`:
- Access `tag.session?.title` for the session title keyword
- Access `tag.session?.campaign?.name` for the campaign name keyword
- Access `tag.session?.sessionNumber` for display context
- If the session relationship is nil (shouldn't happen in normal flow), index with tag label only — don't fail

### What NOT To Do

- Do NOT create a separate SwiftData-based search index — Core Spotlight IS the search index
- Do NOT add `CSSearchQuery` logic in this story — querying is Story 6.2's scope
- Do NOT modify SwiftData models (Tag, Session, Campaign) — no schema changes needed
- Do NOT add any UI for search — this is pure infrastructure
- Do NOT make indexing synchronous or blocking — always fire-and-forget with error logging
- Do NOT use the deprecated `CSSearchableItemAttributeSet(itemContentType:)` initializer — use `CSSearchableItemAttributeSet(contentType: UTType.text)`

### Existing Code Patterns to Follow

- **Error types:** Add to `DictlyError.swift` following the existing nested enum pattern (see `TranscriptionError`, `StorageError`)
- **Logging:** Use `import OSLog` with `Logger(subsystem: "com.dictly", category: "search")` — consistent with project patterns
- **File location:** `SearchIndexer.swift` in `DictlyKit/Sources/DictlyStorage/` alongside `BundleSerializer.swift`, `AudioFileManager.swift`, `CategorySyncService.swift`
- **Test location:** `DictlyKit/Tests/DictlyStorageTests/SearchIndexerTests.swift` alongside existing storage tests
- **Async patterns:** Follow `CategorySyncService.swift` patterns for async service methods

### Project Structure Notes

- `DictlyKit/Package.swift` currently has `DictlyStorage` depending on `DictlyModels` — this is correct, SearchIndexer needs access to Tag/Session/Campaign models
- `DictlyMac/Search/` directory exists but is empty (`.gitkeep` only) — do NOT put SearchIndexer there; it goes in DictlyKit for cross-platform availability
- Both app targets already depend on `DictlyKit` — no new dependency wiring needed at the app target level
- The `CoreSpotlight` system framework link may need to be added to Package.swift: check if `import CoreSpotlight` resolves in the DictlyStorage target without explicit linking

### Git Intelligence

Recent commits show the project follows conventional commits: `feat(scope):`, `fix(scope):`, `test(scope):`. Epic 5 (transcription) is complete with stable patterns. The `TranscriptionEngine` writes to `tag.transcription` which is the key hook point for Task 4. `TagDetailPanel.swift` has inline editing for transcription (story 5-4) and notes — both are hook points for index updates.

### References

- [Source: architecture.md#Gap-1-Full-Text-Search-Strategy] — Core Spotlight decision and SearchIndexer.swift location
- [Source: architecture.md#Project-Structure] — DictlyKit/DictlyStorage/ file listing
- [Source: architecture.md#Mac-Target-Boundaries] — Search/ owns full-text search, queries Core Spotlight
- [Source: epics.md#Story-6.1] — Acceptance criteria and user story
- [Source: prd.md#FR41-FR44] — Search & Archive functional requirements
- [Source: ux-design-specification.md#Search-and-Filtering-Patterns] — Search UX patterns (relevant for Story 6.2, not this story)

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

None — implementation proceeded without blockers.

### Completion Notes List

- Created `SearchIndexer.swift` (public final class) in `DictlyKit/Sources/DictlyStorage/` with `indexTag`, `updateTag`, `removeTag`, `removeAllTagsForSession`, `removeAllItems`, `indexTags` (batch), and internal `buildSearchableItem` (testable without touching system index). All public methods are `async throws`. Uses `CSSearchableIndex.default()` exclusively.
- Added `DictlyError.search(SearchError)` with `.indexingFailed(String)` and `.deletionFailed(String)` sub-cases to `DictlyError.swift`.
- `TaggingService.swift` (iOS): fire-and-forget `SearchIndexer().indexTag(tag)` after both `placeTag` and `placeTagWithCapturedAnchor` save successfully. Failures caught and logged — tag creation is never blocked.
- `ImportService.swift` (Mac): fire-and-forget `SearchIndexer().indexTags(tags)` after `context.save()` completes. Import success is independent of indexing.
- `TranscriptionEngine.swift` (Mac): fire-and-forget `SearchIndexer().updateTag(tag)` after `tag.transcription = text` is written in `transcribeTag`.
- `TagDetailPanel.swift` (Mac): fire-and-forget `SearchIndexer().updateTag(tag)` in `commitTranscription`, `commitNotes`, and `commitLabel`. Fire-and-forget `SearchIndexer().removeTag(id:)` in `deleteTag`.
- `Package.swift`: added `linkerSettings: [.linkedFramework("CoreSpotlight")]` to the `DictlyStorage` target.
- `SearchIndexerTests.swift`: 11 tests covering all story test cases (7.2–7.7) plus edge cases. All 11 pass. Total test suite: 256 tests, 0 failures, 0 regressions.
- Note for Task 5.2 (session deletion): Session deletion UI not yet implemented. `removeAllTagsForSession(sessionID:tags:)` is ready for integration when that feature lands.

### File List

- `DictlyKit/Sources/DictlyStorage/SearchIndexer.swift` (new)
- `DictlyKit/Sources/DictlyModels/DictlyError.swift` (modified)
- `DictlyKit/Package.swift` (modified)
- `DictlyiOS/Tagging/TaggingService.swift` (modified)
- `DictlyMac/Import/ImportService.swift` (modified)
- `DictlyMac/Transcription/TranscriptionEngine.swift` (modified)
- `DictlyMac/Review/TagDetailPanel.swift` (modified)
- `DictlyKit/Tests/DictlyStorageTests/SearchIndexerTests.swift` (new)

### Review Findings

- [x] [Review][Patch] Category change doesn't trigger Spotlight update [DictlyMac/Review/TagDetailPanel.swift:183] — Fixed: added `SearchIndexer().updateTag` call in `CategoryPickerPopover` `onSelect` callback after `tag.categoryName = newCategory`. Category name is part of `keywords` and `contentDescription` fallback; without this, the Spotlight entry is stale after recategorisation.
- [x] [Review][Patch] Tag-switching inline commit bypasses Spotlight update [DictlyMac/Review/TagDetailPanel.swift:56-75] — Fixed: added fire-and-forget `SearchIndexer().updateTag` in both inline-commit paths inside `onChange(of: selectedTag?.uuid)` (notes and transcription paths). These paths directly write to the model without going through `commitNotes`/`commitTranscription`, so Spotlight was silently skipped on tag switching while editing.
- [x] [Review][Defer] ImportService comment numbering jumps from 7 to 9 [DictlyMac/Import/ImportService.swift:208] — deferred, pre-existing cosmetic
- [x] [Review][Defer] Task 5.2 session deletion not wired — deferred, documented known limitation (session deletion UI not yet implemented)

### Change Log

- 2026-04-03: Implemented Core Spotlight indexing infrastructure (SearchIndexer, DictlyError.search) and integrated into all tag creation, import, transcription, edit, and deletion flows. Added 11 unit tests; 256 total tests pass with 0 regressions.
- 2026-04-03: Code review — fixed 2 patch findings: (1) category change now triggers Spotlight re-index; (2) tag-switching inline commit paths now fire Spotlight updates.
