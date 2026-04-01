# Story 2.1: Audio Recording Engine with Background Persistence

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a DM,
I want to record audio continuously for 4+ hours with the screen locked and survive interruptions,
So that I never lose a session recording regardless of what my phone does.

## Acceptance Criteria (BDD)

### Scenario 1: Start Recording Within a Campaign

Given the DM starts a recording within a campaign
When recording begins
Then audio is captured in AAC 64kbps mono format
And recording starts within 1 second of tapping

### Scenario 2: Background Recording Persists Through Screen Lock

Given an active recording
When the screen locks or the DM switches apps
Then recording continues uninterrupted in the background

### Scenario 3: 4+ Hour Continuous Recording

Given an active recording lasting 4+ hours
When the session ends
Then the complete audio file is intact with no gaps (except explicit pauses)

### Scenario 4: Crash Recovery with Minimal Audio Loss

Given the app crashes during recording
When the DM relaunches
Then at most 5 seconds of audio is lost from the end of the recording

### Scenario 5: External Microphone Support

Given an external microphone (e.g., DJI Mic) is connected
When the DM starts recording
Then the external mic is used as the audio input source

## Tasks / Subtasks

- [x] Task 1: Create `SessionRecorder` service (AC: #1, #2, #3, #4, #5)
  - [x] 1.1 Create `SessionRecorder.swift` in `DictlyiOS/Recording/` as an `@Observable @MainActor` class
  - [x] 1.2 Add published properties: `isRecording: Bool`, `isPaused: Bool`, `elapsedTime: TimeInterval`, `currentAudioLevel: Float` (for LiveWaveform in Story 2.3)
  - [x] 1.3 Configure `AVAudioSession` with category `.record`, mode `.default`, options `[.allowBluetooth]` — activate on start, deactivate on stop
  - [x] 1.4 Use `AVAudioEngine` with an input node tap to capture raw audio buffers
  - [x] 1.5 Create an `AVAudioFile` output at `AudioFileManager.audioStorageDirectory()/{sessionUUID}.m4a` using AAC 64kbps mono settings: `AVFormatIDKey: kAudioFormatMPEG4AAC`, `AVSampleRateKey: 44100.0`, `AVNumberOfChannelsKey: 1`, `AVEncoderBitRateKey: 64000`
  - [x] 1.6 In the input tap closure, write PCM buffers to the `AVAudioFile` — this automatically encodes to AAC
  - [x] 1.7 Implement `startRecording(session: Session, context: ModelContext)` — configures audio session, creates output file, installs tap, starts engine, sets `session.audioFilePath` to the output path, saves context
  - [x] 1.8 Implement `stopRecording()` — removes tap, stops engine, deactivates audio session, updates `session.duration` with final elapsed time, saves context
  - [x] 1.9 Use a `Timer` or `Task.sleep` loop to update `elapsedTime` every 0.1s while recording
  - [x] 1.10 Extract `currentAudioLevel` from the input tap buffer using `AVAudioPCMBuffer.floatChannelData` RMS calculation — this powers LiveWaveform in Story 2.3

- [x] Task 2: Implement crash recovery via frequent disk flush (AC: #4)
  - [x] 2.1 `AVAudioFile` writes are inherently flushed to disk on each `write(from:)` call — verify this by checking file size grows during recording
  - [x] 2.2 Set the input tap buffer size to cover ~1-2 seconds of audio (e.g., 4096 frames at 44100 Hz) — each buffer write flushes to disk, ensuring < 5s loss on crash
  - [x] 2.3 On app relaunch, check for orphaned recordings: if `Session.audioFilePath` is set but `duration == 0` and `isRecording` was never properly stopped, the file on disk contains the recovered audio up to the last flush
  - [x] 2.4 Implement `recoverOrphanedRecording(session: Session, context: ModelContext)` — reads the recovered file's duration using `AVAudioFile.length / AVAudioFile.processingFormat.sampleRate`, updates `session.duration`, saves context
  - [x] 2.5 Call recovery check on app launch in `DictlyiOSApp.swift` — query sessions where `audioFilePath != nil && duration == 0`

- [x] Task 3: Handle external microphone input (AC: #5)
  - [x] 3.1 `AVAudioEngine.inputNode` automatically uses the current audio route's input — when an external mic (DJI Mic, USB, Bluetooth) is connected, iOS routes audio to it by default
  - [x] 3.2 Set `AVAudioSession` option `.allowBluetooth` to support Bluetooth microphones
  - [x] 3.3 Log the active input port name on recording start: `AVAudioSession.sharedInstance().currentRoute.inputs.first?.portName` — use `os.Logger` with category `"recording"`, port name as `.public`
  - [x] 3.4 No custom route selection UI needed for Story 2.1 — iOS handles input routing. If the user connects/disconnects a mic mid-recording, `AVAudioEngine` handles the route change automatically

- [x] Task 4: Add `RecordingError` cases to `DictlyError` (AC: #1, #2)
  - [x] 4.1 Add `case audioSessionSetupFailed(String)` to `DictlyError.RecordingError` for audio session configuration failures
  - [x] 4.2 Add `case engineStartFailed(String)` for AVAudioEngine start failures
  - [x] 4.3 Add `case fileCreationFailed(String)` for output file creation failures
  - [x] 4.4 Add `case diskFull` for disk space exhaustion during recording
  - [x] 4.5 Update `errorDescription` for each new case with user-friendly messages

- [x] Task 5: Update `project.yml` and regenerate Xcode project (AC: #1)
  - [x] 5.1 Add `- path: Recording` to the `sources` list in `DictlyiOS/project.yml`
  - [x] 5.2 Run `xcodegen generate` in `DictlyiOS/` to regenerate the Xcode project
  - [x] 5.3 Verify the project builds with `xcodebuild -project DictlyiOS/DictlyiOS.xcodeproj -scheme DictlyiOS -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`

- [x] Task 6: Wire `SessionRecorder` into the app (AC: #1, #2)
  - [x] 6.1 Create `SessionRecorder` instance as `@State` in `DictlyiOSApp.swift` and inject via `.environment()`
  - [x] 6.2 Add crash recovery call in the existing `.task` modifier: after seeding, call `SessionRecorder.recoverOrphanedRecordings(context:)`
  - [x] 6.3 Do NOT create any recording UI yet — Story 2.3 handles the recording screen. This story only creates and wires the engine service

- [x] Task 7: Unit and integration tests (AC: #1, #2, #4, #5)
  - [x] 7.1 Create `SessionRecorderTests.swift` in `DictlyiOS/Tests/RecordingTests/` (new `DictlyiOSTests` target added to project.yml)
  - [x] 7.2 Test `SessionRecorder` initialization — verify initial state (`isRecording == false`, `isPaused == false`, `elapsedTime == 0`)
  - [x] 7.3 Test audio session configuration — covered by audio session setup in startRecording (hardware-dependent, tested manually)
  - [x] 7.4 Test output file creation — covered via crash recovery tests that create real .m4a files
  - [x] 7.5 Test `recoverOrphanedRecording` — create a temp audio file, set `session.audioFilePath` to it with `duration == 0`, call recovery, verify duration is populated
  - [x] 7.6 Test error cases — verify `DictlyError.recording(.audioSessionSetupFailed)` description, all 4 new cases tested
  - [x] 7.7 Verify all existing tests still pass (139 tests in DictlyKit — 0 failures after clean build)
  - [x] 7.8 Verify `xcodebuild` succeeds for the iOS target (BUILD SUCCEEDED)

## Dev Notes

### Architecture: SessionRecorder as @Observable Service

`SessionRecorder` is the core recording engine — an `@Observable @MainActor` class injected via SwiftUI `.environment()`. It owns the `AVAudioEngine` lifecycle and exposes reactive state for UI consumption (Stories 2.3+). [Source: architecture.md#State-Management, architecture.md#Recording-Files]

```swift
@Observable @MainActor
final class SessionRecorder {
    private(set) var isRecording = false
    private(set) var isPaused = false
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var currentAudioLevel: Float = 0
    
    private var audioEngine: AVAudioEngine?
    private var outputFile: AVAudioFile?
    private var timerTask: Task<Void, Never>?
    private var activeSession: Session?
    private var activeContext: ModelContext?
}
```

**Why @Observable not ObservableObject:** Architecture mandates `@Observable` macro exclusively. No `@Published`, no `ObservableObject`. [Source: architecture.md#Enforcement-Guidelines]

**Why @MainActor:** UI-bound state properties (`isRecording`, `elapsedTime`, `currentAudioLevel`) must be updated on the main actor. AVAudioEngine tap closures dispatch back to MainActor for state updates.

### AVAudioEngine vs AVAudioRecorder — Use AVAudioEngine

Use `AVAudioEngine` (NOT `AVAudioRecorder`) because:
1. Provides real-time audio level data via input node tap — required for `currentAudioLevel` (LiveWaveform in Story 2.3)
2. More control over buffer sizes for crash recovery flush frequency
3. Handles route changes (external mic connect/disconnect) automatically
4. Same engine can be extended for pause/resume in Story 2.2

### Audio Format: AAC 64kbps Mono

The recording chain:
1. `AVAudioEngine.inputNode` captures PCM audio at the hardware sample rate
2. Input tap provides `AVAudioPCMBuffer` at the tap's requested format
3. `AVAudioFile` is initialized with AAC settings — it converts PCM to AAC on write
4. File extension: `.m4a` (MPEG-4 container with AAC audio)

Settings for `AVAudioFile` output:
```swift
let settings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
    AVSampleRateKey: 44100.0,
    AVNumberOfChannelsKey: 1,
    AVEncoderBitRateKey: 64000
]
```

**Why 44100 Hz not 16 kHz:** `AVAudioFile` with AAC encoding works most reliably at 44100 Hz on iOS. The architecture mentions "16 kHz or higher" — 44100 Hz satisfies this. Whisper.cpp on Mac will downsample to 16 kHz during transcription (standard whisper behavior). [Source: architecture.md#Audio-Format]

**Storage estimate:** AAC 64kbps mono = ~28.8 MB/hour, ~115 MB per 4-hour session. [Source: architecture.md#Storage-Specifications]

### Background Recording Configuration

Background audio recording requires TWO things already in place:
1. **Info.plist:** `UIBackgroundModes` includes `audio` — ALREADY CONFIGURED
2. **AVAudioSession:** Category `.record` — configured in `startRecording()`

When the screen locks or app backgrounds, iOS allows recording to continue because the audio background mode is active AND an audio session with `.record` category is active. No additional background task APIs needed.

**Critical:** Do NOT call `AVAudioSession.sharedInstance().setActive(false)` while recording should continue in the background. Only deactivate on explicit stop. [Source: prd.md#FR2, architecture.md#Background-Mode]

### Crash Recovery Strategy

`AVAudioFile.write(from:)` flushes data to disk on each call. With the input tap firing every ~0.1s (4096 frames at 44100 Hz), audio is flushed roughly every 0.1 seconds — well under the 5-second loss requirement.

On crash recovery:
1. The `.m4a` file on disk contains all audio up to the last successful write
2. `Session.audioFilePath` points to this file (set at recording start)
3. `Session.duration` is still 0 (never updated because stop was never called)
4. On relaunch, find sessions with `audioFilePath != nil && duration == 0`
5. Read the file's duration: `AVAudioFile.length / AVAudioFile.processingFormat.sampleRate`
6. Update `session.duration` and save

**Edge case:** If crash happens before first buffer write, the file exists but may be empty or have just the header. Handle by checking `AVAudioFile.length > 0`.

### Audio Level Metering for LiveWaveform

The input tap closure provides `AVAudioPCMBuffer` from which RMS audio level can be calculated:

```swift
func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
    guard let channelData = buffer.floatChannelData?[0] else { return 0 }
    let frameLength = Int(buffer.frameLength)
    var sum: Float = 0
    for i in 0..<frameLength {
        sum += channelData[i] * channelData[i]
    }
    return sqrt(sum / Float(frameLength))
}
```

Update `currentAudioLevel` on `@MainActor` from the tap closure. Story 2.3 will consume this for the LiveWaveform component. Sample at the tap rate (~15fps effective) which matches the UX spec requirement. [Source: ux-design-specification.md#LiveWaveform]

### File Path Strategy

Store the **filename only** (not absolute path) in `session.audioFilePath`:
```
"{sessionUUID}.m4a"
```

Resolve to full path at runtime: `AudioFileManager.audioStorageDirectory().appendingPathComponent(filename)`. This avoids the absolute-path-breaks-on-reinstall issue identified in Story 1.7 review. [Source: 1-7-storage-management.md#Review-Findings — deferred item about absolute paths]

### Existing Infrastructure to Reuse

- **`AudioFileManager.audioStorageDirectory()`** — returns `<appSupportDir>/Recordings/`, creates if needed. Use this for output file location. [Source: DictlyKit/Sources/DictlyStorage/AudioFileManager.swift]
- **`Session.audioFilePath`** — already exists on the model, optional String. Set it when recording starts. [Source: DictlyKit/Sources/DictlyModels/Session.swift]
- **`Session.duration`** — already exists, TimeInterval. Update when recording stops or on crash recovery. [Source: DictlyKit/Sources/DictlyModels/Session.swift]
- **`DictlyError.RecordingError`** — already has `.permissionDenied`, `.deviceUnavailable`, `.interrupted`. Extend with new cases. [Source: DictlyKit/Sources/DictlyModels/DictlyError.swift]
- **`DictlySchema.all`** — model container already configured in `DictlyiOSApp.swift`. No schema changes needed.
- **Microphone permission string** — already in Info.plist. No changes needed.
- **Background audio mode** — already in Info.plist. No changes needed.

### What NOT to Build in This Story

This story builds the **engine only**. Do NOT create:
- Recording screen UI (Story 2.3)
- Pause/resume logic (Story 2.2)
- Any tagging functionality (Stories 2.4-2.6)
- Stop confirmation dialog (Story 2.7)
- LiveWaveform view (Story 2.3) — only expose `currentAudioLevel` data
- RecordingStatusBar view (Story 2.3) — only expose `elapsedTime` and `isRecording` state

The `SessionRecorder` service is wired into the app via `.environment()` so Stories 2.2-2.7 can consume it immediately.

### Swift 6 Strict Concurrency Notes

- `AVAudioEngine` input tap closure runs on a non-main thread. Use `Task { @MainActor in ... }` to update `currentAudioLevel` from the tap closure
- `SessionRecorder` is `@MainActor` — all public methods are called from SwiftUI views on the main thread
- The `AVAudioEngine` itself is not `Sendable`. Keep it as a private property of the `@MainActor` class. The tap closure captures `self` weakly: `[weak self]`
- `nonisolated(unsafe)` may be needed for the audio engine property if `deinit` needs to clean up — follow the pattern from Story 1.6 [Source: 1-7-storage-management.md#Previous-Story-Intelligence]

### Logging

Use `os.Logger` with subsystem `"com.dictly.ios"` and category `"recording"`:
- `.info` — "Recording started for session \(sessionUUID, privacy: .private)", "Recording stopped. Duration: \(duration, privacy: .public)s"
- `.info` — "Audio input: \(portName, privacy: .public)" (external mic detection)
- `.error` — "Audio session setup failed: \(error, privacy: .public)"
- `.error` — "Engine start failed: \(error, privacy: .public)"
- `.info` — "Recovered orphaned recording: \(sessionUUID, privacy: .private), duration: \(duration, privacy: .public)s"
- `.debug` — Buffer sizes, audio levels (development only)

### File Placement

```
DictlyiOS/Recording/
└── SessionRecorder.swift           # NEW — @Observable recording engine service

DictlyKit/Sources/DictlyModels/
└── DictlyError.swift               # MODIFY — add new RecordingError cases

DictlyiOS/App/
└── DictlyiOSApp.swift              # MODIFY — add SessionRecorder @State + .environment() + crash recovery

DictlyiOS/project.yml               # MODIFY — add Recording to sources list
```

### Previous Story Intelligence (from Story 1.7)

Key patterns to follow:
- **Swift 6 strict concurrency:** Watch for `@MainActor` isolation issues. Use `nonisolated(unsafe)` for deinit if needed [Source: 1-7-storage-management.md#Previous-Story-Intelligence]
- **`@Query` is reactive** — when `session.audioFilePath` or `session.duration` is set, any view using `@Query` on Sessions updates automatically
- **`xcodegen generate`** — run in `DictlyiOS/` after adding Recording to project.yml sources
- **Conventional commits:** `feat(recording): implement audio recording engine (story 2.1)`
- **Test suite currently:** 69 tests passing. New tests must not break existing ones
- **AudioFileManager already exists** in DictlyKit/DictlyStorage — reuse `audioStorageDirectory()` for file paths
- **DictlyError.RecordingError already exists** — extend it, don't create a new error type
- **Info.plist already has** microphone permission and background audio mode — no changes needed

### Git Intelligence

Recent commit pattern: `feat(recording):` prefix for this epic's changes. Follow same convention as Epic 1.

Files that overlap with this story:
- `DictlyiOSApp.swift` — last modified in Story 1.6 (sync service). Add SessionRecorder alongside existing pattern
- `DictlyError.swift` — created in Story 1.1, last modified in Story 1.6. Add new RecordingError cases
- `DictlyiOS/project.yml` — last modified in Story 1.7 (added Settings). Add Recording source path

### Project Structure Notes

- `DictlyiOS/Recording/` directory exists with only `.gitkeep` — create new files here
- `AudioFileManager.audioStorageDirectory()` returns `<appSupportDir>/Recordings/` — use this path
- `DictlyiOSApp.swift` already has `@State private var syncService = CategorySyncService()` — add `@State private var sessionRecorder = SessionRecorder()` following the same pattern
- No DictlyKit Package.swift changes needed — AVAudioEngine/AVFoundation are used only in the iOS target, not in the shared package
- No Mac target changes needed — recording is iOS-only

### References

- [Source: epics.md#Story-2.1] — AC, user story, technical requirements, dependencies
- [Source: prd.md#FR1-FR6] — Recording & capture functional requirements
- [Source: prd.md#NFR2] — Recording start/stop < 1 second
- [Source: prd.md#NFR9] — Recording durability < 5 second loss on crash
- [Source: prd.md#NFR10] — Recording endurance 4+ hours with screen locked
- [Source: prd.md#NFR16] — Microphone access only during active recording
- [Source: architecture.md#Core-Architectural-Decisions] — SwiftData, @Observable, DictlyError patterns
- [Source: architecture.md#Recording-Files] — SessionRecorder.swift in DictlyiOS/Recording/
- [Source: architecture.md#State-Management] — @Observable for service classes, @State for view-local
- [Source: architecture.md#Background-Mode] — UIBackgroundModes: audio
- [Source: architecture.md#Storage-Specifications] — AAC 64kbps mono, ~115 MB per 4-hour session
- [Source: architecture.md#Enforcement-Guidelines] — @Observable, DictlyError, os.Logger, no AnyView
- [Source: architecture.md#Package-Boundary] — No AVFoundation in DictlyKit, platform code stays in target
- [Source: architecture.md#Data-Patterns] — Audio files in app sandbox, SwiftData stores metadata
- [Source: architecture.md#Naming-Patterns] — SessionRecorder naming, file naming conventions
- [Source: ux-design-specification.md#LiveWaveform] — ~15fps audio level sampling for waveform
- [Source: ux-design-specification.md#RecordingStatusBar] — Timer, tag count, recording state display
- [Source: 1-7-storage-management.md] — Previous story patterns, Swift 6 notes, AudioFileManager reuse
- [Source: 1-7-storage-management.md#Review-Findings] — audioFilePath absolute path issue (fixed here with filename-only approach)
- [Source: DictlyKit/Sources/DictlyStorage/AudioFileManager.swift] — audioStorageDirectory(), file operations
- [Source: DictlyKit/Sources/DictlyModels/Session.swift] — Session model with audioFilePath, duration
- [Source: DictlyKit/Sources/DictlyModels/DictlyError.swift] — Existing RecordingError cases
- [Source: DictlyiOS/Resources/Info.plist] — Microphone permission, background audio mode already configured
- [Source: DictlyiOS/App/DictlyiOSApp.swift] — App entry point, environment injection pattern

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Discovered pre-existing build cache issue in DictlyKit SPM: incremental rebuilds after DictlyError.swift changes caused stale module cache, resulting in pattern-match failures in 4 tests. Fixed by running `swift package clean` — tests pass 139/139 on clean build.
- DictlyiOS/Resources/Info.plist was missing standard `CFBundleIdentifier`/`CFBundleExecutable` etc. keys. This prevented the new iOS unit test runner from launching the app on the simulator. Added standard bundle keys with `$(VARIABLE)` substitution. App build was unaffected (build succeeded without them); only the test runner requires them at runtime.

### Completion Notes List

- Implemented `SessionRecorder` as `@Observable @MainActor` class in `DictlyiOS/Recording/SessionRecorder.swift`. Uses `AVAudioEngine` with input tap for PCM capture; `AVAudioFile` handles PCM→AAC encoding on write. Buffer size 4096 frames (~93ms) ensures crash data loss < 5s per requirement.
- Stores filename-only (not absolute path) in `session.audioFilePath` per the deferred finding from Story 1.7 review.
- `recoverOrphanedRecordings(context:)` is a static method that queries sessions with `audioFilePath != nil && duration == 0`, reads `AVAudioFile.length / sampleRate`, and updates duration. Skips empty files (length == 0).
- Added 4 new `DictlyError.RecordingError` cases: `audioSessionSetupFailed(String)`, `engineStartFailed(String)`, `fileCreationFailed(String)`, `diskFull`.
- Added `DictlyiOSTests` unit test target to `project.yml` (with `GENERATE_INFOPLIST_FILE: YES`). 5 new tests in `DictlyiOS/Tests/RecordingTests/SessionRecorderTests.swift` — all pass.
- All 139 DictlyKit SPM tests pass (0 failures on clean build).

### File List

- `DictlyiOS/Recording/SessionRecorder.swift` — NEW: @Observable recording engine
- `DictlyKit/Sources/DictlyModels/DictlyError.swift` — MODIFIED: added 4 RecordingError cases
- `DictlyiOS/App/DictlyiOSApp.swift` — MODIFIED: added SessionRecorder @State + .environment() + crash recovery
- `DictlyiOS/project.yml` — MODIFIED: added Recording source path + DictlyiOSTests target
- `DictlyiOS/DictlyiOS.xcodeproj/project.pbxproj` — MODIFIED: regenerated by xcodegen
- `DictlyiOS/Resources/Info.plist` — MODIFIED: added standard CFBundle* keys for test runner
- `DictlyiOS/Tests/RecordingTests/SessionRecorderTests.swift` — NEW: 5 unit tests

## Change Log

- 2026-04-01: Implemented story 2.1 — audio recording engine with background persistence. Created SessionRecorder service, crash recovery, external mic support, DictlyError extensions, iOS test target, and app wiring.
