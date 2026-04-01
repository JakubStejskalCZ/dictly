# Deferred Work

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
