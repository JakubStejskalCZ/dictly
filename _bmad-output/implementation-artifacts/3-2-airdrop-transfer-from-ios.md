# Story 3.2: AirDrop Transfer from iOS

Status: review

## Story

As a DM,
I want to send my session to my Mac via AirDrop after recording,
so that I can review it on the big screen without any file management hassle.

## Acceptance Criteria

1. **Given** a completed session on iOS, **when** the DM taps the AirDrop button on the TransferPrompt, **then** the standard iOS AirDrop share sheet appears with the .dictly bundle ready to send.

2. **Given** the AirDrop transfer is in progress, **when** the DM views the TransferPrompt, **then** a progress indicator shows the transfer state (sending → complete or failed).

3. **Given** the transfer completes successfully, **when** the DM views the TransferPrompt, **then** a checkmark confirmation is displayed that auto-dismisses after 2 seconds.

4. **Given** the transfer fails, **when** the DM views the TransferPrompt, **then** an error message with a retry button is displayed.

5. **Given** the DM chooses "Transfer Later", **when** they dismiss the session summary, **then** the session is saved locally and can be transferred later from the session list.

## Tasks / Subtasks

- [x] Task 1: Create `TransferService` (AC: #1, #2, #3, #4)
  - [x] 1.1 Create `TransferService.swift` in `DictlyiOS/Transfer/` as an `@Observable` class
  - [x] 1.2 Implement `prepareBundle(for:)` — reads audio file via `AudioFileManager.audioStorageDirectory()` + session's `audioFilePath`, calls `BundleSerializer.serialize()` to create a temporary `.dictly` bundle directory in `FileManager.default.temporaryDirectory`
  - [x] 1.3 Implement `shareViaAirDrop(session:from:)` — prepares the bundle, then presents `UIActivityViewController` with the `.dictly` bundle URL
  - [x] 1.4 Track transfer state via `@Observable` published property: `transferState: TransferState` (enum: `.idle`, `.preparing`, `.sharing`, `.completed`, `.failed(Error)`)
  - [x] 1.5 Handle `UIActivityViewController` completion callback — set state to `.completed` on success, `.failed` on error/cancellation
  - [x] 1.6 Implement `cleanupTemporaryBundle()` — removes temp `.dictly` directory after transfer completes or fails
  - [x] 1.7 Add `os.Logger` messages at each state transition (subsystem: `com.dictly.ios`, category: `transfer`)

- [x] Task 2: Create `TransferPrompt` view (AC: #1, #2, #3, #4, #5)
  - [x] 2.1 Create `TransferPrompt.swift` in `DictlyiOS/Transfer/`
  - [x] 2.2 Layout: session summary card (duration, tag count, category breakdown) at top, prominent AirDrop button, secondary "Transfer Later" button
  - [x] 2.3 Use `DictlyTheme` tokens for all colors, typography, spacing (no hardcoded values)
  - [x] 2.4 State-driven UI: `.idle` → AirDrop button active; `.preparing` → spinner with "Preparing..."; `.sharing` → "Sharing via AirDrop..."; `.completed` → green checkmark that auto-dismisses after 2 seconds; `.failed` → error message + "Retry" button
  - [x] 2.5 Auto-dismiss on completion: use `.task` with `Task.sleep` for 2-second delay, then call dismiss callback
  - [x] 2.6 "Transfer Later" calls dismiss callback directly (session is already saved from story 2.7)
  - [x] 2.7 Add VoiceOver accessibility labels on all interactive elements

- [x] Task 3: Integrate TransferPrompt into post-recording flow (AC: #1, #5)
  - [x] 3.1 Modify `SessionSummarySheet.swift` — add an "AirDrop to Mac" button that presents `TransferPrompt` (via `.sheet`)
  - [x] 3.2 Pass the completed `Session` from `SessionSummarySheet` to `TransferPrompt`
  - [x] 3.3 Keep existing "Done" button behavior — dismissing without transfer saves session locally (already works from story 2.7)

- [x] Task 4: Enable transfer from session list (AC: #5)
  - [x] 4.1 Add an AirDrop share action to session rows in `CampaignDetailScreen.swift` — swipe action or context menu item
  - [x] 4.2 Present `TransferPrompt` as a sheet when the share action is triggered
  - [x] 4.3 Pass the selected `Session` to `TransferPrompt`

- [x] Task 5: UIActivityViewController bridge (AC: #1)
  - [x] 5.1 Create a `UIViewControllerRepresentable` wrapper for `UIActivityViewController` in `DictlyiOS/Transfer/ActivityViewControllerRepresentable.swift`
  - [x] 5.2 Accept `activityItems: [Any]` and `completion: (Bool, Error?) -> Void` parameters
  - [x] 5.3 Alternatively: use the `presentationCompletionHandler` approach from `TransferService` to present directly via `UIApplication.shared` root view controller — evaluate which is cleaner

- [x] Task 6: Unit tests (AC: #1, #2, #3, #4, #5)
  - [x] 6.1 Create `TransferServiceTests.swift` in `DictlyiOS/Tests/TransferTests/`
  - [x] 6.2 Test `prepareBundle(for:)` — verify `.dictly` directory created in temp with `audio.aac` + `session.json`
  - [x] 6.3 Test state transitions: `.idle` → `.preparing` → `.sharing` → `.completed`
  - [x] 6.4 Test state transitions: `.idle` → `.preparing` → `.failed` when audio file is missing
  - [x] 6.5 Test `cleanupTemporaryBundle()` — verify temp directory removed
  - [x] 6.6 Test that `TransferService` handles a session with zero tags (edge case)

## Dev Notes

### Critical: UIActivityViewController for AirDrop

SwiftUI does not have a native AirDrop/share sheet API. You MUST use `UIActivityViewController` via `UIViewControllerRepresentable` or by presenting it imperatively from the root view controller. The `.dictly` bundle directory URL is passed as an activity item — iOS will automatically offer AirDrop as a sharing option when both devices are nearby.

```swift
// Presenting UIActivityViewController
let bundleURL = temporaryBundleURL // URL to the .dictly directory
let activityVC = UIActivityViewController(
    activityItems: [bundleURL],
    applicationActivities: nil
)
activityVC.completionWithItemsHandler = { _, completed, _, error in
    if let error = error {
        self.transferState = .failed(error)
    } else if completed {
        self.transferState = .completed
    } else {
        // User cancelled — return to idle
        self.transferState = .idle
    }
}
```

### TransferService State Machine

```
idle → preparing (bundle being created)
     → sharing (UIActivityViewController presented)
     → completed (user confirmed AirDrop send)
     → failed(Error) (bundle creation failed OR AirDrop failed)
     → idle (user cancelled share sheet, or retry after failure)
```

### Bundle Creation Flow

1. Read audio data from disk: `session.audioFilePath` is relative to `AudioFileManager.audioStorageDirectory()`
2. Create temp directory: `FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".dictly")`
3. Call `BundleSerializer().serialize(session:audioData:to:)` (already implemented in story 3.1)
4. Pass the temp `.dictly` URL to `UIActivityViewController`
5. Clean up temp directory in completion handler

### Session Audio File Path

Sessions store their audio path in `session.audioFilePath` as an absolute path string. The audio file is `.m4a` format (AAC 64kbps mono) stored under `AudioFileManager.audioStorageDirectory()`. When serializing the bundle, just read the raw bytes with `Data(contentsOf:)` — `BundleSerializer` writes it as `audio.aac` inside the bundle.

### TransferPrompt UX Requirements

From the UX spec:
- **Anatomy:** Session summary card (duration, tag count, category breakdown), AirDrop button (prominent), "Transfer Later" secondary option
- **States:** Ready → Transferring (progress) → Complete (checkmark) → Failed (retry with error context)
- **Success feedback:** Brief, non-blocking. Checkmark → auto-dismiss after 2 seconds
- **Error feedback:** Inline error with specific cause and retry button. Never auto-dismiss errors.
- **Color tokens:** Success = `DictlyColors.success` / `#16A34A`, destructive = `DictlyColors.destructive`

### Integration with SessionSummarySheet

The current `SessionSummarySheet` (story 2.7) has a "Done" button that dismisses the recording screen. Add an "AirDrop to Mac" button alongside "Done" to present the `TransferPrompt`. The session is already saved to SwiftData before the summary appears, so "Transfer Later" is safe — no data loss.

### What NOT to Do

- **Do NOT** register a UTI for `.dictly` in this story — that's story 3.4 (Mac Import)
- **Do NOT** implement Bonjour/local network transfer — that's story 3.3
- **Do NOT** modify `BundleSerializer` — it's complete from story 3.1, just call it
- **Do NOT** use `ShareLink` (SwiftUI) — it doesn't support directory bundles and lacks the completion callback needed for state tracking
- **Do NOT** add any Mac-side import logic — this story is iOS-only
- **Do NOT** create a custom AirDrop implementation — use standard `UIActivityViewController` which provides AirDrop automatically
- **Do NOT** use `@StateObject` or `ObservableObject` — use `@Observable` (project convention)
- **Do NOT** hardcode colors, fonts, or spacing — use `DictlyTheme` tokens

### Existing Code to Reuse

| What | Where | How |
|------|-------|-----|
| `BundleSerializer` | `DictlyKit/Sources/DictlyStorage/BundleSerializer.swift` | Call `serialize(session:audioData:to:)` to create bundle |
| `AudioFileManager` | `DictlyKit/Sources/DictlyStorage/AudioFileManager.swift` | Use `audioStorageDirectory()` to locate audio files |
| `TransferBundle` + DTOs | `DictlyKit/Sources/DictlyModels/TransferBundle.swift` | Session, Tag, Campaign DTOs with `toDTO()` extensions |
| `DictlyError.transfer(...)` | `DictlyKit/Sources/DictlyModels/DictlyError.swift` | Use existing error cases (`.bundleCorrupted`, `.networkUnavailable`) |
| `SessionSummarySheet` | `DictlyiOS/Recording/SessionSummarySheet.swift` | Integrate AirDrop button into existing post-recording flow |
| `CampaignDetailScreen` | `DictlyiOS/Campaigns/CampaignDetailScreen.swift` | Add share/transfer action to session list rows |
| `DictlyTheme` (Colors, Typography, Spacing) | `DictlyKit/Sources/DictlyTheme/` | All UI tokens |
| `Session.audioFilePath` | `DictlyKit/Sources/DictlyModels/Session.swift` | Audio file location for bundle packaging |

### Project Structure Notes

New files go in `DictlyiOS/Transfer/` (iOS app target, not DictlyKit — uses UIKit APIs):

```
DictlyiOS/Transfer/
├── TransferService.swift                    # NEW: @Observable — bundle prep + AirDrop presentation
├── TransferPrompt.swift                     # NEW: Post-session transfer UI
└── ActivityViewControllerRepresentable.swift # NEW: UIViewControllerRepresentable for UIActivityViewController

DictlyiOS/Tests/TransferTests/
└── TransferServiceTests.swift               # NEW: Transfer state + bundle prep tests
```

Modified files:
- `DictlyiOS/Recording/SessionSummarySheet.swift` — add AirDrop button
- `DictlyiOS/Campaigns/CampaignDetailScreen.swift` — add share action on session rows

### Testing Standards

- Use `XCTest` with `@MainActor` (project convention)
- `TransferService` tests can use temporary directories for bundle creation/cleanup verification
- Cannot test `UIActivityViewController` presentation in unit tests — focus on state machine and bundle preparation logic
- Use in-memory `ModelContainer` for tests needing SwiftData sessions:
  ```swift
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  container = try ModelContainer(for: Schema(DictlySchema.all), configurations: config)
  context = container.mainContext
  ```
- Clean up temp directories in `tearDown`

### Previous Story (3.1) Learnings

- `@Model` macro prevents `convenience init` in extensions — use `static func from(_:)` factory methods
- `DictlyError` has `Equatable` conformance — use `XCTAssertEqual` for error assertions
- `BundleSerializer` uses `JSONEncoder` with `.iso8601` dates and `.sortedKeys` — don't reconfigure
- Stale `.o` artifacts can cause link errors — `swift package clean` resolves

### Story 3.2 Learnings

- `Task.detached` conflicts with `@MainActor`-isolated types in Swift 6 — `@MainActor` classes cannot be captured from non-isolated tasks without `await`; avoid `Task.detached` for operations that access main-actor-bound state
- `temporaryBundleURL` is set by `shareViaAirDrop`, not `prepareBundle` — tests for cleanup must use `shareViaAirDrop` to properly exercise the full flow
- `TransferPrompt` auto-dismiss uses `.onChange(of:)` + `Task.sleep` pattern (not `.task`) to allow cancellation of the auto-dismiss on disappear

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 3, Story 3.2 acceptance criteria]
- [Source: _bmad-output/planning-artifacts/architecture.md — API & Communication Patterns, Project Structure, iOS Target Boundaries]
- [Source: _bmad-output/planning-artifacts/prd.md — FR23, FR25 Transfer requirements]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — TransferPrompt component spec, success/error feedback patterns]
- [Source: DictlyKit/Sources/DictlyStorage/BundleSerializer.swift — serialize/deserialize API]
- [Source: DictlyKit/Sources/DictlyStorage/AudioFileManager.swift — audioStorageDirectory()]
- [Source: DictlyKit/Sources/DictlyModels/DictlyError.swift — TransferError enum]
- [Source: DictlyiOS/Recording/SessionSummarySheet.swift — current post-recording UI to integrate with]
- [Source: DictlyiOS/Recording/RecordingScreen.swift — SessionSummarySheet presentation flow]
- [Source: _bmad-output/implementation-artifacts/3-1-dictly-bundle-format-and-serialization.md — previous story dev notes and learnings]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Fixed Swift 6 concurrency issue: removed `Task.detached` in `prepareBundle` — `@MainActor`-isolated types cannot be captured from non-isolated tasks without `await`. Simplified to synchronous call on main actor.
- Fixed test assertions: `temporaryBundleURL` is only set in `shareViaAirDrop`, not `prepareBundle` directly. Updated state-transition and cleanup tests to use `shareViaAirDrop` for proper end-to-end testing.

### Completion Notes List

- Implemented `TransferService` as `@Observable @MainActor` class with full state machine: `.idle → .preparing → .sharing → .completed/.failed`. Handles cancellation (returns to `.idle`). Logger at every state transition.
- Created `ActivityViewControllerRepresentable` wrapping `UIActivityViewController`; completion dispatched to `@MainActor` via `Task`.
- `TransferPrompt` is fully state-driven: idle (AirDrop button), preparing (spinner), sharing (spinner + UIActivityViewController sheet), completed (green checkmark, auto-dismiss 2s via `.onChange`+`Task.sleep`), failed (error + retry + transfer later).
- All DictlyTheme tokens used — no hardcoded colors/fonts/spacing.
- VoiceOver accessibility labels on all interactive elements.
- `SessionSummarySheet` gains "AirDrop to Mac" button that presents `TransferPrompt` as a sheet; existing "Done" behavior unchanged.
- `CampaignDetailScreen` gains leading swipe action ("AirDrop") + context menu item ("AirDrop to Mac") on session rows.
- 13 unit tests — all pass. Full regression suite passes (no regressions).

### File List

- `DictlyiOS/Transfer/TransferService.swift` (new)
- `DictlyiOS/Transfer/TransferPrompt.swift` (new)
- `DictlyiOS/Transfer/ActivityViewControllerRepresentable.swift` (new)
- `DictlyiOS/Tests/TransferTests/TransferServiceTests.swift` (new)
- `DictlyiOS/Recording/SessionSummarySheet.swift` (modified)
- `DictlyiOS/Campaigns/CampaignDetailScreen.swift` (modified)
- `DictlyiOS/project.yml` (modified — added Transfer folder to DictlyiOS target sources)
- `DictlyiOS/DictlyiOS.xcodeproj` (regenerated via xcodegen)

## Change Log

- 2026-04-02: Implemented Story 3.2 — AirDrop Transfer from iOS. Created TransferService, TransferPrompt, ActivityViewControllerRepresentable. Integrated into SessionSummarySheet and CampaignDetailScreen. 13 unit tests added, all pass.
