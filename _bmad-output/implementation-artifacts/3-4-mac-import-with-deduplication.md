# Story 3.4: Mac Import with Deduplication

Status: ready-for-dev

## Story

As a DM,
I want my Mac to automatically recognize incoming Dictly sessions and organize them correctly,
so that import is effortless and I never accidentally duplicate a session.

## Acceptance Criteria

1. **Given** the Mac app has registered the `.dictly` UTI, **when** a `.dictly` bundle arrives via AirDrop or Finder open, **then** the Mac app launches or foregrounds and begins import automatically.

2. **Given** a `.dictly` bundle is being imported, **when** the import processes, **then** the session appears under the correct campaign (matched by campaign UUID), **and** audio is stored in the app sandbox, **and** all tags and metadata are written to SwiftData, **and** an import progress banner is displayed.

3. **Given** a session that has already been imported (matching session UUID), **when** the same `.dictly` bundle is imported again, **then** a duplicate warning is shown: "Session already exists", **and** the DM can choose to skip or replace.

4. **Given** import completes successfully, **when** the DM views the campaign, **then** the new session appears in the chronological session list with correct metadata.

5. **Given** a `.dictly` bundle with a campaign UUID not yet on Mac, **when** the import processes, **then** the campaign is created automatically from the bundle's campaign metadata.

## Tasks / Subtasks

- [ ] Task 1: Add `CFBundleDocumentTypes` to Mac `Info.plist` (AC: #1)
  - [ ] 1.1 Add `CFBundleDocumentTypes` array entry with `CFBundleTypeRole: Viewer`, `LSHandlerRank: Default`, `LSItemContentTypes: ["com.dictly.dictly-bundle"]`
  - [ ] 1.2 Verify the existing `UTImportedTypeDeclarations` for `com.dictly.dictly-bundle` with extension `dictly` is present (already done in story 3.3)
  - [ ] 1.3 Build and verify macOS registers as `.dictly` file handler (double-clicking a `.dictly` file in Finder should open the Mac app)

- [ ] Task 2: Create `ImportService` (AC: #1, #2, #3, #4, #5)
  - [ ] 2.1 Create `ImportService.swift` in `DictlyMac/Import/` as `@Observable @MainActor` class
  - [ ] 2.2 Define `ImportState` enum: `.idle`, `.importing(progress: Double)`, `.completed(sessionTitle: String)`, `.duplicate(sessionTitle: String)`, `.failed(Error)`
  - [ ] 2.3 Inject `ModelContext` via initializer or method parameter (NOT `@Environment` — service classes don't have SwiftUI environment)
  - [ ] 2.4 Implement `importBundle(from url: URL, context: ModelContext)` as the main entry point:
    - Call `BundleSerializer().deserialize(from: url)` to get `(TransferBundle, Data)`
    - Check dedup: query SwiftData for existing `Session` with matching `uuid` from `bundle.session.uuid`
    - If duplicate found → set state `.duplicate(sessionTitle:)` and return (do NOT auto-replace)
    - If not duplicate → proceed with import
  - [ ] 2.5 Implement campaign resolution:
    - If `bundle.campaign` is non-nil, query SwiftData for `Campaign` with matching `uuid`
    - If campaign found → use it
    - If campaign not found → create new `Campaign.from(bundle.campaign!)` and insert into context
    - If `bundle.campaign` is nil → create a default "Imported Sessions" campaign (or leave session unassigned — match iOS behavior)
  - [ ] 2.6 Implement session + tags creation:
    - Create `Session.from(bundle.session)` via the existing factory method
    - Create `Tag.from(dto)` for each tag in `bundle.tags`
    - Set `session.tags = tags` and `session.campaign = campaign`
    - Set `session.audioFilePath` to the destination path (set after audio copy)
  - [ ] 2.7 Implement audio file storage:
    - Copy audio data to `AudioFileManager.audioStorageDirectory()` with filename `{session.uuid}.aac`
    - Set `session.audioFilePath` to the absolute path of the copied file
  - [ ] 2.8 Save context and transition state to `.completed(sessionTitle:)`
  - [ ] 2.9 Implement `replaceExisting(from url: URL, context: ModelContext)` for the duplicate-replace flow:
    - Delete existing session (cascade deletes tags), delete its audio file via `AudioFileManager.deleteAudioFile(at:)`
    - Re-run import as normal
  - [ ] 2.10 Implement `skipDuplicate()` — resets state to `.idle`
  - [ ] 2.11 Add `os.Logger` messages (subsystem: `com.dictly.mac`, category: `import`) for all state transitions and errors
  - [ ] 2.12 Clean up source bundle temp directory after successful import (remove the temp `.dictly` dir)

- [ ] Task 3: Wire `onOpenURL` in `DictlyMacApp` for AirDrop/Finder file opens (AC: #1)
  - [ ] 3.1 Add `@State private var importService = ImportService()` to `DictlyMacApp`
  - [ ] 3.2 Add `.environment(importService)` to ContentView
  - [ ] 3.3 Add `.onOpenURL { url in ... }` modifier on `WindowGroup` — call `importService.importBundle(from: url, context: container.mainContext)`
  - [ ] 3.4 Ensure the URL points to a `.dictly` bundle (directory with `audio.aac` + `session.json`) — AirDrop may deliver the directory or a flattened file; handle both cases

- [ ] Task 4: Wire `LocalNetworkReceiver` → `ImportService` (AC: #1, #2)
  - [ ] 4.1 In `DictlyMacApp` or `ContentView`, observe `networkReceiver.receivedBundleURL` changes
  - [ ] 4.2 When `receivedBundleURL` becomes non-nil, call `importService.importBundle(from: receivedBundleURL, context:)`
  - [ ] 4.3 After import completes (or fails), call `networkReceiver.reset()` to clean up temp bundle and return receiver to `.listening`

- [ ] Task 5: Create `ImportProgressView` banner (AC: #2, #3)
  - [ ] 5.1 Create `ImportProgressView.swift` in `DictlyMac/Import/` as a SwiftUI view
  - [ ] 5.2 Read `ImportService` from `@Environment` — display banner based on `importState`:
    - `.idle` → hidden (no banner)
    - `.importing(progress:)` → "Importing session..." with progress bar
    - `.completed(sessionTitle:)` → "Session imported successfully" with green checkmark, auto-dismiss after 3 seconds
    - `.duplicate(sessionTitle:)` → "Session already exists" warning with "Skip" and "Replace" buttons
    - `.failed(error)` → error message with "Retry" button (retry calls `importBundle` again with same URL)
  - [ ] 5.3 Place `ImportProgressView` as an overlay or top banner in `ContentView`
  - [ ] 5.4 Use `DictlyTheme` tokens for colors, typography, and spacing — no hardcoded values
  - [ ] 5.5 Add VoiceOver accessibility labels on all interactive elements

- [ ] Task 6: Unit tests (AC: #1, #2, #3, #4, #5)
  - [ ] 6.1 Create `ImportServiceTests.swift` in `DictlyMacTests/ImportTests/`
  - [ ] 6.2 Test successful import: deserialize bundle → session + tags + campaign written to SwiftData, audio file copied to storage directory, state transitions `.idle` → `.importing` → `.completed`
  - [ ] 6.3 Test deduplication: import a session, then import same bundle again → state transitions to `.duplicate`, session count unchanged
  - [ ] 6.4 Test replace flow: after `.duplicate` state, call `replaceExisting` → old session deleted, new session created, audio file replaced
  - [ ] 6.5 Test skip flow: after `.duplicate` state, call `skipDuplicate` → state returns to `.idle`, no changes to data
  - [ ] 6.6 Test campaign auto-creation: import bundle with campaign UUID not in SwiftData → new campaign created
  - [ ] 6.7 Test campaign reuse: import bundle with campaign UUID already in SwiftData → session added to existing campaign
  - [ ] 6.8 Test invalid bundle: pass a non-bundle URL → state transitions to `.failed` with appropriate error
  - [ ] 6.9 Test audio file storage: verify audio written to `AudioFileManager.audioStorageDirectory()/{uuid}.aac`

## Dev Notes

### Core Architecture

`ImportService` is the central orchestrator for this story. It:
1. Deserializes `.dictly` bundles via `BundleSerializer.deserialize(from:)` (already implemented in story 3.1)
2. Checks for duplicate sessions by querying SwiftData for matching `Session.uuid`
3. Creates/resolves campaigns, sessions, and tags using existing `DTO → Model` factory methods in `TransferBundle.swift`
4. Copies audio to the app sandbox via `AudioFileManager.audioStorageDirectory()`

Two import entry points exist:
- **AirDrop/Finder open:** macOS delivers a URL via `onOpenURL` when the user opens a `.dictly` file
- **Local network receive:** `LocalNetworkReceiver` (story 3.3) sets `receivedBundleURL` when a bundle arrives over Wi-Fi

### UTI and File Handler Registration (CRITICAL)

The Mac `Info.plist` already has `UTImportedTypeDeclarations` for `com.dictly.dictly-bundle` (added in story 3.3). What's **missing** is `CFBundleDocumentTypes` — this tells macOS "this app can open `.dictly` files." Without it, AirDrop and Finder won't route `.dictly` files to the app.

Add to `DictlyMac/Resources/Info.plist`:

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>LSHandlerRank</key>
        <string>Default</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>com.dictly.dictly-bundle</string>
        </array>
    </dict>
</array>
```

Use `Viewer` (not `Editor`) — the Mac app imports the bundle contents but doesn't edit the `.dictly` file itself.

### onOpenURL for File Opens

SwiftUI's `.onOpenURL` modifier on `WindowGroup` receives URLs when:
- User double-clicks a `.dictly` file in Finder
- User AirDrops a `.dictly` bundle and Mac app is the registered handler
- User drags a `.dictly` file onto the app icon in Dock

```swift
WindowGroup {
    ContentView()
        .environment(importService)
        .environment(networkReceiver)
        .onOpenURL { url in
            importService.importBundle(from: url, context: container.mainContext)
        }
}
```

**AirDrop directory handling:** AirDrop sends `.dictly` as a directory bundle (flat directory with `audio.aac` + `session.json`). The URL from `onOpenURL` will point to this directory. `BundleSerializer.deserialize(from:)` already expects a directory URL — no special handling needed.

### Deduplication Logic

Architecture specifies: "Session UUID in `session.json` checked on Mac import to prevent duplicate imports" [Source: architecture.md — API & Communication Patterns].

```swift
// SwiftData query to check for existing session
let sessionUUID = bundle.session.uuid
let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.uuid == sessionUUID })
let existing = try context.fetch(descriptor)
if !existing.isEmpty {
    importState = .duplicate(sessionTitle: bundle.session.title)
    return
}
```

On duplicate:
- Show "Session already exists" with **Skip** and **Replace** options
- Skip: dismiss, no data changes
- Replace: delete existing session (cascade deletes tags via SwiftData `@Relationship(deleteRule: .cascade)`), delete audio file, re-import

### Campaign Resolution

```swift
if let campaignDTO = bundle.campaign {
    let campaignUUID = campaignDTO.uuid
    let descriptor = FetchDescriptor<Campaign>(predicate: #Predicate { $0.uuid == campaignUUID })
    let existing = try context.fetch(descriptor)
    if let campaign = existing.first {
        session.campaign = campaign
    } else {
        let newCampaign = Campaign.from(campaignDTO)
        context.insert(newCampaign)
        session.campaign = newCampaign
    }
}
```

### Audio File Storage

Use `AudioFileManager.audioStorageDirectory()` (already exists in `DictlyKit/Sources/DictlyStorage/AudioFileManager.swift`) for the destination. Name audio files by session UUID to prevent collisions:

```swift
let storageDir = try AudioFileManager.audioStorageDirectory()
let audioDestination = storageDir.appendingPathComponent("\(session.uuid).aac")
try audioData.write(to: audioDestination)
session.audioFilePath = audioDestination.path
```

### LocalNetworkReceiver Integration

`LocalNetworkReceiver` (story 3.3) publishes `receivedBundleURL: URL?` when a Wi-Fi transfer completes. Observe this in the app and feed to `ImportService`:

```swift
// In ContentView or DictlyMacApp
.onChange(of: networkReceiver.receivedBundleURL) { _, newURL in
    guard let bundleURL = newURL else { return }
    importService.importBundle(from: bundleURL, context: modelContext)
}
```

After import completes, call `networkReceiver.reset()` to clean up the temp bundle and return to `.listening` state.

### ImportProgressView Design

Per UX spec [Source: ux-design-specification.md — Feedback Patterns]:
- "Session imported" → Banner: "Session imported successfully"
- Import progress → Progress bar with percentage (duration: seconds)
- Import errors → inline with specific cause and retry

The banner should overlay the main `ContentView` content (top of window), not block it. Use `.overlay(alignment: .top)` or a `VStack` wrapping approach.

### SwiftData Predicate in Swift 6

SwiftData `#Predicate` requires value types for captures. `UUID` works directly. The session query pattern:

```swift
let targetUUID = bundle.session.uuid
let descriptor = FetchDescriptor<Session>(
    predicate: #Predicate<Session> { session in
        session.uuid == targetUUID
    }
)
```

### What NOT to Do

- **Do NOT** use `DocumentGroup` or `FileDocument` — this is not a document-based app. Use `onOpenURL` for file handling.
- **Do NOT** modify `BundleSerializer` — it's complete from story 3.1 and used by iOS.
- **Do NOT** modify `LocalNetworkReceiver` — it's complete from story 3.3. Only observe its `receivedBundleURL`.
- **Do NOT** modify `DictlyError.ImportError` — the existing cases (`.invalidFormat`, `.duplicateDetected`, `.missingData`) are sufficient.
- **Do NOT** use `@StateObject` or `ObservableObject` — use `@Observable` (project convention).
- **Do NOT** hardcode colors, fonts, or spacing — use `DictlyTheme` tokens.
- **Do NOT** store audio files inside the SwiftData store — audio goes to `AudioFileManager.audioStorageDirectory()`, SwiftData stores the path reference.
- **Do NOT** use `#if os()` in DictlyKit — `ImportService` lives in the Mac target, not the shared package.

### Existing Code to Reuse

| What | Where | How |
|------|-------|-----|
| `BundleSerializer` | `DictlyKit/Sources/DictlyStorage/BundleSerializer.swift` | Call `deserialize(from:)` to unpack `.dictly` bundle |
| `AudioFileManager` | `DictlyKit/Sources/DictlyStorage/AudioFileManager.swift` | Use `audioStorageDirectory()` for audio destination, `deleteAudioFile(at:)` for replace flow |
| `TransferBundle` + DTOs | `DictlyKit/Sources/DictlyModels/TransferBundle.swift` | `Session.from(dto)`, `Tag.from(dto)`, `Campaign.from(dto)` factory methods |
| `DictlyError.import(...)` | `DictlyKit/Sources/DictlyModels/DictlyError.swift` | `.invalidFormat`, `.duplicateDetected`, `.missingData` |
| `DictlySchema` | `DictlyKit/Sources/DictlyModels/DictlySchema.swift` | Schema includes Campaign, Session, Tag, TagCategory |
| `LocalNetworkReceiver` | `DictlyMac/Import/LocalNetworkReceiver.swift` | Observe `receivedBundleURL` — do NOT modify |
| `DictlyTheme` (Colors, Typography, Spacing) | `DictlyKit/Sources/DictlyTheme/` | All UI tokens for ImportProgressView |

### Project Structure Notes

New files:

```
DictlyMac/Import/
├── LocalNetworkReceiver.swift      # EXISTING — unchanged
├── ImportService.swift             # NEW: @Observable — bundle unpacking, dedup, SwiftData writes
└── ImportProgressView.swift        # NEW: Import status banner

DictlyMacTests/ImportTests/
├── LocalNetworkReceiverTests.swift # EXISTING — unchanged
└── ImportServiceTests.swift        # NEW: import, dedup, campaign resolution tests
```

Modified files:
- `DictlyMac/Resources/Info.plist` — add `CFBundleDocumentTypes` for `.dictly` file handling
- `DictlyMac/App/DictlyMacApp.swift` — add `ImportService`, `.onOpenURL`, wire `LocalNetworkReceiver` → `ImportService`
- `DictlyMac/App/ContentView.swift` — add `ImportProgressView` overlay, observe `networkReceiver.receivedBundleURL`

### Testing Standards

- Use `XCTest` with `@MainActor` (project convention)
- Create in-memory `ModelContainer` for SwiftData tests: `ModelConfiguration(isStoredInMemoryOnly: true)`
- Use `BundleSerializer().serialize(...)` to create test `.dictly` bundles (round-trip test)
- Use temporary directories for audio file storage verification
- Clean up temp directories in `tearDown`
- Test state machine transitions on `ImportService`: `.idle` → `.importing` → `.completed` / `.duplicate` / `.failed`
- Mac test target may not run locally without signing certificate (pre-existing constraint from story 3.3) — verify test target builds cleanly

### Previous Story (3.3) Learnings

- `Task.detached` conflicts with `@MainActor`-isolated types in Swift 6 — use `Task {}` which inherits actor isolation
- `LocalNetworkReceiver` publishes `receivedBundleURL` for `ImportService` to consume — this is the integration point
- Mac `DictlyMacTests` cannot run locally without dev signing certificate (iCloud entitlement on host app) — Mac test target builds cleanly (`** TEST BUILD SUCCEEDED **`), same constraint applies here
- `@Observable` `@MainActor` is the pattern for all service classes — `ImportService` must follow this
- Receiver temp bundles are cleaned up via `reset()` — call `reset()` after consuming the bundle URL

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 3, Story 3.4 acceptance criteria]
- [Source: _bmad-output/planning-artifacts/architecture.md — API & Communication Patterns: deduplication via session UUID, transfer bundle format]
- [Source: _bmad-output/planning-artifacts/architecture.md — Project Structure: ImportService.swift, ImportProgressView.swift in DictlyMac/Import/]
- [Source: _bmad-output/planning-artifacts/architecture.md — Mac Target Boundaries: Import/ owns AirDrop receive, bundle unpacking, dedup]
- [Source: _bmad-output/planning-artifacts/architecture.md — Data Flow: AirDrop receive → ImportService → BundleSerializer (unpack)]
- [Source: _bmad-output/planning-artifacts/architecture.md — FR26 maps to ImportService.swift for deduplication]
- [Source: _bmad-output/planning-artifacts/prd.md — FR23-FR26 Transfer & Import, deduplication requirement]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Journey 3: Post-Session Review, import flow, dedup handling]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Feedback Patterns: "Session imported successfully" banner]
- [Source: DictlyKit/Sources/DictlyStorage/BundleSerializer.swift — deserialize(from:) returns (TransferBundle, Data)]
- [Source: DictlyKit/Sources/DictlyModels/TransferBundle.swift — DTO → Model factory methods: Session.from(), Tag.from(), Campaign.from()]
- [Source: DictlyKit/Sources/DictlyModels/DictlyError.swift — ImportError enum: .invalidFormat, .duplicateDetected, .missingData]
- [Source: DictlyKit/Sources/DictlyStorage/AudioFileManager.swift — audioStorageDirectory(), deleteAudioFile(at:)]
- [Source: DictlyMac/Import/LocalNetworkReceiver.swift — receivedBundleURL observable, reset() cleanup]
- [Source: DictlyMac/Resources/Info.plist — existing UTImportedTypeDeclarations for com.dictly.dictly-bundle]
- [Source: DictlyMac/App/DictlyMacApp.swift — existing ModelContainer setup, LocalNetworkReceiver injection]
- [Source: _bmad-output/implementation-artifacts/3-3-local-network-transfer-bonjour-fallback.md — previous story learnings and review findings]
- [Source: Apple Developer Documentation — SwiftUI onOpenURL, CFBundleDocumentTypes, UTImportedTypeDeclarations]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
