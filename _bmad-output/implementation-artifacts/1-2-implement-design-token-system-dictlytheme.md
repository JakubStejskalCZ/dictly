# Story 1.2: Implement Design Token System (DictlyTheme)

Status: done

## Story

As a developer,
I want a shared design token package with colors, typography, spacing, and animation constants,
So that both apps use a consistent visual language matching the UX specification.

## Acceptance Criteria

1. **Given** a SwiftUI view in either app target **When** it references `DictlyTheme` colors, typography, or spacing **Then** the correct values are applied for the current platform (iOS vs Mac)
2. **Given** a view rendered in Dark Mode **When** inspecting the background color **Then** it shows the warm-toned dark palette (`#1A1816` background, not system blue-black)
3. **Given** any tag category color **When** used as text on light/dark surfaces **Then** all 5 tag category colors are defined (Story `#D97706`, Combat `#DC2626`, Roleplay `#7C3AED`, World `#059669`, Meta `#4B7BE5`)
4. **Given** spacing tokens are used **When** inspecting layout values **Then** they match the 8pt grid: xs=4, sm=8, md=16, lg=24, xl=32, 2xl=48

## Tasks / Subtasks

- [x] Task 1: Implement `Colors.swift` — base palette + tag category + accent/state colors (AC: #1, #2, #3)
  - [x] 1.1 Replace the placeholder `DictlyTheme.swift` stub with the real `Colors.swift` file
  - [x] 1.2 Define light mode base palette as `Color` static properties: background `#FAF8F5`, surface `#F2EDE7`, textPrimary `#1C1917`, textSecondary `#78716C`, border `#E7E0D8`
  - [x] 1.3 Define dark mode base palette: background `#1A1816`, surface `#292524`, textPrimary `#F5F0EB`, textSecondary `#A8A29E`, border `#3D3835`
  - [x] 1.4 Implement adaptive colors using `Color(light:dark:)` initializer or `Color(.init(light:dark:))` pattern so colors auto-switch with system appearance
  - [x] 1.5 Define 5 tag category colors as static properties: `story` `#D97706`, `combat` `#DC2626`, `roleplay` `#7C3AED`, `world` `#059669`, `meta` `#4B7BE5` — these are NOT adaptive (same in light/dark)
  - [x] 1.6 Define accent/state colors: `recordingActive` `#EF4444`, `success` `#16A34A`, `warning` `#F59E0B`, `destructive` `#DC2626`
- [x] Task 2: Implement `Typography.swift` — type scale definitions (AC: #1)
  - [x] 2.1 Define type scale as `Font` static properties with platform-conditional sizing
  - [x] 2.2 Sizes per UX spec — iOS / Mac: display 34/28pt Bold, h1 28/24pt Bold, h2 22/20pt Semibold, h3 17/16pt Semibold, body 17/14pt Regular, caption 13/12pt Regular, tagLabel 15/13pt Medium
  - [x] 2.3 Use `Font.system(size:weight:)` with `#if os(iOS)` / `#if os(macOS)` for platform sizing
  - [x] 2.4 Add `monospacedDigits` font for timers/timestamps (SF Mono via `.monospacedDigit()`)
- [x] Task 3: Implement `Spacing.swift` — 8pt grid tokens (AC: #4)
  - [x] 3.1 Define spacing tokens as `CGFloat` static properties: `xs` = 4, `sm` = 8, `md` = 16, `lg` = 24, `xl` = 32, `xxl` = 48
  - [x] 3.2 Define minimum tap target size: `minTapTarget` = 48 (larger than Apple HIG 44pt for mid-game tapping)
- [x] Task 4: Implement `Animation.swift` — shared animation curves and timing (AC: #1)
  - [x] 4.1 Define tag placement animation: scale pulse 0.95→1.0, 150ms ease-out
  - [x] 4.2 Define recording indicator: breathing glow 2s cycle
  - [x] 4.3 Ensure all animations respect `AccessibilityReduceMotion` (provide `.identity` alternatives)
- [x] Task 5: Update `Package.swift` if needed and remove placeholder (AC: #1)
  - [x] 5.1 Remove `DictlyTheme.swift` placeholder stub — replaced by `Colors.swift`, `Typography.swift`, `Spacing.swift`, `Animation.swift`
  - [x] 5.2 Verify DictlyTheme target compiles with the new files (no dependency changes needed — `import SwiftUI` is a system framework)
- [x] Task 6: Write unit tests for DictlyTheme (AC: #1, #2, #3, #4)
  - [x] 6.1 Create `DictlyKit/Tests/DictlyThemeTests/` directory
  - [x] 6.2 Add `DictlyThemeTests` test target in `Package.swift` with dependency on `DictlyTheme`
  - [x] 6.3 `ColorsTests.swift` — verify all 5 tag category colors resolve to expected RGB hex values; verify accent/state colors exist
  - [x] 6.4 `SpacingTests.swift` — verify spacing token values (xs=4, sm=8, md=16, lg=24, xl=32, xxl=48); verify `minTapTarget` = 48
  - [x] 6.5 `TypographyTests.swift` — verify all type scale properties are non-nil / accessible
  - [x] 6.6 Verify both app targets still build after DictlyTheme changes

## Dev Notes

### Architecture Compliance

- **DictlyTheme location**: `DictlyKit/Sources/DictlyTheme/` — 4 files: `Colors.swift`, `Typography.swift`, `Spacing.swift`, `Animation.swift` [Source: architecture.md#Project Structure & Boundaries]
- **Colors as Swift code, NOT asset catalogs**: Architecture explicitly specifies shared colors defined in `DictlyTheme` as Swift code for cross-target consistency [Source: architecture.md#Assets]
- **DictlyKit boundary**: `import SwiftUI` is acceptable in DictlyTheme (SwiftUI is cross-platform). No UIKit or AppKit imports. [Source: architecture.md#Architectural Boundaries]
- **`@Observable` not `ObservableObject`**: If any state is needed, use `@Observable` exclusively [Source: architecture.md#SwiftUI Patterns]
- **No `#if os()` in DictlyKit** except for minor SwiftUI differences in Theme where unavoidable — typography platform sizing is one acceptable case [Source: architecture.md#Code Organization]

### Color Implementation — Critical Details

**Adaptive colors (light/dark):** Use `Color(UIColor { trait in ... })` on iOS or a platform-agnostic approach. The recommended Swift-only approach for cross-platform packages:

```swift
// Option A: Use Color init with explicit light/dark values
// In a Swift Package targeting both iOS and macOS, you can use:
import SwiftUI

extension Color {
    init(light: Color, dark: Color) {
        #if os(iOS)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark) : UIColor(light)
        })
        #elseif os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(dark) : NSColor(light)
        })
        #endif
    }
}
```

**Tag category colors are NOT adaptive** — same hex in light and dark mode. They are verified for WCAG AA contrast (4.5:1) against both surfaces.

**Hex → Color**: Use `Color(red:green:blue:)` with values divided by 255.0, or define a `Color(hex:)` convenience initializer.

### Typography Implementation — Critical Details

- Use `Font.system(size:weight:)` NOT `Font.system(_:design:weight:)` (TextStyle variant) because UX spec defines exact point sizes, not semantic text styles
- Platform sizes differ: use `#if os(iOS)` / `#if os(macOS)` conditionals
- All sizes should honor Dynamic Type — consider using `@ScaledMetric` for values that should scale, but note that the UX spec defines specific sizes as baselines
- Monospaced digits for timers: `Font.system(size:weight:).monospacedDigit()` — used for recording timer, timestamps, tag counts

### Spacing Implementation

- All values are `CGFloat` static properties on a namespace enum
- `minTapTarget: CGFloat = 48` — Apple HIG minimum is 44pt, but UX spec mandates 48pt for mid-game tapping
- Use `@ScaledMetric` in views for spacing that should scale with Dynamic Type (not in the token definitions themselves — tokens are base values)

### Animation Implementation

- Tag placement pulse: `.spring(response: 0.15, dampingFraction: 0.6)` or `.easeOut(duration: 0.15)` scaling from 0.95 to 1.0
- Recording breathing glow: repeating animation with 2s cycle, `.easeInOut` autoreverse
- **Accessibility**: All custom animations must check `AccessibilityReduceMotion` and provide `.identity` / instant alternatives
- Use SwiftUI's `withAnimation` and `.animation()` modifiers — these are just constant definitions for use by views

### Previous Story Intelligence (Story 1.1)

**Key learnings from Story 1.1:**
- `xcodegen` is used to generate `.xcodeproj` files from `project.yml` — no manual Xcode project editing
- DictlyKit exposes a single `DictlyKit` library product with four targets: DictlyModels, DictlyTheme, DictlyStorage, DictlyExport
- All `public` visibility is required for cross-module access from app targets
- `swift build` and `swift test` work for non-SwiftData code (SwiftData `@Model` macros need Xcode.app, but DictlyTheme has no SwiftData dependency)
- Package.swift currently has a test target only for DictlyModelsTests — **you must add DictlyThemeTests test target**
- `ModelConfiguration(isStoredInMemoryOnly: true)` pattern used for tests — not applicable here (no SwiftData)
- ENV-001: Xcode.app not installed on this machine, only CLI tools. DictlyTheme does NOT use `@Model` macros so `swift build` and `swift test` SHOULD work fine for this story

**Files from Story 1.1 that are relevant:**
- `DictlyKit/Package.swift` — must be modified to add DictlyThemeTests target
- `DictlyKit/Sources/DictlyTheme/DictlyTheme.swift` — placeholder to be replaced
- `DictlyiOS/App/ContentView.swift` — could be updated to use theme colors for verification
- `DictlyMac/App/ContentView.swift` — same

### Package.swift Modifications Required

```swift
// Add to the targets array:
.testTarget(
    name: "DictlyThemeTests",
    dependencies: ["DictlyTheme"],
    path: "Tests/DictlyThemeTests"
)
```

No external dependencies needed. `import SwiftUI` is a system framework.

### Namespace Pattern

Use `enum` namespaces to organize tokens (consistent with the existing `DictlyTheme` enum stub pattern):

```swift
// Colors.swift
public enum DictlyColors {
    public static let background = Color(light: ..., dark: ...)
    // ...
    public enum TagCategory {
        public static let story = Color(...)
        // ...
    }
}
```

Or use extensions on `Color` for dot-syntax convenience (e.g., `Color.dictlyBackground`). Choose ONE pattern and be consistent. The architecture doesn't prescribe a specific pattern, but `enum` namespaces prevent accidental instantiation and group related tokens clearly.

### Testing Approach

- Unit tests in `DictlyKit/Tests/DictlyThemeTests/`
- Test that color RGB components resolve to expected hex values (use `Color.resolve(in:)` API on iOS 17+ / macOS 14+ to extract RGBA components)
- Test spacing token values are exact
- Test typography properties are accessible (non-nil)
- **No SwiftData involved** — tests should run with `swift test` even without Xcode.app
- Use `@MainActor` if testing SwiftUI types that require it

### File Structure After Completion

```
DictlyKit/Sources/DictlyTheme/
├── Colors.swift          # Base palette (light/dark adaptive), tag category, accent/state
├── Typography.swift      # Platform-conditional type scale
├── Spacing.swift         # 8pt grid tokens
└── Animation.swift       # Shared animation curves and timing

DictlyKit/Tests/DictlyThemeTests/
├── ColorsTests.swift
├── SpacingTests.swift
└── TypographyTests.swift
```

### Project Structure Notes

- This story replaces the `DictlyTheme.swift` placeholder created in Story 1.1 with the real implementation
- No changes to app targets are strictly required — but optionally updating `ContentView` in either target to use theme tokens would serve as a build-time verification
- No changes to DictlyModels, DictlyStorage, or DictlyExport

### References

- [Source: architecture.md#Starter Template Evaluation] — DictlyTheme role: tag category colors, base palette, typography scale, spacing tokens
- [Source: architecture.md#Project Structure & Boundaries] — File structure: Colors.swift, Typography.swift, Spacing.swift, Animation.swift
- [Source: architecture.md#Implementation Patterns] — Colors as Swift code not asset catalogs, `#if os()` only where truly needed
- [Source: ux-design-specification.md#Color System] — Complete hex values for base palette (light/dark), tag category colors, accent/state colors
- [Source: ux-design-specification.md#Typography System] — Type scale with iOS/Mac sizes, weights, usage
- [Source: ux-design-specification.md#Spacing & Layout Foundation] — 8pt grid tokens, tap target sizes, animation specs
- [Source: ux-design-specification.md#Accessibility Considerations] — WCAG AA contrast, Dynamic Type, Reduce Motion
- [Source: epics.md#Story 1.2] — Acceptance criteria and story definition
- [Source: prd.md#Mobile App + Desktop App Specific Requirements] — Shared data model / design tokens across targets

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Swift 6 strict concurrency: `Color(light:dark:)` extension using `UIColor { traits in ... }` / `NSColor(name:dynamicProvider:)` compiles cleanly — `Color`, `UIColor`, `NSColor` are all `Sendable`, closures satisfy `@Sendable` requirement.
- `Color.Resolved` components are linear-light sRGB, not gamma-encoded sRGB. Test helper creates expected `Color` via `Color(red:green:blue:)` and resolves both actual and expected in the same environment, ensuring consistent color-space comparison.
- `ColorsTests` originally used `#file` in helper; changed to `#filePath` to match XCTest's `file:` parameter expectation and eliminate warnings.
- xcodebuild IS available (Xcode 16.2) despite ENV-001 note about Xcode.app — Task 6.6 was fully verified with real app builds.

### Completion Notes List

- Replaced `DictlyTheme.swift` placeholder with 4 production files: `Colors.swift`, `Typography.swift`, `Spacing.swift`, `Animation.swift`.
- `DictlyColors` uses internal `Color(hex:)` and `Color(light:dark:)` extensions. Adaptive base palette auto-switches via `UIColor` dynamic provider (iOS) / `NSColor` dynamic provider (macOS). Tag category and accent/state colors are non-adaptive flat hex values.
- `DictlyTypography` uses compile-time `#if os(iOS)` / `#if os(macOS)` conditionals for platform-specific font sizes per UX spec. Includes `monospacedDigits` via `.monospacedDigit()` modifier.
- `DictlySpacing` exposes 7 `CGFloat` constants (xs=4, sm=8, md=16, lg=24, xl=32, xxl=48, minTapTarget=48).
- `DictlyAnimation` exposes tag placement (easeOut 150ms + spring variant) and recording breath (2s easeInOut repeating) constants, plus `reduceMotion:` overloads that return `Animation?` (nil = no animation).
- Added `DictlyThemeTests` test target to `Package.swift`; 14 new tests across 3 test files; 27 total tests pass (0 failures, 0 regressions).
- Both app targets (`DictlyiOS`, `DictlyMac`) build successfully with xcodebuild.

### File List

- `DictlyKit/Sources/DictlyTheme/Colors.swift` (new)
- `DictlyKit/Sources/DictlyTheme/Typography.swift` (new)
- `DictlyKit/Sources/DictlyTheme/Spacing.swift` (new)
- `DictlyKit/Sources/DictlyTheme/Animation.swift` (new)
- `DictlyKit/Sources/DictlyTheme/DictlyTheme.swift` (deleted — placeholder removed)
- `DictlyKit/Package.swift` (modified — added DictlyThemeTests target)
- `DictlyKit/Tests/DictlyThemeTests/ColorsTests.swift` (new)
- `DictlyKit/Tests/DictlyThemeTests/SpacingTests.swift` (new)
- `DictlyKit/Tests/DictlyThemeTests/TypographyTests.swift` (new)

### Review Findings

- [x] [Review][Patch] `tagPlacementSpring` missing `reduceMotion` overload — pattern inconsistency with other animation tokens [Animation.swift] — FIXED
- [x] [Review][Patch] Build artifacts (.d, .o, .swiftdeps) not gitignored — compiler intermediates at DictlyKit/ root — FIXED
- [x] [Review][Defer] WCAG AA contrast claims in TagCategory doc comment may be inaccurate for some color/surface combinations [Colors.swift:66] — deferred, design/spec-level concern
- [x] [Review][Defer] No `accessibilityReduceTransparency`/`increaseContrast` palette handling for low-contrast surface boundaries [Colors.swift] — deferred, beyond current story scope

## Change Log

- 2026-04-01: Implemented DictlyTheme design token system — Colors, Typography, Spacing, Animation files created; placeholder removed; DictlyThemeTests added; all 27 tests pass; both app targets build successfully.
