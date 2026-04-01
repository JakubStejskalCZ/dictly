# Story 1.5: Tag Category & Tag Management

Status: done

## Story

As a DM,
I want to create, rename, delete, and reorder tag categories and tags with D&D-oriented defaults,
So that I can organize my tagging palette to match my campaign's needs.

## Acceptance Criteria (BDD)

### Scenario 1: Default Tag Categories on Fresh Install

Given a fresh install of the app
When the DM opens the app for the first time
Then 5 default tag categories are present:
  - Story (amber `#D97706`)
  - Combat (crimson `#DC2626`)
  - Roleplay (violet `#7C3AED`)
  - World (green `#059669`)
  - Meta (blue `#4B7BE5`)
And each category contains a set of sensible default tags

### Scenario 2: Create Custom Tag Category

Given the tag management screen
When the DM creates a new custom category (name, color, icon)
Then it appears in the category list
And is available in the tag palette

### Scenario 3: Rename or Delete Existing Category

Given an existing category
When the DM renames it
Then the change is reflected immediately in the category list
When the DM deletes a category
Then all tags referencing that category's name are reassigned to "Uncategorized" (tags are never deleted by category removal)
And the category is removed from the list

### Scenario 4: Reorder Categories

Given the category list
When the DM reorders categories (drag/move)
Then the new `sortOrder` persists
And the order is reflected in the tag palette

### Scenario 5: CRUD Tags Within a Category

Given a tag category
When the DM creates a new tag within that category
Then it appears in the tag list under that category
When the DM renames or deletes a tag
Then the change is reflected immediately

### Scenario 6: Default Tags Seeded Per Category

Given the 5 default categories exist
Then each category has pre-seeded default tags relevant to D&D:
  - Story: Plot Hook, Lore Drop, Quest Update, Foreshadowing, Revelation
  - Combat: Initiative, Epic Roll, Critical Hit, Encounter Start, Encounter End
  - Roleplay: Character Moment, NPC Introduction, Memorable Quote, In-Character Speech, Emotional Beat
  - World: Location, Item, Lore, Map Note, Environment Description
  - Meta: Ruling, House Rule, Schedule, Break, Player Note

## Tasks / Subtasks

- [x] Task 1: Seed default tag categories on first launch (AC: #1, #6)
  - [x] 1.1 Create `DefaultTagSeeder` utility that checks if TagCategory table is empty and inserts the 5 defaults with correct colorHex, iconName, sortOrder, isDefault=true
  - [x] 1.2 Create default tags for each category (Tag models with matching categoryName string)
  - [x] 1.3 Call seeder from app launch (in `DictlyiOSApp.swift` after ModelContainer setup)
  - [x] 1.4 Write unit tests for seeder: verify 5 categories + correct tag counts created, verify idempotency (second call is no-op)

- [x] Task 2: Tag Category Management Screen (AC: #2, #3, #4)
  - [x] 2.1 Create `TagCategoryListScreen.swift` in `DictlyiOS/Tagging/` — List of all categories sorted by `sortOrder`
  - [x] 2.2 Create `TagCategoryFormSheet.swift` — Create/edit category (name, colorHex picker, iconName picker), following CampaignFormSheet pattern
  - [x] 2.3 Implement delete with reassignment: when deleting a category, update all Tags where `categoryName == deletedCategory.name` to `categoryName = "Uncategorized"`, ensure an "Uncategorized" category exists (create if not)
  - [x] 2.4 Implement reorder via `EditButton` / `.onMove` — update `sortOrder` values on move
  - [x] 2.5 Prevent deletion of the last remaining category

- [x] Task 3: Tag Management Within Category (AC: #5)
  - [x] 3.1 Create `TagListScreen.swift` in `DictlyiOS/Tagging/` — Shows tags filtered by selected category's name
  - [x] 3.2 Create `TagFormSheet.swift` — Create/edit tag label within a category
  - [x] 3.3 Implement tag delete with confirmation dialog
  - [x] 3.4 Tags use `categoryName: String` to reference their parent category (existing model design)

- [x] Task 4: Navigation Integration
  - [x] 4.1 Add "Manage Tags" entry point — accessible from Settings or Campaign detail toolbar menu
  - [x] 4.2 Wire NavigationLink from TagCategoryListScreen → TagListScreen for each category
  - [x] 4.3 Ensure navigation depth stays within 3 levels per UX spec

- [x] Task 5: Testing & Build Verification
  - [x] 5.1 Unit tests for DefaultTagSeeder (category count, tag count, idempotency)
  - [x] 5.2 Unit tests for category deletion + tag reassignment logic
  - [x] 5.3 Unit tests for reorder persistence
  - [x] 5.4 Verify xcodebuild succeeds for iOS target

### Review Findings

- [x] [Review][Patch] Category rename doesn't update tags' categoryName — data orphaning bug [TagCategoryFormSheet.swift:61] — FIXED
- [x] [Review][Patch] Deleting "Uncategorized" category orphans its tags [TagCategoryListScreen.swift:97-124] — FIXED
- [x] [Review][Patch] TagListScreen computed property lacks SwiftData reactivity [TagListScreen.swift:16-20] — FIXED (replaced with @Query)
- [x] [Review][Patch] sortOrder not set for new categories, defaults to 0 [TagCategoryFormSheet.swift:76-86] — FIXED
- [x] [Review][Patch] No duplicate category name validation [TagCategoryFormSheet.swift:57] — FIXED
- [x] [Review][Patch] deleteCategory deletes category even if tag reassignment fetch fails [TagCategoryListScreen.swift:113-124] — FIXED (moved delete inside do block)
- [x] [Review][Patch] No user feedback when delete-last-category is blocked [TagCategoryListScreen.swift:88] — FIXED (added alert)
- [x] [Review][Defer] Concurrent seeding race condition in multi-window scenario [DefaultTagSeeder.swift:26-28] — deferred, pre-existing architectural concern, extremely unlikely in single-window iOS app

## Dev Notes

### Architecture Compliance

- **Campaigns/ pattern is the reference:** Pure SwiftData `@Query` views with no business logic beyond CRUD [Source: architecture.md#iOS-Target-Boundaries]
- **SwiftData access:** `@Query(sort: \TagCategory.sortOrder)` for category list, `@Environment(\.modelContext)` for mutations
- **State management:** `@State` for view-local state (sheet presentation, form fields). No `@Observable` service needed for CRUD
- **Navigation:** iOS uses `NavigationStack` push/pop. Recording screen is modal. Tag management is push-based from settings/campaign detail
- **No ObservableObject or @StateObject** — use `@Observable` only if a stateful service is needed (not the case here)
- **Error UI:** `.confirmationDialog` only for destructive actions (delete category, delete tag). Everything else is instant
- **DictlyKit boundary:** TagCategory and Tag models live in `DictlyModels`. Tag management UI lives in `DictlyiOS/Tagging/`. No DictlyKit modifications needed
- **Logging:** Use `os.Logger` with category `tagging`, subsystem `com.dictly.ios` for any error logging

### SwiftData Model Notes

**TagCategory** (`DictlyKit/Sources/DictlyModels/TagCategory.swift`):
```swift
@Model public final class TagCategory {
    public var uuid: UUID
    public var name: String
    public var colorHex: String    // e.g. "#D97706"
    public var iconName: String    // SF Symbol name
    public var sortOrder: Int
    public var isDefault: Bool     // true for the 5 D&D defaults
}
```

**Tag** (`DictlyKit/Sources/DictlyModels/Tag.swift`):
```swift
@Model public final class Tag {
    public var uuid: UUID
    public var label: String
    public var categoryName: String  // STRING reference to TagCategory.name (NOT a relationship)
    public var anchorTime: TimeInterval
    public var rewindDuration: TimeInterval
    public var notes: String?
    public var transcription: String?
    public var createdAt: Date
    @Relationship(inverse: \Session.tags) public var session: Session?
}
```

**Critical design:** Tags reference categories by `categoryName` string, not a direct SwiftData relationship. This means:
- Deleting a TagCategory does NOT cascade-delete Tags
- When deleting a category, you must manually query all Tags with matching `categoryName` and update them to "Uncategorized"
- Tag creation for the palette (pre-defined tags available for one-tap use) requires Tag instances with `session: nil` (they are template tags, not session-bound tags)

**Schema:** All 4 models already registered in `DictlySchema.all` — no changes needed.

### Default Tag Seeding Strategy

The seeder should:
1. Check if any TagCategory exists in the store (idempotent guard)
2. If empty, insert the 5 default categories with `isDefault: true`
3. Insert pre-defined Tag templates for each category with `session: nil`, `anchorTime: 0`, `rewindDuration: 0`
4. Run once at app launch — call from `DictlyiOSApp.swift` in a `.task` modifier or during ModelContainer setup

**Default categories with icons:**
| Category | colorHex | iconName | sortOrder |
|----------|----------|----------|-----------|
| Story | #D97706 | book.pages | 0 |
| Combat | #DC2626 | shield | 1 |
| Roleplay | #7C3AED | theatermasks | 2 |
| World | #059669 | globe | 3 |
| Meta | #4B7BE5 | info.circle | 4 |

### Color Picker Implementation

For the category color picker, use a fixed palette of predefined colors (the 5 tag category colors from `DictlyColors.TagCategory` plus a few additional options). Do NOT implement a freeform color picker — keep it simple and on-brand. Store selected color as hex string in `colorHex`.

### Icon Picker Implementation

Use a curated grid of SF Symbols relevant to D&D/tabletop (e.g., `book.pages`, `shield`, `theatermasks`, `globe`, `info.circle`, `star`, `flag`, `bolt`, `heart`, `map`, `scroll`, `crown`, `wand.and.stars`). Present as a grid in the form sheet.

### Category Deletion & Tag Reassignment

When deleting a category:
1. Fetch all Tags where `categoryName == category.name`
2. Check if "Uncategorized" category exists; create it if not (with `isDefault: false`, `colorHex: "#78716C"` (textSecondary-like), `iconName: "tag"`)
3. Update each tag's `categoryName` to `"Uncategorized"`
4. Delete the category
5. Do this in a single ModelContext transaction (no explicit save needed — SwiftData auto-saves)

### Reorder Implementation

Use SwiftUI `List` with `.onMove` modifier + `EditButton`:
- On move, recalculate `sortOrder` for all categories based on new array order
- `@Query(sort: \TagCategory.sortOrder)` ensures the list always reflects persisted order

### File Placement

New files go in `DictlyiOS/Tagging/` (directory exists, currently empty):
```
DictlyiOS/Tagging/
├── DefaultTagSeeder.swift          # Seed logic for first-launch defaults
├── TagCategoryListScreen.swift     # List of categories with reorder/CRUD
├── TagCategoryFormSheet.swift      # Create/edit category form
├── TagListScreen.swift             # Tags within a selected category
├── TagFormSheet.swift              # Create/edit tag form
└── ColorPicker.swift               # Fixed palette color picker component (if extracted)
```

### Navigation Entry Point

Add a "Manage Tags" button to the campaign detail toolbar menu (alongside "Edit Campaign" and "Delete Campaign") in `CampaignDetailScreen.swift`. This navigates to `TagCategoryListScreen`. Tag categories are global (not campaign-scoped) per the architecture.

Alternatively or additionally, add a "Tag Categories" row in `SettingsScreen.swift` if it exists.

### UI Patterns to Follow

- **Form sheets:** Follow `CampaignFormSheet` pattern exactly — `NavigationStack` > `Form` > `Section`, Cancel/Save toolbar, optional model init for edit mode, trim whitespace on save
- **List screens:** Follow `CampaignDetailScreen` pattern — `List` > `Section` > `ForEach`, context menus, swipe actions, confirmation dialogs for delete
- **Typography:** `DictlyTypography.body` for primary text, `DictlyTypography.caption` for metadata
- **Colors:** `DictlyColors.textPrimary`, `.textSecondary`, `.surface`, `.background`, `.border`
- **Spacing:** `DictlySpacing.sm` (8pt), `.md` (16pt), `.lg` (24pt)
- **Category color dot:** Small colored circle (6-8pt) next to category name using the category's `colorHex`

### Previous Story Intelligence (from Story 1.4)

Key learnings to apply:
- **CampaignFormSheet create/edit pattern** works well — reuse for TagCategoryFormSheet and TagFormSheet (optional model in init, @State for fields, trim whitespace)
- **Extract subviews as private struct** when body exceeds ~40 lines (like `CampaignRowView`)
- **Use relationship array directly** for filtered child data rather than complex @Query predicates
- **SwiftData @Model requires Xcode compilation** — verify with `xcodebuild`, not `swift build`
- **Run `xcodegen generate`** in `DictlyiOS/` if new files are added to regenerate .xcodeproj
- **Trim whitespace on text inputs** before save to prevent phantom content
- **Stale state refs:** Clear `@State` references to deleted models before performing deletion (e.g., clear sessionToEdit before deleting campaign) — apply same pattern to tag/category deletion

### Git Conventions

- Conventional commits with `feat:` prefix: `feat(tagging): implement tag category and tag management (story 1.5)`
- Recent commits show pattern: `feat(campaigns): implement session organization within campaigns (story 1.4)`

### Project Structure Notes

- `DictlyiOS/Tagging/` directory exists (empty, has `.gitkeep`) — new files go here
- `project.yml` likely already includes `Tagging` path in sources (verify; if not, it may need adding or `xcodegen` may pick up the directory automatically)
- No changes to `DictlyKit/`, `DictlyMac/`, or `Package.swift`
- Schema already includes TagCategory and Tag models — no model changes needed

### References

- [Source: architecture.md#Data-Architecture] — SwiftData models, relationships, cascade rules
- [Source: architecture.md#SwiftData-Relationships] — TagCategory is independent, no cascade delete
- [Source: architecture.md#DictlyModels] — Model file structure and naming
- [Source: architecture.md#Naming-Patterns] — PascalCase types, camelCase properties
- [Source: architecture.md#iOS-Target-Boundaries] — Tagging/ owns tag creation, Campaigns/ is pure CRUD
- [Source: epics.md#Story-1.5] — AC and technical requirements
- [Source: prd.md#FR14-FR17] — Tag & category management functional requirements
- [Source: ux-design-specification.md#Tag-Category-Colors] — 5 category colors and their semantic meaning
- [Source: ux-design-specification.md#CategoryTabBar] — Category tab interaction pattern
- [Source: ux-design-specification.md#Journey-1] — Default tags pre-loaded, no forced customization
- [Source: DictlyKit/Sources/DictlyModels/TagCategory.swift] — Existing model definition
- [Source: DictlyKit/Sources/DictlyModels/Tag.swift] — Tag uses categoryName string reference
- [Source: DictlyKit/Sources/DictlyTheme/Colors.swift] — DictlyColors.TagCategory enum with hex values
- [Source: 1-4-session-organization-within-campaigns.md] — Previous story patterns and learnings

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- `#Predicate` macro in `TagListScreen` required capturing `category.name` into a local `String` variable before use — SwiftData predicate macros cannot access properties of a captured `@Model` object directly (causes type inference failure at compile time).

### Completion Notes List

- **Task 1:** `DefaultTagSeeder` placed in `DictlyKit/Sources/DictlyModels/` (not `DictlyiOS/Tagging/`) for testability — the existing test infrastructure (DictlyModelsTests) only tests DictlyKit code. Seeder is called from `DictlyiOSApp.swift` in a `.task` modifier on `ContentView`, logging errors via `os.Logger`. 12 unit tests added: category count/names/colors/sort/isDefault, tag count/per-category/labels/session-nil, idempotency (double-call and pre-existing-category variants).
- **Task 2:** `TagCategoryListScreen` uses `@Query(sort: \TagCategory.sortOrder)` + `.onMove` + `EditButton`. Deletion guard prevents removing last category. `deleteCategory` reassigns orphaned tags to "Uncategorized" (creating the fallback category if absent) in one ModelContext transaction. `TagCategoryFormSheet` follows `CampaignFormSheet` pattern with fixed 10-color palette (ScrollView) and curated SF Symbol icon grid.
- **Task 3:** `TagListScreen` fetches tags via manual ModelContext query (capturing category name as local `String` due to predicate limitation). `TagFormSheet` follows `CampaignFormSheet` pattern. Delete uses `.confirmationDialog`.
- **Task 4:** "Manage Tags" added to `CampaignDetailScreen` toolbar Menu. Navigation uses `.navigationDestination(isPresented:)` to push `TagCategoryListScreen`. `TagCategoryListScreen` → `TagListScreen` uses `NavigationLink`. Navigation depth: Campaign list (1) → Campaign detail (2) → Tag categories (3) — within 3-level limit.
- **Task 5:** 44 total tests pass, zero regressions. xcodebuild succeeds for DictlyiOS iOS Simulator target.

### File List

- DictlyKit/Sources/DictlyModels/DefaultTagSeeder.swift (new)
- DictlyKit/Tests/DictlyModelsTests/DefaultTagSeederTests.swift (new)
- DictlyKit/Tests/DictlyModelsTests/TagManagementTests.swift (new)
- DictlyiOS/Tagging/TagCategoryListScreen.swift (new)
- DictlyiOS/Tagging/TagCategoryFormSheet.swift (new)
- DictlyiOS/Tagging/TagListScreen.swift (new)
- DictlyiOS/Tagging/TagFormSheet.swift (new)
- DictlyiOS/App/DictlyiOSApp.swift (modified)
- DictlyiOS/Campaigns/CampaignDetailScreen.swift (modified)
- DictlyiOS/project.yml (modified)

### Change Log

- feat(tagging): implement DefaultTagSeeder with 5 D&D categories and 25 default tags (Date: 2026-04-01)
- feat(tagging): add TagCategoryListScreen with CRUD, reorder, delete-with-reassignment (Date: 2026-04-01)
- feat(tagging): add TagListScreen and TagFormSheet for tag CRUD within categories (Date: 2026-04-01)
- feat(tagging): add TagCategoryFormSheet with color palette and icon picker (Date: 2026-04-01)
- feat(campaigns): add Manage Tags navigation entry in CampaignDetailScreen toolbar (Date: 2026-04-01)
- chore(ios): add Tagging source path to project.yml and regenerate xcodeproj (Date: 2026-04-01)
- test(tagging): add 17 unit tests for seeder, deletion/reassignment, reorder persistence (Date: 2026-04-01)
