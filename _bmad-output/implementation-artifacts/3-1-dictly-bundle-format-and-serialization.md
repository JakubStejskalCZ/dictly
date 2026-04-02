# Story 3.1: .dictly Bundle Format & Serialization

Status: ready-for-dev

## Story

As a developer,
I want a custom .dictly bundle format that packages audio, tags, and session metadata,
so that transfer between iOS and Mac preserves all session data in a single file.

## Acceptance Criteria

1. **Given** a completed session with audio, tags, and metadata, **when** the `BundleSerializer` creates a .dictly bundle, **then** the bundle contains `audio.aac` (session recording) and `session.json` (metadata, tags, campaign association), **and** the JSON uses camelCase keys matching Swift Codable defaults.

2. **Given** a valid .dictly bundle, **when** the `BundleSerializer` unpacks it, **then** all Session, Tag, and Campaign association data is restored from `session.json`, **and** the audio file is extracted intact.

3. **Given** a .dictly bundle with corrupted or missing files, **when** deserialization is attempted, **then** a `DictlyError.transfer(.bundleCorrupted)` is thrown with a specific cause.

4. **Given** the DictlyKit package, **when** bundle serialization/deserialization tests run, **then** round-trip tests pass: serialize → deserialize produces identical data.

## Tasks / Subtasks

- [ ] Task 1: Create Codable DTOs for transfer serialization (AC: #1, #2, #4)
  - [ ] 1.1 Create `TransferBundle.swift` in `DictlyKit/Sources/DictlyModels/` with `SessionDTO`, `TagDTO`, `CampaignDTO`, and root `TransferBundle` Codable structs
  - [ ] 1.2 Add `toDTO()` methods on `Session`, `Tag`, `Campaign` models (extensions in TransferBundle.swift)
  - [ ] 1.3 Add `init(from dto:)` convenience initializers on models for import path
  - [ ] 1.4 Include `PauseInterval` array in `SessionDTO` (already Codable)

- [ ] Task 2: Implement `BundleSerializer` (AC: #1, #2, #3)
  - [ ] 2.1 Create `BundleSerializer.swift` in `DictlyKit/Sources/DictlyStorage/`
  - [ ] 2.2 Implement `serialize(session:audioData:to:)` — creates `.dictly` directory with `audio.aac` + `session.json`
  - [ ] 2.3 Implement `deserialize(from:)` — reads `.dictly` directory, returns `(TransferBundle, Data)` tuple (metadata + audio)
  - [ ] 2.4 Configure `JSONEncoder`/`JSONDecoder` with `.iso8601` date strategy, `.sortedKeys` output formatting
  - [ ] 2.5 Add validation: check both `audio.aac` and `session.json` exist before deserializing

- [ ] Task 3: Error handling for corrupted bundles (AC: #3)
  - [ ] 3.1 Verify `DictlyError.transfer(.bundleCorrupted)` covers all failure cases (missing files, invalid JSON, empty audio)
  - [ ] 3.2 Add descriptive error messages to each failure path

- [ ] Task 4: Unit tests (AC: #4)
  - [ ] 4.1 Create `TransferBundleTests.swift` in `DictlyKit/Tests/DictlyModelsTests/`
  - [ ] 4.2 Create `BundleSerializerTests.swift` in `DictlyKit/Tests/DictlyStorageTests/`
  - [ ] 4.3 Test DTO round-trip: model → DTO → JSON → DTO → verify equality
  - [ ] 4.4 Test BundleSerializer round-trip: session + audio → .dictly directory → deserialize → verify all data intact
  - [ ] 4.5 Test error cases: missing audio.aac, missing session.json, corrupted JSON, empty directory
  - [ ] 4.6 Test edge cases: session with zero tags, session with many tags across categories, optional fields nil

## Dev Notes

### Critical: SwiftData @Model Does NOT Auto-Synthesize Codable

The `@Model` macro interferes with Swift's automatic `Codable` synthesis. **Do NOT add `Codable` conformance directly to `@Model` classes.** Instead, use a separate DTO (Data Transfer Object) pattern:

```swift
// ✅ CORRECT: Separate Codable struct
struct SessionDTO: Codable {
    let uuid: UUID
    let title: String
    let date: Date
    // ...
}

// ✅ Extension on @Model for conversion
extension Session {
    func toDTO() -> SessionDTO { ... }
}

// ❌ WRONG: Adding Codable to @Model (macro conflicts)
@Model class Session: Codable { ... }  // Will NOT auto-synthesize
```

This is the same pattern used by `CategorySyncService.swift` which has `SyncableCategory: Codable` as a DTO.

### Bundle Format Specification

The `.dictly` bundle is a **flat directory** (not a zip) containing exactly two files:

```
MySession.dictly/
├── audio.aac      # Session recording (AAC 64kbps mono, actually .m4a format)
└── session.json   # TransferBundle JSON (session + tags + campaign metadata)
```

### TransferBundle JSON Structure

```json
{
  "version": 1,
  "session": {
    "uuid": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
    "title": "Session 3",
    "sessionNumber": 3,
    "date": "2026-04-01T19:30:00Z",
    "duration": 7200.0,
    "locationName": "Game Store",
    "summaryNote": "The party found the artifact",
    "pauseIntervals": [{"start": 1800.0, "end": 1860.0}]
  },
  "tags": [
    {
      "uuid": "...",
      "label": "Combat Start",
      "categoryName": "Combat",
      "anchorTime": 450.5,
      "rewindDuration": 10.0,
      "notes": null,
      "transcription": null,
      "createdAt": "2026-04-01T19:37:30Z"
    }
  ],
  "campaign": {
    "uuid": "...",
    "name": "Curse of Strahd",
    "descriptionText": "Gothic horror campaign",
    "createdAt": "2026-03-15T10:00:00Z"
  }
}
```

Key JSON conventions:
- camelCase keys (Swift Codable default — no custom `CodingKeys` needed on DTOs)
- Dates encoded as ISO 8601 strings (`JSONEncoder.dateEncodingStrategy = .iso8601`)
- UUIDs encoded as uppercase hyphenated strings (Swift default)
- `version` field for future format evolution
- `.sortedKeys` output formatting for deterministic output (easier testing/debugging)

### Implementation Approach: FileManager (Not FileWrapper)

Use plain `FileManager` to create/read the directory bundle — simpler and sufficient since we don't need `FileDocument` or `DocumentGroup` integration:

```swift
// Serialize
func serialize(session: Session, audioData: Data, to url: URL) throws {
    let fm = FileManager.default
    try fm.createDirectory(at: url, withIntermediateDirectories: true)
    try audioData.write(to: url.appendingPathComponent("audio.aac"))
    let jsonData = try JSONEncoder.appDefault.encode(bundle)
    try jsonData.write(to: url.appendingPathComponent("session.json"))
}

// Deserialize
func deserialize(from url: URL) throws -> (TransferBundle, Data) {
    let audioURL = url.appendingPathComponent("audio.aac")
    let jsonURL = url.appendingPathComponent("session.json")
    guard fm.fileExists(atPath: audioURL.path) else {
        throw DictlyError.transfer(.bundleCorrupted)
    }
    // ...
}
```

### Audio File Format Note

Session audio files are stored locally as `.m4a` (AAC 64kbps mono) with UUID-based filenames. When packaging into the bundle, the audio is copied as `audio.aac`. The file content is identical — only the filename changes for bundle format consistency. See `AudioFileManager.audioStorageDirectory()` for path resolution and `SessionRecorder` for the recording format.

### Existing Code to Reuse

| What | Where | How |
|------|-------|-----|
| Data models (Session, Tag, Campaign, TagCategory) | `DictlyKit/Sources/DictlyModels/` | Add DTO extensions, do NOT modify @Model classes |
| PauseInterval (already Codable) | `DictlyKit/Sources/DictlyModels/PauseInterval.swift` | Include directly in SessionDTO |
| DictlyError.transfer(.bundleCorrupted) | `DictlyKit/Sources/DictlyModels/DictlyError.swift` | Already exists — use as-is |
| AudioFileManager | `DictlyKit/Sources/DictlyStorage/AudioFileManager.swift` | Use `audioStorageDirectory()` to locate source audio |
| SyncableCategory DTO pattern | `DictlyKit/Sources/DictlyStorage/CategorySyncService.swift` | Reference for Codable DTO approach |
| In-memory ModelContainer test setup | `DictlyKit/Tests/DictlyModelsTests/SessionTests.swift` | Copy test infrastructure pattern |

### What NOT to Do

- **Do NOT** add `Codable` directly to `@Model` classes — use DTOs
- **Do NOT** create custom `CodingKeys` enums — camelCase default matches architecture spec
- **Do NOT** use `FileWrapper` — plain `FileManager` is simpler and sufficient
- **Do NOT** register the UTI in this story — that's story 3.4 (Mac Import)
- **Do NOT** implement AirDrop or network transfer — those are stories 3.2 and 3.3
- **Do NOT** touch iOS or Mac app targets — this story is entirely within DictlyKit
- **Do NOT** include `TagCategory` sync data in the bundle — categories sync via iCloud KVS (story 1.6), the bundle only needs category *names* on tags
- **Do NOT** use fractional seconds in ISO 8601 — the built-in `.iso8601` strategy doesn't handle them, and standard precision is sufficient

### Project Structure Notes

All new files go in **DictlyKit** (shared package, no platform-specific imports):

```
DictlyKit/Sources/
├── DictlyModels/
│   └── TransferBundle.swift          # NEW: Codable DTOs + model extensions
└── DictlyStorage/
    └── BundleSerializer.swift        # NEW: Pack/unpack .dictly directories

DictlyKit/Tests/
├── DictlyModelsTests/
│   └── TransferBundleTests.swift     # NEW: DTO round-trip tests
└── DictlyStorageTests/
    └── BundleSerializerTests.swift   # NEW: Serializer round-trip + error tests
```

These paths match the architecture document's project structure exactly.

### Testing Standards

- Use `XCTest` with `@MainActor` (project convention)
- Use in-memory `ModelContainer` for tests that need SwiftData models:
  ```swift
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  container = try ModelContainer(for: Schema(DictlySchema.all), configurations: config)
  context = container.mainContext
  ```
- Use temporary directories for BundleSerializer file I/O tests (clean up in `tearDown`)
- Test round-trip equality by comparing all DTO fields, not object identity
- BundleSerializer tests don't need a ModelContainer — they work with DTOs and raw Data

### References

- [Source: _bmad-output/planning-artifacts/architecture.md — Data Architecture, API & Communication Patterns, Data Patterns sections]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 3, Story 3.1 acceptance criteria]
- [Source: _bmad-output/planning-artifacts/prd.md — FR23-FR26 Transfer & Import requirements]
- [Source: DictlyKit/Sources/DictlyModels/Session.swift — Session @Model definition]
- [Source: DictlyKit/Sources/DictlyModels/Tag.swift — Tag @Model definition]
- [Source: DictlyKit/Sources/DictlyModels/Campaign.swift — Campaign @Model definition]
- [Source: DictlyKit/Sources/DictlyModels/PauseInterval.swift — Existing Codable struct pattern]
- [Source: DictlyKit/Sources/DictlyStorage/CategorySyncService.swift — SyncableCategory DTO pattern reference]
- [Source: DictlyKit/Sources/DictlyModels/DictlyError.swift — TransferError enum]
- [Source: DictlyKit/Sources/DictlyStorage/AudioFileManager.swift — Audio path management]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
