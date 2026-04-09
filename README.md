# Dictly

> A tabletop RPG session recording and review tool for Apple platforms.

Record your sessions on iOS, review and transcribe them on macOS. Tag story beats, combat encounters, and character moments in real time -- then search, transcribe, and export them later.

## Overview

Dictly is a dual-app system for tabletop RPG players:

- **iOS** -- Record live sessions with audio capture and place timestamped tags during gameplay
- **macOS** -- Import sessions, review them on an interactive waveform timeline, run on-device speech-to-text transcription, search across sessions, and export to Markdown

Sessions transfer between devices via AirDrop or local network (Bonjour TCP). Tag categories sync bidirectionally through iCloud.

```
┌──────────────┐                                    ┌──────────────┐
│   DictlyiOS  │                                    │   DictlyMac  │
│              │                                    │              │
│  Record audio│     AirDrop / Bonjour TCP          │  Import      │
│  Place tags  │ ──────────────────────────────────> │  Review      │
│  Manage      │     .dictly bundle                 │  Transcribe  │
│  campaigns   │     (audio + session JSON)         │  Search      │
│              │                                    │  Export      │
└──────┬───────┘                                    └──────┬───────┘
       │            iCloud KVS Sync                        │
       │<─────────────────────────────────────────────────>│
       │         TagCategory metadata                      │
       └───────────────────────────────────────────────────┘
```

## Features

### iOS Recording App

- Live audio recording with real-time waveform visualization
- Tag placement during recording via a category-based palette (Story, Combat, Roleplay, World, Meta)
- Campaign and session management with optional location tagging
- Session transfer to Mac via AirDrop or Bonjour TCP

### macOS Review App

- Interactive four-layer waveform timeline with category-specific marker shapes
- On-device transcription via [whisper.cpp](https://github.com/ggerganov/whisper.cpp) with Metal GPU acceleration
- Cross-session full-text search via CoreSpotlight
- Tag editing with notes, transcription preview, and related tags
- Session export to Markdown
- Whisper model management (download from HuggingFace)

## Tech Stack

| Category | Technology |
|----------|------------|
| Language | Swift 6.0 (strict concurrency) |
| UI | SwiftUI (100%) |
| Data | SwiftData |
| Audio | AVAudioEngine |
| Transcription | whisper.cpp + Metal (Mac only) |
| Search | CoreSpotlight |
| Networking | Network.framework (Bonjour) |
| Cloud sync | iCloud Key-Value Store |
| Design system | Custom DictlyTheme (semantic tokens, 8pt grid) |
| Build | XcodeGen |
| Testing | XCTest |

> [!NOTE]
> Zero external Swift Package Manager dependencies. The only vendored dependency is whisper.cpp.

## Project Structure

```
Dictly/
├── DictlyKit/              # Shared Swift Package
│   ├── DictlyModels        # SwiftData entities (Campaign, Session, Tag, TagCategory)
│   ├── DictlyTheme         # Design tokens (colors, typography, spacing, animation)
│   ├── DictlyStorage       # Audio management, Spotlight, iCloud sync
│   └── DictlyExport        # Markdown export
├── DictlyiOS/              # iOS recording app
├── DictlyMac/              # macOS review app
├── DictlyiOSTests/         # iOS test target
├── DictlyMacTests/         # macOS test target
├── Vendor/whisper.cpp/     # Vendored transcription engine (git submodule)
└── Dictly.xcworkspace      # Workspace combining all targets
```

## Getting Started

### Prerequisites

| Requirement | Version |
|-------------|---------|
| macOS | 14.0+ (Sonoma) |
| Xcode | 16.0+ |
| XcodeGen | Latest (`brew install xcodegen`) |
| iOS device | iOS 17.0+ (for on-device testing) |
| Apple Developer account | Required for iCloud and device deployment |

### Setup

```bash
# Clone and pull whisper.cpp submodule
git clone <repo-url> Dictly
cd Dictly
git submodule update --init --recursive

# Generate Xcode projects
cd DictlyiOS && xcodegen generate && cd ..
cd DictlyMac && xcodegen generate && cd ..

# Open workspace
open Dictly.xcworkspace
```

> [!TIP]
> Whisper models are not included in the repository. On first Mac app launch, go to **Preferences > Transcription** to download models from HuggingFace.

### Build

Select the `DictlyiOS` or `DictlyMac` scheme in Xcode and press `Cmd+R`, or build from the command line:

```bash
# iOS (simulator)
xcodebuild -workspace Dictly.xcworkspace -scheme DictlyiOS \
  -sdk iphonesimulator -configuration Debug build

# macOS
xcodebuild -workspace Dictly.xcworkspace -scheme DictlyMac \
  -configuration Debug build
```

### Test

```bash
# Shared package tests (no Xcode project required)
cd DictlyKit && swift test

# Full test suites
xcodebuild test -workspace Dictly.xcworkspace -scheme DictlyiOS \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'

xcodebuild test -workspace Dictly.xcworkspace -scheme DictlyMac \
  -destination 'platform=macOS'
```

## Documentation

Detailed documentation is available in the [`docs/`](./docs/) directory:

- [Project Overview](./docs/project-overview.md) -- High-level summary
- [Architecture](./docs/architecture.md) -- Patterns, technology stack, platform details
- [Data Models](./docs/data-models.md) -- SwiftData entities and relationships
- [Integration Architecture](./docs/integration-architecture.md) -- Cross-platform communication
- [Component Inventory](./docs/component-inventory.md) -- All SwiftUI views by platform
- [Development Guide](./docs/development-guide.md) -- Full setup, build, and testing workflow
