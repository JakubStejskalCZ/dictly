---
title: 'Tag Pack Selector — choosable tag clusters on first launch and from settings'
type: 'feature'
created: '2026-04-09'
status: 'done'
baseline_commit: '3f1021f'
context:
  - '_bmad-output/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Default tags are auto-installed on first launch with no user choice. All 25 tags are TTRPG-specific, which won't suit podcast or meeting recording use cases. Users can't discover or install additional tag packs later.

**Approach:** Replace `DefaultTagSeeder` with a `TagPackRegistry` that defines themed packs (TTRPG, Podcast, Meetings, etc.). On first launch, show a pack picker sheet. The same picker is accessible from Settings at any time to install/uninstall packs. Selecting a pack seeds its categories and template tags; uninstalling removes them.

## Boundaries & Constraints

**Always:**
- Use deterministic UUIDs (existing FNV-1a approach) so packs sync cleanly across iOS/Mac via iCloud
- Template tags remain `session == nil` pattern — no schema changes
- Pack definitions live in `DictlyModels` (shared) so both platforms use identical data
- Keep `deduplicateCategories` call — it still guards against iCloud sync races
- Wipe all existing tags and categories on both platforms (fresh start for sole current user)
- TagCategory `isDefault` field distinguishes pack-installed vs. user-created categories

**Ask First:**
- Adding new pack themes beyond TTRPG, Podcast, Meetings
- Changes to CategorySyncService merge logic

**Never:**
- Don't change the Tag or TagCategory SwiftData models
- Don't bundle pack data as JSON files — keep them as static Swift definitions for compile-time safety
- Don't auto-install any pack without user consent

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First launch, no packs installed | App starts, 0 TagCategories in DB | Pack picker sheet presented modally | N/A |
| User selects 2 of 3 packs | Taps TTRPG + Podcast, taps Install | Those packs' categories + tags seeded, sheet dismissed | N/A |
| User skips all packs | Taps "Skip" / dismisses without selecting | No tags seeded, app proceeds normally, picker available in Settings | N/A |
| Install pack from Settings | Taps uninstalled pack in Settings | Pack categories + tags inserted | N/A |
| Uninstall pack from Settings | Taps installed pack | Pack categories + their template tags deleted; session tags with matching categoryName kept (orphaned to "Uncategorized" if category gone) | N/A |
| All packs uninstalled | Last pack removed | App works with empty tag palette, user can create custom categories | N/A |

</frozen-after-approval>

## Code Map

- `DictlyKit/Sources/DictlyModels/DefaultTagSeeder.swift` -- Replace with `TagPackRegistry.swift` — defines packs, install/uninstall logic
- `DictlyKit/Sources/DictlyModels/TagPack.swift` -- New: pack data model (struct, not @Model)
- `DictlyiOS/App/DictlyiOSApp.swift` -- Remove seeder calls, add first-launch pack picker check
- `DictlyMac/App/DictlyMacApp.swift` -- Same: remove seeder calls, add first-launch check
- `DictlyiOS/Settings/SettingsScreen.swift` -- Add "Tag Packs" section with NavigationLink
- `DictlyMac/Settings/PreferencesWindow.swift` -- Add "Tags" tab with pack management
- `DictlyiOS/Tagging/TagPackPickerView.swift` -- New: shared pack picker UI (iOS sheet)
- `DictlyMac/Settings/TagPackPickerView.swift` -- New: Mac pack picker UI (sheet)

## Tasks & Acceptance

**Execution:**
- [x] `DictlyKit/Sources/DictlyModels/TagPack.swift` -- Create `TagPack` struct (id, name, description, icon, categories+tags) and `TagPackRegistry` with static pack definitions (TTRPG, Podcast, Meetings)
- [x] `DictlyKit/Sources/DictlyModels/DefaultTagSeeder.swift` -- Gut auto-seed logic; keep `deterministicUUID` and `deduplicateCategories`; add `installPack(pack:context:)` and `uninstallPack(pack:context:)` methods; add `installedPackIDs(context:)` query; add `removeAllDefaultData(context:)` for fresh-start wipe
- [x] `DictlyiOS/Tagging/TagPackPickerView.swift` -- Build iOS pack picker: grid of pack cards with toggle/checkmark, Install button, Skip option
- [x] `DictlyMac/Settings/TagPackPickerView.swift` -- Build Mac pack picker: similar layout adapted for Mac window sizing
- [x] `DictlyiOS/App/DictlyiOSApp.swift` -- Remove `DefaultTagSeeder.seedIfNeeded` call; add `@AppStorage("hasChosenTagPacks")` flag; show TagPackPickerView sheet on first launch when flag is false
- [x] `DictlyMac/App/DictlyMacApp.swift` -- Same changes as iOS app entry
- [x] `DictlyiOS/Settings/SettingsScreen.swift` -- Add "Tag Packs" NavigationLink to TagPackPickerView (non-modal, in-settings mode)
- [x] `DictlyMac/Settings/PreferencesWindow.swift` -- Add "Tags" tab with pack management view

**Acceptance Criteria:**
- Given a fresh install, when the app launches, then a pack picker sheet is presented before the main UI
- Given the picker is shown, when the user selects packs and taps Install, then only those packs' categories and template tags exist in the database
- Given the picker is shown, when the user taps Skip, then no tags are seeded and the app proceeds normally
- Given packs are installed, when the user opens Settings > Tag Packs, then installed packs show as active and can be uninstalled
- Given a pack is uninstalled, when the user had session tags in that category, then those tags are reassigned to "Uncategorized"
- Given both iOS and Mac apps, when the same pack is installed on both, then deterministic UUIDs prevent duplicates via iCloud sync

## Design Notes

**Pack identification:** Each `TagPack` has a stable string `id` (e.g., `"ttrpg"`, `"podcast"`). To detect which packs are installed, query TagCategories whose names match a pack's category names and have `isDefault == true`. This avoids adding new model fields.

**First-launch flag:** `@AppStorage("hasChosenTagPacks")` is set to `true` after the user either installs packs or explicitly skips. This replaces the old "are there any categories?" implicit check.

**Fresh-start wipe:** On this deploy, both apps call `removeAllDefaultData(context:)` before checking the flag — this clears old auto-seeded data for the sole current user. This one-time migration call can be removed in a future version.

## Verification

**Manual checks:**
- Fresh install iOS/Mac: pack picker appears, selecting packs seeds correct data
- Settings: installed packs toggleable, uninstall removes categories + template tags
- iCloud: installing same pack on both platforms doesn't create duplicates
- Skip flow: app works with zero tags/categories

## Suggested Review Order

**Pack data model & registry**

- Entry point: static pack definitions — three themed packs with categories and tags
  [`TagPack.swift:1`](../../DictlyKit/Sources/DictlyModels/TagPack.swift#L1)

**Install/uninstall engine**

- UUID-based install with dedup, uninstall with session tag reassignment
  [`DefaultTagSeeder.swift:60`](../../DictlyKit/Sources/DictlyModels/DefaultTagSeeder.swift#L60)

- Pack detection by deterministic category UUIDs, not names
  [`DefaultTagSeeder.swift:119`](../../DictlyKit/Sources/DictlyModels/DefaultTagSeeder.swift#L119)

- One-time migration wipe with session tag orphan protection
  [`DefaultTagSeeder.swift:133`](../../DictlyKit/Sources/DictlyModels/DefaultTagSeeder.swift#L133)

**App entry — first-launch flow**

- iOS: migration gate, pack picker sheet, hasChosenTagPacks flag
  [`DictlyiOSApp.swift:36`](../../DictlyiOS/App/DictlyiOSApp.swift#L36)

- Mac: same pattern, plus syncService injection into Settings scene
  [`DictlyMacApp.swift:47`](../../DictlyMac/App/DictlyMacApp.swift#L47)

**Pack picker UI**

- iOS: card grid with onboarding/settings dual mode
  [`TagPackPickerView.swift:10`](../../DictlyiOS/Tagging/TagPackPickerView.swift#L10)

- Mac: row-based layout adapted for desktop window
  [`TagPackPickerView.swift:10`](../../DictlyMac/Settings/TagPackPickerView.swift#L10)

**Settings integration**

- iOS: Tag Packs NavigationLink in SettingsScreen
  [`SettingsScreen.swift:51`](../../DictlyiOS/Settings/SettingsScreen.swift#L51)

- Mac: Tags tab added to PreferencesWindow
  [`PreferencesWindow.swift:9`](../../DictlyMac/Settings/PreferencesWindow.swift#L9)
