---
title: 'Fix DJI Mic 2 RX recording hang'
type: 'bugfix'
created: '2026-04-11'
status: 'done'
context: []
baseline_commit: '1231c253eaddc546be9f6d01281e42e5b2a92da5'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** When the user starts a recording while a DJI Mic 2 RX (USB-C external mic) is already plugged into the iPhone, `SessionRecorder.startRecording` throws because the file is hardcoded to mono 44.1 kHz while the USB mic delivers a different native format (typically stereo 48 kHz). The error is caught in `RecordingScreen.startRecording`, which sets `recordingFailed = true` for an alert — but `viewModel` is left `nil`, and the screen body conditionally renders the entire recording UI (timer, Stop button, dismiss affordance) on `viewModel != nil`. After dismissing the alert, the user is stranded on a blank full-screen modal with no escape and must force-quit the app.

**Approach:** (1) Root cause: build the AVAudioFile output settings from the live input node format (sample rate + channel count) instead of hardcoded 44.1 kHz mono, and log the input format on every start so future device-specific issues are diagnosable. (2) Defense in depth: ensure `RecordingScreen` always presents an escape hatch when start fails — automatically dismiss the modal when the failure alert is acknowledged.

## Boundaries & Constraints

**Always:**
- Output remains AAC (`kAudioFormatMPEG4AAC`) in an `.m4a` container — only sample rate and channel count adapt to the input device.
- Bitrate continues to come from `SessionRecorder.bitrate(for:)` based on the `audioQuality` UserDefault.
- The recording screen must always offer the user a way out — either a working Stop button or automatic dismissal on failure.
- Existing audio session category (`.record`, `.allowBluetooth`) is preserved.
- The format-validation guard (channels > 0, sampleRate > 0) stays in place.

**Ask First:**
- Any change to the AVAudioSession category, mode, or options.
- Adding a downmix-to-mono converter (out of scope for this fix — accept stereo files when the device is stereo).
- Calling `setPreferredInput` / changing route negotiation logic.

**Never:**
- Don't introduce a new audio-format converter pipeline.
- Don't change the pause/resume/interruption handling.
- Don't alter `Session` model or persistence schema.
- Don't add retry-on-failure loops inside `startRecording`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Built-in mic, fresh start | No external audio device; tap Record | Recording starts, file = mono @ device SR (e.g. 48 kHz), timer ticks, Stop works | N/A |
| DJI Mic 2 RX pre-plugged | USB-C mic active before tap Record | Recording starts, file SR/channels match input node format, timer ticks, Stop works | N/A |
| Bluetooth mic active | BT audio device routed before tap Record | Same as DJI case — file matches input format | N/A |
| Genuinely invalid input | `inputNode.outputFormat` reports 0 channels or 0 SR | `startRecording` throws `audioSessionSetupFailed`; alert shown; **modal auto-dismisses** when alert is acknowledged | User returns to prior screen, can retry |
| File-creation failure post-fix | Disk full / permission denied creating `.m4a` | `startRecording` throws `fileCreationFailed`; alert shown; modal auto-dismisses | User returns to prior screen |

</frozen-after-approval>

## Code Map

- `DictlyiOS/Recording/SessionRecorder.swift:88-93` — hardcoded `settings` dictionary (mono, 44100). Source of the format mismatch.
- `DictlyiOS/Recording/SessionRecorder.swift:105-114` — input node + format validation guard. Add explicit logging of `channelCount` and `sampleRate` here.
- `DictlyiOS/Recording/SessionRecorder.swift:127-134` — `engine.start()` failure path. Already correct; verify it triggers the new dismiss-on-failure UI flow.
- `DictlyiOS/Recording/RecordingScreen.swift:24` — `@State private var recordingFailed = false`.
- `DictlyiOS/Recording/RecordingScreen.swift:88-92` — failure alert. Needs an `onDismiss`/state observer to dismiss the modal.
- `DictlyiOS/Recording/RecordingScreen.swift:188-198` — `startRecording()` catch path that sets `recordingFailed = true` but leaves `viewModel` nil.
- `DictlyiOS/Recording/RecordingScreen.swift:32-67` — body conditioned on `viewModel != nil`; explains why the user sees a blank screen.

## Tasks & Acceptance

**Execution:**
- [x] `DictlyiOS/Recording/SessionRecorder.swift` — In `startRecording`, after the format validation guard, derive `settings` from `inputFormat`: use `inputFormat.sampleRate` for `AVSampleRateKey` and `Int(inputFormat.channelCount)` for `AVNumberOfChannelsKey`. Keep `AVFormatIDKey = kAudioFormatMPEG4AAC` and `AVEncoderBitRateKey = bitRate`. Move the file-creation block to after this so it uses the new settings.
- [x] `DictlyiOS/Recording/SessionRecorder.swift` — Replace the existing `"Audio input: {portName}"` log with a richer line that also logs `inputFormat.channelCount` and `inputFormat.sampleRate` (and optionally `commonFormat.rawValue`). Log it once per `startRecording` call right after the format guard passes.
- [x] `DictlyiOS/Recording/RecordingScreen.swift` — Make the failure alert dismiss the modal. Add a `Button("OK", role: .cancel) { dismiss() }` inside the existing `.alert("Recording Failed", ...)`, replacing the no-op cancel. The full-screen recording modal must close when the user acknowledges the alert.
- [x] `DictlyiOS/Recording/RecordingScreen.swift` — In `startRecording()` catch path, no logic change needed beyond the alert, but verify `recordingFailed = true` still fires; the dismiss happens via the alert button.

**Acceptance Criteria:**
- Given the DJI Mic 2 RX is plugged in via USB-C before the user opens the recording screen, when they tap Record, then the timer advances from 00:00 in real time, the Stop button is responsive, and the resulting `.m4a` file plays back with valid audio.
- Given any device whose `inputNode.outputFormat(forBus: 0)` returns sample rate ≠ 44100 or channel count ≠ 1, when recording starts, then no AVAudioEngine format-mismatch error is logged and `file.write(from:)` succeeds for every tap buffer.
- Given `startRecording` throws for any reason (e.g. simulated by toggling airplane mode + revoking mic mid-flow, or any genuinely invalid input format), when the user taps OK on the "Recording Failed" alert, then the full-screen recording modal dismisses and the user is returned to the previous screen without needing to force-quit.
- Given a successful recording start with the built-in mic (regression check), when the user records and stops normally, then existing behavior is preserved: file created, duration persisted, session summary shown.

## Design Notes

`AVAudioFile(forWriting:settings:)` derives its `processingFormat` (PCM) from `AVSampleRateKey` and `AVNumberOfChannelsKey`. `AVAudioFile.write(from:)` requires the buffer's format to match `processingFormat` exactly — there is no implicit conversion. Today the file is mono 44.1 kHz, but the input tap is installed with the input node's native format (e.g. stereo 48 kHz from a USB device). Every write throws, and `engine.start()` itself can also fail when the tap format is incompatible with downstream nodes.

By deriving `settings` from `inputFormat`, the file's processing format matches the tap buffers byte-for-byte. AAC-in-M4A supports stereo and arbitrary common sample rates, so the encoder happily accepts whatever the device delivers. We accept that USB stereo mics will produce ~2x larger files than the prior built-in-mic recordings; downmix is explicitly out of scope here.

The screen-dismiss fix is independent of root cause: any future failure in `startRecording` would have produced the same hang, so the escape hatch is worth fixing on its own merits.

## Verification

**Commands:**
- `xcodebuild -project DictlyiOS/Dictly.xcodeproj -scheme DictlyiOS -destination 'generic/platform=iOS' build` — expected: build succeeds.

**Manual checks (if no CLI):**
- Plug DJI Mic 2 RX into iPhone via USB-C *before* opening the app. Tap Record. Confirm: timer advances, Stop responds, recorded file plays back.
- Repeat with built-in mic only (regression). Confirm: timer advances, Stop responds, file plays back.
- Watch Console.app filtered by `subsystem == com.dictly.ios` and category `recording`. Confirm a single line per start that includes the input port name AND `channels=` / `sampleRate=` values.
- Force a failure path (e.g. temporarily inject a throw at the format guard via debugger) and confirm tapping OK on the "Recording Failed" alert dismisses the modal back to the previous screen.

## Suggested Review Order

**Root cause: derive file format from the live input node**

- Engine + format are now read up front so the file matches the device's native rate/channels.
  [`SessionRecorder.swift:74`](../../DictlyiOS/Recording/SessionRecorder.swift#L74)

- Format validation guard moves with the engine; same semantics, earlier checkpoint.
  [`SessionRecorder.swift:79`](../../DictlyiOS/Recording/SessionRecorder.swift#L79)

- File settings now use `inputFormat.sampleRate` and `inputFormat.channelCount` instead of hardcoded mono 44.1 kHz.
  [`SessionRecorder.swift:102`](../../DictlyiOS/Recording/SessionRecorder.swift#L102)

**Diagnostics: richer start log**

- Single info line per start now includes port name + channels + sampleRate for future device debugging.
  [`SessionRecorder.swift:87`](../../DictlyiOS/Recording/SessionRecorder.swift#L87)

**UX escape hatch on failure**

- "Recording Failed" alert OK button now calls `dismiss()` so users can never get stranded on a blank modal.
  [`RecordingScreen.swift:89`](../../DictlyiOS/Recording/RecordingScreen.swift#L89)

**Cosmetic**

- Buffer size comment refreshed — sample rate is no longer hardcoded.
  [`SessionRecorder.swift:118`](../../DictlyiOS/Recording/SessionRecorder.swift#L118)
