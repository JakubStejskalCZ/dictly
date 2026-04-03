# Story 5.3: Per-Tag & Batch Transcription

Status: ready-for-dev

## Story

As a DM,
I want to transcribe individual tags or all tags at once,
So that I can get text versions of my tagged moments efficiently.

## Acceptance Criteria

1. **Given** a tag without transcription in the detail panel
   **When** the DM clicks the inline "Transcribe" button
   **Then** the transcription engine processes the tag's audio segment (~30 seconds around the anchor)
   **And** an inline spinner shows progress
   **And** the transcription text appears when complete

2. **Given** the session toolbar "Transcribe All" button
   **When** the DM clicks it
   **Then** all unprocessed tags in the session are queued for transcription
   **And** a batch progress indicator shows (e.g., "3/28 tags transcribed")

3. **Given** batch transcription is running
   **When** the DM continues reviewing tags, editing labels, or navigating
   **Then** the UI remains fully responsive — transcription runs in the background

4. **Given** a tag transcription fails
   **When** the error is displayed
   **Then** a per-tag error badge with "Retry" button appears
   **And** other tags continue processing unaffected

## Tasks / Subtasks

- [ ] Task 1: Create TranscriptionEngine orchestration service (AC: #1, #2, #3)
  - [ ] 1.1 Create `DictlyMac/Transcription/TranscriptionEngine.swift` as `@Observable` class
  - [ ] 1.2 Inject `WhisperBridge` and `ModelManager` as dependencies (accept in init or via environment)
  - [ ] 1.3 Implement `transcribeTag(_ tag: Tag, session: Session) async throws` — extracts ~30s audio segment around `tag.anchorTime` (using `rewindDuration` before anchor, and remaining after to total ~30s), calls `WhisperBridge.transcribe(audioURL:modelURL:)`, saves result to `tag.transcription`
  - [ ] 1.4 Implement audio segment extraction: use `AVAudioFile` + `AVAudioConverter` to read the session's audio file and write a temporary WAV/CAF file for the tag's time window (`anchorTime - rewindDuration` to `anchorTime + remainingDuration`). Clean up temp file after transcription.
  - [ ] 1.5 Add published state properties: `isTranscribing: Bool`, `currentTagId: UUID?` for single-tag progress tracking
  - [ ] 1.6 Implement `transcribeAllTags(in session: Session) async` — filters tags where `transcription == nil`, queues them sequentially, updates progress after each
  - [ ] 1.7 Add batch progress properties: `isBatchTranscribing: Bool`, `batchTotal: Int`, `batchCompleted: Int`, `batchErrors: [(tag: Tag, error: Error)]`
  - [ ] 1.8 Implement per-tag error isolation: wrap each tag transcription in do/catch, record failures in `batchErrors`, continue processing remaining tags
  - [ ] 1.9 Implement `retryTag(_ tag: Tag, session: Session) async throws` — clears error state for tag, re-runs transcription
  - [ ] 1.10 Implement `cancelBatch()` — sets cancellation flag checked between tag processing, stops after current tag completes
  - [ ] 1.11 Use `os.Logger` (subsystem `com.dictly.mac`, category `transcription`) for all operations

- [ ] Task 2: Implement audio segment extraction utility (AC: #1, #2)
  - [ ] 2.1 Create a method `extractAudioSegment(from audioURL: URL, start: TimeInterval, duration: TimeInterval) throws -> URL` in TranscriptionEngine
  - [ ] 2.2 Open session audio file with `AVAudioFile`, seek to start position, read `duration` worth of frames
  - [ ] 2.3 Write extracted segment to a temporary file in `FileManager.default.temporaryDirectory`
  - [ ] 2.4 Handle edge cases: start < 0 clamp to 0, end > file duration clamp to file end
  - [ ] 2.5 Return temp file URL — caller is responsible for cleanup after transcription

- [ ] Task 3: Integrate "Transcribe" button into TagDetailPanel (AC: #1, #4)
  - [ ] 3.1 In `DictlyMac/SessionReview/TagDetailPanel.swift`, add transcription block below tag header
  - [ ] 3.2 When `tag.transcription == nil` and not currently transcribing this tag: show "Transcribe" button (inline, secondary style)
  - [ ] 3.3 When transcription is in progress for this tag (`transcriptionEngine.currentTagId == tag.uuid`): show `ProgressView()` inline spinner with "Transcribing..." label
  - [ ] 3.4 When `tag.transcription != nil`: display transcription text in the transcription block (read-only for this story — editing is Story 5.4)
  - [ ] 3.5 When transcription failed for this tag: show error badge with "Retry" button
  - [ ] 3.6 Access `TranscriptionEngine` via `@Environment(TranscriptionEngine.self)`

- [ ] Task 4: Add "Transcribe All" toolbar button and batch progress (AC: #2, #3)
  - [ ] 4.1 In `DictlyMac/SessionReview/SessionReviewScreen.swift` (or equivalent toolbar view), add "Transcribe All" button to session toolbar
  - [ ] 4.2 Button disabled when: no tags in session, all tags already transcribed, or batch transcription already running
  - [ ] 4.3 When batch is running: replace button with progress indicator showing "3/28 tags transcribed" (using `transcriptionEngine.batchCompleted` / `batchTotal`)
  - [ ] 4.4 Add cancel button alongside batch progress to allow stopping batch
  - [ ] 4.5 When batch completes: restore "Transcribe All" button (disabled if all done), show summary if errors occurred

- [ ] Task 5: Inject TranscriptionEngine into app environment (AC: #1, #2, #3)
  - [ ] 5.1 In `DictlyMac/App/DictlyMacApp.swift`, create `@State private var transcriptionEngine: TranscriptionEngine`
  - [ ] 5.2 Initialize TranscriptionEngine with WhisperBridge and ModelManager references
  - [ ] 5.3 Add `.environment(transcriptionEngine)` to both `WindowGroup` and `Settings` scenes
  - [ ] 5.4 Ensure TranscriptionEngine is available wherever TagDetailPanel and session toolbar are used

- [ ] Task 6: Handle audio file resolution (AC: #1, #2)
  - [ ] 6.1 Resolve session audio file URL from `session.audioFilePath` using `AudioFileManager` path conventions
  - [ ] 6.2 If audio file not found, throw `DictlyError.transcription(.audioFileNotFound)`
  - [ ] 6.3 Validate audio file is readable before attempting segment extraction

- [ ] Task 7: Write unit tests (AC: #1–#4)
  - [ ] 7.1 Create `DictlyMacTests/TranscriptionTests/TranscriptionEngineTests.swift`
  - [ ] 7.2 Test: `transcribeTag` sets `isTranscribing` to true during operation, false after
  - [ ] 7.3 Test: `transcribeAllTags` filters only tags with nil transcription
  - [ ] 7.4 Test: `transcribeAllTags` updates `batchCompleted` count after each tag
  - [ ] 7.5 Test: per-tag error isolation — one failure doesn't stop batch
  - [ ] 7.6 Test: `cancelBatch` stops processing after current tag
  - [ ] 7.7 Test: `retryTag` clears error state and re-attempts transcription
  - [ ] 7.8 Test: audio segment extraction clamps start/end to valid range
  - [ ] 7.9 Verify all existing DictlyKit tests still pass (245 tests, 0 regressions)
  - [ ] 7.10 Verify existing WhisperBridge tests still pass (6 tests)
  - [ ] 7.11 Verify existing ModelManager tests still pass (11 tests)

## Dev Notes

### Architecture Compliance

- **Module boundary:** All new code lives in `DictlyMac/Transcription/` (TranscriptionEngine) and modifications to existing `DictlyMac/SessionReview/` views. TranscriptionEngine is Mac-only — never import into DictlyKit or DictlyiOS.
- **State management:** TranscriptionEngine MUST be `@Observable` (not `ObservableObject`). Inject via `@Environment`. Use `@State` only for view-local UI state.
- **Async pattern:** Use `Task { }` inside `@Observable` service class for background work. In views, use `.task` modifier or button actions. Never `Task` inside `body`.
- **Error handling:** All errors MUST use `DictlyError.transcription(...)` cases. Never silently swallow errors — log at `.error` minimum with `os.Logger`.
- **Logging:** Subsystem `com.dictly.mac`, category `transcription`. Use `.debug` for progress, `.info` for user actions, `.error` for failures.
- **SwiftData saves:** Tag's `transcription` property is already defined on the model. Writing `tag.transcription = result` auto-saves via SwiftData context. No manual save calls needed — SwiftData auto-saves on property mutation.
- **Anti-patterns:** No `ObservableObject`/`@StateObject`. No `AnyView`. No custom `CodingKeys`. No `Result` return types — use `throw`.

### Existing Code to Reuse / Extend

- **`WhisperBridge.swift`** at `DictlyMac/Transcription/WhisperBridge.swift` — already has `transcribe(audioURL:modelURL:) async throws -> String`. This is the core transcription call. It handles audio conversion to 16kHz mono PCM Float32 internally. TranscriptionEngine orchestrates calls to this method.
- **`ModelManager.swift`** at `DictlyMac/Transcription/ModelManager.swift` — provides `activeModelURL -> URL` for the currently selected whisper model. TranscriptionEngine must use `modelManager.activeModelURL` when calling WhisperBridge.
- **`Tag.swift`** at `DictlyKit/Sources/DictlyModels/Tag.swift` — already has `transcription: String?` property. Also has `anchorTime: TimeInterval` and `rewindDuration: TimeInterval` which define the audio segment window.
- **`Session.swift`** at `DictlyKit/Sources/DictlyModels/Session.swift` — has `audioFilePath: String?` pointing to the session's audio file, and `tags: [Tag]` relationship.
- **`AudioFileManager`** at `DictlyKit/Sources/DictlyStorage/AudioFileManager.swift` — provides `recordingsDirectory` and file utilities. Use to resolve `session.audioFilePath` to a full URL.
- **`DictlyError.TranscriptionError`** at `DictlyKit/Sources/DictlyModels/DictlyError.swift` — already has `modelNotFound`, `modelCorrupted`, `processingFailed`, `audioConversionFailed`, `audioFileNotFound`, `downloadFailed`. These cover all needed error cases.
- **`DictlyMacApp.swift`** at `DictlyMac/App/DictlyMacApp.swift` — already injects `WhisperBridge` and `ModelManager` via `@State` + `.environment()`. Add TranscriptionEngine following the same pattern.

### Audio Segment Extraction Strategy

Each tag represents a ~30-second audio moment. The segment window is:
- **Start:** `tag.anchorTime - tag.rewindDuration` (the rewind buffer, typically 5-20 seconds before the tap)
- **End:** `tag.anchorTime + (30 - tag.rewindDuration)` to make a ~30-second total segment
- **Edge cases:** Clamp start to 0 if negative, clamp end to session duration if exceeding file length

WhisperBridge already handles audio format conversion internally (converts to 16kHz mono PCM Float32). TranscriptionEngine just needs to extract the time-windowed segment from the full session audio file and pass it as a temporary file URL.

Use `AVAudioFile` to read the segment:
1. Open the session audio file
2. Calculate frame positions from time intervals (`time * sampleRate`)
3. Read the frame range into `AVAudioPCMBuffer`
4. Write buffer to a temp file
5. Pass temp URL to `WhisperBridge.transcribe()`
6. Delete temp file after transcription completes (in defer block)

### Batch Processing Design

Sequential processing (not parallel) is correct for whisper.cpp — it uses Metal/Core ML acceleration and running multiple transcriptions concurrently would contend for GPU resources. Process tags one at a time in order.

Batch cancellation uses a `Task` cancellation check between tags:
```swift
for tag in unprocessedTags {
    try Task.checkCancellation()
    do {
        try await transcribeTag(tag, session: session)
        batchCompleted += 1
    } catch is CancellationError {
        throw CancellationError()
    } catch {
        batchErrors.append((tag: tag, error: error))
        batchCompleted += 1 // count as processed even if failed
    }
}
```

### UI Integration Points

**TagDetailPanel** (existing file `DictlyMac/SessionReview/TagDetailPanel.swift`):
- Below the tag header (editable label + category badge + timestamp), add a transcription block
- Three states: (1) no transcription → "Transcribe" button, (2) transcribing → inline `ProgressView()`, (3) transcribed → display text read-only
- Error state: error badge with "Retry" button

**Session toolbar** (existing `SessionReviewScreen.swift` or equivalent):
- Add "Transcribe All" button using `systemImage: "waveform"` or similar
- During batch: replace with `ProgressView` + "3/28 tags transcribed" text + cancel button
- Architecture specifies toolbar contains: session name, campaign/duration/tag count metadata, **Transcribe All** / Export MD / Session Notes actions

**UX requirements from design spec:**
- Never block the full UI for loading — sidebar, waveform, and other tags remain interactive during transcription
- Show progress for operations longer than 5 seconds
- Batch transcription runs in the background while DM continues reviewing

### Previous Story Intelligence (5-2)

Key learnings from Story 5-2 implementation:
- **`@MainActor` for UI-driving services:** ModelManager used `@MainActor @Observable` because its state drives UI updates. TranscriptionEngine similarly drives UI progress state, so consider `@MainActor` isolation.
- **Testability pattern:** ModelManager accepts `modelsDirectory: URL` in init for test isolation. TranscriptionEngine should similarly accept dependencies via init for testability.
- **WhisperBridge environment injection:** Already injected in `DictlyMacApp.swift` via `@State` + `.environment()`. Follow same pattern for TranscriptionEngine.
- **Build process:** Re-run xcodegen after adding new source files to `project.yml`.
- **Pre-existing test failures:** 2 pre-existing failures in `RetroactiveTagTests` and `TagEditingTests` (whitespace validation) — these are unrelated, do not attempt to fix.
- **`@Observable` final class pattern:** All service classes use `@Observable final class`. Follow this convention.
- **Code review findings:** Thread safety with NSLock is critical for WhisperBridge. TranscriptionEngine doesn't need its own lock if it processes sequentially and accesses WhisperBridge's thread-safe API.

### Git Intelligence

Recent commit patterns: `feat(transcription):`, `fix(transcription):`, `refactor(transcription):`. Continue using `feat(transcription):` for this story. Re-run xcodegen after modifying `project.yml`.

### Anti-Patterns to Avoid

- Do NOT run multiple transcriptions in parallel — whisper.cpp uses Metal/GPU, concurrent runs would contend for resources
- Do NOT store audio segments permanently — extract to temp, transcribe, delete
- Do NOT use `ObservableObject` / `@StateObject` — use `@Observable` exclusively
- Do NOT put TranscriptionEngine in DictlyKit — it depends on WhisperBridge which is Mac-only
- Do NOT add a full session transcription view — Dictly transcribes only tagged segments, never a wall of text (explicit UX anti-pattern from design spec: "Otter.ai wall of transcription")
- Do NOT implement inline editing of transcription text — that's Story 5.4
- Do NOT block UI during batch transcription — it MUST run in background
- Do NOT skip failed tags during batch — record errors, continue processing, show retry option
- Do NOT add any new `DictlyError` cases — existing `TranscriptionError` variants cover all needs

### Project Structure Notes

Files to create:
```
DictlyMac/Transcription/
├── TranscriptionEngine.swift          # @Observable — orchestrates per-tag and batch transcription
└── TranscriptionProgressView.swift    # Batch progress indicator component (optional — may inline in toolbar)
DictlyMacTests/TranscriptionTests/
└── TranscriptionEngineTests.swift     # Unit tests for TranscriptionEngine
```

Files to modify:
```
DictlyMac/SessionReview/TagDetailPanel.swift       # Add transcription block with Transcribe/spinner/text/retry
DictlyMac/SessionReview/SessionReviewScreen.swift   # Add "Transcribe All" toolbar button and batch progress
DictlyMac/App/DictlyMacApp.swift                    # Add TranscriptionEngine to environment
DictlyMac/project.yml                               # Add new source files (if not auto-discovered)
```

Alignment with architecture `DictlyMac/Transcription/` structure:
```
DictlyMac/Transcription/
├── TranscriptionEngine.swift       # NEW — @Observable — whisper.cpp orchestration, batch processing
├── WhisperBridge.swift             # EXISTING — C interop layer for whisper.cpp
├── TranscriptionProgressView.swift # NEW — Per-tag and batch progress UI
├── ModelManager.swift              # EXISTING — whisper model download & selection
└── ModelManagementView.swift       # EXISTING — Preferences transcription tab
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 5, Story 5.3]
- [Source: _bmad-output/planning-artifacts/architecture.md — DictlyMac/Transcription/ module, TranscriptionEngine.swift]
- [Source: _bmad-output/planning-artifacts/architecture.md — FR37-FR40 requirements mapping]
- [Source: _bmad-output/planning-artifacts/architecture.md — @Observable state management, async work patterns]
- [Source: _bmad-output/planning-artifacts/architecture.md — SwiftData relationships: Session → Tag (cascade)]
- [Source: _bmad-output/planning-artifacts/prd.md — FR37 local transcription, FR38 per-tag/batch]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — TagDetailPanel anatomy, transcription block]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Loading states: inline spinner per tag, progress bar with count for batch]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Anti-pattern: wall of transcription]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Mac toolbar: Transcribe All action]
- [Source: _bmad-output/implementation-artifacts/5-2-whisper-model-management.md — ModelManager patterns, environment injection, test conventions]
- [Source: DictlyMac/Transcription/WhisperBridge.swift — transcribe(audioURL:modelURL:) API]
- [Source: DictlyMac/Transcription/ModelManager.swift — activeModelURL, model registry]
- [Source: DictlyKit/Sources/DictlyModels/Tag.swift — transcription: String? property, anchorTime, rewindDuration]
- [Source: DictlyKit/Sources/DictlyModels/Session.swift — audioFilePath, tags relationship]
- [Source: DictlyKit/Sources/DictlyModels/DictlyError.swift — TranscriptionError cases]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
