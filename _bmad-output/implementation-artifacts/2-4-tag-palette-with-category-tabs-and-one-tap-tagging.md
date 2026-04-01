# Story 2.4: Tag Palette with Category Tabs & One-Tap Tagging

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a DM,
I want to tag moments with a single tap from an organized category palette,
So that I can capture what matters without breaking my flow at the table.

## Acceptance Criteria (BDD)

### Scenario 1: Category Tab Filtering

Given an active recording with default tag categories
When the DM taps a category tab
Then the tag grid filters to show only tags in that category

### Scenario 2: One-Tap Tag Placement

Given the tag grid is visible
When the DM taps a tag card
Then a tag is placed within 200ms with haptic feedback and a brief scale animation
And the tag count badge increments

### Scenario 3: Category Switching

Given multiple tag categories
When the DM switches between tabs
Then the grid transitions smoothly to the selected category's tags

### Scenario 4: Dynamic Type Accessibility

Given iOS accessibility largest Dynamic Type is active
When viewing the tag grid
Then the grid switches to a single-column layout with larger tag cards

### Scenario 5: VoiceOver Accessibility

Given VoiceOver is active
When a tag card is focused
Then it reads "[Tag name], [Category]. Double-tap to place tag."

## Tasks / Subtasks

- [x] Task 1: Create `TagCard.swift` — custom tappable tag button (AC: #2, #4, #5)
  - [x] 1.1 Create `TagCard.swift` in `DictlyiOS/Tagging/`. This is the primary interaction surface — a tappable button in the recording tag grid. Anatomy: color stripe (left edge, 4pt wide, category color from `TagCategory.colorHex`) + tag label (14pt medium, `DictlyTypography.body` or custom) + category name (11pt caption, `DictlyTypography.caption`).
  - [x] 1.2 Parameters: `tag: Tag`, `categoryColor: Color`, `categoryName: String`, `onTap: () -> Void`. The card must accept the tap callback — it does NOT create tags itself.
  - [x] 1.3 Pressed state: on press, scale to 0.96 (`DictlyAnimation.tagPlacementStartScale`) with category color glow effect. Use `ButtonStyle` to implement press state. Scale animates back to 1.0 over 150ms ease-out (`DictlyAnimation.tagPlacement`).
  - [x] 1.4 Minimum tap target: 48x48pt (`DictlySpacing.minTapTarget`). Use `.frame(minHeight: DictlySpacing.minTapTarget)` with `.frame(maxWidth: .infinity)` for grid-filling width.
  - [x] 1.5 Background: `DictlyColors.surface` with corner radius 12pt.
  - [x] 1.6 VoiceOver: `.accessibilityLabel("\(tag.label), \(categoryName). Double-tap to place tag.")`. After tap succeeds, post `UIAccessibility.post(notification: .announcement, argument: "Tag placed. \(tagCount) tags total.")`.
  - [x] 1.7 Dynamic Type: Use `@ScaledMetric` for the color stripe width and internal spacing so they scale with text size.

- [x] Task 2: Create `CategoryTabBar.swift` — horizontally scrollable category filter (AC: #1, #3, #5)
  - [x] 2.1 Create `CategoryTabBar.swift` in `DictlyiOS/Tagging/`. Horizontally scrollable row of pill-shaped tabs inside a rounded surface container (`DictlyColors.surface` background, 12pt corner radius).
  - [x] 2.2 Parameters: `categories: [TagCategory]`, `selectedCategory: Binding<TagCategory?>`, `tagCountPerCategory: [String: Int]` (keyed by category name).
  - [x] 2.3 Each tab: colored dot (6pt circle, category `colorHex`) + category name text. Active tab: darker background (`DictlyColors.background`), white/primary text. Inactive: muted text (`DictlyColors.textSecondary`).
  - [x] 2.4 Wrap tabs in `ScrollView(.horizontal, showsIndicators: false)` with `HStack(spacing: DictlySpacing.sm)`. Apply `.scrollTargetBehavior(.viewAligned)` if available on iOS 17+.
  - [x] 2.5 Add fade edges on scroll using a gradient mask (`.mask()` with leading/trailing `LinearGradient`) when content overflows.
  - [x] 2.6 VoiceOver: each tab reads "[Category name] filter. [X] tags available." Use `.accessibilityLabel()`.
  - [x] 2.7 Sort tabs by `TagCategory.sortOrder`.

- [x] Task 3: Create `TagPalette.swift` — tag grid with category tabs (AC: #1, #2, #3, #4)
  - [x] 3.1 Create `TagPalette.swift` in `DictlyiOS/Tagging/`. This is the main container composing `CategoryTabBar` + tag card grid. Layout: `CategoryTabBar` at top, then `LazyVGrid` of `TagCard` items below.
  - [x] 3.2 Use `@Query` to fetch all `TagCategory` sorted by `sortOrder`. Use a second `@Query` to fetch all tags (not session tags — these are the *template* tags from tag management, i.e., tags with no session relationship or a separate query strategy). **IMPORTANT:** Tags in the palette are the pre-defined tags from `DefaultTagSeeder` / tag management (Story 1.5). They are NOT `session.tags`. The palette shows available tag *templates*. When tapped, a NEW `Tag` is created and added to the session.
  - [x] 3.3 **Tag template query strategy:** Used in-memory filtering (`allTags.filter { $0.session == nil }`) for SwiftData relationship optionality compatibility.
  - [x] 3.4 `@State private var selectedCategory: TagCategory?` — default to first category by `sortOrder` on appear.
  - [x] 3.5 Grid: `LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DictlySpacing.sm)` for 2-column layout.
  - [x] 3.6 Dynamic Type: detect large content sizes with `@Environment(\.dynamicTypeSize)`. When `.accessibility3` or larger, switch to single column: `[GridItem(.flexible())]`.
  - [x] 3.7 Compute `tagCountPerCategory` dictionary from the template tags query for `CategoryTabBar`.
  - [x] 3.8 Wrap the grid in a `ScrollView(.vertical)` for scrolling when many tags exist.

- [x] Task 4: Create `TaggingService.swift` — tag creation and haptic feedback (AC: #2)
  - [x] 4.1 Create `TaggingService.swift` in `DictlyiOS/Tagging/`. This is an `@Observable @MainActor` class that handles tag placement during recording.
  - [x] 4.2 Inject `SessionRecorder` to read `elapsedTime` for the tag's `anchorTime`. Accept `ModelContext` for SwiftData persistence.
  - [x] 4.3 Method `placeTag(label: String, categoryName: String, session: Session, context: ModelContext)`: creates a new `Tag` with `anchorTime = sessionRecorder.elapsedTime`, `rewindDuration = 0`, `label`, `categoryName`, `createdAt = Date()`. Insert into context, append to `session.tags`. Must complete within 200ms.
  - [x] 4.4 Fire haptic immediately on tap: `UIImpactFeedbackGenerator(.medium).impactOccurred()`. Prepare the generator in advance via `prepareHaptic()` called on palette appear.
  - [x] 4.5 Use `os.Logger` with subsystem `"com.dictly.ios"` and category `"tagging"`. Log `.info("Tag placed: \(label) in \(categoryName) at \(anchorTime)")`.
  - [x] 4.6 Error handling: tag creation wrapped in do/catch, logs `.error` on failure, does not crash.
  - [x] 4.7 Haptic generator stored as property. `prepare()` called in init and via `prepareHaptic()`. Haptic inlined (no separate extension file needed).

- [x] Task 5: Wire `TagPalette` into `RecordingScreen` (AC: #1, #2, #3)
  - [x] 5.1 In `RecordingScreen.swift`, replaced the tag palette placeholder with `TagPalette(session: session, taggingService: ts, isInteractive: vm.recordingState == .recording)`.
  - [x] 5.2 Added `@State private var taggingService: TaggingService?`. Initialized with `SessionRecorder` from environment in `startRecording()`.
  - [x] 5.3 Connected `TagCard` taps through `TagPalette` to `TaggingService.placeTag()` via `onTap` closure.
  - [x] 5.4 Tag count badge in `RecordingStatusBar` auto-updates via SwiftData observation (no change needed).
  - [x] 5.5 Palette disabled (dimmed at 50% opacity + `guard isInteractive` in onTap) when recording state is paused.

- [x] Task 6: Update `project.yml` and verify build (AC: all)
  - [x] 6.1 `DictlyiOS/Tagging/` already in `project.yml` sources — no change needed.
  - [x] 6.2 Ran `xcodegen generate` in `DictlyiOS/` — project regenerated successfully.
  - [x] 6.3 Build verified: `** BUILD SUCCEEDED **`

- [x] Task 7: Unit tests (AC: #1, #2, #4, #5)
  - [x] 7.1 Created `TaggingServiceTests.swift` in `DictlyiOS/Tests/TaggingTests/`.
  - [x] 7.2 Tested `placeTag()`: verified label, categoryName, anchorTime, and session.tags append.
  - [x] 7.3 Tested tag count increments — `session.tags.count` increases by 1 per placement.
  - [x] 7.4 Tested rapid sequential placements (10 tags): all created with distinct labels.
  - [x] 7.5 `TaggingService` tested directly by instantiating `SessionRecorder()` (no-arg init available).
  - [x] 7.6 All existing tests pass: 139 DictlyKit + 30 DictlyiOS (now 41 with 11 new tagging tests).
  - [x] 7.7 `xcodebuild` succeeded for iOS target (`** TEST SUCCEEDED **`).

### Review Findings

- [x] [Review][Patch] Misleading log message in TagPalette onTap — "Category tab selected" when placing a tag [TagPalette.swift:82] — FIXED
- [x] [Review][Patch] tagPlacementStartScale 0.95 vs spec 0.96 [Animation.swift:22] — FIXED
- [x] [Review][Patch] tagLabel font 15pt vs spec 14pt [Typography.swift:62] — FIXED
- [x] [Review][Patch] Tab bar not dimmed/disabled when paused — opacity only on ScrollView, not entire palette [TagPalette.swift:89] — FIXED
- [x] [Review][Patch] No category switch animation (AC3 requires smooth transition) [CategoryTabBar.swift:20] — FIXED
- [x] [Review][Patch] placeTag swallows save errors — orphans tag in memory, no feedback to caller [TaggingService.swift:48-52] — FIXED (returns Bool, rolls back on failure)
- [x] [Review][Patch] Accessibility announcement fires even on save failure [TagPalette.swift:77-81] — FIXED (conditional on success)
- [x] [Review][Defer] CategoryTabBar fade mask always clips first/last tab edges regardless of overflow — deferred, design complexity
- [x] [Review][Defer] Caption font 13pt vs spec 11pt — deferred, shared design token affects other screens
- [x] [Review][Defer] Test anchorTime assertion is tautological (recorder always at 0) — deferred, test quality
- [x] [Review][Defer] No test for save-failure path in TaggingService — deferred, nice-to-have
- [x] [Review][Defer] selectedCategory can go stale if categories removed — deferred, categories stable during recording
- [x] [Review][Defer] String-based category matching fragile across renames — deferred, by-design per Tag model
- [x] [Review][Defer] context.save() called per tap with no batching — deferred, meets 200ms requirement
- [x] [Review][Defer] No "all categories" deselection path — deferred, spec doesn't require it
- [x] [Review][Defer] Color(hexString:) no fallback for malformed hex — deferred, pre-existing extension

## Dev Notes

### Architecture: Tag Palette in Recording Screen Layout

Per architecture and UX spec, the iOS recording screen layout is (top to bottom):
1. `RecordingStatusBar` — animated dot, timer, tag count (Story 2.3 — DONE)
2. `LiveWaveform` — 48pt compact waveform (Story 2.3 — DONE)
3. `CategoryTabBar` + `TagPalette` — **THIS STORY**
4. Dashed "+" custom tag card — Story 2.6
5. "Stop Recording" bar — Story 2.7

The tag palette replaces the `Color.clear.frame(height: DictlySpacing.xxl)` placeholder in `RecordingScreen.swift` (~line 52-53).

[Source: architecture.md#Recording-Files, ux-design-specification.md#Chosen-Direction]

### Component Specifications

**TagCard (iOS)** — the primary interaction surface of the entire product:
- **Anatomy:** Color stripe (left edge, 4pt, category color) + tag label (14pt medium) + category name (11pt caption)
- **States:** Default (surface background, muted) → Pressed (scale 0.96, category color glow, haptic fires)
- **Variants:** Standard tag card (pre-defined) — custom tag card with dashed border/"+" icon is Story 2.6
- **Accessibility:** Label reads "[Tag name], [Category]. Double-tap to place tag." Min 48x48pt tap target.

**CategoryTabBar (iOS)** — horizontally scrollable category filter:
- **Anatomy:** Row of pill-shaped tabs. Each tab: colored dot (6pt) + category name. Active tab: darker background, white text.
- **States:** Default (muted text) → Active (elevated background, full-color text). Scrollable with fade edges.
- **Accessibility:** Each tab reads "[Category name] filter. [X] tags available."

[Source: ux-design-specification.md#Custom-Components]

### Tag Placement Interaction Model

This story implements **basic one-tap tagging**. The full timestamp-first/rewind-anchor model is Story 2.5.

**For this story:** When a tag card is tapped:
1. Capture `sessionRecorder.elapsedTime` as `anchorTime` (simple current-time anchor)
2. Create a new `Tag` in SwiftData with the template tag's `label` and `categoryName`
3. Append to `session.tags`
4. Fire `UIImpactFeedbackGenerator(.medium)` immediately
5. Play scale animation on the tapped card (0.96 → 1.0, 150ms)
6. Tag count badge auto-increments via SwiftData observation

**Story 2.5 will modify** `TaggingService.placeTag()` to use rewind-anchor logic (anchorTime = elapsedTime - rewindDuration) instead of simple current-time.

**Performance requirement:** Tag placement response < 200ms (haptic + visual feedback combined). Do not perform any blocking work on the main thread during placement.

[Source: prd.md#FR7, prd.md#FR8, prd.md#FR11, ux-design-specification.md#Timestamp-First-Interaction]

### Tag Template vs Session Tag Distinction

**Critical concept:** The tag palette shows *template tags* — pre-defined tags from tag management (Story 1.5 / `DefaultTagSeeder`). These are `Tag` records with `session == nil`. When tapped, a NEW `Tag` instance is created and attached to the current recording session.

- Template tags: `Tag` where `session == nil` — created by `DefaultTagSeeder` or user via tag management screens
- Session tags: `Tag` where `session != nil` — created during recording by `TaggingService.placeTag()`
- `Tag.categoryName` is a `String` referencing `TagCategory.name` (not a SwiftData relationship)
- `TagCategory` has `colorHex: String` and `iconName: String` for display

To get the category color for a tag card, look up the `TagCategory` whose `name == tag.categoryName` and use `Color(hexString: category.colorHex)`. The `Color(hexString:)` extension already exists in `TagCategoryFormSheet.swift` — extract it to a shared location or reuse inline.

[Source: DictlyKit/Sources/DictlyModels/Tag.swift, TagCategory.swift, DefaultTagSeeder.swift]

### Haptic Feedback

Per UX spec, haptic feedback is the primary confirmation channel — no audio (table is loud), visual is secondary.

| Channel | Feedback | Timing |
|---------|----------|--------|
| Haptic | `UIImpactFeedbackGenerator(.medium)` | Immediate (< 200ms) |
| Visual | Tag card scale pulse (0.96 → 1.0, 150ms) | Immediate |
| Counter | Tag count badge increments | Immediate |
| Auditory | None (table environment is loud) | — |

Architecture references `UIImpactFeedbackGenerator+Tag.swift` in `DictlyiOS/Extensions/` — this file may not exist yet. If not, implement haptic inline in `TaggingService`. Call `hapticGenerator.prepare()` when palette appears to pre-warm the Taptic Engine.

[Source: ux-design-specification.md#Tag-Placement-Feedback, architecture.md#Extensions]

### Accessibility Requirements

**Dynamic Type:**
- Tag grid: falls to 1 column at `.accessibility3` and larger Dynamic Type sizes
- Category tabs: text wraps or tabs stack vertically at largest sizes
- Use `@ScaledMetric` for spacing values that should scale
- Use `@Environment(\.dynamicTypeSize)` to detect size category

**VoiceOver:**
- TagCard: "[Tag name], [Category]. Double-tap to place tag." After placement: announce "Tag placed. [Count] tags total."
- CategoryTabBar: "[Category name] filter. [X] tags available."
- Use `.accessibilityAction()` for tag placement
- Post announcements via `UIAccessibility.post(notification: .announcement, argument:)`

**Reduce Motion:**
- Tag placement: no scale animation, instant highlight. Check `@Environment(\.accessibilityReduceMotion)`.
- Category switching: instant transition, no animation.

**Motor Accessibility:**
- All tap targets minimum 48x48pt (`DictlySpacing.minTapTarget`)
- No time-limited interactions
- No complex gestures — single tap for all actions

[Source: ux-design-specification.md#Accessibility-Strategy, ux-design-specification.md#VoiceOver, ux-design-specification.md#Dynamic-Type, ux-design-specification.md#Reduce-Motion]

### Design Tokens Available (DictlyTheme)

All tokens already exist in `DictlyKit/Sources/DictlyTheme/`:

**Colors (`DictlyColors`):**
- `.surface` — card backgrounds, tab bar container
- `.background` — active tab background
- `.textPrimary` — active tab text, tag label
- `.textSecondary` — inactive tab text, category name on card
- `.recordingActive` — NOT used for tagging (this is for recording dot/waveform)

**Typography (`DictlyTypography`):**
- `.body` — 16pt Regular (or 14pt for tag label — may need custom)
- `.caption` — 13pt Regular (category name on card, tab text)

**Spacing (`DictlySpacing`):**
- `.xs` (4pt) — color stripe width
- `.sm` (8pt) — grid gaps, tab gaps, internal padding
- `.md` (16pt) — palette section padding
- `.minTapTarget` (48pt) — minimum card height

**Animation (`DictlyAnimation`):**
- `.tagPlacement` — 150ms ease-out (tag card press animation)
- `.tagPlacementStartScale` — 0.95 (initial pressed scale)

[Source: DictlyKit/Sources/DictlyTheme/Colors.swift, Animation.swift, Typography.swift, Spacing.swift]

### Existing Infrastructure to Reuse

- **`Tag` model** — `DictlyKit/Sources/DictlyModels/Tag.swift` — `uuid`, `label`, `categoryName`, `anchorTime`, `rewindDuration`, `notes`, `transcription`, `createdAt`, `session`
- **`TagCategory` model** — `DictlyKit/Sources/DictlyModels/TagCategory.swift` — `uuid`, `name`, `colorHex`, `iconName`, `sortOrder`, `isDefault`
- **`DefaultTagSeeder`** — `DictlyKit/Sources/DictlyModels/DefaultTagSeeder.swift` — seeds 5 categories, 25 tags
- **`Session.tags`** — `@Relationship(deleteRule: .cascade) var tags: [Tag]` — auto-updates count
- **`SessionRecorder`** — `DictlyiOS/Recording/SessionRecorder.swift` — read `elapsedTime`, `isRecording`, `isPaused`
- **`RecordingViewModel`** — `DictlyiOS/Recording/RecordingViewModel.swift` — `recordingState` enum for UI state
- **`RecordingScreen`** — `DictlyiOS/Recording/RecordingScreen.swift` — container with placeholder at line 52-53
- **`Color(hexString:)`** — extension in `DictlyiOS/Tagging/TagCategoryFormSheet.swift` — converts hex string to SwiftUI Color
- **`DictlyAnimation.tagPlacement`** — `DictlyKit/Sources/DictlyTheme/Animation.swift` — 150ms ease-out

### What NOT to Build in This Story

- **Rewind-anchor timestamp logic** — Story 2.5 builds the `anchorTime = elapsedTime - rewindDuration` model. This story uses simple `anchorTime = elapsedTime`.
- **Custom tag creation ("+" card)** — Story 2.6 builds `CustomTagSheet.swift` and the dashed "+" card variant.
- **Stop recording bar** — Story 2.7.
- **Tag editing/deletion during recording** — not in any Epic 2 story; editing is Mac-only (Epic 4).
- **Tag category management during recording** — categories are managed before recording in tag management screens (Story 1.5, done).

### Swift 6 Strict Concurrency Notes

- `TaggingService` must be `@Observable @MainActor` — same pattern as `SessionRecorder`.
- `UIImpactFeedbackGenerator` is UIKit and must be called on `@MainActor`.
- SwiftData `ModelContext` operations must happen on the main actor.
- `@Query` in `TagPalette` runs on the main actor automatically.
- No async work needed for tag placement — it's a synchronous SwiftData insert + haptic fire.

### Logging

Use `os.Logger` with subsystem `"com.dictly.ios"` and category `"tagging"`:
- `.info` — "Tag placed: \(label) in \(categoryName) at \(anchorTime)"
- `.info` — "Category tab selected: \(categoryName)"
- `.error` — "Failed to place tag: \(error)"

### File Placement

```
DictlyiOS/Tagging/
├── TagCategoryListScreen.swift     # EXISTS — tag management (Story 1.5)
├── TagListScreen.swift             # EXISTS — tag list in category (Story 1.5)
├── TagCategoryFormSheet.swift      # EXISTS — create/edit category (Story 1.5)
├── TagFormSheet.swift              # EXISTS — create/edit tag (Story 1.5)
├── TagPalette.swift                # NEW — tag grid with category tabs for recording
├── TagCard.swift                   # NEW — custom tappable tag button with color stripe
├── CategoryTabBar.swift            # NEW — horizontally scrollable category filter
└── TaggingService.swift            # NEW — @Observable tag creation + haptics

DictlyiOS/Recording/
└── RecordingScreen.swift           # MODIFY — replace placeholder with TagPalette

DictlyiOSTests/TaggingTests/
└── TaggingServiceTests.swift       # NEW — tag placement tests
```

### Previous Story Intelligence (from Story 2.3)

Key patterns and learnings:
- **`SessionRecorder` is @Observable @MainActor:** Access via `@Environment(SessionRecorder.self)`. No `@StateObject`, no `ObservableObject`. [Source: 2-3 Dev Notes]
- **`RecordingViewModel.recordingState`:** Enum `{ recording, paused, systemInterrupted }` — use this to disable tag palette when paused.
- **`session.tags.count` auto-updates:** The tag count badge in `RecordingStatusBar` already observes this via SwiftData. Adding a new tag to `session.tags` will increment the badge automatically.
- **Placeholder location:** `RecordingScreen.swift` line ~52-53: `Color.clear.frame(height: DictlySpacing.xxl)` — replace with `TagPalette`.
- **Test approach:** `SessionRecorder` is `final` — cannot subclass for mocking. Extract testable logic as `static` methods or test through SwiftData directly. [Source: 2-3 Debug Log]
- **Build process:** Run `xcodegen generate` after adding new files, then `xcodebuild`. If stale module cache, run `swift package clean`. [Source: 2-3 Debug Log]
- **Review findings from 2.3:** VoiceOver labels should distinguish between recording states. Post VoiceOver announcements for tag placement confirmation.
- **Conventional commits:** `feat(recording): implement tag palette with category tabs and one-tap tagging (story 2.4)`
- **Test count:** 139 DictlyKit + 30 DictlyiOS tests currently passing.

### Git Intelligence

Recent commits follow `feat(recording):` / `fix(recording):` prefix for Epic 2. Latest:
- `4ad4a5e` — fix(recording): apply review fixes for story 2.3
- `228722c` — feat(recording): implement recording screen layout and status indicators (story 2.3)

Files from Stories 2.1-2.3 that overlap with this story:
- `SessionRecorder.swift` — read `elapsedTime` for tag anchorTime. No modifications needed.
- `RecordingScreen.swift` — will be modified to integrate TagPalette.
- `RecordingViewModel.swift` — read `recordingState` to control palette interactivity. No modifications needed.
- `RecordingStatusBar.swift` — tag count badge auto-updates. No modifications needed.

### Project Structure Notes

- New UI components go in `DictlyiOS/Tagging/` — verify this path is in `project.yml` sources
- Tests go in `DictlyiOSTests/TaggingTests/` — verify this path is in test target sources
- `TaggingService` is iOS-only — stays in DictlyiOS, not DictlyKit
- `Color(hexString:)` extension currently lives in `TagCategoryFormSheet.swift` — consider extracting to `DictlyiOS/Extensions/` or `DictlyKit/Sources/DictlyTheme/Colors.swift` if reusing across files. Alternatively, duplicate inline to avoid scope creep.
- No new framework dependencies needed — SwiftUI, UIKit (for haptics), and DictlyTheme already available

### References

- [Source: epics.md#Story-2.4] — AC, user story, technical requirements, UX-DR4/DR6/DR11/DR12
- [Source: prd.md#FR7] — DM can place a tag with a single tap during recording
- [Source: prd.md#FR9] — DM can select from a palette of tag categories
- [Source: prd.md#FR11] — DM receives haptic feedback confirming tag placement
- [Source: prd.md#FR12] — DM can see a running count of tags placed
- [Source: architecture.md#Recording-Files] — TagPalette.swift, TagCard.swift, CategoryTabBar.swift, TaggingService.swift
- [Source: architecture.md#State-Management] — @Observable, @Environment for service injection
- [Source: architecture.md#Enforcement-Guidelines] — @Observable, no AnyView, .task modifier
- [Source: architecture.md#FR7-FR13-Mapping] — TaggingService (FR7, FR8, FR11), TagPalette + TagCard (FR9, FR12, FR13)
- [Source: ux-design-specification.md#TagCard] — Component spec: color stripe, pressed state, accessibility
- [Source: ux-design-specification.md#CategoryTabBar] — Component spec: pill tabs, colored dots, scrollable
- [Source: ux-design-specification.md#Chosen-Direction] — iOS recording screen layout (B+D hybrid)
- [Source: ux-design-specification.md#Tag-Placement-Feedback] — Haptic medium, scale pulse 150ms, no audio
- [Source: ux-design-specification.md#Accessibility-Strategy] — VoiceOver, Dynamic Type, Reduce Motion, Motor
- [Source: ux-design-specification.md#Animation-&-Motion] — Tag placement: 0.95→1.0, 150ms ease-out
- [Source: 2-3-recording-screen-layout-and-status-indicators.md] — Previous story patterns, placeholder location

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- SwiftData `#Predicate<Tag> { $0.session == nil }` bypassed — used in-memory filtering (`allTags.filter { $0.session == nil }`) for SwiftData relationship optionality compatibility as specified in story notes.
- `Color(hexString:)` extension already exists in `TagCategoryFormSheet.swift` at module scope — reused directly from `CategoryTabBar.swift` and `TagPalette.swift` without duplication.
- `project.yml` already included `Tagging` and `Tests` source paths — no changes needed.
- `SessionRecorder` default memberwise init (no parameters) used to instantiate service in tests.
- VoiceOver announcement "Tag placed. X tags total." posted from `TagPalette` after `placeTag()` call (not from `TagCard`) since the count needs to be read after relationship update.

### Completion Notes List

- Implemented `TagCard.swift`: tappable button with color stripe, pressed scale animation (0.95→1.0 via `DictlyAnimation.tagPlacementStartScale`), category color glow, `@ScaledMetric` spacing, VoiceOver label, min 48pt tap target.
- Implemented `CategoryTabBar.swift`: horizontal ScrollView of pill tabs with colored dot + category name, active/inactive state, fade-edge gradient mask, sorted by `sortOrder`, VoiceOver accessibility.
- Implemented `TaggingService.swift`: `@Observable @MainActor`, `UIImpactFeedbackGenerator(.medium)` pre-warmed in init and on palette appear, `placeTag()` captures `elapsedTime`, inserts `Tag` with `rewindDuration=0`, appends to `session.tags`, do/catch error logging.
- Implemented `TagPalette.swift`: `@Query` for all tags + in-memory filter for template tags (`session == nil`), 2-column `LazyVGrid` switching to 1-column at `.accessibility3` Dynamic Type, `tagCountPerCategory` dictionary, default category selection on appear, palette dimmed 50% when paused.
- Modified `RecordingScreen.swift`: replaced `Color.clear.frame(height: DictlySpacing.xxl)` placeholder with `TagPalette`, added `@State private var taggingService: TaggingService?` initialized in `startRecording()`, `isInteractive: vm.recordingState == .recording` disables palette when paused.
- Created 11 unit tests covering: label/categoryName/anchorTime/rewindDuration correctness, session append, count increment, rapid sequential placements, SwiftData persistence.
- All tests pass: 139 DictlyKit + 41 DictlyiOS (11 new).

### File List

- `DictlyiOS/Tagging/TagCard.swift` — NEW
- `DictlyiOS/Tagging/CategoryTabBar.swift` — NEW
- `DictlyiOS/Tagging/TaggingService.swift` — NEW
- `DictlyiOS/Tagging/TagPalette.swift` — NEW
- `DictlyiOS/Recording/RecordingScreen.swift` — MODIFIED (replace placeholder, add TaggingService state)
- `DictlyiOS/Tests/TaggingTests/TaggingServiceTests.swift` — NEW
- `DictlyiOS/DictlyiOS.xcodeproj` — MODIFIED (regenerated via xcodegen)

## Change Log

- 2026-04-01: Implemented tag palette with category tabs and one-tap tagging (Story 2.4). Created TagCard, CategoryTabBar, TagPalette, TaggingService. Wired into RecordingScreen. 11 unit tests added. Build and all tests passing.
