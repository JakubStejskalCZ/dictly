# Dictly — Project Documentation Index

**Generated:** 2026-04-09 | **Scan level:** Deep | **Mode:** Initial scan

---

## Project Overview

- **Type:** Monorepo (Xcode workspace) with 3 parts
- **Primary Language:** Swift 6.0 (strict concurrency)
- **Architecture:** MVVM + @Observable service layer
- **Platforms:** iOS 17+ / macOS 14+

## Quick Reference

### DictlyKit (library)
- **Tech Stack:** Swift 6.0, SwiftData, CoreSpotlight, NSUbiquitousKeyValueStore
- **Root:** `DictlyKit/`
- **Entry Point:** `Package.swift` (SPM manifest)
- **Purpose:** Shared models, design system, storage services, export

### DictlyiOS (mobile)
- **Tech Stack:** Swift 6.0, SwiftUI, AVAudioEngine, Network.framework
- **Root:** `DictlyiOS/`
- **Entry Point:** `DictlyiOS/App/DictlyiOSApp.swift`
- **Purpose:** Audio recording, tag placement, session transfer to Mac

### DictlyMac (desktop)
- **Tech Stack:** Swift 6.0, SwiftUI, whisper.cpp + Metal, CoreSpotlight, Network.framework
- **Root:** `DictlyMac/`
- **Entry Point:** `DictlyMac/App/DictlyMacApp.swift`
- **Purpose:** Session review, on-device transcription, search, export

---

## Generated Documentation

- [Project Overview](./project-overview.md) — What Dictly is, quick reference, data flow
- [Architecture](./architecture.md) — Architecture patterns, tech stack, platform-specific details
- [Source Tree Analysis](./source-tree-analysis.md) — Annotated directory structure, critical folders, entry points
- [Data Models](./data-models.md) — SwiftData entities, relationships, storage services, error taxonomy
- [Component Inventory](./component-inventory.md) — All SwiftUI views cataloged by platform and category
- [Development Guide](./development-guide.md) — Prerequisites, setup, build, test, conventions
- [Integration Architecture](./integration-architecture.md) — iOS-Mac transfer, iCloud sync, shared dependencies

---

## Existing Documentation

- [Project Context](./../_bmad-output/project-context.md) — AI agent context rules (Swift 6, SwiftData patterns, coding standards)

---

## Getting Started

1. Clone the repo and initialize submodules: `git submodule update --init --recursive`
2. Install XcodeGen: `brew install xcodegen`
3. Generate Xcode projects: `cd DictlyiOS && xcodegen generate && cd ../DictlyMac && xcodegen generate && cd ..`
4. Open `Dictly.xcworkspace` in Xcode
5. Select `DictlyiOS` or `DictlyMac` scheme and build (`Cmd+B`)
6. For Mac transcription: download Whisper models via Preferences > Transcription
