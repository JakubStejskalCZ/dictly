---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-04-01'
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/product-brief-Dictly.md
  - _bmad-output/planning-artifacts/product-brief-Dictly-distillate.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
workflowType: 'architecture'
project_name: 'Dictly'
user_name: 'Stejk'
date: '2026-04-01'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
49 FRs spanning 9 domains. The requirements split cleanly across two platforms:
- **iOS-only (FR1–FR22):** Recording engine (6 FRs), real-time tagging (7 FRs), tag/category management (4 FRs), campaign/session organization (5 FRs)
- **Both platforms (FR23–FR26):** Transfer & import (4 FRs) — iOS sends, Mac receives
- **Mac-only (FR27–FR49):** Post-session review (10 FRs), transcription (4 FRs), search & archive (4 FRs), export (2 FRs), settings (3 FRs)

Architecturally significant FRs:
- **FR2 (4+ hour background recording)** — drives audio session architecture and disk-flush strategy
- **FR6 (survive phone calls/interrupts)** — requires robust AVAudioSession interruption handling
- **FR8 (rewind-anchor tagging)** — requires either a circular buffer or post-hoc timestamp calculation
- **FR23–FR26 (transfer with bundled metadata)** — requires a custom file format/UTI for Dictly session bundles
- **FR37 (WhisperX local transcription)** — requires Python runtime integration or native alternative on Mac
- **FR41 (full-text search across sessions)** — requires indexing strategy for transcriptions and tag labels

**Non-Functional Requirements:**
- **Performance:** Tag response < 200ms, recording start < 1s, waveform 60fps, search < 1min across 10+ sessions
- **Data integrity:** < 5s audio loss on crash (frequent disk flush), zero tag loss, zero transfer corruption, session data isolation
- **Privacy:** Zero network calls, all data on-device, microphone only during recording, location only at session start
- **Accessibility:** VoiceOver, Dynamic Type, color independence (shape + color for tag markers), Reduce Motion support

**Scale & Complexity:**
- Primary domain: Native Apple ecosystem (iOS + macOS, Swift/SwiftUI)
- Complexity level: Medium
- Estimated architectural components: ~8–10 major modules (audio engine, tag system, data persistence, transfer, waveform rendering, transcription engine, search index, shared data model, UI layer per platform)

### Technical Constraints & Dependencies

- **Language/Framework:** Swift + SwiftUI (both targets), no cross-platform frameworks
- **Audio:** AVFoundation/AVAudioEngine (iOS recording), Core Audio (Mac waveform rendering and playback)
- **Storage:** App sandbox on both platforms, AAC 64kbps mono (~115 MB per 4-hour session)
- **Transcription:** WhisperX (Python) or mlx-whisper (native) — decision required
- **Transfer:** AirDrop via UTI registration + Bonjour local network as fallback
- **Distribution:** App Store (iOS) + Mac App Store — must comply with sandbox and review requirements
- **No backend:** Fully offline architecture — no APIs, no accounts, no sync in MVP

### Cross-Cutting Concerns Identified

1. **Shared data model** — Tag, Session, Campaign structures used by both iOS and Mac apps. Must be defined once (Swift package or shared framework) with serialization for transfer bundles.
2. **Tag category system** — Categories (Story, Combat, Roleplay, World, Meta) with colors, icons, and custom user additions flow through tagging, display, filtering, waveform markers, and export across both apps.
3. **Audio file format** — AAC 64kbps mono must be consistent from iOS recording through Mac playback, waveform rendering, and WhisperX input.
4. **Transfer bundle format** — Custom file format packaging audio + tag metadata + session metadata + campaign association. Needs UTI registration on both platforms.
5. **Accessibility** — VoiceOver labels, Dynamic Type scaling, color-independent tag markers, and Reduce Motion support affect every custom component on both platforms.
6. **Data integrity** — Immediate-write strategy for tags, frequent audio flush, import verification — consistent reliability patterns across all data operations.

## Starter Template Evaluation

### Primary Technology Domain

Native Apple ecosystem (iOS + macOS) with Swift and SwiftUI, based on project requirements mandating fully local, App Store-distributed, offline-only applications.

### Starter Options Considered

**Option A — Xcode Multiplatform App Template:**
Apple's built-in multiplatform template creates shared SwiftUI code with platform-specific targets. However, Dictly's iOS and Mac apps have deliberately zero feature overlap (iOS captures, Mac reviews). A multiplatform template assumes shared UI, which would create artificial coupling between apps that serve fundamentally different purposes.

**Option B — Two App Targets + Shared Swift Package (Selected):**
Two independent app targets in one Xcode workspace, with a local `DictlyKit` Swift package for shared data models, business logic, and design tokens. Each app target contains only its platform-specific code. The shared package is independently testable and enforces a clean boundary between shared logic and platform-specific implementation.

**Option C — Fully Separate Xcode Projects:**
Maximum isolation but unnecessary overhead for a solo developer on a single product at MVP scale.

### Selected Starter: Two App Targets + Shared DictlyKit Swift Package

**Rationale for Selection:**
- Dictly's two apps have zero feature overlap by design — iOS captures, Mac reviews. A shared-UI multiplatform template would fight this architecture.
- The UX specification already defines a `DictlyTheme`/`DictlyUI` shared package for colors, typography, and spacing — this structure supports it natively.
- Shared data models (Tag, Session, Campaign) are defined once in the package and used by both targets, ensuring transfer bundle compatibility.
- Each app target stays focused: iOS-specific code (AVAudioEngine, haptics, background recording) stays in the iOS target; Mac-specific code (waveform rendering, Core Audio playback, transcription) stays in the Mac target.
- Swift Package is testable independently of either app target.

**Initialization:**

```
Dictly.xcworkspace/
├── DictlyiOS/              (iOS app target)
│   ├── App/                (SwiftUI App entry point, scenes)
│   ├── Recording/          (audio engine, recording UI)
│   ├── Tagging/            (tag palette, real-time tagging)
│   ├── Transfer/           (AirDrop send, session export)
│   └── Resources/          (assets, Info.plist)
├── DictlyMac/              (macOS app target)
│   ├── App/                (SwiftUI App entry point, scenes)
│   ├── Review/             (waveform timeline, tag detail panel)
│   ├── Transcription/      (whisper.cpp integration)
│   ├── Search/             (full-text search, archive browse)
│   ├── Import/             (AirDrop receive, session import)
│   └── Resources/          (assets, Info.plist)
├── DictlyKit/              (shared Swift package)
│   ├── Sources/
│   │   ├── DictlyModels/   (Tag, Session, Campaign, Category)
│   │   ├── DictlyTheme/    (colors, typography, spacing tokens)
│   │   ├── DictlyStorage/  (persistence layer, bundle format)
│   │   └── DictlyExport/   (markdown export logic)
│   └── Tests/
└── Dictly.xcworkspace
```

**Architectural Decisions Provided by Starter:**

**Language & Runtime:**
- Swift (latest stable) for all code
- SwiftUI for all UI on both platforms
- Swift Package Manager for dependency management and code sharing

**Shared Package (`DictlyKit`):**
- `DictlyModels`: Tag, Session, Campaign, TagCategory — Codable structs shared by both apps and used for transfer bundle serialization
- `DictlyTheme`: tag category colors, base palette (light/dark), typography scale, spacing tokens — as defined in the UX specification
- `DictlyStorage`: shared persistence layer (SwiftData or Core Data for structured data, file system for audio)
- `DictlyExport`: markdown export logic (shared because both apps may need export in post-MVP)

**Testing Framework:**
- XCTest for unit and integration tests on the shared package
- XCUITest for UI testing on each app target

**Code Organization:**
- Feature-based folder structure within each app target (Recording, Tagging, Review, etc.)
- Module-based organization in the shared package (Models, Theme, Storage, Export)
- Platform-specific `#if os(iOS)` / `#if os(macOS)` only in the shared package where truly needed — prefer keeping platform code in platform targets

**Transcription Engine Decision:**
- **whisper.cpp** (C/C++) with Metal and Core ML support instead of WhisperX (Python)
- Rationale: native performance on Apple Silicon (>3x speedup via ANE), no Python runtime bundling required, Mac App Store sandbox compatible, available as a C library callable from Swift
- Transcription runs only on Mac, only on tagged segments (~30s each)

**Note:** Project initialization using this structure should be the first implementation story.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
- Data persistence: SwiftData
- Transfer bundle format: Custom UTI flat directory bundle
- State management: SwiftUI native `@Observable`
- Transcription engine: whisper.cpp with Metal/Core ML

**Important Decisions (Shape Architecture):**
- Error handling: Swift native `Result` + `DictlyError` enum
- Logging: OSLog/Logger for structured local debugging
- CI/CD: Manual Xcode builds initially, Xcode Cloud for App Store submission

**Deferred Decisions (Post-MVP):**
- Authentication: Apple Sign-In (Phase 2)
- Encryption: AES-256-GCM E2E for Vault tier (Phase 2)
- Cloud sync: iCloud/custom backend (Phase 2)
- CI/CD automation: Xcode Cloud pipeline (when ready for TestFlight)

### Data Architecture

- **Persistence:** SwiftData with `@Model` macro for Tag, Session, Campaign, TagCategory entities
- **SwiftUI integration:** `@Query` for reactive list/detail views on both platforms
- **Migration strategy:** SwiftData lightweight automatic migrations — sufficient for MVP single-user scope
- **Transfer serialization:** SwiftData models also conform to `Codable` for JSON serialization in `.dictly` transfer bundles. Persistence store and transfer format are separate representations of the same models.
- **Audio storage:** File system within app sandbox. SwiftData stores metadata references (file paths), not audio data.
- **Session isolation:** Each session's audio and metadata are stored independently — corruption in one session cannot affect others (NFR requirement).

### Authentication & Security

- **MVP:** No authentication, no accounts, no network access
- **Data protection:** App sandbox on both platforms provides OS-level data isolation
- **Permissions:** Microphone (iOS, during recording only), Location (iOS, optional, at session start only)
- **No application-level encryption in MVP** — platform sandboxing is sufficient for local-only data
- **Post-MVP:** Apple Sign-In + AES-256-GCM E2E encryption for cloud Vault tier

### API & Communication Patterns

- **No REST/GraphQL APIs** — fully offline architecture, no backend
- **Transfer bundle format:** Custom UTI (`.dictly`) as a flat directory package containing:
  - `audio.aac` — session recording (AAC 64kbps mono)
  - `session.json` — session metadata, tags, campaign association, all as Codable JSON
  - UTI registered on both platforms so AirDrop/Finder recognizes Dictly bundles
- **Deduplication:** Session UUID in `session.json` checked on Mac import to prevent duplicate imports
- **Local network fallback:** Bonjour service discovery + direct Wi-Fi transfer of the same `.dictly` bundle
- **Error handling:** Swift native `do/catch` with `Result` type. `DictlyError` enum defined in `DictlyKit` shared package covering: recording failures, disk space issues, transfer failures, transcription failures, import errors.

### Frontend Architecture

- **State management:** SwiftUI native observation (`@Observable`, `@State`, `@Environment`, `@Bindable`)
- **No external state management dependencies** — app state is not deeply interconnected across platforms; recording state (iOS) and review state (Mac) are independent
- **SwiftData `@Query`** drives reactive data display in list/detail views
- **Component architecture:** Native SwiftUI components for standard UI + custom components for signature interactions (TagCard, LiveWaveform, CategoryTabBar, SessionWaveformTimeline, TagDetailPanel) as defined in UX specification
- **Design tokens:** `DictlyTheme` shared package with colors, typography, spacing constants used by both targets

### Infrastructure & Deployment

- **Distribution:** App Store (iOS) + Mac App Store (macOS), universal purchase
- **Signing:** Standard Apple Developer Program, Xcode-managed signing
- **CI/CD:** Manual Xcode builds for MVP. Xcode Cloud added when ready for TestFlight/App Store submission.
- **Logging:** `OSLog`/`Logger` framework for structured local debugging. No remote crash reporting or analytics (zero network calls by design).
- **Monitoring:** Xcode Organizer for crash logs once on App Store
- **Storage:** ~115 MB per 4-hour session (iOS), audio + transcriptions on Mac. User manages storage via FR49 (view usage, delete recordings). No automated cleanup.

### Decision Impact Analysis

**Implementation Sequence:**
1. Project workspace setup (two targets + DictlyKit package)
2. SwiftData models in DictlyKit (Tag, Session, Campaign, TagCategory)
3. DictlyTheme package (colors, typography, spacing)
4. iOS recording engine (AVAudioEngine, background session)
5. iOS tagging system (tag palette, rewind-anchor, haptics)
6. Transfer bundle format (`.dictly` UTI, Codable serialization)
7. Mac import and session display
8. Mac waveform timeline and playback
9. Mac transcription (whisper.cpp integration)
10. Mac search and archive
11. Markdown export

**Cross-Component Dependencies:**
- SwiftData models must be finalized before any UI work begins (both targets depend on them)
- Transfer bundle format must match between iOS export and Mac import
- DictlyTheme must be established before custom component development
- whisper.cpp integration is Mac-only and can proceed independently once audio format is settled
- Search indexing depends on transcription output format

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

**Critical Conflict Points Identified:** 6 areas where AI agents could make different choices — naming, file structure, SwiftUI view patterns, data modeling, error handling, and logging.

### Naming Patterns

**Swift Naming (Apple Swift API Design Guidelines as baseline):**
- Types: `PascalCase` — `TagCategory`, `SessionRecorder`, `WaveformView`
- Properties/functions: `camelCase` — `tagCount`, `startRecording()`, `isRecording`
- Booleans: prefix with `is`/`has`/`should` — `isRecording`, `hasTranscription`, `shouldAutoScroll`
- Enum cases: `camelCase` — `case story`, `case combat`, `case roleplay`

**SwiftData Model Naming:**
- Singular `PascalCase` — `Tag`, `Session`, `Campaign`, `TagCategory`
- All models define a `uuid: UUID` property for identity and transfer deduplication

**File Naming:**
- Match primary type name — `TagCard.swift`, `SessionRecorder.swift`
- View files: suffix with `View` only if ambiguous — `RecordingScreen.swift` (clear), but `TagDetailView.swift` if `TagDetail` model also exists
- No `+` extension file convention — extensions go in the type's own file or `Extensions/` folder

**JSON Keys (`.dictly` transfer bundle):**
- `camelCase` — Swift `Codable` default encoding, no custom `CodingKeys` needed
- Example: `{ "sessionId": "...", "tagCount": 25, "rewindDuration": 10.0 }`

### Structure Patterns

**Test Organization:**
- Shared package: `DictlyKit/Tests/DictlyModelsTests/`, `DictlyKit/Tests/DictlyStorageTests/`, etc.
- Platform targets: `DictlyiOSTests/`, `DictlyMacTests/`
- Not co-located — tests live in dedicated test targets

**View + ViewModel Organization:**
- Same file if view model is small (<50 lines)
- Separate file if larger — e.g., `RecordingScreen.swift` + `RecordingViewModel.swift`
- ViewModel file named `{Feature}ViewModel.swift`

**Extensions:**
- Extensions on Apple types: `Extensions/` folder within the relevant target or package module
- Extensions on Dictly types: same file as the type definition

**Assets:**
- Each app target has its own `Assets.xcassets`
- Shared colors defined in `DictlyTheme` as Swift code (not asset catalogs) for cross-target consistency

### SwiftUI Patterns

**View Composition:**
- Extract subview when `body` exceeds ~40 lines or a section is reused
- Use `@ViewBuilder` or concrete conditional views — never `AnyView` type erasure
- Prefer computed properties for simple extracted subviews within the same file

**State Management:**
- `@Observable` classes for stateful services (`SessionRecorder`, `TranscriptionEngine`, `AudioPlayer`) injected via `@Environment`
- `@State` for view-local state only (UI toggles, sheet presentation, text input)
- `@Query` for SwiftData-driven lists and detail views
- No `@StateObject` / `ObservableObject` — use `@Observable` macro exclusively

**Navigation:**
- iOS: `NavigationStack` with programmatic `NavigationPath` for push/pop
- Mac: `NavigationSplitView` with selection bindings for sidebar/detail
- Recording screen (iOS): presented as full-screen modal — no back button, only Stop

**Async Work:**
- Prefer `.task` modifier on views for async loading and observation
- Use explicit `Task { }` only inside `@Observable` service classes
- Never `Task` inside `body` — always `.task` modifier or button action

### Data Patterns

**Timestamps:**
- Tag anchors: `TimeInterval` (seconds from session recording start)
- Session/campaign dates: `Date` (absolute)
- Display formatting: `DateFormatter` / `Duration` formatting, never raw number display

**SwiftData Relationships:**
- Explicit `@Relationship` macro with cascade delete rules on parent
- Campaign → Session (cascade delete)
- Session → Tag (cascade delete)
- TagCategory is independent — deleting a category does not delete its tags (reassign to "Uncategorized")

**Model Identity:**
- All SwiftData models have `uuid: UUID` as stable identity
- `uuid` used for transfer bundle deduplication on Mac import
- SwiftData's `PersistentIdentifier` used internally, `uuid` used for cross-device identity

### Error Handling Patterns

**Error Definition:**
- `DictlyError` enum with associated values, defined in `DictlyKit/DictlyModels`
- Conforms to `LocalizedError` for user-facing messages
- Categories: `.recording(RecordingError)`, `.transfer(TransferError)`, `.transcription(TranscriptionError)`, `.storage(StorageError)`, `.import(ImportError)`

**Error Propagation:**
- Service layer: `throw` — no `Result` type wrapping
- SwiftUI views: handle errors from `.task` with `do/catch` or `.alert` presentation
- Never silently swallow errors — log at `.error` level minimum

**Error UI:**
- Recording errors: persistent top banner, never auto-dismiss
- Transfer errors: inline in transfer prompt with retry
- Transcription errors: per-tag inline badge with retry button
- Import errors: inline with specific cause and retry

### Logging Patterns

**Logger Configuration:**
- Subsystem: `com.dictly.ios` / `com.dictly.mac`
- Category per module: `recording`, `tagging`, `transfer`, `transcription`, `search`, `import`, `storage`

**Log Levels:**
- `.debug` — development-only detail (audio buffer sizes, frame timing)
- `.info` — user actions (session started, tag placed, import completed)
- `.error` — recoverable failures (transcription failed, transfer timeout)
- `.fault` — unrecoverable state (audio session cannot be configured, database corruption)

**Format:**
- Use string interpolation with privacy: `Logger.recording.info("Tag placed at \(timestamp, privacy: .public) in session \(sessionId, privacy: .private)")`
- Session IDs and user data: `.private` privacy level
- Timestamps and counts: `.public` privacy level

### Enforcement Guidelines

**All AI Agents MUST:**
1. Follow Swift API Design Guidelines for all naming
2. Use `@Observable` (not `ObservableObject`) for all service classes
3. Use `.task` modifier (not inline `Task {}`) for async work in views
4. Define errors as `DictlyError` cases, never ad-hoc `Error` types
5. Log all failures at `.error` or `.fault` level with `os.Logger`
6. Use `uuid: UUID` on all SwiftData models for stable identity
7. Keep JSON keys as `camelCase` in transfer bundles — no custom `CodingKeys`

**Anti-Patterns to Avoid:**
- `AnyView` type erasure — use `@ViewBuilder` or conditional views
- `@StateObject` or `ObservableObject` — replaced by `@Observable`
- `Result` return types — use `throw` instead
- Hardcoded strings for log categories — use predefined `Logger` extensions
- Co-located test files — tests go in dedicated test targets
- Custom `CodingKeys` for JSON serialization — stick with `camelCase` default

## Project Structure & Boundaries

### Complete Project Directory Structure

```
Dictly/
├── .gitignore
├── .swiftlint.yml
├── Dictly.xcworkspace/
│
├── DictlyKit/                              # Shared Swift Package
│   ├── Package.swift
│   ├── Sources/
│   │   ├── DictlyModels/
│   │   │   ├── Campaign.swift              # @Model — name, description, uuid, sessions
│   │   │   ├── Session.swift               # @Model — uuid, date, duration, title, location, tags
│   │   │   ├── Tag.swift                   # @Model — uuid, label, category, anchorTime, rewindDuration, notes, transcription
│   │   │   ├── TagCategory.swift           # @Model — uuid, name, color, icon, sortOrder, isDefault
│   │   │   ├── DictlyError.swift           # Error enum with RecordingError, TransferError, etc.
│   │   │   └── TransferBundle.swift        # Codable wrapper for .dictly bundle serialization
│   │   ├── DictlyTheme/
│   │   │   ├── Colors.swift                # Tag category colors, base palette (light/dark)
│   │   │   ├── Typography.swift            # Type scale definitions
│   │   │   ├── Spacing.swift               # 8pt grid spacing tokens
│   │   │   └── Animation.swift             # Shared animation curves and timing
│   │   ├── DictlyStorage/
│   │   │   ├── StorageManager.swift        # SwiftData ModelContainer setup, shared config
│   │   │   ├── BundleSerializer.swift      # Encode/decode .dictly directory bundles
│   │   │   └── AudioFileManager.swift      # Audio file path management, cleanup helpers
│   │   └── DictlyExport/
│   │       └── MarkdownExporter.swift      # Session/campaign → CommonMark markdown
│   └── Tests/
│       ├── DictlyModelsTests/
│       │   ├── CampaignTests.swift
│       │   ├── SessionTests.swift
│       │   ├── TagTests.swift
│       │   └── TransferBundleTests.swift
│       ├── DictlyStorageTests/
│       │   ├── BundleSerializerTests.swift
│       │   └── StorageManagerTests.swift
│       └── DictlyExportTests/
│           └── MarkdownExporterTests.swift
│
├── DictlyiOS/                              # iOS App Target
│   ├── App/
│   │   ├── DictlyiOSApp.swift              # @main entry point, ModelContainer setup
│   │   └── ContentView.swift               # Root NavigationStack
│   ├── Recording/
│   │   ├── SessionRecorder.swift           # @Observable — AVAudioEngine, background session, disk flush
│   │   ├── RecordingScreen.swift           # Main recording UI — waveform, tag palette, timer
│   │   ├── RecordingViewModel.swift        # Recording state, interruption handling
│   │   ├── LiveWaveform.swift              # Custom SwiftUI view — real-time audio level bars
│   │   └── RecordingStatusBar.swift        # Animated red dot, timer, tag count
│   ├── Tagging/
│   │   ├── TagPalette.swift                # Tag grid with category tabs
│   │   ├── TagCard.swift                   # Custom tappable tag button with color stripe
│   │   ├── CategoryTabBar.swift            # Horizontally scrollable category filter
│   │   ├── CustomTagSheet.swift            # .sheet for custom tag label input
│   │   └── TaggingService.swift            # @Observable — rewind-anchor logic, tag creation, haptics
│   ├── Campaigns/
│   │   ├── CampaignListScreen.swift        # Campaign list with create/edit
│   │   ├── CampaignDetailScreen.swift      # Session list within campaign
│   │   ├── SessionListRow.swift            # Session row (date, duration, tag count)
│   │   └── CampaignFormSheet.swift         # Create/edit campaign form
│   ├── Transfer/
│   │   ├── TransferService.swift           # @Observable — AirDrop send, bundle packaging
│   │   ├── TransferPrompt.swift            # Post-session transfer UI
│   │   └── LocalNetworkSender.swift        # Bonjour + direct Wi-Fi fallback
│   ├── Settings/
│   │   ├── SettingsScreen.swift            # Rewind duration, audio quality, storage management
│   │   └── StorageManagementView.swift     # Space used, delete old recordings
│   ├── Extensions/
│   │   └── UIImpactFeedbackGenerator+Tag.swift
│   └── Resources/
│       ├── Assets.xcassets/
│       ├── Info.plist                      # Microphone usage, location usage, background audio, UTI
│       └── Localizable.strings
│
├── DictlyiOSTests/
│   ├── RecordingTests/
│   │   ├── SessionRecorderTests.swift
│   │   └── RecordingViewModelTests.swift
│   ├── TaggingTests/
│   │   └── TaggingServiceTests.swift
│   └── TransferTests/
│       └── TransferServiceTests.swift
│
├── DictlyMac/                              # macOS App Target
│   ├── App/
│   │   ├── DictlyMacApp.swift              # @main entry point, ModelContainer setup
│   │   └── ContentView.swift               # Root NavigationSplitView
│   ├── Review/
│   │   ├── SessionReviewScreen.swift       # Main review layout — sidebar + waveform + detail
│   │   ├── SessionWaveformTimeline.swift   # Custom view — Core Audio waveform + tag markers + playhead
│   │   ├── TagDetailPanel.swift            # Below-waveform detail — label, transcription, notes, related tags
│   │   ├── TagSidebar.swift                # Scrollable tag list with category filters
│   │   ├── TagSidebarRow.swift             # Individual tag row in sidebar
│   │   ├── AudioPlayer.swift              # @Observable — Core Audio playback, seek, scrub
│   │   └── RetroactiveTagPlacer.swift      # Interaction for placing tags on waveform scrub
│   ├── Transcription/
│   │   ├── TranscriptionEngine.swift       # @Observable — whisper.cpp Swift bridge, batch processing
│   │   ├── WhisperBridge.swift             # C interop layer for whisper.cpp
│   │   └── TranscriptionProgressView.swift # Per-tag and batch progress UI
│   ├── Search/
│   │   ├── SearchService.swift             # @Observable — full-text search across sessions
│   │   ├── SearchResultsView.swift         # Cross-session search results list
│   │   └── SearchResultRow.swift           # Result row — label, session #, timestamp, snippet
│   ├── Import/
│   │   ├── ImportService.swift             # @Observable — AirDrop receive, bundle unpacking, dedup
│   │   ├── LocalNetworkReceiver.swift      # Bonjour listener + Wi-Fi receive
│   │   └── ImportProgressView.swift        # Import status banner
│   ├── Campaigns/
│   │   ├── CampaignSidebar.swift           # Campaign source list in NavigationSplitView
│   │   ├── SessionListView.swift           # Chronological session list
│   │   └── SessionNotesView.swift          # Session-level summary notes
│   ├── Export/
│   │   └── ExportSheet.swift               # Export options — single session or campaign markdown
│   ├── Settings/
│   │   └── PreferencesWindow.swift         # macOS Preferences (⌘,) — storage, transcription model
│   ├── Extensions/
│   │   └── NSPasteboard+Dictly.swift
│   └── Resources/
│       ├── Assets.xcassets/
│       ├── Info.plist                      # UTI handler registration, file type associations
│       └── Localizable.strings
│
├── DictlyMacTests/
│   ├── ReviewTests/
│   │   └── AudioPlayerTests.swift
│   ├── TranscriptionTests/
│   │   └── TranscriptionEngineTests.swift
│   ├── SearchTests/
│   │   └── SearchServiceTests.swift
│   └── ImportTests/
│       └── ImportServiceTests.swift
│
└── Vendor/
    └── whisper.cpp/                        # whisper.cpp source (git submodule or SPM)
```

### Architectural Boundaries

**Package Boundary (DictlyKit ↔ App Targets):**
- DictlyKit exposes only models, theme tokens, storage API, and export logic
- DictlyKit has zero platform-specific imports — no UIKit, no AppKit, no AVFoundation
- App targets import DictlyKit modules; DictlyKit never imports app target code
- Platform-specific code stays in its app target — no `#if os()` in DictlyKit (exception: minor SwiftUI differences in Theme if unavoidable)

**iOS Target Boundaries:**
- `Recording/` owns AVAudioEngine, audio session configuration, and disk flush — no other module touches audio recording
- `Tagging/` owns rewind-anchor calculation, haptic feedback, and tag creation during recording
- `Transfer/` owns AirDrop send and bundle packaging — calls `BundleSerializer` from DictlyKit
- `Campaigns/` is pure SwiftData `@Query` views — no business logic beyond CRUD

**Mac Target Boundaries:**
- `Import/` owns AirDrop receive, bundle unpacking, and deduplication — calls `BundleSerializer` from DictlyKit
- `Review/` owns waveform rendering (Core Audio), audio playback, and tag editing
- `Transcription/` owns whisper.cpp bridge — isolated from all other modules, communicates results by writing to SwiftData
- `Search/` owns full-text search — queries SwiftData directly, no intermediate service

**Data Boundary:**
- SwiftData `ModelContainer` is configured once at app launch in the `@main` App struct
- All modules access data through SwiftData `@Query` or `ModelContext` — no custom data access layer wrapping SwiftData
- Audio files live in app sandbox file system, referenced by path in SwiftData models
- Transfer bundles are the only data exchange format between iOS and Mac

### Requirements to Structure Mapping

**FR1–FR6 (Recording & Capture):** `DictlyiOS/Recording/`
- `SessionRecorder.swift` — FR1 (new session), FR2 (4+ hours), FR3 (pause/resume), FR4 (external mic), FR6 (interruption handling)
- `RecordingScreen.swift` + `LiveWaveform.swift` — FR5 (visual indicator)

**FR7–FR13 (Real-Time Tagging):** `DictlyiOS/Tagging/`
- `TaggingService.swift` — FR7 (single tap), FR8 (rewind anchor), FR11 (haptic)
- `TagPalette.swift` + `TagCard.swift` — FR9 (category palette), FR12 (tag count), FR13 (active categories)
- `CustomTagSheet.swift` — FR10 (custom tag)

**FR14–FR17 (Tag & Category Management):** `DictlyiOS/Campaigns/` + `DictlyKit/DictlyModels/`
- `TagCategory.swift` model — FR14–FR16 (CRUD, reorder)
- FR17 (default categories) — seeded on first launch in `DictlyiOSApp.swift`

**FR18–FR22 (Campaign & Session Organization):** `DictlyiOS/Campaigns/` + `DictlyMac/Campaigns/`
- Shared `Campaign.swift` + `Session.swift` models in DictlyKit
- Platform-specific list/detail views in each target

**FR23–FR26 (Transfer & Import):** `DictlyiOS/Transfer/` + `DictlyMac/Import/` + `DictlyKit/DictlyStorage/`
- `BundleSerializer.swift` — FR25 (bundled package format)
- `TransferService.swift` — FR23 (AirDrop), FR24 (local network)
- `ImportService.swift` — FR26 (deduplication)

**FR27–FR36 (Post-Session Review):** `DictlyMac/Review/`
- `SessionWaveformTimeline.swift` — FR27 (timeline), FR28 (click to jump), FR33 (retroactive tags), FR36 (full audio scrub)
- `TagSidebar.swift` — FR29 (filter by category)
- `TagDetailPanel.swift` — FR30–FR32 (edit/change/delete tags), FR34 (notes), FR35 (session summary)

**FR37–FR40 (Transcription):** `DictlyMac/Transcription/`
- `TranscriptionEngine.swift` + `WhisperBridge.swift` — FR37 (local whisper.cpp), FR38 (per-tag/batch)
- `TagDetailPanel.swift` — FR39 (view transcription), FR40 (edit transcription)

**FR41–FR44 (Search & Archive):** `DictlyMac/Search/` + `DictlyMac/Campaigns/`
- `SearchService.swift` — FR41 (full-text search), FR43 (link to audio moment)
- `TagSidebar.swift` — FR42 (browse by category across sessions)
- `SessionListView.swift` — FR44 (chronological session list)

**FR45–FR46 (Export):** `DictlyMac/Export/` + `DictlyKit/DictlyExport/`
- `MarkdownExporter.swift` — FR45 (single session), FR46 (multi-session/campaign)

**FR47–FR49 (Settings):** `DictlyiOS/Settings/` + `DictlyMac/Settings/`
- FR47 (rewind duration), FR48 (audio quality) — iOS settings
- FR49 (storage management) — both platforms

### Cross-Cutting Concerns Mapping

| Concern | Location |
|---------|----------|
| SwiftData models | `DictlyKit/DictlyModels/` |
| Design tokens | `DictlyKit/DictlyTheme/` |
| Transfer bundle format | `DictlyKit/DictlyStorage/BundleSerializer.swift` |
| Error types | `DictlyKit/DictlyModels/DictlyError.swift` |
| Markdown export | `DictlyKit/DictlyExport/MarkdownExporter.swift` |
| UTI registration | `DictlyiOS/Resources/Info.plist` + `DictlyMac/Resources/Info.plist` |
| Accessibility | Every custom component in both targets |

### Data Flow

```
iOS Capture Flow:
  AVAudioEngine → AAC file (disk) → SessionRecorder
  User tap → TaggingService → Tag (SwiftData) + haptic
  Stop recording → Session summary
  Transfer → BundleSerializer → .dictly bundle → AirDrop/Wi-Fi

Mac Review Flow:
  AirDrop receive → ImportService → BundleSerializer (unpack)
  → Session + Tags (SwiftData) + audio file (disk)
  → SessionWaveformTimeline (Core Audio render)
  → Tag selected → AudioPlayer (seek + play)
  → TranscriptionEngine (whisper.cpp) → transcription text (SwiftData)
  → SearchService (SwiftData queries) → cross-session results
  → MarkdownExporter → .md file
```

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:**
All technology choices are Apple-native and fully compatible: Swift + SwiftUI + SwiftData + `@Observable` + AVFoundation + Core Audio + whisper.cpp (C interop) + Core Spotlight + `NSUbiquitousKeyValueStore`. No version conflicts or incompatible dependencies.

**Pattern Consistency:**
- Naming follows Swift API Design Guidelines uniformly across models, services, and views
- `@Observable` used for all service classes, `@State` for view-local state — no mixed observation patterns
- Error handling is consistently `throw` in services, `.task` catch in views
- JSON serialization uses `camelCase` default everywhere — no custom `CodingKeys`

**Structure Alignment:**
- DictlyKit maintains zero platform-specific imports
- Every FR maps to a specific file/directory with no orphaned requirements
- Test structure mirrors source structure
- Architectural boundaries are clearly enforced between package and targets

### Requirements Coverage Validation ✅

**Functional Requirements Coverage (49/49):**
- FR1–FR6 (Recording & Capture) → `DictlyiOS/Recording/` ✅
- FR7–FR13 (Real-Time Tagging) → `DictlyiOS/Tagging/` ✅
- FR14–FR17 (Tag & Category Management) → `DictlyKit/DictlyModels/` + `DictlyiOS/Campaigns/` ✅
- FR18–FR22 (Campaign & Session Organization) → Both platforms' `Campaigns/` ✅
- FR23–FR26 (Transfer & Import) → `Transfer/` + `Import/` + `DictlyKit/DictlyStorage/` ✅
- FR27–FR36 (Post-Session Review) → `DictlyMac/Review/` ✅
- FR37–FR40 (Transcription) → `DictlyMac/Transcription/` ✅
- FR41–FR44 (Search & Archive) → `DictlyMac/Search/` + Core Spotlight ✅
- FR45–FR46 (Export) → `DictlyMac/Export/` + `DictlyKit/DictlyExport/` ✅
- FR47–FR49 (Settings) → Both platforms' `Settings/` ✅

**Non-Functional Requirements Coverage:**
- Performance (< 200ms tag, 60fps waveform, < 1s recording start) — native frameworks ✅
- Data integrity (< 5s audio loss, zero tag loss) — frequent disk flush, immediate SwiftData writes ✅
- Privacy (zero network for user data) — no analytics, no telemetry, model downloads are user-initiated only ✅
- Accessibility (VoiceOver, Dynamic Type, color independence) — enforcement guidelines on all custom components ✅

### Gap Analysis Results

**Three gaps identified during validation — all resolved:**

**Gap 1: Full-Text Search Strategy (Resolved)**
- **Issue:** SwiftData `#Predicate` string matching may not scale for 50+ sessions
- **Resolution:** Core Spotlight (`CSSearchableIndex`) for full-text search indexing
- Tags and transcriptions indexed on creation (iOS) and import (Mac)
- Fast ranked search with metadata for direct tag navigation
- Bonus: system Spotlight integration on macOS — users can search Dictly tags from Spotlight
- **Structural impact:** Add `SearchIndexer.swift` to `DictlyKit/DictlyStorage/` for shared indexing logic. `SearchService.swift` on Mac queries Core Spotlight instead of SwiftData predicates for text search.

**Gap 2: Whisper Model Bundling (Resolved)**
- **Issue:** No model size specified, affecting app size and transcription quality
- **Resolution:** Ship with `base.en` (~150 MB) as default. Offer downloadable models in Preferences:
  - `small.en` (~500 MB) — better accuracy
  - `medium.en` (~1.5 GB) — best quality
- Model downloads are the one exception to "zero network" — user-initiated, optional, downloads a model file only (no user data sent)
- `TranscriptionEngine` detects available models and uses the best one present
- **Structural impact:** Add `ModelManager.swift` to `DictlyMac/Transcription/` for model download, storage, and selection.

**Gap 3: Tag Category Sync Between Platforms (Resolved)**
- **Issue:** Tag categories created on iOS don't appear on Mac (and vice versa) without a sync mechanism
- **Resolution:** `NSUbiquitousKeyValueStore` (iCloud Key-Value Store) for automatic bidirectional category sync
  - Syncs only tag category metadata (name, color, icon, sort order) — never recordings or session data
  - 1 MB limit is more than sufficient for tag categories (hundreds of categories fit easily)
  - Automatic, real-time, zero user friction
  - Privacy story intact: "your recordings and sessions never leave your devices" — only tag preferences sync
  - Both apps observe key-value store changes and merge into local SwiftData
- **Structural impact:** Add `CategorySyncService.swift` to `DictlyKit/DictlyStorage/` — shared between both targets. Both app entry points register for `NSUbiquitousKeyValueStore` change notifications.

### Validation Issues Addressed

All three gaps resolved with no contradictions to existing architectural decisions. Updated structural impacts:

```
DictlyKit/Sources/DictlyStorage/
├── StorageManager.swift
├── BundleSerializer.swift
├── AudioFileManager.swift
├── SearchIndexer.swift          # NEW — Core Spotlight indexing logic
└── CategorySyncService.swift    # NEW — iCloud KVS category sync

DictlyMac/Transcription/
├── TranscriptionEngine.swift
├── WhisperBridge.swift
├── TranscriptionProgressView.swift
└── ModelManager.swift           # NEW — whisper model download & selection
```

### Architecture Completeness Checklist

**✅ Requirements Analysis**
- [x] Project context thoroughly analyzed
- [x] Scale and complexity assessed
- [x] Technical constraints identified
- [x] Cross-cutting concerns mapped

**✅ Architectural Decisions**
- [x] Critical decisions documented (SwiftData, whisper.cpp, Core Spotlight, iCloud KVS)
- [x] Technology stack fully specified — all Apple-native
- [x] Integration patterns defined (transfer bundle, Core Spotlight, iCloud KVS)
- [x] Performance considerations addressed

**✅ Implementation Patterns**
- [x] Naming conventions established (Swift API Design Guidelines)
- [x] Structure patterns defined (feature-based, package boundary)
- [x] Communication patterns specified (`@Observable`, SwiftData, `.task`)
- [x] Process patterns documented (error handling, logging)

**✅ Project Structure**
- [x] Complete directory structure with all files defined
- [x] Component boundaries established (DictlyKit ↔ app targets)
- [x] Integration points mapped (transfer bundle, Core Spotlight, iCloud KVS)
- [x] All 49 FRs mapped to specific files/directories

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High — all decisions use established Apple-native technologies with no experimental dependencies. The only external dependency (whisper.cpp) is mature and well-tested on Apple Silicon.

**Key Strengths:**
- Fully Apple-native stack — no cross-platform abstractions, no web dependencies
- Clean separation: shared package (DictlyKit) + two focused app targets
- Every FR mapped to a concrete file location
- Zero backend complexity — fully offline with lightweight iCloud KVS for category sync only
- Privacy-first architecture validated at every layer
- whisper.cpp with Core ML/Metal provides native transcription without Python runtime

**Areas for Future Enhancement:**
- Full iCloud sync for sessions/recordings (Phase 2 — requires backend architecture decisions)
- Additional whisper models and language support beyond English
- Core Spotlight indexing could be extended to support campaign-level search
- Watch app companion would need its own target + shared DictlyKit dependency

### Implementation Handoff

**AI Agent Guidelines:**
- Follow all architectural decisions exactly as documented
- Use implementation patterns consistently across all components
- Respect project structure and boundaries — DictlyKit has zero platform imports
- Refer to this document for all architectural questions
- When in doubt about a pattern, check the Enforcement Guidelines section

**First Implementation Priority:**
1. Create Xcode workspace with two app targets + `DictlyKit` Swift package
2. Define SwiftData models in `DictlyKit/DictlyModels/`
3. Set up `DictlyTheme` with colors, typography, spacing from UX specification
4. Implement `CategorySyncService` with `NSUbiquitousKeyValueStore`
5. Build iOS recording engine (`SessionRecorder` + AVAudioEngine)
