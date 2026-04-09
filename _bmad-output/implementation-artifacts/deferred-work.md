# Deferred Work

## E3: Cross-device migration race with AppStorage
`didMigrateToTagPacks` is stored in `UserDefaults` (not synced via iCloud). If two devices update at different times, the migration order is racy. Consider using a SwiftData-persisted flag or iCloud KVS key for coordination.

## E6: No @MainActor on DefaultTagSeeder
All current callers use `container.mainContext` which is `@MainActor`-isolated, so this is safe today. But the static methods accept any `ModelContext`. A future background caller could violate SwiftData's threading contract. Consider adding `@MainActor` annotation.

## R1: SyncableCategoryTests missing @MainActor
`SyncableCategoryTests` (CategorySyncServiceTests.swift) is not annotated `@MainActor`, violating the project testing convention. Pre-existing issue — all test classes should be `@MainActor final class`.

## R2: Unknown pack IDs linger in iCloud KVS
If a pack ID was pushed from an older app version that included a pack since removed from `TagPackRegistry`, the ID persists in KVS indefinitely. Pull skips it (unknown), push doesn't include it (not locally installed), but the originating device keeps re-pushing it. No visible user impact but causes minor KVS pollution.

## R3: Partial pack install in installSelected() doesn't push
If `DefaultTagSeeder.installPack` throws midway through the batch loop in `TagPackPickerView.installSelected()`, successfully installed packs are never pushed to cloud. Pre-existing issue in both iOS and Mac TagPackPickerView.
