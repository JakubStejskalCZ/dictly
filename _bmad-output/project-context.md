---
project_name: 'Dictly'
user_name: 'Stejk'
date: '2026-04-09'
sections_completed: ['technology_stack', 'language_rules', 'framework_rules', 'testing_rules', 'code_quality', 'workflow', 'critical_rules']
status: 'complete'
rule_count: 38
optimized_for_llm: true
---

# Project Context for AI Agents

_This file contains critical rules and patterns that AI agents must follow when implementing code in this project. Focus on unobvious details that agents might otherwise miss._

---

## Technology Stack & Versions

- **Language**: Swift 6.0 (strict concurrency) — all targets compile under Swift 6 rules
- **UI**: SwiftUI (no UIKit/AppKit views)
- **Persistence**: SwiftData (not Core Data)
- **Platforms**: iOS 17.0, macOS 14.0
- **IDE**: Xcode 16.0 — projects generated from `project.yml` via XcodeGen (never edit `.xcodeproj` directly)
- **Shared package**: `DictlyKit` (local SPM) with targets: DictlyModels, DictlyStorage, DictlyTheme, DictlyExport
- **Transcription (Mac only)**: whisper.cpp 1.8.4 vendored at `Vendor/whisper.cpp/`, compiled as static `WhisperLib` target with Metal + CPU + Accelerate backends
- **Search**: CoreSpotlight integration via DictlyStorage/SearchIndexer
- **Logging**: OSLog exclusively (`Logger(subsystem:category:)`) — never use `print()`

## Critical Implementation Rules

### Swift 6 Concurrency

- All ViewModels and services: `@Observable @MainActor final class` — never use `ObservableObject` or `@Published`
- Swift 6 strict concurrency is enforced across all targets — resolve sendability warnings, do not suppress them
- For real-time audio threads that cannot use MainActor: use `@unchecked Sendable` inner class pattern (see `TapState` in `SessionRecorder`)
- Inject services into SwiftUI views via `.environment()`, not init parameters

### SwiftData Model Rules

- Models are `@Model public final class` with an explicit `uuid: UUID` stored property
- Always use `DictlySchema.all` when constructing `ModelContainer` — never list model types individually
- Relationships require explicit `@Relationship(deleteRule:)` and `@Relationship(inverse:)` annotations
- Complex value types SwiftData cannot persist: encode as JSON `String` property with a computed property for type-safe access
- Tag→TagCategory is intentionally denormalized (`categoryName: String`) — do not add a relationship

### Error Handling

- All domain errors go in `DictlyError` (nested sub-enums per domain) — do not create standalone error types
- `DictlyError` conforms to `Error, LocalizedError, Equatable` — maintain all three

### Framework & Platform Rules

- `DictlyKit` must never import UIKit or AppKit — only Foundation, SwiftData, SwiftUI
- Platform-specific APIs (AVFoundation, AVAudioEngine, MultipeerConnectivity) belong in app targets only (`DictlyiOS/`, `DictlyMac/`)
- Screens are `*Screen.swift`, not `*View.swift` — ViewModels are co-located as `*ViewModel.swift`
- ViewModels are thin formatting layers — business logic goes in service classes
- Use `DictlyTheme` tokens for all UI values: `DictlyColors`, `DictlySpacing`, `DictlyTypography`, `DictlyAnimation`
- Design tokens are caseless `enum` namespaces — do not use structs or classes
- Platform branching in theme: `#if os(iOS) / #else` compile-time conditionals, never runtime checks
- Spacing grid is 8pt: xs(4), sm(8), md(16), lg(24), xl(32), xxl(48)

### Testing Rules

- All test classes: `@MainActor final class SomeTests: XCTestCase`
- SwiftData tests use real in-memory containers: `ModelConfiguration(isStoredInMemoryOnly: true)` + `DictlySchema.all` — never mock SwiftData
- Unit tests per target in `DictlyKit/Tests/{TargetName}Tests/`
- App-level tests per feature in `DictlyiOS/Tests/{Feature}Tests/`
- E2E tests named `Epic{N}*E2ETests.swift` — map to acceptance criteria with `// AC#N:` comments
- E2E tests verify full data flows including cascade deletes and cross-story interactions

### Code Quality & Style

- File names: PascalCase matching primary type
- Import DictlyKit sub-modules individually: `import DictlyModels`, `import DictlyStorage` — not `import DictlyKit`
- Logger at file scope: `private let logger = Logger(subsystem: "com.dictly", category: "FeatureName")`
- No SwiftLint configured — maintain consistency with existing patterns
- No docstrings on internal code unless logic is non-obvious
- Prefer `guard` for early returns over nested `if` blocks

### Development Workflow

- Xcode projects generated from `project.yml` via XcodeGen — never edit `.xcodeproj` manually
- To add new source files/groups: update the relevant `project.yml`, then regenerate
- Commit messages: conventional format with scope — `feat(epic-N):`, `fix(mac):`, `test(epic-N):`
- Monorepo layout: `DictlyKit/` (shared), `DictlyMac/` (macOS app), `DictlyiOS/` (iOS app), `Vendor/` (vendored C/C++)
- New shared logic goes in `DictlyKit` — new platform-specific code in the appropriate app target
- Do not modify files under `Vendor/` — these are upstream vendored sources

### Critical Don't-Miss Rules

- NEVER use `ObservableObject`, `@Published`, or `@StateObject` — use `@Observable` (Observation framework)
- NEVER use Core Data APIs — this is SwiftData only
- NEVER construct `ModelContainer` without `DictlySchema.all` — omitting model types causes runtime crashes
- NEVER import UIKit/AppKit in `DictlyKit` targets — platform isolation is enforced by tests
- whisper.cpp / `WhisperLib` is Mac-only — iOS has no on-device transcription
- `WhisperLib` compiles with `-O3 -DNDEBUG` in all configurations — do not change optimization flags
- Metal shader paths in the Mac post-compile script must match `Vendor/whisper.cpp/ggml/src/ggml-metal/` — do not relocate
- New Spotlight search APIs must go in `DictlyStorage` (which links CoreSpotlight)
- The Mac bridging header is at `Transcription/WhisperBridge-Bridging-Header.h` — iOS has none

---

## Usage Guidelines

**For AI Agents:**

- Read this file before implementing any code
- Follow ALL rules exactly as documented
- When in doubt, prefer the more restrictive option
- Update this file if new patterns emerge

**For Humans:**

- Keep this file lean and focused on agent needs
- Update when technology stack changes
- Review quarterly for outdated rules
- Remove rules that become obvious over time

Last Updated: 2026-04-09
