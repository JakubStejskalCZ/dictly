# Dictly — Source Tree Analysis

**Generated:** 2026-04-09 | **Scan level:** Deep

---

## Repository Structure

**Type:** Monorepo (Xcode workspace with shared Swift Package)

```
Dictly/                              # Repository root
├── Dictly.xcworkspace/              # Xcode workspace tying all projects together
│
├── DictlyKit/                       # Shared Swift Package (library)
│   ├── Package.swift                # SPM manifest: 4 library targets + 4 test targets
│   ├── Sources/
│   │   ├── DictlyModels/            # @Model classes, DTOs, error types, schema
│   │   │   ├── Campaign.swift       # Campaign entity
│   │   │   ├── Session.swift        # Session entity with audio reference
│   │   │   ├── Tag.swift            # Tag entity anchored to audio timeline
│   │   │   ├── TagCategory.swift    # Category metadata (soft FK to Tag.categoryName)
│   │   │   ├── PauseInterval.swift  # Value type for recording pause gaps
│   │   │   ├── DictlySchema.swift   # Schema registration for ModelContainer
│   │   │   ├── DictlyError.swift    # Domain error taxonomy
│   │   │   ├── DefaultTagSeeder.swift # First-launch category/tag seeding
│   │   │   └── TransferBundle.swift # Codable DTOs for .dictly bundle serialisation
│   │   ├── DictlyTheme/             # Design system tokens
│   │   │   ├── Colors.swift         # Semantic color palette (light/dark adaptive)
│   │   │   ├── Typography.swift     # Platform-conditional type scale
│   │   │   ├── Spacing.swift        # 8-point grid spacing constants
│   │   │   └── Animation.swift      # Animation curves with reduce-motion support
│   │   ├── DictlyStorage/           # Persistence and system integration
│   │   │   ├── AudioFileManager.swift    # Audio file CRUD in Application Support
│   │   │   ├── BundleSerializer.swift    # .dictly bundle pack/unpack
│   │   │   ├── SearchIndexer.swift       # CoreSpotlight tag indexing
│   │   │   └── CategorySyncService.swift # iCloud KVS cross-device category sync
│   │   └── DictlyExport/            # Export formats
│   │       └── MarkdownExporter.swift    # Session → Markdown export
│   └── Tests/
│       ├── DictlyModelsTests/       # Model unit tests
│       ├── DictlyThemeTests/        # Theme token tests
│       ├── DictlyStorageTests/      # Storage and indexer tests
│       └── DictlyExportTests/       # Export format tests
│
├── DictlyiOS/                       # iOS app (XcodeGen-managed)
│   ├── project.yml                  # XcodeGen project definition
│   ├── App/                         # ★ Entry point: DictlyiOSApp.swift, ContentView
│   ├── Campaigns/                   # Campaign/session list and form screens
│   ├── Recording/                   # Live recording: waveform, status bar, summary
│   ├── Tagging/                     # Tag palette, category management, forms
│   ├── Settings/                    # Preferences and storage management
│   ├── Transfer/                    # .dictly bundle send via AirDrop/Bonjour
│   ├── Extensions/                  # View extensions
│   ├── Resources/                   # Info.plist, entitlements, asset catalog
│   └── Tests/                       # iOS-specific integration tests
│       ├── RecordingTests/
│       ├── TaggingTests/
│       └── TransferTests/
│
├── DictlyMac/                       # macOS app (XcodeGen-managed)
│   ├── project.yml                  # XcodeGen project definition (includes WhisperLib)
│   ├── App/                         # ★ Entry point: DictlyMacApp.swift, ContentView
│   ├── Campaigns/                   # Session notes editing
│   ├── Review/                      # ★ Core Mac experience: waveform, tag sidebar, detail
│   ├── Import/                      # .dictly bundle import from AirDrop/Bonjour
│   ├── Export/                      # Session export sheet
│   ├── Search/                      # Cross-session CoreSpotlight search UI
│   ├── Settings/                    # Preferences (storage, model management)
│   ├── Transcription/               # Whisper.cpp bridge, engine, model manager
│   ├── Extensions/                  # View extensions
│   ├── Models/                      # Whisper GGML model binaries (gitignored)
│   └── Resources/                   # Info.plist, entitlements, assets, bridging header
│
├── DictlyiOSTests/                  # iOS test target (XCTest)
├── DictlyMacTests/                  # Mac test target (XCTest)
│   ├── ExportTests/
│   ├── ImportTests/
│   ├── ReviewTests/
│   ├── SearchTests/
│   ├── SidebarTests/
│   └── TranscriptionTests/
│
├── Vendor/
│   └── whisper.cpp/                 # Git submodule: whisper.cpp v1.8.4
│
├── docs/                            # Generated project documentation
└── .scripts/
    └── install-ios-device.sh        # USB device deployment script
```

---

## Critical Folders

| Folder | Purpose |
|--------|---------|
| `DictlyKit/Sources/DictlyModels/` | Core domain: SwiftData entities, DTOs, error types, schema |
| `DictlyKit/Sources/DictlyStorage/` | Persistence: audio files, Spotlight indexing, iCloud sync, bundle serialisation |
| `DictlyKit/Sources/DictlyTheme/` | Design system tokens shared across both apps |
| `DictlyiOS/Recording/` | Live audio recording with real-time waveform and tag placement |
| `DictlyiOS/Transfer/` | Session transfer to Mac via AirDrop or Bonjour TCP |
| `DictlyMac/Review/` | Primary Mac experience: waveform timeline, tag navigation, detail panel |
| `DictlyMac/Transcription/` | On-device whisper.cpp speech-to-text pipeline |
| `DictlyMac/Import/` | Receives .dictly bundles from iOS via AirDrop or Bonjour |

---

## Entry Points

| Part | Entry File | Bootstrap Summary |
|------|-----------|-------------------|
| DictlyiOS | `DictlyiOS/App/DictlyiOSApp.swift` | ModelContainer → seed categories → start iCloud sync → inject services |
| DictlyMac | `DictlyMac/App/DictlyMacApp.swift` | ModelContainer → seed categories → start iCloud sync → start Bonjour listener → inject services + transcription engine |

---

## Integration Points

| From | To | Mechanism | Data |
|------|----|-----------|------|
| DictlyiOS | DictlyMac | AirDrop / Bonjour TCP (`_dictly._tcp`) | `.dictly` bundle (audio.aac + session.json) |
| DictlyiOS ↔ DictlyMac | iCloud | NSUbiquitousKeyValueStore (`com.dictly.shared`) | TagCategory metadata sync |
| Both apps | DictlyKit | Swift Package dependency | Shared models, storage, theme, export |
| DictlyMac | whisper.cpp | Static library + bridging header | C API for speech-to-text inference |
