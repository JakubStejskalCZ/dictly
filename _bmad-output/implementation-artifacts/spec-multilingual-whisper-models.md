---
title: 'Multilingual Whisper Model Support'
type: 'feature'
created: '2026-04-13'
status: 'done'
baseline_commit: '675b62d'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Dictly only offers English-only whisper models (`base.en`, `small.en`, `medium.en`) and hardcodes the language to English in transcription params. Non-English sessions (e.g. Czech) transcribe poorly or produce garbage output.

**Approach:** Add multilingual whisper models to the registry, expose a language setting (with auto-detect default), and pass the selected language through to `whisper_full_params`. Users can then download multilingual models and transcribe in any supported language.

## Boundaries & Constraints

**Always:** Keep existing `.en` models in the registry — they are faster/smaller for English-only users. Default language to `"auto"` (whisper auto-detection). Persist language preference in UserDefaults.

**Ask First:** Adding more model sizes beyond base/small/medium (e.g. large, turbo). Any changes to the bundled `base.en` model.

**Never:** Remove or rename existing English models. Change the Hugging Face download URL pattern. Alter the transcription audio extraction or segment windowing logic.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Auto-detect Czech | Multilingual model active, language="auto", Czech audio | Transcription in Czech | N/A |
| Explicit language | language="cs", multilingual model | Czech transcription | N/A |
| English model + non-English lang | `small.en` active, language="cs" | Warn user: English model selected for non-English language | Show alert suggesting multilingual model |
| Download multilingual model | User taps download on `medium` | Downloads `ggml-medium.bin` from HF | Same error handling as existing downloads |

</frozen-after-approval>

## Code Map

- `DictlyMac/Transcription/ModelManager.swift` -- Model registry & download; add multilingual entries
- `DictlyMac/Transcription/WhisperBridge.swift` -- Whisper params config; add language parameter to transcribe()
- `DictlyMac/Transcription/TranscriptionEngine.swift` -- Calls WhisperBridge; pass language through
- `DictlyMac/Transcription/ModelManagementView.swift` -- Model list UI; add language picker & model grouping

## Tasks & Acceptance

**Execution:**
- [x] `DictlyMac/Transcription/ModelManager.swift` -- Add multilingual models (`base`, `small`, `medium`) to registry with `isMultilingual` flag on `WhisperModel`. Add `selectedLanguage` UserDefaults property (default: `"auto"`). Add computed property to check if active model supports selected language.
- [x] `DictlyMac/Transcription/WhisperBridge.swift` -- Add `language: String` parameter to `transcribe()`. Set `params.language` via `withCString` to the provided language code. When `"auto"`, pass `"auto"` to let whisper auto-detect.
- [x] `DictlyMac/Transcription/TranscriptionEngine.swift` -- Read language from `ModelManager.selectedLanguage` and pass it to `WhisperBridge.transcribe()`.
- [x] `DictlyMac/Transcription/ModelManagementView.swift` -- Group models by language support (English-only / Multilingual). Add language picker (Picker with common languages + "Auto-detect"). Show warning when English model is active but non-English language selected.

**Acceptance Criteria:**
- Given a multilingual model is active and language is "auto", when transcribing Czech audio, then the output is Czech text (not English gibberish).
- Given `medium` model is selected in UI, when user taps download, then `ggml-medium.bin` downloads from Hugging Face and becomes selectable.
- Given language is set to "cs" and an English-only model is active, when user opens model management, then a warning suggests switching to a multilingual model.

## Verification

**Manual checks (if no CLI):**
- Open Model Management, verify multilingual models appear grouped separately from English models
- Download a multilingual model, select it, set language to Czech
- Transcribe a Czech audio tag and verify output is Czech text
- Switch to English model with Czech language and verify warning appears

## Suggested Review Order

**Language plumbing (core change)**

- New `WhisperLanguage` type and multilingual model entries in registry
  [`ModelManager.swift:28`](../../DictlyMac/Transcription/ModelManager.swift#L28)

- Language param added to whisper C-interop bridge with strdup safety
  [`WhisperBridge.swift:46`](../../DictlyMac/Transcription/WhisperBridge.swift#L46)

- Language threaded from ModelManager through to bridge call
  [`TranscriptionEngine.swift:202`](../../DictlyMac/Transcription/TranscriptionEngine.swift#L202)

**Language persistence & mismatch detection**

- `selectLanguage()` and `hasLanguageMismatch` computed property
  [`ModelManager.swift:217`](../../DictlyMac/Transcription/ModelManager.swift#L217)

**UI: picker, grouping, warning**

- Language picker binding and mismatch warning banner
  [`ModelManagementView.swift:68`](../../DictlyMac/Transcription/ModelManagementView.swift#L68)

- Model list sectioned into English-only / Multilingual
  [`ModelManagementView.swift:107`](../../DictlyMac/Transcription/ModelManagementView.swift#L107)
