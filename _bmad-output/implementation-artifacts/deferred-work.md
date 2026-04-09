# Deferred Work

## E3: Cross-device migration race with AppStorage
`didMigrateToTagPacks` is stored in `UserDefaults` (not synced via iCloud). If two devices update at different times, the migration order is racy. Consider using a SwiftData-persisted flag or iCloud KVS key for coordination.

## E6: No @MainActor on DefaultTagSeeder
All current callers use `container.mainContext` which is `@MainActor`-isolated, so this is safe today. But the static methods accept any `ModelContext`. A future background caller could violate SwiftData's threading contract. Consider adding `@MainActor` annotation.
