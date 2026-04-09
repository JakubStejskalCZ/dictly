# Dictly — Architecture

**Generated:** 2026-04-09 | **Scan level:** Deep

---

## Executive Summary

Dictly is a tabletop RPG session recording and review tool built as an Apple-native monorepo. An iOS app records audio and places timestamped tags during play; sessions are transferred to a macOS companion app for review, transcription, and export. The codebase is 100% Swift 6.0 / SwiftUI with a single vendored C/C++ dependency (whisper.cpp for on-device speech-to-text on Mac).

---

## Architecture Pattern

**MVVM with @Observable Service Layer** — consistent across all three parts.

- **Views** hold no business logic; they observe ViewModel/service state and dispatch actions.
- **Services** are `@Observable @MainActor` classes injected via `.environment()`.
- **Models** are SwiftData `@Model` entities in DictlyKit.
- **No Combine, no Coordinator, no Redux/TCA** — lean SwiftUI + Swift Observation + SwiftData.
- **Swift 6 strict concurrency** enforced project-wide; `@MainActor` isolation on all UI-bound services.

```
┌─────────────────────────────────────────────────────────┐
│                   Dictly.xcworkspace                     │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │  DictlyiOS   │  │  DictlyMac   │  │   DictlyKit   │  │
│  │  (iOS app)   │  │  (Mac app)   │  │   (Package)   │  │
│  ├──────────────┤  ├──────────────┤  ├───────────────┤  │
│  │ Recording    │  │ Review       │  │ DictlyModels  │  │
│  │ Tagging      │  │ Transcribe   │  │ DictlyTheme   │  │
│  │ Transfer     │  │ Import       │  │ DictlyStorage │  │
│  │ Campaigns    │  │ Export       │  │ DictlyExport  │  │
│  │ Settings     │  │ Search       │  │               │  │
│  │              │  │ Campaigns    │  │               │  │
│  │              │  │ Settings     │  │               │  │
│  └──────┬───────┘  └──────┬───────┘  └───────────────┘  │
│         │                 │                  ▲            │
│         └─────────────────┴──────────────────┘            │
│                      depends on                           │
│                                                           │
│  ┌──────────────────────────────────────────────────────┐│
│  │               Vendor/whisper.cpp                     ││
│  │      (static lib, linked by DictlyMac only)          ││
│  └──────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

---

## Technology Stack

| Category | Technology | Version | Part(s) |
|---|---|---|---|
| Language | Swift | 6.0 (strict concurrency) | All |
| UI Framework | SwiftUI | iOS 17+ / macOS 14+ | All |
| Data Persistence | SwiftData | iOS 17+ / macOS 14+ | All |
| iCloud Sync | NSUbiquitousKeyValueStore | — | DictlyKit |
| Audio Recording | AVAudioEngine + AVAudioFile | — | iOS, Mac |
| System Search | CoreSpotlight | — | DictlyKit, Mac |
| Transcription | whisper.cpp | 1.8.4 | Mac only |
| GPU Acceleration | Metal + MetalKit + MPS | — | Mac only |
| CPU Acceleration | Accelerate.framework | — | Mac only |
| Local Networking | Network.framework (Bonjour) | — | iOS, Mac |
| Design System | DictlyTheme (custom) | — | All |
| Project Gen | XcodeGen | — | iOS, Mac |
| Logging | OSLog (unified logging) | — | All |
| Testing | XCTest | — | All |

**Third-party dependencies:** Only whisper.cpp (vendored git submodule). Zero SPM external dependencies.

---

## Data Architecture

### SwiftData Models

Four `@Model` entities: `Campaign`, `Session`, `Tag`, `TagCategory`.

- **Campaign → Session:** One-to-many, cascade delete.
- **Session → Tag:** One-to-many, cascade delete.
- **TagCategory:** Standalone; soft-linked to `Tag` via `categoryName` string.
- **Schema:** `DictlySchema.all` — flat array, no versioned migrations.

### Persistence Strategy

| Store | Purpose |
|-------|---------|
| SwiftData | Structured data (campaigns, sessions, tags, categories) |
| Filesystem | Audio files (`<ApplicationSupport>/Recordings/`, M4A) |
| iCloud KVS | TagCategory cross-device sync (last-write-wins) |
| CoreSpotlight | Full-text search indexing of tags |

### Transfer Format

`.dictly` bundle directory: `audio.aac` + `session.json` (JSON-encoded `TransferBundle` with session, tags, and campaign DTOs).

---

## Platform-Specific Architecture

### DictlyiOS — Recording & Transfer

```
DictlyiOSApp
  ├── ModelContainer (SwiftData)
  ├── SessionRecorder (@Observable)    → AVAudioEngine recording
  ├── CategorySyncService (@Observable) → iCloud KVS sync
  └── View hierarchy
       ├── CampaignListScreen → CampaignDetailScreen
       ├── RecordingScreen (modal)
       │    ├── RecordingStatusBar
       │    ├── LiveWaveform
       │    └── TagPalette
       ├── TransferPrompt (post-recording)
       │    ├── AirDrop (UIActivityViewController)
       │    └── Bonjour TCP (LocalNetworkSender)
       └── Settings / TagCategoryManagement
```

**Key flows:**
1. **Record:** `SessionRecorder` → `AVAudioEngine` → M4A file → `Session` in SwiftData.
2. **Tag:** `TagPalette` → `Tag` created with `anchorTime` from recorder elapsed time.
3. **Transfer:** `BundleSerializer.serialize()` → AirDrop or `LocalNetworkSender` (Bonjour TCP, 4-byte framing).
4. **Orphan recovery:** On launch, `SessionRecorder.recoverOrphanedRecordings()` repairs interrupted sessions.

### DictlyMac — Review & Transcription

```
DictlyMacApp
  ├── ModelContainer (SwiftData)
  ├── TranscriptionEngine (@Observable)
  │    ├── WhisperBridge (C interop)
  │    └── ModelManager (download/manage GGML models)
  ├── ImportService (@Observable)
  ├── LocalNetworkReceiver (@Observable) → Bonjour listener
  ├── CategorySyncService (@Observable) → iCloud KVS sync
  └── View hierarchy (HSplitView)
       ├── Sidebar: campaign-grouped session list + search
       ├── Detail: SessionReviewScreen
       │    ├── TagSidebar (filterable tag list)
       │    ├── SessionWaveformTimeline (interactive waveform)
       │    └── TagDetailPanel (notes, transcription, related tags)
       └── Settings: PreferencesWindow
            ├── StoragePreferencesTab
            └── ModelManagementView
```

**Key flows:**
1. **Import:** AirDrop `.onOpenURL` or Bonjour `receivedBundleURL` → `ImportService.importBundle()` → deserialize → SwiftData insert + audio copy.
2. **Review:** `SessionReviewScreen` → `AudioPlayer` (AVAudioEngine) → waveform + tag navigation.
3. **Transcribe:** Select tag → `TranscriptionEngine.transcribe()` → `WhisperBridge` (off-main-actor, `Task.detached`) → whisper.cpp C API → `Tag.transcription` updated.
4. **Search:** `SearchService` queries CoreSpotlight → results resolved through SwiftData → cross-session navigation.
5. **Export:** `ExportSheet` → `MarkdownExporter` → Markdown output.

---

## Cross-Platform Communication

### iOS → Mac Transfer

| Method | Protocol | Discovery | Data Path |
|--------|----------|-----------|-----------|
| AirDrop | Apple proprietary | Proximity | `UIActivityViewController` → `.onOpenURL` |
| Bonjour TCP | `_dictly._tcp` | `NWBrowser` / `NWListener` | `LocalNetworkSender` → 4-byte length-framed TCP → `LocalNetworkReceiver` |

### iCloud KVS Sync

- **Key:** `"tagCategories"` → JSON array of `SyncableCategory`
- **Direction:** Bidirectional
- **Conflict resolution:** Last-write-wins (ISO 8601 fractional-second timestamps)
- **Side effects:** Category renames propagate to all matching `Tag.categoryName` records

---

## Testing Architecture

| Tier | Location | Framework | Scope |
|------|----------|-----------|-------|
| Unit (Kit) | `DictlyKit/Tests/` | XCTest | Models, theme, storage, export — runnable via `swift test` |
| Integration (Mac) | `DictlyMacTests/` | XCTest | Review, search, transcription, import, sidebar |
| Integration (iOS) | `DictlyiOS/Tests/` | XCTest | Recording, tagging, transfer |

All tests use in-memory `ModelContainer`. Mac tests require valid dev signing certificate.

---

## Key Design Decisions

1. **Vendored whisper.cpp:** Compiled as static library for full control over build flags and Metal shader compilation.
2. **Soft FK for TagCategory:** No SwiftData relationship enables independent iCloud KVS sync without cascading conflicts.
3. **Pause intervals as JSON blob:** Avoids SwiftData child entity for simple time-range array.
4. **Deterministic UUIDs in seeder:** FNV-1a hash from names prevents duplicates across synced devices.
5. **No schema versioning:** All changes additive so far. Migration plan needed before field removal/rename.
6. **XcodeGen:** `project.yml` is source of truth; `.xcodeproj` files are generated artifacts.
