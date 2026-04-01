# Story 2.2: Pause, Resume & Phone Call Interruption Handling

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a DM,
I want to pause and resume recording and have it survive phone calls,
So that interruptions don't create separate files or lose my session continuity.

## Acceptance Criteria (BDD)

### Scenario 1: Manual Pause

Given an active recording
When the DM taps pause
Then recording stops capturing audio, the state shows "PAUSED", and the timer freezes

### Scenario 2: Manual Resume

Given a paused recording
When the DM taps resume
Then recording continues in the same session and file seamlessly

### Scenario 3: Phone Call Auto-Pause

Given an active recording
When a phone call is received
Then recording auto-pauses and the state reflects "Recording Paused"

### Scenario 4: Resume After Phone Call

Given a phone-call-paused recording
When the call ends
Then a prominent "Resume Recording" button is displayed
And tapping it resumes recording in the same session

### Scenario 5: Pause Gaps Visible on Mac

Given a session with pauses
When reviewed later on Mac
Then pauses appear as gaps in the timeline with all tags before and after intact

## Tasks / Subtasks

- [ ] Task 1: Implement `pauseRecording()` and `resumeRecording()` on `SessionRecorder` (AC: #1, #2)
  - [ ] 1.1 Add `pauseRecording()` — call `audioEngine.inputNode.removeTap(onBus: 0)` and `audioEngine.pause()` to stop capturing audio. Set `isPaused = true`, record `pauseStartDate = Date()`. Do NOT deactivate the AVAudioSession (keep background mode alive). Do NOT close `outputFile`.
  - [ ] 1.2 Add `resumeRecording()` — reinstall the input tap on `audioEngine.inputNode` with the same buffer size and format, call `try audioEngine.start()` to restart capture. Set `isPaused = false`, accumulate pause duration from `pauseStartDate` into `totalPauseDuration`, clear `pauseStartDate`.
  - [ ] 1.3 Update the timer task: when `isPaused == true`, the timer already skips updating `elapsedTime` (line 164 guard). On resume, anchor elapsed time correctly: `elapsedTime = Date().timeIntervalSince(recordingStartDate!) - totalPauseDuration`. Add `totalPauseDuration: TimeInterval` private property (init 0).
  - [ ] 1.4 Add `pauseStartDate: Date?` private property to track when the current pause began.
  - [ ] 1.5 On pause, set `currentAudioLevel = 0` so the LiveWaveform (Story 2.3) shows muted/gray state.

- [ ] Task 2: Implement AVAudioSession interruption handling (AC: #3, #4)
  - [ ] 2.1 In `startRecording()`, after `audioEngine.start()`, register for `AVAudioSession.interruptionNotification` using `NotificationCenter.default.addObserver(forName:object:queue:)`. Store the observer token as `private var interruptionObserver: (any NSObjectProtocol)?`.
  - [ ] 2.2 In the interruption handler, extract `AVAudioSession.InterruptionType` from `userInfo[AVAudioSessionInterruptionTypeKey]`. On `.began`: call `pauseRecording()` and set a flag `wasInterruptedBySystem = true` so the UI knows to show the resume prompt.
  - [ ] 2.3 On `.ended`: check `userInfo[AVAudioSessionInterruptionOptions]` for `.shouldResume`. Do NOT auto-resume — per UX spec, phone call resume requires user action. Instead, ensure the "Resume Recording" button is prominent. The `wasInterruptedBySystem` flag drives this UI state.
  - [ ] 2.4 In `stopRecording()`, remove the interruption observer: `NotificationCenter.default.removeObserver(interruptionObserver!)` and set it to nil.
  - [ ] 2.5 In `pauseRecording()` and `resumeRecording()`, set `wasInterruptedBySystem = false` when the user manually pauses/resumes (only system interruptions set it to true).

- [ ] Task 3: Handle AVAudioEngine configuration changes (AC: #3, #4)
  - [ ] 3.1 Register for `Notification.Name.AVAudioEngineConfigurationChange` in `startRecording()`. Store observer as `private var configChangeObserver: (any NSObjectProtocol)?`.
  - [ ] 3.2 On configuration change (e.g., Bluetooth mic disconnects mid-recording), log the new audio route. If `isRecording && !isPaused`, re-install the input tap with the new input format from `audioEngine.inputNode.outputFormat(forBus: 0)` and restart the engine. Log the route change.
  - [ ] 3.3 Remove the observer in `stopRecording()`.

- [ ] Task 4: Track pause intervals for Mac timeline gaps (AC: #5)
  - [ ] 4.1 Add `pauseIntervals: [[TimeInterval]]` property to `Session` model — array of `[pauseStart, pauseEnd]` pairs, where times are seconds from recording start. This is a lightweight Codable property stored via SwiftData's `Transformable` or as JSON-encoded `Data`. Alternatively, store as a JSON string in a `pauseIntervalsJSON: String?` property for simplicity with SwiftData.
  - [ ] 4.2 When `pauseRecording()` is called, record the pause start time as `elapsedTime` (seconds from recording start).
  - [ ] 4.3 When `resumeRecording()` is called, record the pause end time as current `elapsedTime` and append `[pauseStart, pauseEnd]` to the session's pause intervals. Save context.
  - [ ] 4.4 Add a `PauseInterval` struct in `DictlyModels`: `struct PauseInterval: Codable { let start: TimeInterval; let end: TimeInterval }`. Add `pauseIntervals: [PauseInterval]` as a computed property on `Session` that encodes/decodes from `pauseIntervalsJSON`.
  - [ ] 4.5 The Mac waveform timeline (Epic 4) will read these intervals to render gaps. No Mac changes in this story.

- [ ] Task 5: Add `wasInterruptedBySystem` public state property (AC: #3, #4)
  - [ ] 5.1 Add `private(set) var wasInterruptedBySystem = false` to `SessionRecorder` public state section. This signals the UI (Story 2.3) to show a prominent "Resume Recording" banner instead of the normal paused state.
  - [ ] 5.2 Set `wasInterruptedBySystem = true` only in the interruption handler `.began` case.
  - [ ] 5.3 Clear `wasInterruptedBySystem = false` in `resumeRecording()`, `stopRecording()`, and manual `pauseRecording()`.

- [ ] Task 6: Update `stopRecording()` for pause-aware duration (AC: #1, #2, #5)
  - [ ] 6.1 If recording is paused when `stopRecording()` is called, finalize the last pause interval before stopping (append the open pause interval with current time as end).
  - [ ] 6.2 The authoritative duration from `AVAudioFile` (already implemented) excludes paused time because no audio was written during pauses — this is correct. No change needed to the file-duration calculation.
  - [ ] 6.3 Reset `totalPauseDuration`, `pauseStartDate`, `wasInterruptedBySystem` in `stopRecording()`.

- [ ] Task 7: Update `project.yml` if needed and verify build (AC: all)
  - [ ] 7.1 No new source folders needed — all changes are in existing `DictlyiOS/Recording/SessionRecorder.swift` and `DictlyKit/Sources/DictlyModels/`.
  - [ ] 7.2 If `Session` model changes require a SwiftData schema migration, verify that SwiftData lightweight migration handles the new `pauseIntervalsJSON` property (it should — it's an additive optional property).
  - [ ] 7.3 Run `xcodegen generate` in `DictlyiOS/` if project.yml changes were needed.
  - [ ] 7.4 Verify build: `xcodebuild -project DictlyiOS/DictlyiOS.xcodeproj -scheme DictlyiOS -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`

- [ ] Task 8: Unit tests (AC: #1, #2, #3, #5)
  - [ ] 8.1 Add tests in `DictlyiOS/Tests/RecordingTests/SessionRecorderTests.swift` (existing test file from Story 2.1)
  - [ ] 8.2 Test pause state: after `pauseRecording()`, verify `isPaused == true`, `isRecording == true`, `currentAudioLevel == 0`
  - [ ] 8.3 Test resume state: after `resumeRecording()`, verify `isPaused == false`, `isRecording == true`
  - [ ] 8.4 Test `wasInterruptedBySystem` state transitions: default false, true after system interruption simulation, false after resume
  - [ ] 8.5 Test `PauseInterval` Codable round-trip: encode and decode, verify start/end values preserved
  - [ ] 8.6 Test `pauseIntervalsJSON` on `Session`: set intervals, save, fetch, verify decoded intervals match
  - [ ] 8.7 Verify all existing tests still pass (139 DictlyKit + 5 DictlyiOS tests)
  - [ ] 8.8 Verify `xcodebuild` succeeds for the iOS target

## Dev Notes

### Architecture: Extending SessionRecorder with Pause/Resume

`SessionRecorder` (created in Story 2.1) is an `@Observable @MainActor` class injected via `.environment()`. This story adds pause/resume methods and interruption handling to the same service. No new service classes needed. [Source: architecture.md#State-Management, 2-1-audio-recording-engine-with-background-persistence.md]

The key architectural insight: **pausing does NOT deactivate the AVAudioSession**. The audio session must remain active with category `.record` to keep the background audio mode alive. Only the AVAudioEngine capture is paused. Deactivating the session would risk iOS suspending the app.

### AVAudioEngine Pause Strategy

Use `audioEngine.pause()` + `inputNode.removeTap(onBus: 0)` for pause, NOT `audioEngine.stop()`. The difference:

- `engine.pause()` — suspends processing but keeps the engine in a startable state. Cheaper to resume.
- `engine.stop()` — tears down the engine graph. Requires re-setup. Used only in `stopRecording()`.

On resume, reinstall the input tap and call `engine.start()` (which restarts a paused engine). The tap must be reinstalled because removing it is necessary to stop audio buffer callbacks during pause.

```swift
func pauseRecording() {
    guard isRecording, !isPaused else { return }
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine?.pause()
    isPaused = true
    pauseStartDate = Date()
    currentAudioLevel = 0
    wasInterruptedBySystem = false
    // Record pause start in elapsed time for timeline gap
    logger.info("Recording paused at \(self.elapsedTime, privacy: .public)s")
}

func resumeRecording() {
    guard isRecording, isPaused, let engine = audioEngine, let file = outputFile else { return }
    // Accumulate pause duration
    if let pauseStart = pauseStartDate {
        totalPauseDuration += Date().timeIntervalSince(pauseStart)
    }
    // Reinstall tap and restart
    let inputNode = engine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)
    let bufferSize: AVAudioFrameCount = 4096
    inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
        // Same tap closure as startRecording — write buffer + calculate level
    }
    try? engine.start()
    isPaused = false
    pauseStartDate = nil
    wasInterruptedBySystem = false
    logger.info("Recording resumed at \(self.elapsedTime, privacy: .public)s")
}
```

### AVAudioSession Interruption Handling

Register for `AVAudioSession.interruptionNotification` — this fires when iOS interrupts audio for phone calls, alarms, Siri, etc.

```swift
interruptionObserver = NotificationCenter.default.addObserver(
    forName: AVAudioSession.interruptionNotification,
    object: AVAudioSession.sharedInstance(),
    queue: nil
) { [weak self] notification in
    Task { @MainActor [weak self] in
        self?.handleInterruption(notification)
    }
}
```

**Critical behavior per UX spec:** On `.began`, auto-pause recording. On `.ended`, do NOT auto-resume — show a prominent "Resume Recording" button instead. The `wasInterruptedBySystem` flag drives this UI distinction. [Source: ux-design-specification.md#Journey-4, epics.md#Story-2.2]

The interruption handler:
```swift
private func handleInterruption(_ notification: Notification) {
    guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
    
    switch type {
    case .began:
        guard isRecording, !isPaused else { return }
        pauseRecording()
        wasInterruptedBySystem = true
        logger.info("Recording interrupted by system (phone call/alarm)")
    case .ended:
        // Check if system says we should resume — but per UX spec, always require user action
        logger.info("System interruption ended. Awaiting user resume.")
    @unknown default:
        break
    }
}
```

### AVAudioEngine Configuration Change

When Bluetooth/external mic disconnects during recording, iOS posts `AVAudioEngineConfigurationChange`. Handle by re-reading the input format and reinstalling the tap:

```swift
configChangeObserver = NotificationCenter.default.addObserver(
    forName: .AVAudioEngineConfigurationChange,
    object: audioEngine,
    queue: nil
) { [weak self] _ in
    Task { @MainActor [weak self] in
        self?.handleConfigChange()
    }
}
```

If recording is active (not paused), remove the old tap, read the new `inputNode.outputFormat(forBus: 0)`, reinstall the tap, and restart the engine. Log the new audio route.

### Elapsed Time Accounting with Pauses

The timer task (line 161-167 in current code) already has `guard !self.isPaused else { continue }` so it skips updates during pause. On resume, the wall-clock-anchored approach needs adjustment:

```swift
self.elapsedTime = Date().timeIntervalSince(recordingStartDate!) - totalPauseDuration
```

Add `private var totalPauseDuration: TimeInterval = 0` and accumulate each pause's duration on resume. Reset to 0 in `startRecording()` and `stopRecording()`.

### Pause Interval Persistence for Mac Timeline

The Mac timeline (Epic 4, Story 4.2) needs to know where pauses occurred to render gaps. Store pause intervals on the `Session` model as a JSON string:

```swift
// In Session.swift — add property:
public var pauseIntervalsJSON: String?

// In DictlyModels — add struct:
public struct PauseInterval: Codable, Equatable {
    public let start: TimeInterval  // seconds from recording start
    public let end: TimeInterval    // seconds from recording start
    
    public init(start: TimeInterval, end: TimeInterval) {
        self.start = start
        self.end = end
    }
}
```

Add a computed property on `Session` for convenient access:
```swift
extension Session {
    public var pauseIntervals: [PauseInterval] {
        get {
            guard let json = pauseIntervalsJSON, let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([PauseInterval].self, from: data)) ?? []
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { pauseIntervalsJSON = nil; return }
            pauseIntervalsJSON = String(data: data, encoding: .utf8)
        }
    }
}
```

**Why JSON string instead of `@Attribute(.transformable)`:** SwiftData's transformable attributes require registering a ValueTransformer, which is verbose and error-prone for simple arrays. A JSON string is lightweight, debuggable, and compatible with the `.dictly` transfer bundle serialization. [Source: architecture.md#Data-Patterns]

**SwiftData migration:** Adding an optional `pauseIntervalsJSON: String?` property is an additive change — SwiftData lightweight migration handles it automatically. No manual migration needed.

### What NOT to Build in This Story

- Recording screen UI — Story 2.3 builds `RecordingScreen.swift` which consumes `isPaused`, `wasInterruptedBySystem`
- Pause/resume buttons — Story 2.3 creates the UI
- LiveWaveform paused state (gray bars) — Story 2.3 reads `isPaused`
- RecordingStatusBar paused state (yellow dot, "PAUSED") — Story 2.3 reads `isPaused`
- Any tagging functionality — Stories 2.4-2.6
- Mac waveform gap rendering — Story 4.2 reads `pauseIntervals`

This story builds **pause/resume engine logic + interruption handling + pause interval persistence only**. The UI will be built in Story 2.3.

### Swift 6 Strict Concurrency Notes

- The interruption notification handler runs on an arbitrary queue. Dispatch to `@MainActor` via `Task { @MainActor in }` before mutating any `SessionRecorder` state.
- `NotificationCenter.addObserver(forName:object:queue:)` returns `any NSObjectProtocol` — store and remove in `stopRecording()`.
- The `isStopping` flag is already `nonisolated(unsafe)` — the same pattern applies for the tap closure which checks `self.isStopping`.
- The config change observer also dispatches to MainActor.

### Logging

Use existing `os.Logger` with subsystem `"com.dictly.ios"` and category `"recording"`:
- `.info` — "Recording paused at \(elapsedTime)s", "Recording resumed at \(elapsedTime)s"
- `.info` — "Recording interrupted by system (phone call/alarm)"
- `.info` — "System interruption ended. Awaiting user resume."
- `.info` — "Audio route changed: \(newPortName)" (on config change)
- `.error` — "Failed to restart engine after config change: \(error)"
- `.error` — "Failed to resume recording: \(error)"

### File Placement

```
DictlyiOS/Recording/
└── SessionRecorder.swift           # MODIFY — add pause/resume, interruption handling

DictlyKit/Sources/DictlyModels/
├── Session.swift                   # MODIFY — add pauseIntervalsJSON property
└── PauseInterval.swift             # NEW — PauseInterval struct + Session extension
```

### Previous Story Intelligence (from Story 2.1)

Key patterns and learnings to follow:
- **Timer drift fix:** Story 2.1 review fixed timer drift by anchoring to `Date()` instead of accumulating +0.1. This story extends that with `totalPauseDuration` subtraction — follow the same wall-clock-anchored pattern. [Source: 2-1 Review Finding]
- **Thread safety:** Story 2.1 review added `isStopping` flag for tap closure thread safety. The same pattern applies — the tap closure must check `isStopping` before writing. [Source: 2-1 Review Finding]
- **Audio session deactivation:** Only call `setActive(false)` in `stopRecording()` and error paths, never during pause. Story 2.1 review fixed missing deactivation on error paths. [Source: 2-1 Review Finding]
- **Write failure counter:** Story 2.1 added `consecutiveWriteFailures` — reset this counter on `resumeRecording()` to prevent stale failure counts from a previous recording segment.
- **File duration as authoritative:** `stopRecording()` reads duration from `AVAudioFile.length / sampleRate`. This is correct for pause/resume because no audio is written during pause — file duration reflects only active recording time.
- **Filename-only storage:** `session.audioFilePath` stores filename only, not absolute path. No change needed.
- **DictlyError.RecordingError.interrupted:** Already exists — use this if the engine fails to restart after interruption.
- **Test count:** 139 DictlyKit + 5 DictlyiOS tests currently passing. New tests must not break existing ones.
- **Conventional commits:** `feat(recording): implement pause/resume and interruption handling (story 2.2)`

### Git Intelligence

Recent commits follow `feat(recording):` / `fix(recording):` prefix for Epic 2.

Files that overlap with this story:
- `SessionRecorder.swift` — last modified in Story 2.1 review fixes. Primary file for this story.
- `Session.swift` — last modified in Story 1.1 (model creation). Adding `pauseIntervalsJSON` property.
- `DictlyError.swift` — already has `.interrupted` case from Story 1.1. No new error cases needed.

### Project Structure Notes

- All recording logic stays in `DictlyiOS/Recording/SessionRecorder.swift`
- `PauseInterval` struct goes in `DictlyKit/Sources/DictlyModels/` (shared — Mac needs it for timeline rendering)
- No new dependencies or frameworks needed — `AVFoundation` and `NotificationCenter` already imported
- No `project.yml` changes expected unless new files require source path updates
- Run `swift package clean` if incremental build shows stale module cache (Story 2.1 debug finding)

### Existing Infrastructure to Reuse

- **`SessionRecorder`** — `DictlyiOS/Recording/SessionRecorder.swift` — extend with pause/resume/interruption methods
- **`Session.audioFilePath`** — already set by `startRecording()`, single file persists across pauses
- **`DictlyError.RecordingError.interrupted`** — use if engine restart fails after interruption
- **`AudioFileManager.audioStorageDirectory()`** — no changes needed, same audio file location
- **`AVAudioSession` configuration** — already `.record` category with `.allowBluetooth` from `startRecording()`
- **Timer task** — already has `!isPaused` guard, just needs `totalPauseDuration` offset
- **`consecutiveWriteFailures`** — reset on resume

### References

- [Source: epics.md#Story-2.2] — AC, user story, technical requirements
- [Source: prd.md#FR3] — Pause/resume recording without losing data or creating a new file
- [Source: prd.md#FR6] — System continues recording through phone calls and system interruptions
- [Source: prd.md#NFR9] — Recording durability < 5 second loss on crash (applies to pause/resume too)
- [Source: prd.md#NFR10] — Recording endurance 4+ hours with screen locked
- [Source: architecture.md#Core-Architectural-Decisions] — SwiftData, @Observable, DictlyError patterns
- [Source: architecture.md#State-Management] — @Observable for service classes
- [Source: architecture.md#Recording-Files] — SessionRecorder.swift, RecordingViewModel.swift
- [Source: architecture.md#Enforcement-Guidelines] — @Observable, DictlyError, os.Logger, no AnyView
- [Source: architecture.md#Data-Patterns] — Timestamps as TimeInterval from session start
- [Source: architecture.md#Error-Handling-Patterns] — Recording errors: persistent top banner
- [Source: ux-design-specification.md#Journey-4] — Interruption recovery flow: phone call auto-pauses, user taps resume
- [Source: ux-design-specification.md#LiveWaveform] — Paused state: bars freeze, color shifts to muted gray
- [Source: ux-design-specification.md#Flow-Optimization] — Only phone calls require user action to resume
- [Source: 2-1-audio-recording-engine-with-background-persistence.md] — Previous story patterns, review findings, file list
- [Source: DictlyiOS/Recording/SessionRecorder.swift] — Current implementation to extend
- [Source: DictlyKit/Sources/DictlyModels/Session.swift] — Session model to extend
- [Source: DictlyKit/Sources/DictlyModels/DictlyError.swift] — Existing .interrupted error case

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
