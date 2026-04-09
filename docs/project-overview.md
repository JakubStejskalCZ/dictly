# Dictly — Project Overview

**Generated:** 2026-04-09 | **Scan level:** Deep

---

## What is Dictly?

Dictly is a **tabletop RPG session recording and review tool** for Apple platforms. Players use the iOS app to record audio and place timestamped tags during gameplay sessions. Sessions are then transferred to the macOS companion app for review, on-device transcription, search, and export.

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **Repository type** | Monorepo (Xcode workspace) |
| **Primary language** | Swift 6.0 (strict concurrency) |
| **UI framework** | SwiftUI |
| **Data persistence** | SwiftData |
| **Architecture** | MVVM + @Observable service layer |
| **Platforms** | iOS 17+ / macOS 14+ |
| **Third-party deps** | whisper.cpp v1.8.4 (vendored, Mac only) |
| **Project tooling** | XcodeGen |
| **Testing** | XCTest |

---

## Project Parts

### DictlyKit — Shared Swift Package

The foundation library shared by both apps:
- **DictlyModels** — SwiftData `@Model` entities (Campaign, Session, Tag, TagCategory), DTOs, error types
- **DictlyTheme** — Design system tokens (colors, typography, spacing, animation)
- **DictlyStorage** — Audio file management, CoreSpotlight indexing, iCloud KVS sync, bundle serialisation
- **DictlyExport** — Markdown export

### DictlyiOS — iOS Recording App

The capture companion:
- Audio recording with real-time waveform visualization
- Tag placement during live recording via category-based palette
- Campaign/session management with location tagging
- Session transfer to Mac via AirDrop or Bonjour TCP
- Tag category management with iCloud cross-device sync

### DictlyMac — macOS Review App

The analysis workstation:
- Interactive waveform timeline with color-coded, shape-distinct tag markers
- On-device transcription via whisper.cpp (Metal GPU-accelerated)
- Cross-session search via CoreSpotlight
- Tag review and editing with notes, transcription, and related tags
- Session import from iOS via AirDrop or Bonjour
- Session export to Markdown
- Whisper model management (download from HuggingFace)

---

## Data Flow

```
┌──────────────┐                                    ┌──────────────┐
│   DictlyiOS  │                                    │   DictlyMac  │
│              │                                    │              │
│  Record audio│     AirDrop / Bonjour TCP          │  Import      │
│  Place tags  │ ─────────────────────────────────> │  Review      │
│  Manage      │     .dictly bundle                 │  Transcribe  │
│  campaigns   │     (audio + session JSON)         │  Search      │
│              │                                    │  Export      │
└──────┬───────┘                                    └──────┬───────┘
       │                                                   │
       │            iCloud KVS Sync                        │
       │<──────────────────────────────────────────────────│
       │         TagCategory metadata                      │
       │         (bidirectional, last-write-wins)           │
       └───────────────────────────────────────────────────┘
```

---

## Technology Stack Summary

| Category | Technology | Notes |
|---|---|---|
| Language | Swift 6.0 | Strict concurrency, `@MainActor` isolation |
| UI | SwiftUI | 100%, no UIKit/AppKit views |
| Data | SwiftData | 4 model entities, no versioned migrations yet |
| Audio | AVAudioEngine | Recording (iOS), playback (Mac) |
| Search | CoreSpotlight | Full-text tag search |
| ML/Transcription | whisper.cpp + Metal | On-device, Mac only |
| Networking | Network.framework | Bonjour `_dictly._tcp` |
| Cloud sync | NSUbiquitousKeyValueStore | TagCategory sync only |
| Design system | DictlyTheme | Custom tokens, 8pt grid, reduce-motion |
| Build | XcodeGen | project.yml → .xcodeproj |
| Logging | OSLog | Privacy-annotated unified logging |

---

## Documentation

- [Architecture](./architecture.md) — Architecture patterns, technology stack, platform details
- [Source Tree Analysis](./source-tree-analysis.md) — Annotated directory structure
- [Data Models](./data-models.md) — SwiftData entities, relationships, storage services
- [Component Inventory](./component-inventory.md) — All SwiftUI views cataloged by platform
- [Development Guide](./development-guide.md) — Setup, build, test, and development workflow
- [Integration Architecture](./integration-architecture.md) — Cross-platform communication details
