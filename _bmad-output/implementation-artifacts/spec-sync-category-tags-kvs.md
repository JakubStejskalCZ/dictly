---
title: 'Sync template tags to iCloud KVS'
type: 'feature'
created: '2026-04-09'
status: 'done'
baseline_commit: 'b0214f8'
context:
  - '_bmad-output/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Template tags (the quick-pick tags within categories, `session == nil`) are not synced between devices via iCloud KVS. Users who create, rename, or delete custom template tags on one device don't see the changes on the other. Only category metadata and installed pack IDs are synced today.

**Approach:** Extend `CategorySyncService` with a new `"templateTags"` KVS key. Serialize template tags as a `[SyncableTag]` payload (uuid, label, categoryName, modifiedAt). Use the same last-write-wins merge strategy as categories. Wire up push calls from iOS tag management screens (`TagFormSheet`, `TagListScreen`).

## Boundaries & Constraints

**Always:**
- Only sync template tags (`session == nil`) — never session tags
- Use the same LWW merge pattern as categories (cachedModifiedAt dictionary)
- Preserve local-only tags on pull (no deletion on pull, matching category behavior)
- Use the existing ISO 8601 formatter for date encoding
- Keep SyncableTag minimal: uuid, label, categoryName, modifiedAt

**Ask First:**
- If KVS payload size (categories + tags combined) risks approaching the 1 MB limit

**Never:**
- Sync session-bound tags, notes, transcriptions, or audio data
- Delete tags on pull that are absent from cloud
- Change existing category or pack sync behavior

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Push after create | User creates template tag via TagFormSheet | Tag serialized to KVS under `"templateTags"` key | Log error, do not crash |
| Push after rename | User renames template tag via TagFormSheet | Updated label pushed to KVS | Log error, do not crash |
| Push after delete | User deletes template tag via TagListScreen | Tag removed from KVS payload | Log error, do not crash |
| Pull inserts new | Cloud has tag UUID not in local | New template tag inserted locally | Skip invalid UUIDs, log |
| Pull updates existing | Cloud tag newer than cached modifiedAt | Local label/categoryName updated | N/A |
| Pull keeps local | Local tag newer than cloud | Local fields preserved | N/A |
| Pull keeps local-only | Tag in local but not in cloud | Tag preserved (no deletion) | N/A |
| Category rename cascades | Cloud renames category that tags reference | Tags' categoryName updated via existing rename logic | N/A |
| Duplicate UUIDs in cloud | Same UUID appears twice in payload | Deduplicate, keep last occurrence | N/A |

</frozen-after-approval>

## Code Map

- `DictlyKit/Sources/DictlyStorage/CategorySyncService.swift` -- Add SyncableTag DTO, push/pull/merge logic for template tags
- `DictlyiOS/Tagging/TagFormSheet.swift` -- Call syncService.pushTagsToCloud() after create/rename
- `DictlyiOS/Tagging/TagListScreen.swift` -- Call syncService.pushTagsToCloud() after delete
- `DictlyKit/Tests/DictlyStorageTests/CategorySyncServiceTests.swift` -- Add tag sync merge tests

## Tasks & Acceptance

**Execution:**
- [x] `DictlyKit/Sources/DictlyStorage/CategorySyncService.swift` -- Add `SyncableTag` struct (uuid, label, categoryName, modifiedAt) and `templateTagsKey` constant
- [x] `DictlyKit/Sources/DictlyStorage/CategorySyncService.swift` -- Add `pushTagsToCloud()` method: fetch template tags (session == nil), serialize as JSON, write to KVS
- [x] `DictlyKit/Sources/DictlyStorage/CategorySyncService.swift` -- Add `pullTagsFromCloud()` and `processTagsPayload(_:into:)` with LWW merge logic matching category pattern
- [x] `DictlyKit/Sources/DictlyStorage/CategorySyncService.swift` -- Add `markTagModified(_:)` public method for LWW timestamp tracking
- [x] `DictlyKit/Sources/DictlyStorage/CategorySyncService.swift` -- Wire tag push/pull into `startObserving` and `handleExternalChange`
- [x] `DictlyiOS/Tagging/TagFormSheet.swift` -- Inject `CategorySyncService` via environment, call `markTagModified` + `pushTagsToCloud()` after save
- [x] `DictlyiOS/Tagging/TagListScreen.swift` -- Inject `CategorySyncService` via environment, call `pushTagsToCloud()` after delete
- [x] `DictlyKit/Tests/DictlyStorageTests/CategorySyncServiceTests.swift` -- Add tests: insert from cloud, update when newer, keep local when older, preserve local-only, deduplicate UUIDs, SyncableTag round-trip encoding

**Acceptance Criteria:**
- Given a template tag created on device A, when device B pulls from KVS, then the tag appears in device B's tag palette under the correct category
- Given a template tag renamed on device A, when device B pulls, then the tag label is updated on device B
- Given a template tag deleted on device A, when device A pushes, then the tag is absent from the KVS payload (device B keeps its local copy per no-delete-on-pull policy)
- Given template tags from both custom creation and pack installation, when pushing, then only template tags (session == nil) are included in the payload

## Verification

**Manual checks (if no CLI):**
- Inspect that `pushTagsToCloud()` is called from TagFormSheet and TagListScreen after mutations
- Verify `handleExternalChange` dispatches to `pullTagsFromCloud()` for the new key
- Confirm SyncableTag payload contains only uuid, label, categoryName, modifiedAt fields

## Suggested Review Order

**Core sync logic**

- SyncableTag DTO — minimal payload matching category pattern
  [`CategorySyncService.swift:23`](../../DictlyKit/Sources/DictlyStorage/CategorySyncService.swift#L23)

- Push: fetches template tags, serializes with ISO 8601 dates, writes to KVS
  [`CategorySyncService.swift:160`](../../DictlyKit/Sources/DictlyStorage/CategorySyncService.swift#L160)

- Pull + merge: LWW conflict resolution mirroring category merge
  [`CategorySyncService.swift:460`](../../DictlyKit/Sources/DictlyStorage/CategorySyncService.swift#L460)

- Lifecycle wiring: pull/push in startObserving, handleExternalChange dispatches
  [`CategorySyncService.swift:95`](../../DictlyKit/Sources/DictlyStorage/CategorySyncService.swift#L95)

**UI integration (push triggers)**

- TagFormSheet: marks modified + pushes after create/rename
  [`TagFormSheet.swift:51`](../../DictlyiOS/Tagging/TagFormSheet.swift#L51)

- TagListScreen: pushes after delete
  [`TagListScreen.swift:85`](../../DictlyiOS/Tagging/TagListScreen.swift#L85)

- TagPackPickerView (iOS): pushes tags after pack install/uninstall
  [`TagPackPickerView.swift:118`](../../DictlyiOS/Tagging/TagPackPickerView.swift#L118)

- TagPackPickerView (Mac): same push wiring for Mac target
  [`TagPackPickerView.swift:118`](../../DictlyMac/Settings/TagPackPickerView.swift#L118)

**Tests**

- Merge tests: insert, update, keep local, preserve absent, dedup, invalid UUID
  [`CategorySyncServiceTests.swift:406`](../../DictlyKit/Tests/DictlyStorageTests/CategorySyncServiceTests.swift#L406)

- Encoding tests: SyncableTag round-trip and field validation
  [`CategorySyncServiceTests.swift:104`](../../DictlyKit/Tests/DictlyStorageTests/CategorySyncServiceTests.swift#L104)
