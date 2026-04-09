# Dictly — Development Guide

**Generated:** 2026-04-09 | **Scan level:** Deep

---

## Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| macOS | 14.0+ (Sonoma) | Required for deployment target |
| Xcode | 16.0+ | Required for Swift 6.0 |
| XcodeGen | Latest | `brew install xcodegen` |
| iOS device | iOS 17.0+ | For on-device recording testing |
| Apple Developer account | — | Required for iCloud KVS and device deployment |
| Git | — | With submodule support |

---

## Initial Setup

### 1. Clone and initialize submodules

```bash
git clone https://github.com/JakubStejskalCZ/dictly.git Dictly
cd Dictly
git submodule update --init --recursive
```

This pulls `Vendor/whisper.cpp/` (required for Mac transcription).

### 2. Generate Xcode projects

```bash
cd DictlyiOS && xcodegen generate && cd ..
cd DictlyMac && xcodegen generate && cd ..
```

### 3. Open workspace

```bash
open Dictly.xcworkspace
```

### 4. Download Whisper models (Mac only)

Model files are gitignored. On first Mac app launch, use **Preferences > Transcription** to download models from HuggingFace. Stored in `~/Library/Application Support/Dictly/Models/`.

---

## Project Structure

| Target | Type | Source of Truth |
|--------|------|----------------|
| `DictlyKit` | Swift Package | `DictlyKit/Package.swift` |
| `DictlyiOS` | iOS app | `DictlyiOS/project.yml` |
| `DictlyMac` | macOS app | `DictlyMac/project.yml` |
| `WhisperLib` | Static library (C/C++) | `DictlyMac/project.yml` |
| `DictlyiOSTests` | Test bundle | `DictlyiOS/project.yml` |
| `DictlyMacTests` | Test bundle | `DictlyMac/project.yml` |

---

## Build Commands

### From Xcode

Select scheme (`DictlyiOS` or `DictlyMac`) → select device → `Cmd+B` / `Cmd+R`.

### From command line

```bash
# Build iOS (simulator)
xcodebuild -workspace Dictly.xcworkspace -scheme DictlyiOS \
  -sdk iphonesimulator -configuration Debug build

# Build Mac
xcodebuild -workspace Dictly.xcworkspace -scheme DictlyMac \
  -configuration Debug build

# Build DictlyKit only
cd DictlyKit && swift build
```

### Install on iOS device via USB

```bash
.scripts/install-ios-device.sh
```

---

## Testing

### DictlyKit tests (no Xcode required)

```bash
cd DictlyKit && swift test
```

### Full test suite (requires Xcode)

```bash
# iOS tests
xcodebuild -workspace Dictly.xcworkspace -scheme DictlyiOS \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' test

# Mac tests (requires dev signing certificate)
xcodebuild -workspace Dictly.xcworkspace -scheme DictlyMac test
```

### Test organization

| Location | Scope | Notes |
|----------|-------|-------|
| `DictlyKit/Tests/` | Model, theme, storage, export unit tests | Runnable via `swift test` |
| `DictlyMacTests/` | Review, search, transcription, import, sidebar | Requires signing cert |
| `DictlyiOS/Tests/` | Recording, tagging, transfer | Simulator or device |

### Conventions

- All tests use **in-memory ModelContainer** (no on-disk leakage).
- `@MainActor` class-level on tests touching `@MainActor`-isolated services.
- Tests reference story/AC numbers (e.g., `// MARK: - 7.2`, `// AC1:`).

---

## Development Workflow

### Adding source files

- **DictlyKit:** Add `.swift` to appropriate source dir — SPM auto-discovers.
- **iOS/Mac apps:** Add file, then re-run `xcodegen generate` if needed.

### Modifying project settings

1. Edit `project.yml`.
2. Run `xcodegen generate`.
3. Commit both `.yml` and regenerated `.xcodeproj`.

### SwiftData models

- All in `DictlyKit/Sources/DictlyModels/`.
- Register new models in `DictlySchema.all`.
- Keep changes additive (new optional fields) — no versioned migrations yet.
- For serialisation, create companion DTO structs (see `TransferBundle.swift`).

### Design system

- **Colors:** `DictlyColors.background`, `.textPrimary`, etc. (adaptive light/dark)
- **Typography:** `DictlyTypography.body`, `.title`, etc. (platform-conditional)
- **Spacing:** `DictlySpacing.md` (16pt), `.sm` (8pt), etc. (8-point grid)
- **Animations:** `DictlyAnimation` tokens with reduce-motion support

---

## Environment & Signing

### Debug builds

Debug entitlements are **empty** — no iCloud KVS. Category sync won't function in Debug.

### Release builds

- iCloud KVS: `$(TeamIdentifierPrefix)com.dictly.shared`
- Team: `9H8L6QA868`, automatic signing

### File locations

| Data | Location |
|------|----------|
| Audio files | `<ApplicationSupport>/Recordings/` (M4A, AAC 64 kbps mono) |
| Whisper models | `~/Library/Application Support/Dictly/Models/` (gitignored) |
| SwiftData store | Default SwiftData location (persistent, iCloud-backed) |

---

## Key Conventions

| Convention | Details |
|---|---|
| Concurrency | Swift 6 strict; `@MainActor` on UI services; `Task.detached` for whisper inference |
| Observation | `@Observable` only — no Combine, no `ObservableObject` |
| Logging | `os.Logger(subsystem:category:)` with privacy annotations |
| Error handling | `DictlyError` domain enum; `do/catch` at service boundaries |
| Naming | Views: `*Screen`, `*Sheet`, `*View`; Services: `*Service`, `*Manager`, `*Engine` |

---

## CI/CD

No CI/CD pipeline configured. Testing and deployment are manual.
