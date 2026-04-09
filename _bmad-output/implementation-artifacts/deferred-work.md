# Deferred Work

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
