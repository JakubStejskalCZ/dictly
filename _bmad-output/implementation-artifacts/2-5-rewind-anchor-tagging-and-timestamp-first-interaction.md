# Story 2.5: Rewind-Anchor Tagging & Timestamp-First Interaction

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a DM,
I want each tag to capture the ~10 seconds before I tapped (not the moment of the tap),
So that the tag anchors to the actual moment I'm reacting to, not my reaction.

## Acceptance Criteria (BDD)

### Scenario 1: Default Rewind-Anchor Tagging

Given recording is active with default 10-second rewind
When the DM taps a tag at timestamp 2:30:00
Then the tag's anchor time is stored as 2:29:50 (10 seconds before the tap)
And the tag's rewindDuration is stored as 10.0

### Scenario 2: Configurable Rewind Duration

Given the DM has configured rewind duration to 15 seconds in Settings
When they place a tag at timestamp 1:00:00
Then the anchor time is 0:59:45
And the tag's rewindDuration is 15.0

### Scenario 3: Timestamp-First for Custom Tags

Given the DM taps the "+" custom tag card
When the custom tag sheet appears
Then the anchor timestamp is already captured from the moment of the first tap
And the DM can take their time entering a label without losing the moment

### Scenario 4: Tag Persistence on Force-Quit

Given a tag is placed
When the app is force-quit immediately after
Then the tag is persisted in SwiftData (zero tag loss)

### Scenario 5: Rewind Duration Settings

Given iOS Settings screen
When the DM changes rewind duration to 5s/10s/15s/20s
Then the new duration applies to all subsequent tags in future sessions

### Scenario 6: Early Recording Edge Case

Given recording started 3 seconds ago
When the DM places a tag with 10-second rewind configured
Then the anchor time is clamped to 0.0 (not negative)
And the rewindDuration reflects the actual rewind applied (3 seconds)

## Tasks / Subtasks

- [x] Task 1: Modify `TaggingService.placeTag()` for rewind-anchor logic (AC: #1, #2, #6)
  - [x] 1.1 Add `rewindDuration` parameter to `placeTag()` signature. The caller passes the configured rewind duration.
  - [x] 1.2 Calculate `anchorTime = max(0, sessionRecorder.elapsedTime - rewindDuration)`. Clamp to 0 to avoid negative timestamps for tags placed early in a recording.
  - [x] 1.3 Calculate `actualRewind = sessionRecorder.elapsedTime - anchorTime` (may be less than configured duration for early tags). Store this as the tag's `rewindDuration`.
  - [x] 1.4 Update the `Tag` init call: `anchorTime: anchorTime, rewindDuration: actualRewind`.
  - [x] 1.5 Update the log message to include rewind info: `"Tag placed: \(label) in \(categoryName) at \(anchorTime) (rewound \(actualRewind)s from \(elapsedTime))"`.

- [x] Task 2: Add rewind duration setting to `SettingsScreen.swift` (AC: #5)
  - [x] 2.1 Add `@AppStorage("rewindDuration") private var rewindDuration: Double = 10.0` to `SettingsScreen`. Use the key `"rewindDuration"` in standard `UserDefaults`.
  - [x] 2.2 Add a new `Section("Tagging")` above the existing "Storage" section.
  - [x] 2.3 Use a `Picker` with `.pickerStyle(.menu)` or `.segmented` for the 4 options: 5s, 10s, 15s, 20s. Display as "5 seconds", "10 seconds", "15 seconds", "20 seconds".
  - [x] 2.4 Add a descriptive footer: "How far back each tag captures before the moment you tap."
  - [x] 2.5 VoiceOver: the picker should read "Rewind duration, [current value]. Double-tap to change."

- [x] Task 3: Update `TagPalette.swift` to read and pass rewind duration (AC: #1, #2, #3)
  - [x] 3.1 Add `@AppStorage("rewindDuration") private var rewindDuration: Double = 10.0` to `TagPalette`.
  - [x] 3.2 Update the `taggingService.placeTag()` call at line ~71-76 to pass `rewindDuration: rewindDuration`.
  - [x] 3.3 **Timestamp-first for custom tag flow (Story 2.6 preparation):** The rewindDuration is read at tap time, not at sheet dismiss time. This ensures the anchor is captured at the moment of first tap. Story 2.6 will consume this — no custom tag sheet work in THIS story.

- [x] Task 4: Update existing `TaggingServiceTests` and add rewind-anchor tests (AC: #1, #2, #4, #6)
  - [x] 4.1 Update ALL existing `placeTag()` calls in `TaggingServiceTests.swift` to pass `rewindDuration: 0` (or the applicable value) to match new signature. Existing tests must still pass.
  - [x] 4.2 Test: `testPlaceTag_withRewindDuration_calculatesCorrectAnchorTime()` — recorder at 0, rewindDuration 10 → anchorTime 0 (clamped), rewindDuration 0 (actual).
  - [x] 4.3 Test: `testPlaceTag_withRewindDuration_storesActualRewind()` — verify `tag.rewindDuration` reflects actual rewind, not just configured.
  - [x] 4.4 Test: `testPlaceTag_earlyRecording_clampsAnchorTimeToZero()` — with elapsedTime < rewindDuration, anchorTime should be 0.
  - [x] 4.5 Test: `testPlaceTag_rewindDuration15s_calculatesCorrectly()` — verify 15s rewind from a sufficient elapsed time.
  - [x] 4.6 Test: `testPlaceTag_rewindDuration5s_calculatesCorrectly()` — verify 5s rewind.
  - [x] 4.7 Test: `testPlaceTag_rewindDuration20s_calculatesCorrectly()` — verify 20s rewind.
  - [x] 4.8 Verify all existing tests (139 DictlyKit + 41 DictlyiOS) still pass after signature change.

- [x] Task 5: Build verification (AC: all)
  - [x] 5.1 Run `xcodegen generate` in `DictlyiOS/`.
  - [x] 5.2 Run `xcodebuild` — verify `** BUILD SUCCEEDED **`.
  - [x] 5.3 Run full test suite — verify `** TEST SUCCEEDED **`.

## Dev Notes

### Architecture: Rewind-Anchor Model

The rewind-anchor is Dictly's defining interaction. Normal bookmarks mark "now." Dictly marks "just before now" — matching how human attention works. The DM realizes something was important a few seconds after it happened. The tap captures the moment, not the reaction.

**Formula:**
```
tapTime = sessionRecorder.elapsedTime          // e.g., 9000.0 (2:30:00)
configuredRewind = rewindDuration              // e.g., 10.0 (from @AppStorage)
anchorTime = max(0, tapTime - configuredRewind) // e.g., 8990.0 (2:29:50)
actualRewind = tapTime - anchorTime            // e.g., 10.0 (or less if clamped)
```

The `Tag` model already has both `anchorTime: TimeInterval` and `rewindDuration: TimeInterval` properties. Story 2.4 stored `rewindDuration: 0`. This story makes them meaningful.

[Source: prd.md#FR8, ux-design-specification.md#Timestamp-First-Interaction, epics.md#Story-2.5]

### What to Modify vs. Create

**This story modifies existing files only — NO new files are created.**

| File | Change |
|------|--------|
| `DictlyiOS/Tagging/TaggingService.swift` | Add `rewindDuration` param, calculate anchor |
| `DictlyiOS/Tagging/TagPalette.swift` | Read `@AppStorage`, pass rewindDuration to placeTag |
| `DictlyiOS/Settings/SettingsScreen.swift` | Add "Tagging" section with rewind duration picker |
| `DictlyiOS/Tests/TaggingTests/TaggingServiceTests.swift` | Update existing calls, add rewind tests |

### Current `placeTag()` Signature (to be modified)

```swift
// CURRENT (Story 2.4):
func placeTag(label: String, categoryName: String, session: Session, context: ModelContext) -> Bool

// NEW (Story 2.5):
func placeTag(label: String, categoryName: String, rewindDuration: TimeInterval, session: Session, context: ModelContext) -> Bool
```

### Current `TaggingService.swift` Implementation

The full file is at `DictlyiOS/Tagging/TaggingService.swift` (66 lines). Key lines to change:
- Line 34: Add `rewindDuration: TimeInterval` parameter
- Line 38: Change `let anchorTime = sessionRecorder.elapsedTime` to rewind-anchor calculation
- Line 43: Change `rewindDuration: 0` to `rewindDuration: actualRewind`

### Current `TagPalette.swift` Call Site

At `DictlyiOS/Tagging/TagPalette.swift` lines 71-76:
```swift
let success = taggingService.placeTag(
    label: tag.label,
    categoryName: tag.categoryName,
    session: session,
    context: modelContext
)
```
Add `rewindDuration: rewindDuration` parameter after `categoryName`.

### Current `SettingsScreen.swift`

At `DictlyiOS/Settings/SettingsScreen.swift` (36 lines). Currently has only a "Storage" section in a `Form`. Add a "Tagging" section before it with a `Picker` for rewind duration.

### @AppStorage Key Convention

Use `@AppStorage("rewindDuration")` with `Double` type (default `10.0`). Both `SettingsScreen` and `TagPalette` read from the same `UserDefaults` key. No custom `UserDefaults` suite needed — standard suite is fine since this is iOS-only.

The valid options are `5.0`, `10.0`, `15.0`, `20.0` — matching FR47 and the epics spec.

[Source: prd.md#FR47, architecture.md#FR47-FR49-Mapping]

### Tag Model — Already Correct

`DictlyKit/Sources/DictlyModels/Tag.swift` already has `anchorTime: TimeInterval` and `rewindDuration: TimeInterval`. No model changes needed. The model was designed with this story in mind.

[Source: DictlyKit/Sources/DictlyModels/Tag.swift]

### Timestamp-First Interaction for Custom Tags

The UX spec mandates timestamp-first: on ANY tag tap (standard or custom), immediately capture timestamp + rewind-anchor before any label input. For custom tags (Story 2.6), the "+" tap captures the anchor first, then shows the label sheet. The user can take their time — the moment is already saved.

**This story establishes the rewind-anchor logic that Story 2.6 will consume.** The custom tag sheet itself is NOT in scope here, but the `placeTag()` rewind logic must work correctly when Story 2.6 calls it with the anchor captured at first-tap time.

[Source: ux-design-specification.md#Chosen-Direction, epics.md#Story-2.6]

### Edge Case: Early Recording

If the DM places a tag 3 seconds into recording with a 10-second rewind configured, `anchorTime` must clamp to `0.0` (not negative). The `actualRewind` stored on the tag should be `3.0` (the real rewind applied), not `10.0`.

### Settings Picker UX

Per architecture, Settings uses standard `Form` + `Picker` components. The rewind duration picker should be simple and match iOS Settings conventions:
- `Picker("Rewind Duration", selection: $rewindDuration)` with labeled options
- Footer text explains the concept: "How far back each tag captures before the moment you tap."
- No custom UI needed — standard SwiftUI Form picker

### Existing Infrastructure to Reuse

- **`Tag` model** — `DictlyKit/Sources/DictlyModels/Tag.swift` — `anchorTime`, `rewindDuration` already present
- **`TaggingService`** — `DictlyiOS/Tagging/TaggingService.swift` — modify `placeTag()`, keep haptic/logging/error handling intact
- **`TagPalette`** — `DictlyiOS/Tagging/TagPalette.swift` — add `@AppStorage`, pass to `placeTag()`
- **`SettingsScreen`** — `DictlyiOS/Settings/SettingsScreen.swift` — add Tagging section
- **`SessionRecorder.elapsedTime`** — already available in `TaggingService` via `sessionRecorder` property
- **`DictlyTheme`** — no new tokens needed, settings use standard Form styling
- **`os.Logger`** — existing logger in `TaggingService` with category `"tagging"`

### What NOT to Build in This Story

- **Custom tag creation ("+" card / `CustomTagSheet`)** — Story 2.6 builds the custom tag sheet. This story only ensures the rewind-anchor placeTag logic is ready for it.
- **Stop recording bar** — Story 2.7.
- **Circular audio buffer** — Architecture considered this but the post-hoc timestamp calculation approach (current elapsed - rewind) is simpler and sufficient. No audio buffer needed.
- **Tag editing/deletion** — Mac-only (Epic 4).
- **Any new UI files** — This story modifies existing files only.

### Swift 6 Strict Concurrency Notes

- `TaggingService` is already `@Observable @MainActor` — no changes needed to concurrency model.
- `@AppStorage` is thread-safe and reads from `UserDefaults` on main thread.
- No new async work introduced.

### Logging

Update the existing tag placement log in `TaggingService` to include rewind info:
- `.info` — `"Tag placed: \(label) in \(categoryName) at \(anchorTime) (rewound \(actualRewind)s from \(elapsedTime))"`
- `.error` — unchanged from Story 2.4

### Testing Strategy

**Update existing tests first** — all 11 existing `TaggingServiceTests` call `placeTag()` without `rewindDuration`. They must be updated to pass `rewindDuration: 0` so they continue to pass with identical behavior.

**Then add rewind-specific tests** — verify the formula `max(0, elapsed - rewind)` with multiple rewind values and the early-recording edge case.

`SessionRecorder` starts with `elapsedTime = 0` when not recording. Tests that need a specific elapsed time should note this limitation (deferred from Story 2.4 review). Test the rewind formula as a calculation, not through actual recording.

[Source: 2-4 story Dev Notes, TaggingServiceTests.swift]

### Previous Story Intelligence (from Story 2.4)

Key patterns and learnings:
- **`TaggingService` is `@Observable @MainActor final class`** — follows `SessionRecorder` pattern. Injected into `TagPalette` as `let taggingService: TaggingService`.
- **`placeTag()` returns `Bool`** — `true` on success, `false` on save failure. Rolls back tag on failure (deletes from context, removes from session.tags).
- **`hapticGenerator.prepare()` called in init and via `prepareHaptic()`** — keep this pattern, no changes.
- **In-memory tag filtering** — `allTags.filter { $0.session == nil }` for template tags. Don't change this.
- **Test count** — 139 DictlyKit + 41 DictlyiOS currently passing.
- **Build process** — Run `xcodegen generate` after changes, then `xcodebuild`.
- **Review findings from 2.4:** `placeTag` returns Bool and rolls back on failure. VoiceOver announcement conditional on success. These patterns are established — don't change them.

### Git Intelligence

Recent commits follow `feat(tagging):` / `fix(tagging):` prefix for tagging stories:
- `efd3ea3` — fix(tagging): apply review fixes for story 2.4 tag palette
- `c885d94` — feat(tagging): implement tag palette with category tabs and one-tap tagging (story 2.4)

Use commit prefix: `feat(tagging): implement rewind-anchor tagging and timestamp-first interaction (story 2.5)`

### Project Structure Notes

- No new files created — only modifications to 4 existing files
- `@AppStorage` key `"rewindDuration"` is a new user preference — standard `UserDefaults` in iOS app sandbox
- No new framework dependencies
- No changes to `project.yml` or `Package.swift`

### References

- [Source: epics.md#Story-2.5] — AC, user story, rewind-anchor requirements
- [Source: prd.md#FR8] — Each tag automatically anchors to configurable time window before tap (default ~10s; options: 5s/10s/15s/20s)
- [Source: prd.md#FR47] — DM can configure the default rewind duration (5s/10s/15s/20s)
- [Source: architecture.md#FR7-FR13-Mapping] — TaggingService owns FR7 (single tap), FR8 (rewind anchor)
- [Source: architecture.md#FR47-FR49-Mapping] — iOS Settings for rewind duration
- [Source: architecture.md#Settings] — SettingsScreen.swift for rewind duration, audio quality
- [Source: ux-design-specification.md#Defining-Experience] — Rewind-anchor is Dictly's defining interaction
- [Source: ux-design-specification.md#Chosen-Direction] — Timestamp-first interaction model
- [Source: ux-design-specification.md#Experience-Mechanics] — Tag anchors to ~10s before tap (configurable: 5/10/15/20s)
- [Source: ux-design-specification.md#Interaction-Patterns] — Timestamp-first on every tag action
- [Source: 2-4-tag-palette-with-category-tabs-and-one-tap-tagging.md] — Previous story patterns, TaggingService implementation

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

### Completion Notes List

- Implemented rewind-anchor formula: `anchorTime = max(0, elapsedTime - rewindDuration)`, `actualRewind = elapsedTime - anchorTime`
- Added `rewindDuration: TimeInterval` parameter to `TaggingService.placeTag()` — stored as `actualRewind` on tag (reflects real rewind, not just configured value)
- Updated log message to include full rewind info: anchor time + actual rewind + elapsed time
- Added `@AppStorage("rewindDuration")` to `SettingsScreen` (default 10.0) with Tagging section, `.menu` Picker for 5/10/15/20s, footer text, and VoiceOver accessibilityLabel
- Added `@AppStorage("rewindDuration")` to `TagPalette` — rewind captured at tap time (timestamp-first, ready for Story 2.6)
- Updated all 11 existing `placeTag()` calls in tests to `rewindDuration: 0` — all pass
- Added 7 new rewind tests: `withRewindDuration_calculatesCorrectAnchorTime`, `storesActualRewind`, `earlyRecording_clampsAnchorTimeToZero`, `rewindDuration15s`, `5s`, `20s`, `zeroRewindDuration_anchorEqualsElapsedTime`
- Build: `** BUILD SUCCEEDED **`; Tests: 18/18 TaggingServiceTests + 139 DictlyKit = `** TEST SUCCEEDED **`

### File List

- DictlyiOS/Tagging/TaggingService.swift
- DictlyiOS/Tagging/TagPalette.swift
- DictlyiOS/Settings/SettingsScreen.swift
- DictlyiOS/Tests/TaggingTests/TaggingServiceTests.swift

## Change Log

- 2026-04-02: Implemented rewind-anchor tagging (Story 2.5) — added `rewindDuration` param to `placeTag()`, rewind-anchor formula with early-recording clamping, rewind duration Picker in Settings (5/10/15/20s via @AppStorage), @AppStorage in TagPalette for timestamp-first capture, 7 new rewind tests, all existing tests updated and passing.
