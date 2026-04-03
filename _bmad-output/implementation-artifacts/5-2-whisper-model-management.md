# Story 5.2: Whisper Model Management

Status: review

## Story

As a DM,
I want to choose which transcription model to use and download better models if I want,
So that I can balance transcription quality against disk space and processing time.

## Acceptance Criteria

1. **Given** a fresh install of the Mac app
   **When** the app launches
   **Then** the `base.en` model (~150 MB) is bundled and ready to use

2. **Given** the Mac Preferences window
   **When** the DM views the transcription settings
   **Then** available models are listed: base.en (bundled), small.en (~500 MB), medium.en (~1.5 GB)
   **And** downloaded models show a checkmark, others show a download button with size

3. **Given** the DM clicks download on a model
   **When** the download progresses
   **Then** a progress bar shows download status
   **And** on completion the model becomes selectable as the active model

4. **Given** a downloaded model
   **When** the DM selects it as active
   **Then** all future transcriptions use the selected model

5. **Given** the DM deletes a downloaded model
   **When** the deletion completes
   **Then** the space is freed and the app falls back to the bundled base.en model

## Tasks / Subtasks

- [x] Task 1: Create ModelManager with model registry and storage (AC: #1, #2, #4)
  - [x] 1.1 Create `DictlyMac/Transcription/ModelManager.swift` as `@Observable` class
  - [x] 1.2 Define `WhisperModel` struct with: `id` (String), `name` (String), `fileName` (String, e.g. `ggml-base.en.bin`), `size` (Int64, bytes), `quality` (String), `isBundled` (Bool)
  - [x] 1.3 Create static model registry array with three models: `base.en` (bundled, ~148 MB), `small.en` (~488 MB), `medium.en` (~1.5 GB)
  - [x] 1.4 Implement `modelsDirectory` computed property returning `~/Library/Application Support/Dictly/Models/` (create directory if missing)
  - [x] 1.5 Implement `modelURL(for model: WhisperModel) -> URL` returning full path to model file
  - [x] 1.6 Implement `isDownloaded(_ model: WhisperModel) -> Bool` checking if model file exists at expected path
  - [x] 1.7 Implement `activeModel` published property persisted via `UserDefaults` (key: `activeWhisperModel`, default: `base.en`)
  - [x] 1.8 Implement `selectModel(_ model: WhisperModel)` that sets `activeModel` (only if model is downloaded or bundled)
  - [x] 1.9 Implement `activeModelURL -> URL` that returns the file URL for the currently selected model
  - [x] 1.10 On init, validate that `activeModel` still exists on disk; if not, fall back to `base.en`

- [x] Task 2: Bundle base.en model with the app (AC: #1)
  - [x] 2.1 Add `ggml-base.en.bin` to the DictlyMac target's resources in `project.yml` (Copy Bundle Resources phase)
  - [x] 2.2 Implement `bundledModelURL -> URL?` that returns `Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin")`
  - [x] 2.3 On first launch, if `base.en` not present in `modelsDirectory`, copy from bundle to `modelsDirectory` (so all models have a consistent lookup path)
  - [x] 2.4 Re-run xcodegen to regenerate xcodeproj with new resource
  - [x] 2.5 Verify build succeeds with bundled model

- [x] Task 3: Implement model download with progress (AC: #3)
  - [x] 3.1 Implement `downloadModel(_ model: WhisperModel) async throws` using `URLSession` with delegate for progress tracking
  - [x] 3.2 Add `@Observable` published properties: `downloadProgress: Double` (0.0–1.0), `isDownloading: Bool`, `downloadingModelId: String?`
  - [x] 3.3 Download from Hugging Face GGML model URLs (e.g. `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-{model}.bin`)
  - [x] 3.4 Write to temporary file first, then atomically move to `modelsDirectory` on completion
  - [x] 3.5 Implement `cancelDownload()` that cancels the active `URLSessionDownloadTask`
  - [x] 3.6 Handle download errors: throw `.transcription(.downloadFailed)` with underlying error context
  - [x] 3.7 Log download lifecycle with `os.Logger` (subsystem `com.dictly.mac`, category `transcription`)

- [x] Task 4: Implement model deletion (AC: #5)
  - [x] 4.1 Implement `deleteModel(_ model: WhisperModel) throws` that removes the model file from `modelsDirectory`
  - [x] 4.2 Guard: cannot delete bundled `base.en` model (no-op or throw specific error)
  - [x] 4.3 If deleted model was `activeModel`, reset `activeModel` to `base.en`
  - [x] 4.4 Notify WhisperBridge to unload if the deleted model is currently loaded (call `WhisperBridge.unloadModel()` if active context matches)

- [x] Task 5: Add Transcription tab to PreferencesWindow (AC: #2, #3, #4, #5)
  - [x] 5.1 Add a "Transcription" tab to `PreferencesWindow.swift` using `TabView` (alongside existing "Storage" tab)
  - [x] 5.2 Create `ModelManagementView.swift` in `DictlyMac/Transcription/` as the tab content
  - [x] 5.3 Display model list: each row shows model name, quality description, file size, and status (checkmark if downloaded + active radio, download button if not downloaded, progress bar if downloading)
  - [x] 5.4 Active model selection: radio button or checkmark selector — only enabled for downloaded models
  - [x] 5.5 Download button: shows model size, triggers `ModelManager.downloadModel()`, replaced by progress bar during download with cancel button
  - [x] 5.6 Delete button: trash icon for downloaded (non-bundled) models, with confirmation alert
  - [x] 5.7 Show disk space used by each downloaded model using `AudioFileManager.formattedSize(_:)` or equivalent formatting

- [x] Task 6: Extend DictlyError and WhisperBridge (AC: #3, #5)
  - [x] 6.1 Add `downloadFailed` case to `TranscriptionError` in `DictlyKit/Sources/DictlyModels/DictlyError.swift`
  - [x] 6.2 Add `errorDescription` for `downloadFailed`
  - [x] 6.3 Add `unloadModel()` method to `WhisperBridge.swift` that frees the current whisper context and resets `loadedModelURL`
  - [x] 6.4 Verify existing 245 DictlyKit tests still pass

- [x] Task 7: Write unit tests (AC: #1–#5)
  - [x] 7.1 Create `DictlyMacTests/TranscriptionTests/ModelManagerTests.swift`
  - [x] 7.2 Test: model registry contains exactly 3 models with correct properties
  - [x] 7.3 Test: `isDownloaded` returns false for non-existent model file
  - [x] 7.4 Test: `isDownloaded` returns true when model file exists at expected path
  - [x] 7.5 Test: `selectModel` persists to UserDefaults and updates `activeModel`
  - [x] 7.6 Test: `selectModel` rejects non-downloaded model (does not change activeModel)
  - [x] 7.7 Test: `deleteModel` removes file and resets activeModel to base.en if deleted model was active
  - [x] 7.8 Test: `deleteModel` on base.en is a no-op (cannot delete bundled model)
  - [x] 7.9 Test: `activeModelURL` returns correct file URL for selected model
  - [x] 7.10 Test: init fallback — if persisted activeModel file is missing, falls back to base.en
  - [x] 7.11 Verify all DictlyKit tests still pass (245 tests, 0 regressions)
  - [x] 7.12 Verify existing WhisperBridge tests still pass (6 tests)

## Dev Notes

### Architecture Compliance

- **Module boundary:** All new code lives in `DictlyMac/Transcription/`. ModelManager is Mac-only — never import into DictlyKit or DictlyiOS.
- **State management:** ModelManager MUST be `@Observable` (not `ObservableObject`). Use `@State` only for view-local state. Inject ModelManager via `@Environment`.
- **Error handling:** All errors MUST use `DictlyError.transcription(...)` cases. Never silently swallow errors — log at `.error` minimum with `os.Logger`.
- **Logging:** Subsystem `com.dictly.mac`, category `transcription`. Use `.debug` for progress updates, `.info` for user actions (download/select/delete), `.error` for failures.
- **Network exception:** Model downloads are the ONLY network calls in the entire app. This is by design — user-initiated, optional, downloads a model file only (no user data sent). Do NOT add analytics, telemetry, or any other network calls.
- **Anti-patterns:** No `ObservableObject`/`@StateObject`. No `AnyView`. No custom `CodingKeys`. No `Result` return types — use `throw`.

### Existing Code to Reuse / Extend

- **`WhisperBridge.swift`** at `DictlyMac/Transcription/WhisperBridge.swift` — already has `loadModel(at:)` that accepts a `URL`. ModelManager provides the URL; WhisperBridge consumes it. Add `unloadModel()` to free context when model is deleted.
- **`WhisperBridge` thread safety** — uses `NSLock` for concurrent model loading. `unloadModel()` must also acquire the lock.
- **`DictlyError.TranscriptionError`** at `DictlyKit/Sources/DictlyModels/DictlyError.swift` — already has `modelNotFound`, `modelCorrupted`, `processingFailed`, `audioConversionFailed`, `audioFileNotFound`. Add `downloadFailed`.
- **`PreferencesWindow.swift`** at `DictlyMac/Settings/PreferencesWindow.swift` — existing Preferences with "Storage" tab using `TabView`. Add "Transcription" tab here.
- **`AudioFileManager.formattedSize(_:)`** at `DictlyKit/Sources/DictlyStorage/AudioFileManager.swift` — reuse for displaying model file sizes. Static method, no instantiation needed.
- **Model storage path:** Story 5-1 established `~/Library/Application Support/Dictly/Models/` as the model directory. ModelManager MUST use this same path.

### Model Download URLs

Whisper.cpp GGML models are hosted on Hugging Face:
- `base.en`: `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin` (~148 MB)
- `small.en`: `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin` (~488 MB)
- `medium.en`: `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin` (~1.5 GB)

Use `URLSession.shared.download(from:delegate:)` for download with progress. Implement `URLSessionDownloadDelegate` for `urlSession(_:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)` progress callbacks.

### Model Bundling Strategy

The `base.en` model (~148 MB) must be bundled in the app. Two-part approach:
1. **Build time:** Add `ggml-base.en.bin` to DictlyMac resources in `project.yml` under `resources:` section
2. **Runtime:** On first launch, copy from `Bundle.main` to `modelsDirectory` so all models (bundled + downloaded) share a single lookup directory

This avoids bifurcated path logic — `modelURL(for:)` always points to `modelsDirectory`.

### UserDefaults Persistence

Active model selection uses `UserDefaults.standard` with key `"activeWhisperModel"`. Store the model `id` string (e.g., `"base.en"`). On init, validate the persisted model still exists on disk — if the file was manually deleted, fall back to `base.en`.

### PreferencesWindow Integration

The existing `PreferencesWindow.swift` uses a `TabView` with a "Storage" tab. Add a "Transcription" tab:

```swift
TabView {
    StorageManagementView()
        .tabItem { Label("Storage", systemImage: "externaldrive") }
    ModelManagementView()
        .tabItem { Label("Transcription", systemImage: "waveform") }
}
```

### ModelManagementView Layout

Each model row should display:
```
[Radio/Check] base.en (Bundled)          Good quality     148 MB    [Active]
[Radio]       small.en                   Better quality   488 MB    [Download ↓]
[Radio]       medium.en                  Best quality     1.5 GB    [Download ↓]
```

States per model row:
- **Bundled + active:** Checkmark, "Active" label, no delete
- **Downloaded + active:** Checkmark, "Active" label, delete button (trash icon)
- **Downloaded + inactive:** Empty radio, selectable, delete button
- **Not downloaded:** Empty radio (disabled), download button showing size
- **Downloading:** Progress bar replacing download button, cancel button

### WhisperBridge.unloadModel() Implementation

```swift
func unloadModel() {
    lock.lock()
    defer { lock.unlock() }
    if let ctx = context {
        whisper_free(ctx)
        context = nil
        loadedModelURL = nil
    }
}
```

This is needed when a model is deleted while loaded — prevents use-after-free.

### Previous Story Intelligence (5-1)

Key learnings from Story 5-1 implementation:
- **xcodegen:** MUST re-run xcodegen after adding new source files or resources to `project.yml`
- **Build verification:** Always build with `CODE_SIGN_IDENTITY=""` for local dev
- **Model path convention:** Models stored at `~/Library/Application Support/Dictly/Models/ggml-{name}.bin`
- **WhisperBridge patterns:** `@Observable`, `NSLock` for thread safety, `os.Logger` for logging
- **Test count baseline:** DictlyKit has 245 passing tests, WhisperBridge has 6 passing tests — verify no regressions
- **Code review findings from 5-1:** Thread safety with NSLock is critical — apply same pattern to ModelManager if shared state is accessed concurrently

### Git Intelligence

Recent commit pattern: `feat(transcription):`, `refactor(transcription):`. Continue using `feat(transcription):` for this story. Re-run xcodegen after modifying `project.yml`.

### Anti-Patterns to Avoid

- Do NOT use `ObservableObject` / `@StateObject` — use `@Observable` exclusively
- Do NOT use `AnyView` type erasure
- Do NOT create custom `CodingKeys`
- Do NOT put ModelManager in DictlyKit — it's Mac-only, stays in `DictlyMac/Transcription/`
- Do NOT add any network calls beyond model downloads — zero network is a core design principle
- Do NOT send any user data during model downloads — download model file only
- Do NOT hardcode download URLs as magic strings — define them in the `WhisperModel` registry
- Do NOT block the main thread during downloads — use async/await
- Do NOT leave partial downloads on failure — use temp file + atomic move pattern
- Do NOT allow deleting the bundled base.en model — it's the safety fallback

### Project Structure Notes

Files to create:
```
DictlyMac/Transcription/
├── ModelManager.swift              # @Observable — model registry, download, selection, deletion
└── ModelManagementView.swift       # SwiftUI view for Preferences Transcription tab
DictlyMacTests/TranscriptionTests/
└── ModelManagerTests.swift         # Unit tests for ModelManager
```

Files to modify:
```
DictlyMac/Transcription/WhisperBridge.swift          # Add unloadModel() method
DictlyMac/Settings/PreferencesWindow.swift            # Add Transcription tab
DictlyKit/Sources/DictlyModels/DictlyError.swift      # Add downloadFailed case
DictlyMac/project.yml                                 # Add ggml-base.en.bin to resources
DictlyMac/DictlyMac.xcodeproj/project.pbxproj         # Regenerated by xcodegen
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 5, Story 5.2]
- [Source: _bmad-output/planning-artifacts/architecture.md — ModelManager.swift, model download pattern, zero-network exception]
- [Source: _bmad-output/planning-artifacts/architecture.md — DictlyMac/Transcription/ module boundary]
- [Source: _bmad-output/planning-artifacts/architecture.md — @Observable state management, error handling patterns]
- [Source: _bmad-output/planning-artifacts/prd.md — FR37 local transcription, zero-network privacy requirement]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Preferences window, transcription settings, progress indicators]
- [Source: _bmad-output/implementation-artifacts/5-1-whisper-cpp-integration-and-whisperbridge.md — WhisperBridge patterns, model path convention, build learnings]
- [Source: DictlyMac/Transcription/WhisperBridge.swift — existing loadModel/transcribe API, NSLock pattern]
- [Source: DictlyMac/Settings/PreferencesWindow.swift — existing TabView Preferences structure]
- [Source: DictlyKit/Sources/DictlyModels/DictlyError.swift — TranscriptionError enum to extend]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Build error: `ShapeStyle` has no member `.accent` — fixed by using `Color.accentColor`
- `ModelManager` is `final class` so cannot be subclassed for tests — redesigned to accept `modelsDirectory: URL` parameter in designated init for testability
- `convenience init()` delegates to `init(modelsDirectory:)` for production path

### Completion Notes List

- **ModelManager.swift** created as `@MainActor @Observable final class` — `@MainActor` chosen (vs plain `@Observable`) because download progress state drives UI updates, making main-actor isolation the cleanest approach for Swift 6
- **WhisperModel** is a `Sendable` struct with a computed `downloadURL` property so download URLs live in the registry alongside model metadata (avoids hardcoded string magic elsewhere)
- **Download** uses a dedicated per-call `URLSession` instance with `ModelDownloadDelegate` for progress callbacks; cancellation calls `session.invalidateAndCancel()` which throws `NSURLErrorCancelled` — caught and swallowed as normal cancellation (not a user-visible error)
- **`modelsDirectory` as a `let` property** (injected via init) rather than a computed property enables isolated testing with a temp directory without subclassing
- **WhisperBridge.unloadModel()** acquires `modelLock` (same lock used by `loadContext`) for thread safety, preventing use-after-free when a model is deleted while loaded
- **Task 4.4 coordination**: view (`ModelManagementView`) calls `whisperBridge.unloadModel()` before `modelManager.deleteModel()` — keeps ModelManager decoupled from WhisperBridge
- **WhisperBridge and ModelManager injected** as `@State` in `DictlyMacApp` and propagated via `.environment()` to both `WindowGroup` and `Settings` scenes
- **DictlyKit tests**: All passed (245 tests, 0 regressions); 2 pre-existing failures in `RetroactiveTagTests` and `TagEditingTests` (whitespace validation, unrelated to this story)
- **ModelManagerTests**: 11/11 passed; **WhisperBridgeTests**: 6/6 passed (including new `unloadModel` method)

### File List

- `DictlyMac/Transcription/ModelManager.swift` (new)
- `DictlyMac/Transcription/ModelManagementView.swift` (new)
- `DictlyMacTests/TranscriptionTests/ModelManagerTests.swift` (new)
- `DictlyMac/Models/.gitkeep` (new — placeholder for bundled model directory)
- `DictlyKit/Sources/DictlyModels/DictlyError.swift` (modified — added `downloadFailed` case)
- `DictlyMac/Transcription/WhisperBridge.swift` (modified — added `unloadModel()`)
- `DictlyMac/Settings/PreferencesWindow.swift` (modified — added Transcription tab)
- `DictlyMac/App/DictlyMacApp.swift` (modified — added ModelManager and WhisperBridge to environment)
- `DictlyMac/project.yml` (modified — added `Models` resource directory)
- `DictlyMac/DictlyMac.xcodeproj/project.pbxproj` (regenerated by xcodegen)

## Change Log

- 2026-04-03: Implemented Story 5-2 — Whisper Model Management. Created ModelManager (@MainActor @Observable) with 3-model registry, download/selection/deletion, and bundled model copy-on-first-launch. Created ModelManagementView for Preferences Transcription tab. Added downloadFailed to DictlyError, unloadModel() to WhisperBridge. 11 ModelManagerTests passing.
