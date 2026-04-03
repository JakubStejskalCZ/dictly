# Deferred Work

## Deferred from: code review of 5-4-view-and-edit-transcription-text (2026-04-03)

- Delete tag while transcription editor focused may attempt a write to the deleted model object — alert dialog naturally dismisses focus before delete fires, making this a no-op in practice; same pattern as notes commit. Address if delete can be triggered programmatically without focus dismissal.
- Tests cannot directly cover the `commitTranscription` stale-capture guard path (`selectedTag?.uuid != tag.uuid`) — Swift `private` method limitation; model-layer tests are the correct granularity per project convention.

## Deferred from: code review of 5-3-per-tag-and-batch-transcription (2026-04-03)

- Cancellation not forwarded into `bridge.transcribe` (`WhisperBridge.swift`) — Swift cooperative cancellation cannot be injected into the whisper.cpp FFI layer; batch cancellation is best-effort (between tags). Address when/if WhisperBridge adds cancellation support.
- `isBatchTranscribing` stays `true` while the current tag finishes after `cancelBatch()` — by-design: the defer block in `transcribeAllTags` resets it after the current tag completes. No action needed unless UX decides immediate UI reset is required.
- Temp CAF segment files accumulate on hard crash — `extractAudioSegment` uses `defer` for cleanup on normal exits, but crash leaves orphaned `.caf` files in `temporaryDirectory`. OS clears tmp on reboot; acceptable until a periodic cleanup pass is added.

## Deferred from: code review of 4-6-retroactive-tag-placement (2026-04-02)

- F13: `RightClickView.rightMouseDown` uses `convert(event.locationInWindow, from: nil)` which produces incorrect coordinates when the view is in a secondary/non-key window. Only affects multi-window scenarios not in scope for this story.

## Deferred from: code review of story 1-1 (2026-04-01)

- `fatalError` on `ModelContainer` failure in `DictlyiOSApp.swift` and `DictlyMacApp.swift` — no recovery path if store is corrupted or migration fails. Consider retry-with-delete or error UI in a future story.
- `Session.locationLatitude` and `Session.locationLongitude` are independent optionals — no enforcement that both are set or both are nil. Add validation when location features are implemented.
- App-level test targets (`DictlyiOSTests`, `DictlyMacTests`) exist as directories but are not wired into `project.yml` — add when first app-layer tests are written.

## Deferred from: code review of story 1-2 (2026-04-01)

- WCAG AA contrast claims in `DictlyColors.TagCategory` doc comment may be inaccurate for some color/surface combinations (e.g., `story` #D97706 on light surface #F2EDE7). Verify actual contrast ratios and update or remove the claim.
- No `accessibilityReduceTransparency`/`increaseContrast` palette handling — background (#FAF8F5) and surface (#F2EDE7) are very close in lightness, making boundaries hard to distinguish for some users. Consider an increased-contrast palette variant.

## Deferred from: code review of 1-3-campaign-management (2026-04-01)

- `campaign.sessions.count` in `CampaignRowView` triggers a lazy relationship fault on every row render. With many campaigns this causes N relationship faults during list scroll. Consider prefetching or a denormalized session count property when scaling.

## Deferred from: code review of 1-4-session-organization-within-campaigns (2026-04-01)

- `formatDuration` in `SessionListRow` does not guard against negative `TimeInterval` values. Currently impossible (duration set to 0 on creation, real values from recording engine in Story 2.x), but add a `max(0, duration)` clamp when recording engine is implemented.
- `SessionListRow.dateFormatter` uses system locale without explicit locale setting — pre-existing pattern from `CampaignRowView`. May produce unexpected date formats on non-Gregorian calendars. Consider standardizing locale handling across all formatters.

## Deferred from: code review of 1-5-tag-category-and-tag-management (2026-04-01)

- `DefaultTagSeeder.seedIfNeeded` performs a read-then-write (`fetchCount` → insert loop) with no transaction lock. In multi-window scenarios, concurrent calls could both observe `existingCount == 0` and insert duplicate defaults. Extremely unlikely in single-window iOS app but should be addressed if multi-window support is added.

## Deferred from: code review of 1-6-tag-category-sync-via-icloud-key-value-store (2026-04-01)

- iCloud KVS 1 MB total store limit is not checked before `store.set(data:forKey:)`. Unit test validates 200 categories fit easily, but no runtime guard exists. Consider adding a size check before writing if category volume may grow significantly.
- Tag↔category linkage uses `categoryName` string rather than UUID. Rename cascades work (both local and sync), but concurrent renames on different devices can orphan tags on the losing device. Pre-existing architectural decision from Story 1.5 — address if cross-device rename conflicts become a user issue.

## Deferred from: code review of 1-7-storage-management (2026-04-01)

- `audioFilePath` stores an absolute path which will break on app reinstall/iCloud restore (container UUID changes). Epic 2 should store paths relative to the Recordings directory and reconstruct full URLs at runtime via `audioStorageDirectory()`.
- `audioFilePath` is not validated as a regular file — if set to a directory path, `deleteAudioFile` would recursively delete it. Add a file-type guard when the recording engine (Epic 2) writes the path.
- Campaign cascade deletion (`modelContext.delete(campaign)`) removes Session models but does not delete orphaned audio files from disk. Add cleanup logic in the campaign delete flow or implement a periodic orphan-file scanner.

## Deferred from: code review of 2-1-audio-recording-engine-with-background-persistence (2026-04-01)

- No microphone permission check before recording — `startRecording` does not call `AVAudioApplication.requestRecordPermission` and relies on engine failure for permission denial. Story 2.3 recording UI should add a permission gate with the already-defined `.permissionDenied` error.
- `recoverOrphanedRecordings` runs synchronous file I/O on the main actor during app launch. For many orphaned recordings with large files, this could block the UI. Consider making it async or dispatching to a background queue.

## Deferred from: code review of 2-2-pause-resume-and-phone-call-interruption-handling (2026-04-01)

## Deferred from: code review of 2-3-recording-screen-layout-and-status-indicators (2026-04-01)

- VoiceOver accessibility label collapses `.paused` and `.systemInterrupted` into same "Paused." string — user relying on VoiceOver cannot distinguish phone call interruption from manual pause. Needs spec clarification on whether distinct labels are required.

## Deferred from: code review of 2-2 (continued)

- `isStopping` is declared `nonisolated(unsafe)` and written from `@MainActor` while read from the AVAudioEngine tap callback thread. No memory barrier guarantees visibility ordering. In practice ARM's strong ordering makes this safe, but it is a formal data race by Swift concurrency rules. Consider using `Atomic<Bool>` when adopting Swift 6 atomics.
- `totalPauseDuration` can go negative if the system clock moves backward (DST change, NTP correction) between `pauseStartDate = Date()` and `Date().timeIntervalSince(pauseStart)` on resume, causing the elapsed time to overshoot. Extremely unlikely for a recording session, but could be guarded with `max(0, ...)` on the increment.

## Deferred from: code review of story 2-4 (2026-04-02)

- CategoryTabBar fade mask always clips first/last tab edges via leading/trailing LinearGradient, even when content does not overflow the scroll view. Should conditionally apply mask only when scrollable.
- DictlyTypography.caption is 13pt (iOS) but story 2.4 spec calls for 11pt caption on TagCard. Shared design token — changing it would affect all caption usages across the app.
- TaggingServiceTests anchorTime assertion is tautological — recorder is never started, so elapsedTime is always 0. Test verifies 0 == 0.
- No test coverage for placeTag save-failure path (context.save() throwing).
- selectedCategory in TagPalette can become stale if categories are removed while the palette is visible. Only the empty→non-empty transition is handled.
- Tag↔category matching uses String comparison (categoryName == category.name). Renames can orphan tags from their category tab.
- context.save() is called synchronously per tap with no batching/debounce. Could cause frame drops on older devices during rapid tapping.
- No UI affordance to deselect category filter and view all tags across categories.
- Color(hexString:) produces black for empty or malformed hex strings. Pre-existing extension — no fallback.

## Deferred from: code review of story 2-5 (2026-04-02)

- @AppStorage key `"rewindDuration"` and default value `10.0` duplicated in `SettingsScreen.swift` and `TagPalette.swift`. Story 2.6 will likely add a third declaration. Consider extracting to a shared constant.
- @AppStorage accepts arbitrary Double values from UserDefaults (e.g., via MDM or manual defaults write). No validation exists outside the Picker UI. An out-of-range value (e.g., 3600.0) would cause all tags to anchor at time 0 for the first hour.
- `placeTag()` reads `sessionRecorder.elapsedTime` internally at call time. Story 2.6's custom tag sheet needs to capture elapsed time at first-tap and pass it to a deferred `placeTag` call — the current API doesn't support this. Story 2.6 should add an overload or parameter for pre-captured elapsed time.
- AC #4 "zero tag loss on force-quit" is not testable in unit tests. Relies on SwiftData `context.save()` durability — verified by manual/integration testing only.

## Deferred from: code review of story 2-6 (2026-04-02)

- `capturedAnchor` in `TaggingService` could leak (remain non-nil) if the view is removed from the hierarchy between the "+" button tap and the sheet presentation completing. Extremely unlikely SwiftUI edge case — the orphaned anchor would be harmlessly overwritten on the next capture or discarded on the next sheet dismiss.

## Deferred from: code review of story 2-7 (2026-04-02)

- Tag `categoryName` could be an empty string, rendering a blank section header in SessionSummarySheet's grouped tag list. Pre-existing data model concern — all current tag creation paths populate `categoryName` from a TagCategory, but no model-level validation prevents an empty string.
- Stop recording ViewModel tests (`testStopRecording_callsRecorderStop`, etc.) only verify behavior on a non-recording recorder due to hardware dependency (AVAudioEngine requires a real audio input). The actual stop-while-recording path is covered by integration/manual testing.

## Deferred from: code review of story 3-1 (2026-04-02)

- Race condition on concurrent `serialize()` calls to the same URL can interleave file writes — caller responsibility to serialize access.
- `deserialize()` does not check if URL is a directory vs a regular file — functionally correct (throws `.bundleCorrupted`) but diagnostics are misleading.
- `PauseInterval` has no invariant validation (start <= end, non-negative) — pre-existing struct, affects all consumers.
- Corrupted `pauseIntervalsJSON` on source `Session` silently becomes empty `pauseIntervals` array in `toDTO()` — pre-existing getter behavior in `PauseInterval.swift`.
- `CampaignDTO.descriptionText` is non-optional `String` — if a future bundle version makes it optional/absent, decode fails instead of defaulting. Forward-compatibility risk.

## Deferred from: code review of story 3-2 (2026-04-02)

- Main-thread blocking I/O in `TransferService._prepareBundleSync` — `Data(contentsOf:)` reads entire audio file into memory on the main actor. For large recordings (100+ MB) this freezes UI and risks jetsam kill. Requires `BundleSerializer` API change to accept file URLs instead of `Data`, or an off-main-actor preparation path.
- Nested 3-level sheet stack: `SessionSummarySheet` → `TransferPrompt` → `ActivityViewControllerRepresentable`. On iOS 16 and earlier, `UIActivityViewController` inside a double-nested SwiftUI sheet may fail to present. Consider flattening to `fullScreenCover` or dismissing parent before presenting.
- Multiple `.sheet(item:)` modifiers in `CampaignDetailScreen` (edit, transfer, recording) can queue presentations unexpectedly. Pre-existing pattern — consider enum-based `ActiveSheet` state in a future cleanup.
- Test audio files are written to real `AudioFileManager.audioStorageDirectory()`, not a sandboxed temp path. A test crash skipping `tearDown` pollutes the app's audio storage. Pre-existing test pattern across transfer tests.
- `TransferState` Equatable compares `.failed` errors via `localizedDescription` string — lossy and can suppress consecutive distinct error transitions. Pragmatic for mixed UIKit `Error` types but could miss state changes.

## Deferred from: code review of story 3-3 (2026-04-02)

- No authentication on TCP listener — any device on the local network can push data to the receiver. Spec states MVP without encryption; platform-level local network security is sufficient for now.
- UInt32 overflow on payloads > 4GB — the 4-byte length prefix cannot represent payloads larger than ~4 GB. Unrealistic for audio sessions (a 4-hour session at 128kbps AAC is ~230 MB).
- Audio data double-loaded in memory during payload prep — `preparePayload` loads audio into `Data` and also writes it to a temp bundle via `BundleSerializer`. Inherent to the approach; the temp bundle is cleaned up on completion.
- `TransferError.timeout` declared but never raised — added per spec task 1.1 but the 5-second no-peers timeout is handled via UI state (`showNoPeersMessage`) rather than through the error state machine.

## Deferred from: code review of story 3-4 (2026-04-02)

- `lastContext` stores a strong reference to `ModelContext` in `ImportService` — stale context risk if `ModelContainer` is deallocated. Acceptable for current app lifecycle where container is static, but fragile if architecture changes.
- Replace flow (`replaceExisting`) is not atomic — deletes old session then re-imports. If reimport fails after delete, user's original session is permanently lost with no recovery path.
- All SwiftData operations (fetch, insert, save, delete) run on `@MainActor` — large bundles with many tags or big audio files may block the UI thread. Consider background `ModelContext` for heavy operations.
- `retry()` after network receiver failure may use a stale `lastBundleURL` that was already cleaned up by `LocalNetworkReceiver.reset()`. No coordination between receiver cleanup and ImportService retry timing.

## Deferred from: code review of story 4-1-mac-session-review-layout (2026-04-02)

- Negative/NaN `anchorTime` in `formatTimestamp` produces garbled/negative timestamp strings. `Tag.anchorTime` (`TimeInterval`) has no lower-bound constraint in the model. Pre-existing model validation gap.
- SwiftData model lifecycle: `selectedTag` and `selectedSession` (`@State`) can hold strong references to faulted/deleted objects if a `Session` or `Tag` is deleted externally while the review screen is displayed. Pre-existing pattern across the app.

## Deferred from: code review of story 4-2 (2026-04-02)

- Multi-channel audio only reads channel 0 in `WaveformDataProvider.extractFromFile`. For stereo/surround files, channels 1–N are silently ignored. Pre-existing architectural decision — waveform shows peak of channel 0 only.
- Missing test for unknown category color (`DictlyColors.textSecondary`) — the color mapping lives in `CategoryColorHelper` (story 4.1), not tested in waveform context.

## Deferred from: code review of story 4-3 (2026-04-02)

- `AVAudioEngineConfigurationChange` not handled — audio route changes (Bluetooth headphones connect/disconnect, USB audio unplugged) stop the engine silently. `isPlaying` stays true with no audio output. Handle in a future story when audio resilience is prioritized.
- `viewWidth` state may be stale during simultaneous window-resize + drag — gesture uses stored `@State viewWidth` rather than live geometry. Edge case; only affects window-resize-while-dragging scenario.
- `isPlaying=true` set before `playerNode.play()` potential failure — if the engine stops unexpectedly (route change, resource exhaustion), the timer detects `playerNode.isPlaying=false` and self-corrects via `handlePlaybackFinished`. Pre-existing pattern; acceptable with the route-change deferred above.

## Deferred from: code review of story 5-1-whisper-cpp-integration-and-whisperbridge (2026-04-03)

- `AVAudioFrameCount` (UInt32) overflow in `convertToPCM` for audio files longer than ~73 hours — `Double(inputFrameCount) * targetFormat.sampleRate / inputSampleRate` silently wraps to a much smaller `UInt32`, allocating an undersized output buffer. Unrealistic for session-notes use case; address if very long recordings become supported.

## Deferred from: code review of story 4-4 (2026-04-02)

- `AccessibilityNotification.LayoutChanged` posted on every keystroke in search field — consider debounce to avoid interrupting VoiceOver on every character typed. `TagSidebar.swift`.
- O(n) tag count scan per category pill (`session.tags.filter { $0.categoryName == category.name }.count`) runs on every render pass. Optimize with a single grouped dictionary for sessions with many tags. `TagSidebar.swift`.
- `sessionID: UUID` parameter in `TagSidebar` is always `session.uuid` at call site — redundant; could be derived internally. `TagSidebar.swift` / `SessionReviewScreen.swift`.
- `TagSidebarFilterTests`: in-memory `ModelContainer` + `ModelContext` created in `setUp` but never used by pure-function tests — dead infrastructure. Remove or convert to integration tests in a future refactor. `TagSidebarFilterTests.swift`.
