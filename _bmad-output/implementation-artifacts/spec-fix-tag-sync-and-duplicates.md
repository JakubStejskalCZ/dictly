---
title: 'Fix iCloud tag pack sync and custom tag duplication on iOS'
type: 'bugfix'
created: '2026-04-09'
status: 'done'
baseline_commit: 'bf9f4ce'
context:
  - '_bmad-output/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** (1) Tags don't sync across devices because `CategorySyncService` only syncs `TagCategory` metadata — the installed pack IDs and their template `Tag` records are never propagated. Device B sees synced categories but empty palettes. (2) Custom tags created via `CustomTagSheet` on iOS are duplicated because `onDisappear` races with the Save button's `didSave` state update, firing `onSave` a second time.

**Approach:** (1) Extend `CategorySyncService` to also sync the set of installed pack IDs via iCloud KVS. On pull, auto-install any missing packs locally — template tags use deterministic UUIDs so they naturally deduplicate. (2) Remove the `onDisappear` safety-net from `CustomTagSheet` and instead use the `.sheet(onDismiss:)` callback in `TagPalette` (which already exists) to handle the discard path.

## Boundaries & Constraints

**Always:** Use existing `NSUbiquitousKeyValueStore` for pack ID sync (no CloudKit container needed). Preserve deterministic UUID seeding in `DefaultTagSeeder`. Sync pack installs and uninstalls bidirectionally.

**Ask First:** If a device has manually modified tags from a synced pack (e.g. deleted some template tags), should re-syncing the pack ID restore them?

**Never:** Do not sync individual `Tag` records or `Session` data. Do not add CloudKit container configuration. Do not change the `Tag` or `TagCategory` model schemas.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Pack installed on Device A | User installs "Podcast" pack on Device A | Pack ID pushed to KVS; Device B pulls and auto-installs "Podcast" categories + template tags | If install fails, log error, skip pack |
| Pack uninstalled on Device A | User removes "Podcast" pack on Device A | Pack ID removed from KVS; Device B pulls and auto-uninstalls "Podcast" | If uninstall fails, log error, keep local state |
| Both devices install same pack | Same pack installed independently | Deterministic UUIDs prevent duplicates; KVS converges to same set | N/A |
| Custom tag Save button | User types label, taps Save | Tag created once, sheet dismissed | N/A |
| Custom tag swipe-dismiss | User types label, swipes sheet down | No tag created, anchor discarded | N/A |
| Custom tag Cancel button | User taps Cancel | No tag created, anchor discarded | N/A |

</frozen-after-approval>

## Code Map

- `DictlyKit/Sources/DictlyStorage/CategorySyncService.swift` -- Add pack ID sync alongside category sync
- `DictlyiOS/Tagging/CustomTagSheet.swift` -- Remove `onDisappear` safety-net that causes duplication
- `DictlyiOS/Tagging/TagPalette.swift` -- Already has `onDismiss` handler; no changes expected
- `DictlyKit/Sources/DictlyModels/DefaultTagSeeder.swift` -- Used for pack install/uninstall on sync pull
- `DictlyiOS/App/DictlyiOSApp.swift` -- May need sync timing adjustment
- `DictlyMac/App/DictlyMacApp.swift` -- Same sync wiring as iOS
- `DictlyiOS/Tagging/TagPackPickerView.swift` -- Push pack IDs after install/uninstall
- `DictlyMac/Settings/TagPackPickerView.swift` -- Push pack IDs after install/uninstall

## Tasks & Acceptance

**Execution:**
- [x] `DictlyKit/Sources/DictlyStorage/CategorySyncService.swift` -- Add `pushPackIDsToCloud()` and `pullPackIDsFromCloud()` methods using a new KVS key `"installedPackIDs"`. On pull, diff remote vs local installed packs and call `DefaultTagSeeder.installPack` / `uninstallPack` accordingly. Call pull on `startObserving` and on external change notification. -- Enables bidirectional pack sync
- [x] `DictlyiOS/Tagging/TagPackPickerView.swift` -- Call `syncService.pushPackIDsToCloud()` after each pack install/uninstall operation -- Propagates pack changes to other devices
- [x] `DictlyMac/Settings/TagPackPickerView.swift` -- Same as iOS: call `syncService.pushPackIDsToCloud()` after pack install/uninstall -- Mac parity
- [x] `DictlyiOS/Tagging/CustomTagSheet.swift` -- Remove the `.onDisappear` block (lines 75-79) entirely -- Eliminates duplicate tag creation race condition
- [x] `DictlyKit/Tests/DictlyStorageTests/CategorySyncServiceTests.swift` -- Add tests for pack ID sync: push/pull round-trip, install-on-pull, uninstall-on-pull, idempotent re-install -- Validates sync correctness

**Acceptance Criteria:**
- Given a pack installed on Device A, when Device B receives the KVS change, then Device B auto-installs the same pack with identical categories and template tags
- Given a pack uninstalled on Device A, when Device B receives the KVS change, then Device B auto-uninstalls the pack
- Given a user creating a custom tag and tapping Save, when the sheet dismisses, then exactly one tag is created
- Given a user swiping the custom tag sheet away without saving, when the sheet dismisses, then no tag is created and the anchor is discarded

## Verification

**Manual checks (if no CLI):**
- Install a pack on one device, verify it appears on the second device within ~30s
- Uninstall a pack on one device, verify it disappears from the second device
- Create a custom tag via the "+" button on iOS, verify only one tag appears in the session
- Swipe-dismiss the custom tag sheet after typing a label, verify no tag is created

## Suggested Review Order

**Pack ID sync (core logic)**

- New KVS key and bidirectional sync methods — entry point for the entire change
  [`CategorySyncService.swift:34`](../../DictlyKit/Sources/DictlyStorage/CategorySyncService.swift#L34)

- `processPackIDsPayload` — diff remote vs local, install/uninstall with correct sort order increment
  [`CategorySyncService.swift:176`](../../DictlyKit/Sources/DictlyStorage/CategorySyncService.swift#L176)

- Startup wiring — pull then push pack IDs alongside existing category sync
  [`CategorySyncService.swift:85`](../../DictlyKit/Sources/DictlyStorage/CategorySyncService.swift#L85)

- External change handler — pack IDs pulled on serverChange and accountChange
  [`CategorySyncService.swift:217`](../../DictlyKit/Sources/DictlyStorage/CategorySyncService.swift#L217)

**Pack ID push from UI**

- iOS TagPackPickerView — push pack IDs after toggle and batch install
  [`TagPackPickerView.swift:117`](../../DictlyiOS/Tagging/TagPackPickerView.swift#L117)

- Mac TagPackPickerView — same wiring for Mac parity
  [`TagPackPickerView.swift:116`](../../DictlyMac/Settings/TagPackPickerView.swift#L116)

**Custom tag duplication fix**

- Removed `onDisappear` safety-net that raced with Save button's `@State` update
  [`CustomTagSheet.swift:74`](../../DictlyiOS/Tagging/CustomTagSheet.swift#L74)

**Tests**

- Four new tests: install-on-pull, uninstall-on-pull, idempotency, unknown pack ID
  [`CategorySyncServiceTests.swift:305`](../../DictlyKit/Tests/DictlyStorageTests/CategorySyncServiceTests.swift#L305)
