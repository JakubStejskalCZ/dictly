# Story 3.2: AirDrop Transfer from iOS

Status: ready-for-dev

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

- [ ] Task 1: Create `TransferService` (AC: #1, #2, #3, #4)
  - [ ] 1.1 Create `TransferService.swift` in `DictlyiOS/Transfer/` as an `@Observable` class
  - [ ] 1.2 Implement `prepareBundle(for:)` — reads audio file via `AudioFileManager.audioStorageDirectory()` + session's `audioFilePath`, calls `BundleSerializer.serialize()` to create a temporary `.dictly` bundle directory in `FileManager.default.temporaryDirectory`
  - [ ] 1.3 Implement `shareViaAirDrop(session:from:)` — prepares the bundle, then presents `UIActivityViewController` with the `.dictly` bundle URL
  - [ ] 1.4 Track transfer state via `@Observable` published property: `transferState: TransferState` (enum: `.idle`, `.preparing`, `.sharing`, `.completed`, `.failed(Error)`)
  - [ ] 1.5 Handle `UIActivityViewController` completion callback — set state to `.completed` on success, `.failed` on error/cancellation
  - [ ] 1.6 Implement `cleanupTemporaryBundle()` — removes temp `.dictly` directory after transfer completes or fails
  - [ ] 1.7 Add `os.Logger` messages at each state transition (subsystem: `com.dictly.ios`, category: `transfer`)

- [ ] Task 2: Create `TransferPrompt` view (AC: #1, #2, #3, #4, #5)
  - [ ] 2.1 Create `TransferPrompt.swift` in `DictlyiOS/Transfer/`
  - [ ] 2.2 Layout: session summary card (duration, tag count, category breakdown) at top, prominent AirDrop button, secondary "Transfer Later" button
  - [ ] 2.3 Use `DictlyTheme` tokens for all colors, typography, spacing (no hardcoded values)
  - [ ] 2.4 State-driven UI: `.idle` → AirDrop button active; `.preparing` → spinner with "Preparing..."; `.sharing` → "Sharing via AirDrop..."; `.completed` → green checkmark that auto-dismisses after 2 seconds; `.failed` → error message + "Retry" button
  - [ ] 2.5 Auto-dismiss on completion: use `.task` with `Task.sleep` for 2-second delay, then call dismiss callback
  - [ ] 2.6 "Transfer Later" calls dismiss callback directly (session is already saved from story 2.7)
  - [ ] 2.7 Add VoiceOver accessibility labels on all interactive elements

- [ ] Task 3: Integrate TransferPrompt into post-recording flow (AC: #1, #5)
  - [ ] 3.1 Modify `SessionSummarySheet.swift` — add an "AirDrop to Mac" button that presents `TransferPrompt` (via `.sheet`)
  - [ ] 3.2 Pass the completed `Session` from `SessionSummarySheet` to `TransferPrompt`
  - [ ] 3.3 Keep existing "Done" button behavior — dismissing without transfer saves session locally (already works from story 2.7)

- [ ] Task 4: Enable transfer from session list (AC: #5)
  - [ ] 4.1 Add an AirDrop share action to session rows in `CampaignDetailScreen.swift` — swipe action or context menu item
  - [ ] 4.2 Present `TransferPrompt` as a sheet when the share action is triggered
  - [ ] 4.3 Pass the selected `Session` to `TransferPrompt`

- [ ] Task 5: UIActivityViewController bridge (AC: #1)
  - [ ] 5.1 Create a `UIViewControllerRepresentable` wrapper for `UIActivityViewController` in `DictlyiOS/Transfer/ActivityViewControllerRepresentable.swift`
  - [ ] 5.2 Accept `activityItems: [Any]` and `completion: (Bool, Error?) -> Void` parameters
  - [ ] 5.3 Alternatively: use the `presentationCompletionHandler` approach from `TransferService` to present directly via `UIApplication.shared` root view controller — evaluate which is cleaner

- [ ] Task 6: Unit tests (AC: #1, #2, #3, #4, #5)
  - [ ] 6.1 Create `TransferServiceTests.swift` in `DictlyiOS/Tests/TransferTests/`
  - [ ] 6.2 Test `prepareBundle(for:)` — verify `.dictly` directory created in temp with `audio.aac` + `session.json`
  - [ ] 6.3 Test state transitions: `.idle` → `.preparing` → `.sharing` → `.completed`
  - [ ] 6.4 Test state transitions: `.idle` → `.preparing` → `.failed` when audio file is missing
  - [ ] 6.5 Test `cleanupTemporaryBundle()` — verify temp directory removed
  - [ ] 6.6 Test that `TransferService` handles a session with zero tags (edge case)

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

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
