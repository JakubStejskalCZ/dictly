# Story 1.7: Storage Management

Status: ready-for-dev

## Story

As a DM,
I want to view how much storage my recordings use and delete old ones,
So that I can manage my device space as sessions accumulate.

## Acceptance Criteria (BDD)

### Scenario 1: View Storage Usage with Per-Session Breakdown

Given the DM opens storage management
When there are recorded sessions (sessions with audio files on disk)
Then total space used is displayed along with a per-session breakdown (audio size, date)

### Scenario 2: Delete Session Recording with Confirmation

Given the DM selects a session for deletion
When they confirm the delete action
Then the audio file and associated metadata are removed
And the storage total updates to reflect freed space

### Scenario 3: Empty State — No Recordings

Given no recordings exist
When the DM opens storage management
Then a message indicates no recordings are stored

## Tasks / Subtasks

- [ ] Task 1: Add `audioFilePath` property to Session model (AC: #1, #2)
  - [ ] 1.1 Add `public var audioFilePath: String?` to `Session` SwiftData `@Model` in `DictlyKit/Sources/DictlyModels/Session.swift`
  - [ ] 1.2 Add `audioFilePath` as optional parameter (default `nil`) to `Session.init`
  - [ ] 1.3 SwiftData lightweight migration handles adding a new optional property automatically — no migration code needed
  - [ ] 1.4 Verify existing tests still pass (new property is optional, existing code unaffected)

- [ ] Task 2: Create `AudioFileManager` in DictlyKit/DictlyStorage (AC: #1, #2)
  - [ ] 2.1 Create `AudioFileManager.swift` as a `public struct` (stateless utility) in `DictlyKit/Sources/DictlyStorage/`
  - [ ] 2.2 Implement `static func audioStorageDirectory() -> URL` — returns the app sandbox subdirectory for audio files (`<appSupportDir>/Recordings/`), creating it if needed
  - [ ] 2.3 Implement `static func fileSize(at path: String) throws -> Int64` — returns file size in bytes using `FileManager.default.attributesOfItem(atPath:)[.size]`
  - [ ] 2.4 Implement `static func totalAudioStorageSize(sessions: [Session]) -> Int64` — iterates sessions with non-nil `audioFilePath`, sums file sizes, skips missing files gracefully
  - [ ] 2.5 Implement `static func deleteAudioFile(at path: String) throws` — removes file using `FileManager.default.removeItem(atPath:)`, throws `DictlyError.storage(.fileNotFound)` if file doesn't exist
  - [ ] 2.6 Implement `static func formattedSize(_ bytes: Int64) -> String` — returns human-readable string using `ByteCountFormatter` with `.file` count style (e.g., "115 MB", "2.3 GB")

- [ ] Task 3: Create `StorageManagementView` for iOS (AC: #1, #2, #3)
  - [ ] 3.1 Create `StorageManagementView.swift` in `DictlyiOS/Settings/`
  - [ ] 3.2 Use `@Query(sort: \Session.date, order: .reverse)` to fetch all sessions
  - [ ] 3.3 Display total storage used at the top (sum of all audio file sizes) using `AudioFileManager.formattedSize`
  - [ ] 3.4 Display per-session rows: session title, campaign name, date, audio file size
  - [ ] 3.5 Sessions without audio files (`audioFilePath == nil`) are excluded from the storage list
  - [ ] 3.6 Implement swipe-to-delete on session rows with `.confirmationDialog` for destructive action confirmation
  - [ ] 3.7 On confirmed delete: call `AudioFileManager.deleteAudioFile`, set session's `audioFilePath = nil`, clear `duration = 0` — do NOT delete the Session model itself (session metadata and tags are preserved)
  - [ ] 3.8 After deletion, the list and total storage update reactively via `@Query`
  - [ ] 3.9 Show empty state when no sessions have audio files: "No recordings are stored" with explanatory subtext
  - [ ] 3.10 Use `Form` container with sections per UX patterns for settings screens

- [ ] Task 4: Create `SettingsScreen` for iOS (AC: #1, #2, #3)
  - [ ] 4.1 Create `SettingsScreen.swift` in `DictlyiOS/Settings/`
  - [ ] 4.2 Use `Form` with a `Section` for "Storage" containing a `NavigationLink` to `StorageManagementView`
  - [ ] 4.3 Show total storage used as secondary text in the navigation link row
  - [ ] 4.4 Add toolbar navigation to Settings from `CampaignListScreen` (gear icon in toolbar)

- [ ] Task 5: Add storage management to Mac Preferences (AC: #1, #2, #3)
  - [ ] 5.1 Create `PreferencesWindow.swift` in `DictlyMac/Settings/`
  - [ ] 5.2 Register as a `Settings` scene in `DictlyMacApp.swift` (macOS `Settings { PreferencesWindow() }`)
  - [ ] 5.3 Reuse the same storage display logic: total size, per-session breakdown, delete with `.alert` confirmation (Mac uses `.alert` not `.confirmationDialog` per UX spec)
  - [ ] 5.4 Use `Table` or `List` for session breakdown appropriate to macOS idiom
  - [ ] 5.5 Same empty state handling as iOS

- [ ] Task 6: Navigation Integration (AC: #1)
  - [ ] 6.1 Add a gear icon (`Image(systemName: "gearshape")`) toolbar button to `CampaignListScreen.swift` that navigates to `SettingsScreen`
  - [ ] 6.2 Mac: the `Settings` scene is accessible via the standard macOS app menu (Cmd+,) — no additional navigation needed

- [ ] Task 7: Unit Tests (AC: #1, #2, #3)
  - [ ] 7.1 Test `AudioFileManager.fileSize(at:)` — returns correct size for a temp file, throws for missing file
  - [ ] 7.2 Test `AudioFileManager.totalAudioStorageSize(sessions:)` — correctly sums sizes, handles nil paths, handles missing files
  - [ ] 7.3 Test `AudioFileManager.deleteAudioFile(at:)` — removes file, throws `.fileNotFound` for missing
  - [ ] 7.4 Test `AudioFileManager.formattedSize(_:)` — correct human-readable output for various sizes (0 B, KB, MB, GB)
  - [ ] 7.5 Test `AudioFileManager.audioStorageDirectory()` — returns valid URL, creates directory if missing
  - [ ] 7.6 Verify `xcodebuild` succeeds for both iOS and Mac targets

## Dev Notes

### Critical Context: Audio Recording Not Yet Implemented

Audio recording is Epic 2 (Story 2.1). The `Session` model currently has **no** `audioFilePath` property. This story builds the storage management **infrastructure and UI** in advance. Until Epic 2 is implemented:
- All sessions will have `audioFilePath == nil`
- The storage management UI will show the empty state ("No recordings are stored")
- This is the correct and expected behavior

The `audioFilePath: String?` property added in Task 1 is the hook that Epic 2's `SessionRecorder` will use to store the recorded audio path. This property MUST be added now so the storage management code has something to query against.

### Architecture Compliance

- **`AudioFileManager` is a `struct` with static methods** — it's a stateless utility, not a service. Place in `DictlyKit/Sources/DictlyStorage/AudioFileManager.swift` [Source: architecture.md#DictlyStorage]
- **`@Observable` for any service classes** — not needed here since `AudioFileManager` is stateless [Source: architecture.md#Enforcement-Guidelines]
- **Error handling:** Throw `DictlyError.storage(...)` cases. Never use `Result` wrapping [Source: architecture.md#Core-Architectural-Decisions]
- **Logging:** Use `os.Logger` with subsystem `"com.dictly"` and category `"storage"`. File paths are `.private`, sizes are `.public` [Source: architecture.md#Enforcement-Guidelines]
- **No `#if os()` in DictlyKit** — `AudioFileManager` uses only Foundation `FileManager` APIs available on both iOS and macOS. Platform-specific UI stays in platform targets [Source: architecture.md#Package-Boundary]
- **SwiftData `@Query` for reactive views** — storage management views use `@Query` to fetch sessions. When `audioFilePath` is set to `nil` after deletion, views update automatically [Source: architecture.md#Data-Patterns]
- **Cascade delete awareness:** Deleting a Session via SwiftData cascade-deletes its Tags. But this story only deletes the **audio file**, not the Session model itself. Session metadata and tags are preserved — only the recording is freed [Source: architecture.md#SwiftData-Relationships]

### Audio File Storage Pattern

Per architecture: "Audio storage: File system within app sandbox. SwiftData stores metadata references (file paths), not audio data."

- Audio files will live in the app sandbox under a `Recordings/` subdirectory
- `Session.audioFilePath` stores the relative or absolute path to the audio file
- `AudioFileManager` operates on these paths using `FileManager`
- AAC 64kbps mono: ~115 MB per 4-hour session [Source: architecture.md#Storage-Specifications]

### Delete Behavior — Audio File Only

The delete action in storage management removes the **audio file from disk** and sets `session.audioFilePath = nil`. It does NOT:
- Delete the Session model from SwiftData
- Delete Tags associated with the session
- Delete any transcription text stored in Tags

This preserves the session's metadata, tag timeline, and notes while freeing disk space. The session remains browsable but without playback capability.

### UX Patterns

- **iOS Settings:** Full-screen push navigation from campaign list (gear icon). `Form` with sections. `.confirmationDialog` for delete confirmation [Source: ux-design-specification.md#Modal-Patterns]
- **Mac Preferences:** Standard macOS `Settings` scene (Cmd+,). `.alert` for delete confirmation [Source: ux-design-specification.md#Modal-Patterns]
- **Destructive action styling:** Red text, confirmation required for delete [Source: ux-design-specification.md#Button-Hierarchy]
- **Empty state:** "No recordings are stored" with warm, encouraging subtext explaining that recordings will appear here once sessions are recorded. Always explain why and what to do next [Source: ux-design-specification.md#Empty-States]
- **Warning color for low storage:** Amber `#F59E0B` — consider showing a warning badge if device storage is critically low (optional enhancement) [Source: ux-design-specification.md#Color-System]

### File Placement

```
DictlyKit/Sources/DictlyModels/
└── Session.swift                    # MODIFY — add audioFilePath: String?

DictlyKit/Sources/DictlyStorage/
├── DictlyStorage.swift              # Existing placeholder
├── CategorySyncService.swift        # Existing (Story 1.6)
└── AudioFileManager.swift           # NEW — file size, delete, path helpers

DictlyKit/Tests/DictlyStorageTests/
└── AudioFileManagerTests.swift      # NEW — unit tests

DictlyiOS/Settings/
├── SettingsScreen.swift             # NEW — iOS settings Form
└── StorageManagementView.swift      # NEW — storage usage + delete UI

DictlyMac/Settings/
└── PreferencesWindow.swift          # NEW — macOS preferences with storage tab

DictlyiOS/Campaigns/
└── CampaignListScreen.swift         # MODIFY — add gear icon toolbar button
```

### Previous Story Intelligence (from Story 1.6)

Key patterns to follow from the most recent story:
- **Swift 6 strict concurrency:** Watch for `@MainActor` isolation issues. If `deinit` accesses actor-isolated state, use `nonisolated(unsafe)` pattern [Source: 1-6-tag-category-sync-via-icloud-key-value-store.md#Debug-Log]
- **`@Query` is reactive** — when you modify a Session's `audioFilePath` in the ModelContext, any view using `@Query` on Sessions updates automatically. No manual refresh needed [Source: 1-6-tag-category-sync-via-icloud-key-value-store.md#Previous-Story-Intelligence]
- **`#Predicate` macro limitation** — capture values into local variables before using in predicates [Source: 1-6-tag-category-sync-via-icloud-key-value-store.md#Previous-Story-Intelligence]
- **`xcodegen generate`** — run in `DictlyiOS/` and `DictlyMac/` if project.yml changes needed (new files in app targets). SPM auto-discovers DictlyKit sources
- **Conventional commits:** `feat(storage): implement storage management (story 1.7)`
- **Test suite currently:** 54 tests passing. New tests must not break existing ones
- **DictlyStorage already depends on DictlyModels** in `Package.swift` — no Package.swift changes needed

### Git Intelligence

Recent commit pattern: `feat(storage):` prefix used for storage-related changes (see story 1.6 commits). Follow same convention.

Files recently modified that overlap:
- `DictlyiOS/App/DictlyiOSApp.swift` — modified in Story 1.6, no changes needed here for Story 1.7
- `DictlyMac/App/DictlyMacApp.swift` — modified in Story 1.6, needs `Settings` scene addition for Story 1.7
- `DictlyKit/Package.swift` — last modified in Story 1.6, no changes needed (DictlyStorage target already exists with DictlyModels dependency)

### Project Structure Notes

- `DictlyiOS/Settings/` directory exists with only `.gitkeep` — create new files here
- `DictlyMac/Settings/` directory exists with only `.gitkeep` — create new files here
- `DictlyKit/Sources/DictlyStorage/` contains `DictlyStorage.swift` (placeholder) and `CategorySyncService.swift`
- `DictlyKit/Tests/DictlyStorageTests/` exists with `CategorySyncServiceTests.swift` — add `AudioFileManagerTests.swift` alongside
- Both `DictlyiOS/project.yml` and `DictlyMac/project.yml` may need updating if xcodegen is used — regenerate xcodeproj after adding new source files in app targets
- `DictlyMacApp.swift` currently has only a `WindowGroup` scene — add a `Settings` scene for preferences

### References

- [Source: epics.md#Story-1.7] — AC and user story for storage management
- [Source: prd.md#FR49] — DM can manage storage (view space used, delete old recordings)
- [Source: architecture.md#Storage-Specifications] — AAC 64kbps mono, ~115 MB per 4-hour session, app sandbox
- [Source: architecture.md#DictlyStorage] — AudioFileManager.swift planned with "Audio file path management, cleanup helpers"
- [Source: architecture.md#Data-Patterns] — Audio files in app sandbox, SwiftData stores metadata references
- [Source: architecture.md#SwiftData-Relationships] — Campaign → Session cascade delete, Session → Tag cascade delete
- [Source: architecture.md#Enforcement-Guidelines] — @Observable, DictlyError, os.Logger patterns
- [Source: architecture.md#Package-Boundary] — DictlyKit has zero platform-specific imports
- [Source: ux-design-specification.md#Modal-Patterns] — iOS .confirmationDialog, Mac .alert
- [Source: ux-design-specification.md#Button-Hierarchy] — Destructive: red text, confirmation required
- [Source: ux-design-specification.md#Empty-States] — Warm, encouraging tone, explain why and what to do
- [Source: ux-design-specification.md#Color-System] — Warning amber #F59E0B, Destructive red #DC2626
- [Source: 1-6-tag-category-sync-via-icloud-key-value-store.md] — Previous story patterns, Swift 6 concurrency notes
- [Source: DictlyKit/Sources/DictlyModels/Session.swift] — Current Session model (no audioFilePath yet)
- [Source: DictlyKit/Sources/DictlyStorage/DictlyStorage.swift] — Existing placeholder enum
- [Source: DictlyKit/Sources/DictlyModels/DictlyError.swift] — StorageError cases: diskFull, permissionDenied, fileNotFound, syncFailed

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
