# Deferred Work

## From spec-fix-dji-mic-recording-hang (review 2026-04-11)

### Mid-recording route changes can break the open file
`SessionRecorder.handleConfigChange` (`DictlyiOS/Recording/SessionRecorder.swift:443`) and `resumeRecording` (`:247`) reinstall the input tap using the *current* `inputNode.outputFormat(forBus: 0)`, but the `outputFile` was created with the format that was active at `startRecording` time. If the user starts on the built-in mic and then plugs in (or unplugs) a USB / Bluetooth mic mid-recording, the new tap buffers no longer match the file's `processingFormat` and every `file.write(from:)` throws. After 10 consecutive failures the fatal-failure path stops the recording (`:494`). The current spec only addresses the case where the external mic is connected *before* recording starts; the mid-flight transition is a separate latent bug. Fix candidates: re-create the file on config change, or install a converter from the new tap format to the file's processing format.

### `recoverOrphanedRecordings` salvage edge case
`SessionRecorder.swift:351` deletes files where `audioFile.length == 0` even though bytes may exist on disk (header not finalized after a crash mid-write). Pre-existing; not introduced by this fix. Worth a closer look if users report missing crash-recovered audio.

### `pauseRecording` force-unwraps `recordingStartDate`
`SessionRecorder.swift:213`: `pauseIntervalStart = Date().timeIntervalSince(recordingStartDate!)`. Safe today only because everything runs on `@MainActor`. Any future change that makes `pauseRecording` reachable before `startRecording` finishes assigning `recordingStartDate` would crash. Replace with a `guard let` or assign the date earlier in `startRecording`.

### UI elapsed time keeps ticking after silent config-change failure
If `handleConfigChange` fails to restart the engine (`SessionRecorder.swift:447-451`), `isRecording` stays true and `isPaused` stays false, so the on-screen timer keeps advancing while no audio is captured. Authoritative file duration on stop is correct, but the UI lies during the dead interval. Surface a banner or stop the timer when the engine restart fails.

---

## E3: Cross-device migration race with AppStorage — RESOLVED (no change needed)
Analyzed: `didMigrateToTagPacks` correctly uses local `@AppStorage` because each device must independently migrate its own SwiftData store. Migration runs before `startObserving`, so ordering is safe. KVS sync handles convergence after migration.

## R2: Unknown pack IDs linger in iCloud KVS — RESOLVED (no change needed)
Analyzed: `installedPackIDs` only returns IDs from `TagPackRegistry.all`. Unknown IDs from old devices are ignored on pull. Minor KVS pollution with no user impact.

## Resolved in feat/sync-template-tags-kvs:
- **E6**: Added `@MainActor` to `DefaultTagSeeder`
- **R1**: Added `@MainActor` to `SyncableCategoryTests`
- **R3**: Moved push calls after do/catch in `installSelected()` (iOS + Mac)
- **R4**: Filtered `TagListScreen` to only show template tags (`session == nil`)
- **R5**: Moved logger to file scope in `CategorySyncService`
