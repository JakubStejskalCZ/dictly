# Story 5.1: whisper.cpp Integration & WhisperBridge

Status: done

## Story

As a developer,
I want a Swift-callable bridge to whisper.cpp with Metal/Core ML acceleration,
So that the Mac app can transcribe audio segments natively without a Python runtime.

## Acceptance Criteria

1. **Given** the whisper.cpp source is included in the project (git submodule or SPM)
   **When** the Mac target builds
   **Then** the WhisperBridge compiles and links successfully with whisper.cpp

2. **Given** an audio segment (AAC 64kbps mono, ~30 seconds)
   **When** `WhisperBridge.transcribe(audioURL:modelURL:)` is called
   **Then** a transcription string is returned
   **And** Metal/Core ML acceleration is used on Apple Silicon

3. **Given** a transcription request
   **When** the whisper model file is missing or corrupted
   **Then** a `DictlyError.transcription` is thrown with a specific cause

4. **Given** the transcription engine
   **When** processing a segment
   **Then** it runs on a background thread and does not block the UI

## Tasks / Subtasks

- [x] Task 1: Add whisper.cpp as git submodule (AC: #1)
  - [x] 1.1 Add git submodule at `Vendor/whisper.cpp` pointing to `https://github.com/ggml-org/whisper.cpp`
  - [x] 1.2 Pin to latest stable release tag
  - [x] 1.3 Verify submodule clones correctly with `git submodule update --init`

- [x] Task 2: Configure Xcode build for whisper.cpp C library (AC: #1)
  - [x] 2.1 Create a C library target or bridging approach in the DictlyMac Xcode project that compiles the whisper.cpp source files
  - [x] 2.2 Add required whisper.cpp source files: `whisper.cpp`, `ggml*.c/cpp` files from `Vendor/whisper.cpp/src/` and `Vendor/whisper.cpp/ggml/src/`
  - [x] 2.3 Set header search paths to include `Vendor/whisper.cpp/include` and `Vendor/whisper.cpp/ggml/include`
  - [x] 2.4 Enable Metal acceleration: link `Metal.framework`, `MetalKit.framework`, `MetalPerformanceShaders.framework`; compile `ggml-metal.m` with Metal backend enabled (`GGML_USE_METAL=1`)
  - [x] 2.5 Enable Core ML acceleration: link `CoreML.framework`; set `WHISPER_USE_COREML=1` if using Core ML model variant
  - [x] 2.6 Add `Accelerate.framework` for BLAS optimizations
  - [x] 2.7 Set C/C++ compiler flags: `-O3`, `-DNDEBUG`, `-DGGML_USE_METAL`, `-DGGML_USE_ACCELERATE`
  - [x] 2.8 Create bridging header `DictlyMac/Transcription/WhisperBridge-Bridging-Header.h` that imports `whisper.h`
  - [x] 2.9 Verify DictlyMac target builds and links cleanly with `CODE_SIGN_IDENTITY=""`

- [x] Task 3: Implement WhisperBridge Swift wrapper (AC: #2, #3, #4)
  - [x] 3.1 Create `DictlyMac/Transcription/WhisperBridge.swift` as `@Observable` class
  - [x] 3.2 Implement `init()` — no model loaded yet (lazy loading)
  - [x] 3.3 Implement `loadModel(at modelURL: URL) throws` — calls `whisper_init_from_file_with_params()` with `use_gpu = true`; stores opaque `OpaquePointer` to `whisper_context`; throws `.transcription(.modelNotFound)` if file missing, `.transcription(.modelCorrupted)` if init returns nil
  - [x] 3.4 Implement `transcribe(audioURL: URL, modelURL: URL) async throws -> String`:
    - Load model if not already loaded (or if modelURL differs from current)
    - Convert AAC audio to PCM float32 samples at 16kHz mono using AVFoundation (`AVAudioFile` + `AVAudioConverter`)
    - Call `whisper_full()` with greedy sampling params (`WHISPER_SAMPLING_GREEDY`), language `"en"`, threads = `ProcessInfo.processInfo.activeProcessorCount` (capped at 8)
    - Collect segment text via `whisper_full_n_segments()` / `whisper_full_get_segment_text()`
    - Return concatenated transcription string
  - [x] 3.5 Implement `deinit` — calls `whisper_free()` on context if loaded
  - [x] 3.6 Ensure `transcribe` is dispatched off main thread (the `async` context handles this; verify with `MainActor` assertion in debug)
  - [x] 3.7 Log transcription lifecycle events with `os.Logger` (subsystem `com.dictly.mac`, category `transcription`)

- [x] Task 4: Implement audio format conversion helper (AC: #2)
  - [x] 4.1 Create private method `convertToPCM(audioURL: URL) throws -> [Float]`
  - [x] 4.2 Use `AVAudioFile` to read source AAC file
  - [x] 4.3 Use `AVAudioConverter` to convert to 16kHz mono `Float32` PCM format (`AVAudioCommonFormat.pcmFormatFloat32`, sampleRate 16000, channels 1)
  - [x] 4.4 Return `[Float]` array of samples
  - [x] 4.5 Throw `.transcription(.audioConversionFailed)` on conversion error

- [x] Task 5: Extend DictlyError.TranscriptionError (AC: #3)
  - [x] 5.1 Add new cases to `TranscriptionError` enum in `DictlyKit/Sources/DictlyModels/DictlyError.swift`:
    - `modelCorrupted` — model file exists but failed to load
    - `audioConversionFailed` — AAC to PCM conversion failed
    - `audioFileNotFound` — source audio file missing
  - [x] 5.2 Add `errorDescription` for each new case
  - [x] 5.3 Verify existing tests in DictlyKit still pass (245 tests)

- [x] Task 6: Write unit tests (AC: #1, #2, #3, #4)
  - [x] 6.1 Create `DictlyMacTests/TranscriptionTests/WhisperBridgeTests.swift`
  - [x] 6.2 Test: model loading throws `.modelNotFound` for nonexistent path
  - [x] 6.3 Test: model loading throws `.modelCorrupted` for invalid file (e.g., empty file)
  - [x] 6.4 Test: audio conversion produces correct sample rate and channel count
  - [x] 6.5 Test: transcribe throws `.audioFileNotFound` for missing audio
  - [x] 6.6 Test: transcription runs off main thread (assert `!Thread.isMainThread` inside)
  - [x] 6.7 Test: full transcription pipeline with bundled test audio + model (integration test, mark as performance/integration if model files are large)
  - [x] 6.8 Verify all DictlyKit tests still pass (no regressions)

- [x] Task 7: Download base.en model for development/testing (AC: #2)
  - [x] 7.1 Use whisper.cpp's `models/download-ggml-model.sh` script to download `ggml-base.en.bin` (~148 MB)
  - [x] 7.2 Place in a known development path (do NOT bundle in git — add to `.gitignore`)
  - [x] 7.3 Document model download instructions in story completion notes

## Dev Notes

### Architecture Compliance

- **Module boundary:** All transcription code lives in `DictlyMac/Transcription/`. WhisperBridge is Mac-only — never import into DictlyKit or DictlyiOS.
- **State management:** WhisperBridge MUST be `@Observable` (not `ObservableObject`). Use `@State` only for view-local state.
- **Error handling:** All errors MUST use `DictlyError.transcription(...)` cases. Never silently swallow errors — log at `.error` minimum with `os.Logger`.
- **Async pattern:** Use Swift concurrency (`async throws`). Views call via `.task` modifier. Do NOT use inline `Task {}` from views.
- **Logging:** Subsystem `com.dictly.mac`, category `transcription`. Use `.debug` for buffer sizes/timing, `.info` for user actions, `.error` for failures.

### whisper.cpp C API — Key Functions

```c
// Context initialization (use this, NOT whisper_init_from_file)
struct whisper_context_params cparams = whisper_context_default_params();
cparams.use_gpu = true;  // Metal acceleration on Apple Silicon
struct whisper_context * ctx = whisper_init_from_file_with_params(model_path, cparams);

// Transcription parameters
struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
params.language = "en";
params.n_threads = 4;       // cap at ProcessInfo.activeProcessorCount or 8
params.translate = false;
params.print_timestamps = false;
params.print_progress = false;
params.print_special = false;
params.no_timestamps = true; // we only need text, not timestamps

// Run transcription (pcmf32 = Float array, n_samples = count)
whisper_full(ctx, params, pcmf32, n_samples);

// Extract results
int n_segments = whisper_full_n_segments(ctx);
for (int i = 0; i < n_segments; i++) {
    const char * text = whisper_full_get_segment_text(ctx, i);
}

// Cleanup
whisper_free(ctx);
```

### Audio Format Conversion (AAC -> PCM for whisper.cpp)

whisper.cpp requires **16kHz mono Float32 PCM** samples. Dictly records at **AAC 64kbps mono**. Conversion approach:

```swift
// 1. Read source AAC
let audioFile = try AVAudioFile(forReading: audioURL)

// 2. Target format: 16kHz mono Float32
let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

// 3. Convert using AVAudioConverter
let converter = AVAudioConverter(from: audioFile.processingFormat, to: targetFormat)!
// Read into buffer, convert, extract floatChannelData[0]
```

### Build Configuration — Critical Details

- **Xcode project approach** (NOT Swift Package Manager for whisper.cpp): whisper.cpp has complex C/C++/Metal build requirements that don't map well to SPM. Add source files directly to an Xcode target or use a static library target.
- **Metal shader compilation:** The `ggml-metal.metal` shader file from whisper.cpp must be compiled via a post-compile build script using `xcrun metal`/`xcrun metallib` because Xcode's Metal compiler doesn't have the whisper.cpp include paths. The compiled `default.metallib` is placed in the app bundle's resources.
- **Header search paths:** Must include both `Vendor/whisper.cpp/include` (for `whisper.h`) and `Vendor/whisper.cpp/ggml/include` (for `ggml.h` and related headers).
- **Compiler flags per file:** C files need `-std=c11`, C++ files need `-std=c++17`. Both need `-O3 -DNDEBUG` for release performance.
- **Framework linking:** `Metal.framework`, `MetalKit.framework`, `MetalPerformanceShaders.framework`, `CoreML.framework`, `Accelerate.framework`.
- **Build command:** `CODE_SIGN_IDENTITY=""` for local dev builds (established pattern from previous stories).
- **ARM64-specific sources:** Must include `ggml-cpu/arch/arm/quants.c`, `ggml-cpu/arch/arm/repack.cpp`, `ggml-cpu/arch/arm/cpu-feats.cpp` for Apple Silicon quantization support.
- **MRC required:** ggml Metal ObjC files use manual reference counting (`[release]`). Set `CLANG_ENABLE_OBJC_ARC = NO` for the WhisperLib target.
- **C++ stdlib:** Must link `-lc++` in DictlyMac's `OTHER_LDFLAGS` to resolve C++ standard library symbols from the static library.
- **Version defines:** Must define `WHISPER_VERSION`, `GGML_VERSION`, and `GGML_COMMIT` as they're not auto-generated without CMake.

### Existing Code to Reuse / Extend

- **`DictlyError.TranscriptionError`** at `DictlyKit/Sources/DictlyModels/DictlyError.swift:62-72` — already has `modelNotFound` and `processingFailed`. Add `modelCorrupted`, `audioConversionFailed`, `audioFileNotFound`.
- **`DictlyMac/Transcription/`** directory exists with `.gitkeep` — this is where WhisperBridge.swift goes.
- **`Tag.swift`** model has properties for transcription text (will be used by Story 5.3, not this story).
- **Audio files** are stored in app sandbox, referenced by path in SwiftData models. `AudioFileManager.swift` in `DictlyKit/Sources/DictlyStorage/` manages paths.

### Anti-Patterns to Avoid

- Do NOT use `ObservableObject` / `@StateObject` — use `@Observable` exclusively.
- Do NOT use `AnyView` type erasure.
- Do NOT create custom `CodingKeys`.
- Do NOT put whisper.cpp integration in DictlyKit — it's Mac-only and stays in `DictlyMac/Transcription/`.
- Do NOT bundle the model in the git repo — it's 148+ MB. Document download steps instead.
- Do NOT use `whisper_init_from_file()` (deprecated) — use `whisper_init_from_file_with_params()`.
- Do NOT run whisper inference on the main thread — always use async context.
- Do NOT hardcode thread count — use `ProcessInfo.processInfo.activeProcessorCount` capped at 8.

### Previous Epic Learnings (Epic 4)

- **xcodegen:** Must re-run xcodegen after adding new source files to the project.
- **Build verification:** Always build with `CODE_SIGN_IDENTITY=""` for local dev.
- **Auto-save pattern:** Use blur-commit pattern for editable fields (established in 4-5, 4-7).
- **SwiftData testing:** Use `ModelConfiguration(isStoredInMemoryOnly: true)` for unit tests.
- **Test count baseline:** DictlyKit has 245 passing tests — verify no regressions.
- **`@Bindable`** for two-way binding to `@Model` properties (established in 4-5).
- **Stale-capture guards:** Always verify object identity before writing (established in 4-7).

### Git Intelligence

Recent commit pattern: `feat(review):`, `fix(review):`, `test(epic4):`, `docs(bmad):`. For this story use `feat(transcription):` prefix. Epic 4 is fully done — this is the first story of Epic 5.

### Model Files Reference

| Model | Size | Quality | Use Case |
|-------|------|---------|----------|
| `ggml-base.en.bin` | ~148 MB | Good | Default bundled model (Story 5.2) |
| `ggml-small.en.bin` | ~488 MB | Better | Downloadable upgrade |
| `ggml-medium.en.bin` | ~1.5 GB | Best | Downloadable premium |

For this story, only `base.en` is needed for development/testing. Model management UI comes in Story 5.2.

### Project Structure Notes

Files to create:
```
DictlyMac/Transcription/
├── WhisperBridge.swift              # @Observable — C interop layer + transcription API
└── WhisperBridge-Bridging-Header.h  # Imports whisper.h for Swift access

Vendor/
└── whisper.cpp/                     # Git submodule (new)

DictlyMacTests/TranscriptionTests/
└── WhisperBridgeTests.swift         # Unit + integration tests
```

Files to modify:
```
DictlyKit/Sources/DictlyModels/DictlyError.swift  # Add new TranscriptionError cases
.gitignore                                          # Add model file patterns
.gitmodules                                         # Created by git submodule add
DictlyMac/project.yml                               # WhisperLib target + Metal build script
DictlyMac/Resources/Info.plist                      # Add required CFBundle* keys
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 5, Story 5.1]
- [Source: _bmad-output/planning-artifacts/architecture.md — Transcription section, whisper.cpp decision]
- [Source: _bmad-output/planning-artifacts/architecture.md — DictlyMac/Transcription/ module boundary]
- [Source: _bmad-output/planning-artifacts/architecture.md — Implementation Patterns & Anti-Patterns]
- [Source: DictlyKit/Sources/DictlyModels/DictlyError.swift — TranscriptionError enum]
- [Source: DictlyKit/Package.swift — Swift tools version 6.0, platforms iOS 17 / macOS 14]
- [Source: whisper.cpp README — C API usage, Metal/CoreML build flags, audio format requirements]
- [Source: _bmad-output/implementation-artifacts/4-7-tag-notes-and-session-summary-notes.md — Previous story learnings]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Build error: `WHISPER_VERSION` undeclared — added `-DWHISPER_VERSION=\"1.8.4\"` to compiler flags (CMake generates this automatically)
- Build error: `GGML_VERSION`/`GGML_COMMIT` undeclared — added version defines (0.9.8, 9386f239)
- Build error: Metal ObjC files use MRC — disabled ARC (`CLANG_ENABLE_OBJC_ARC = NO`) for WhisperLib target
- Build error: ggml-metal.metal `ggml-common.h` not found — Metal compiler uses different search paths; replaced with post-compile build script using `xcrun metal`/`xcrun metallib`
- Build error: linker missing C++ symbols — added `-lc++` to DictlyMac `OTHER_LDFLAGS`
- Build error: linker missing `ggml_vec_dot_*` — added ARM64-specific sources from `ggml-cpu/arch/arm/`
- Test runner error: `CFBundleIdentifier not found in Info.plist` — added required `CFBundle*` keys to Resources/Info.plist

### Completion Notes List

- ✅ whisper.cpp v1.8.4 added as git submodule at `Vendor/whisper.cpp`
- ✅ `WhisperLib` static library target created in project.yml with 27 C/C++/ObjC source files from whisper.cpp
- ✅ Metal shader compiled to `default.metallib` via post-compile build script (xcrun metal/metallib) with correct include paths; bundled in app resources
- ✅ All 5 required frameworks linked: Metal, MetalKit, MetalPerformanceShaders, CoreML, Accelerate
- ✅ `WhisperBridge.swift` implemented as `@Observable` class with lazy model loading, async transcription, and full PCM conversion pipeline
- ✅ `WhisperBridge-Bridging-Header.h` created at `DictlyMac/Transcription/`
- ✅ `DictlyError.TranscriptionError` extended with 3 new cases: `modelCorrupted`, `audioConversionFailed`, `audioFileNotFound`
- ✅ 6 WhisperBridge unit tests passing (integration test 6.7 skipped if model not present — by design)
- ✅ DictlyKit: 245 tests passing, 0 regressions
- ✅ DictlyMacTests: WhisperBridgeTests 6/6 pass; 2 pre-existing failures from Epic 4 (stories 4-5/4-6) unrelated to this story
- ✅ Model download: `cd Vendor/whisper.cpp && bash models/download-ggml-model.sh base.en`; place at `~/Library/Application Support/Dictly/Models/ggml-base.en.bin`; add `**/ggml-*.bin` to .gitignore (done)

### File List

- `Vendor/whisper.cpp/` — git submodule (new, v1.8.4)
- `.gitmodules` — created by `git submodule add`
- `DictlyMac/Transcription/WhisperBridge.swift` — new
- `DictlyMac/Transcription/WhisperBridge-Bridging-Header.h` — new
- `DictlyMac/project.yml` — modified (WhisperLib target, post-compile Metal shader script, bridging header, framework deps)
- `DictlyMac/DictlyMac.xcodeproj/project.pbxproj` — regenerated by xcodegen
- `DictlyKit/Sources/DictlyModels/DictlyError.swift` — modified (3 new TranscriptionError cases)
- `DictlyMac/Resources/Info.plist` — modified (added CFBundle* keys)
- `.gitignore` — modified (added whisper model file patterns)
- `DictlyMacTests/TranscriptionTests/WhisperBridgeTests.swift` — new

### Review Findings

- [x] [Review][Patch] Dangling `params.language` C string pointer [WhisperBridge.swift:84] — `"en".withCString { params.language = lang }` stored a pointer freed after the closure; removed block, default params already set `language = "en"`. **Fixed.**
- [x] [Review][Patch] Data race: concurrent `transcribe` calls shared `context`/`loadedModelURL` without synchronization [WhisperBridge.swift:28] — added `NSLock` + private `loadContext(for:)` helper that serializes model loading under the lock. **Fixed.**
- [x] [Review][Patch] `whisper_full` called with zero-length samples / nil `baseAddress` for empty audio [WhisperBridge.swift:97] — added `guard !samples.isEmpty` before `whisper_full` call; returns empty string for silent/empty audio. **Fixed.**
- [x] [Review][Defer] `AVAudioFrameCount` (UInt32) overflow for audio files >73 hours [WhisperBridge.swift:148] — deferred, unrealistic for session-notes use case

## Change Log

- 2026-04-03: Story 5.1 implemented — whisper.cpp v1.8.4 integration, WhisperBridge @Observable class, PCM audio conversion, DictlyError extension, unit tests, Metal shader build pipeline, model download documentation
- 2026-04-03: Code review patches applied — fixed dangling params.language pointer, added NSLock for concurrent model loading, guarded empty samples before whisper_full
