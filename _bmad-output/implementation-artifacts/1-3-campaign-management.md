# Story 1.3: Campaign Management

Status: done

## Story

As a DM,
I want to create, rename, and delete campaigns with metadata,
So that I can organize my different tabletop games.

## Acceptance Criteria

1. **Given** the DM opens the app with no campaigns **When** they view the campaign list **Then** an empty state message is displayed with a "Create Campaign" button
2. **Given** the DM taps "Create Campaign" **When** they enter a name and optional description and save **Then** the campaign appears in the list with the entered metadata
3. **Given** an existing campaign **When** the DM renames it **Then** the updated name is displayed immediately
4. **Given** an existing campaign **When** the DM deletes it and confirms **Then** the campaign and all its sessions are removed (cascade delete) **And** a confirmation dialog is shown before deletion
5. **Given** campaigns exist in the list **When** the DM views the campaign list **Then** campaigns are displayed with name, description, session count, and creation date

## Tasks / Subtasks

- [x] Task 1: Implement `CampaignListScreen.swift` — root campaign list view (AC: #1, #2, #5)
  - [x] 1.1 Create `DictlyiOS/Campaigns/CampaignListScreen.swift` with `@Query` for all campaigns sorted by `createdAt` descending
  - [x] 1.2 Display each campaign as a `NavigationLink` row showing name, description (truncated), session count (`campaign.sessions.count`), and `createdAt` formatted date
  - [x] 1.3 Implement empty state: centered text "Create your first campaign to start recording sessions" with a prominent "Create Campaign" button (matches UX spec empty state)
  - [x] 1.4 Add toolbar button (top trailing, `+` icon) to present `CampaignFormSheet` for creation
  - [x] 1.5 Add swipe-to-delete on rows with `.confirmationDialog` before deletion (AC: #4)
  - [x] 1.6 Use `DictlyTypography` for text styles: `.display` for screen title, `.body` for campaign names, `.caption` for metadata

- [x] Task 2: Implement `CampaignFormSheet.swift` — create/edit campaign form (AC: #2, #3)
  - [x] 2.1 Create `DictlyiOS/Campaigns/CampaignFormSheet.swift` as a `.sheet` with `Form` containing fields for name (`TextField`) and description (`TextField`, optional)
  - [x] 2.2 Support both create and edit modes: pass optional `Campaign` for editing, nil for creation
  - [x] 2.3 On save (create mode): insert new `Campaign` into `ModelContext` with provided name and description
  - [x] 2.4 On save (edit mode): update existing `Campaign.name` and `Campaign.descriptionText` directly
  - [x] 2.5 Disable save button when name is empty (validation)
  - [x] 2.6 Add Cancel button that dismisses without saving

- [x] Task 3: Implement `CampaignDetailScreen.swift` — campaign detail with session list placeholder (AC: #3, #4)
  - [x] 3.1 Create `DictlyiOS/Campaigns/CampaignDetailScreen.swift` showing campaign name as navigation title
  - [x] 3.2 Show empty state for sessions: "Start your first session — place your phone on the table and hit record" with disabled "New Session" button (session recording is Story 2.x)
  - [x] 3.3 Add toolbar edit button to present `CampaignFormSheet` in edit mode
  - [x] 3.4 Add toolbar delete button with `.confirmationDialog` — on confirm, delete campaign from `ModelContext` and pop navigation

- [x] Task 4: Wire up navigation in `ContentView.swift` (AC: #1, #2, #5)
  - [x] 4.1 Replace the placeholder `Text("Dictly")` with a `NavigationStack` containing `CampaignListScreen`
  - [x] 4.2 Ensure `NavigationLink` from campaign rows pushes to `CampaignDetailScreen`
  - [x] 4.3 Navigation title: "Campaigns" on the list screen

- [x] Task 5: Verify cascade delete and data integrity (AC: #4)
  - [x] 5.1 Verify the existing `Campaign` model's `@Relationship(deleteRule: .cascade)` on `sessions` works correctly — deleting a campaign removes all child sessions
  - [x] 5.2 Confirm `ModelContext.delete()` propagates cascade and SwiftData auto-saves

### Review Findings

- [x] [Review][Patch] descriptionText not trimmed before save — whitespace-only descriptions create phantom line in CampaignRowView [CampaignFormSheet.swift:52] — **FIXED**
- [x] [Review][Defer] sessions.count triggers lazy relationship fault per row render [CampaignListScreen.swift:113] — deferred, pre-existing model design concern for scale

## Dev Notes

### Architecture Compliance

- **Campaigns/ is pure CRUD** — "Campaigns/ is pure SwiftData @Query views — no business logic beyond CRUD" [Source: architecture.md#iOS Target Boundaries]
- **SwiftData access**: Use `@Query` for lists, `@Environment(\.modelContext)` for mutations. No custom data access layer. [Source: architecture.md#Data Boundary]
- **State management**: `@State` for view-local state (sheet presentation, form text fields). No `@Observable` service needed for CRUD — SwiftData handles reactivity via `@Query`. [Source: architecture.md#SwiftUI Patterns]
- **Navigation**: iOS uses `NavigationStack` with programmatic `NavigationPath` for push/pop. [Source: architecture.md#SwiftUI Patterns]
- **No `ObservableObject`/`@StateObject`** — use `@Observable` only if needed (not needed here). [Source: architecture.md#Enforcement Guidelines]
- **Error UI**: Confirmation only for destructive actions (delete). Everything else is instant. [Source: ux-design-specification.md#Interaction Patterns]
- **DictlyKit boundary**: Campaign model is in `DictlyModels` — import `DictlyModels` and `DictlyTheme` in campaign views. No modifications to `DictlyKit` needed for this story.

### SwiftUI Patterns — Critical Details

**View composition:**
- Extract subview when `body` exceeds ~40 lines or a section is reused [Source: architecture.md#SwiftUI Patterns]
- Use `@ViewBuilder` or computed properties for extracted subviews — never `AnyView` [Source: architecture.md#Anti-Patterns]

**Form sheets:**
- iOS: Use `.sheet` for create/edit forms [Source: ux-design-specification.md#Modal and Overlay Patterns]
- `.confirmationDialog` for destructive actions (delete campaign) [Source: ux-design-specification.md#Modal and Overlay Patterns]

**Empty states:**
- No campaigns (iOS): "Create your first campaign to start recording sessions" with "Create Campaign" button [Source: ux-design-specification.md#Empty States]
- No sessions in campaign: "Start your first session — place your phone on the table and hit record" with "New Session" button [Source: ux-design-specification.md#Empty States]
- Warm, encouraging tone — never feel like an error [Source: ux-design-specification.md#Empty States]

**Navigation hierarchy (iOS):**
```
Campaigns (list) → [Campaign] (detail) → New Session / Session History / Campaign Settings
```
Max 3 levels deep. [Source: ux-design-specification.md#Navigation Patterns]

**Typography usage:**
- Display (34pt Bold): Campaign name on home [Source: ux-design-specification.md#Type Scale]
- Body (17pt Regular): Descriptions [Source: ux-design-specification.md#Type Scale]
- Caption (13pt Regular): Timestamps, metadata, session counts [Source: ux-design-specification.md#Type Scale]

**Standard SwiftUI components to use (NOT custom):**
- `List` for campaign list [Source: ux-design-specification.md#Standard Components]
- `Form` for campaign creation form [Source: ux-design-specification.md#Standard Components]
- `.sheet` for form presentation [Source: ux-design-specification.md#Standard Components]
- `.confirmationDialog` for delete confirmation [Source: ux-design-specification.md#Standard Components]
- `NavigationStack` + `NavigationLink` for navigation [Source: ux-design-specification.md#Standard Components]

### Campaign Model — Already Implemented

The `Campaign` SwiftData model exists at `DictlyKit/Sources/DictlyModels/Campaign.swift`:

```swift
@Model
public final class Campaign {
    public var uuid: UUID
    public var name: String
    public var descriptionText: String       // Note: NOT "description" (Swift keyword conflict)
    public var createdAt: Date
    @Relationship(deleteRule: .cascade) public var sessions: [Session]
}
```

- Cascade delete on `sessions` is already defined — deleting a campaign removes all sessions
- `descriptionText` (not `description`) — avoid Swift property name conflict
- `sessions` array is initialized to `[]` in init

### File Structure After Completion

```
DictlyiOS/Campaigns/
├── CampaignListScreen.swift        # @Query campaign list with empty state
├── CampaignDetailScreen.swift      # Campaign detail with session list placeholder
└── CampaignFormSheet.swift         # Create/edit campaign form (.sheet)

DictlyiOS/App/
└── ContentView.swift               # Updated: NavigationStack → CampaignListScreen
```

### Previous Story Intelligence (Story 1.2)

**Key learnings from Story 1.2:**
- DictlyTheme is fully implemented: `DictlyColors`, `DictlyTypography`, `DictlySpacing` — use these for consistent styling
- `import DictlyTheme` is available in app targets
- All `public` visibility is required for cross-module access from app targets
- `xcodebuild` IS available on this machine (Xcode 16.2) despite ENV-001 note — use for build verification
- SwiftData `@Model` macros require Xcode for compilation — `swift build` alone may not work for app targets that use SwiftData models. Use `xcodebuild` for verification.

**DictlyTheme tokens to use:**
- `DictlyColors.background`, `.surface`, `.textPrimary`, `.textSecondary` for adaptive color scheme
- `DictlyTypography.display` for campaign name on home screen
- `DictlyTypography.body` for descriptions
- `DictlyTypography.caption` for metadata (dates, counts)
- `DictlySpacing.md` (16pt) for standard padding, `.sm` (8pt) for compact spacing

### Git Intelligence

Recent commits:
- `de37c71` — feat: implement DictlyTheme design token system (Story 1.2)
- `2d4c73a` — feat: initialize Dictly project with macOS/iOS targets and shared DictlyKit package

Patterns established:
- Conventional commit messages: `feat:` prefix for new features
- `DictlyiOS/Campaigns/` directory exists (with `.gitkeep`) — ready for new files
- `DictlyiOS/App/ContentView.swift` is a minimal placeholder — ready to be replaced with real navigation

### Naming Conventions

Per architecture.md naming patterns:
- Types: `PascalCase` — `CampaignListScreen`, `CampaignFormSheet`, `CampaignDetailScreen`
- File naming matches primary type — `CampaignListScreen.swift`
- View files: suffix with `Screen` for full-screen views (established pattern from architecture: `RecordingScreen`, `SettingsScreen`)
- Properties: `camelCase` — `campaignName`, `isShowingForm`
- Booleans: prefix with `is`/`has`/`should` — `isShowingDeleteConfirmation`

### Testing Approach

- This story is pure SwiftUI CRUD views backed by SwiftData `@Query`
- **No unit tests required** for this story — the views are thin wrappers over SwiftData with no custom business logic
- Verify manually or via `xcodebuild` that the iOS target builds successfully
- The `Campaign` model is already tested via `DictlyModelsTests/CampaignTests.swift` from Story 1.1

### What This Story Does NOT Include

- Session list rows within campaign detail (Story 1.4)
- Tag category management UI (Story 1.5)
- "New Session" button functionality / recording (Story 2.x)
- Mac-side campaign views (separate epic)
- No `@Observable` service classes needed — pure `@Query` views

### Project Structure Notes

- All new files go in `DictlyiOS/Campaigns/` (directory already exists with `.gitkeep`)
- `ContentView.swift` is the only file modified in `DictlyiOS/App/`
- No changes to `DictlyKit` or `DictlyMac`
- No changes to `Package.swift` or `project.yml`

### References

- [Source: architecture.md#iOS Target Boundaries] — Campaigns/ is pure SwiftData @Query views
- [Source: architecture.md#Data Boundary] — @Query for lists, ModelContext for mutations
- [Source: architecture.md#SwiftUI Patterns] — NavigationStack, @State for view-local, @Query for data
- [Source: architecture.md#Naming Patterns] — PascalCase types, camelCase properties, boolean prefixes
- [Source: architecture.md#Project Structure & Boundaries] — CampaignListScreen.swift, CampaignDetailScreen.swift, CampaignFormSheet.swift in DictlyiOS/Campaigns/
- [Source: ux-design-specification.md#Empty States] — Empty state messages and actions for no campaigns / no sessions
- [Source: ux-design-specification.md#Navigation Patterns] — iOS NavigationStack, max 3 levels deep
- [Source: ux-design-specification.md#Modal and Overlay Patterns] — .sheet for forms, .confirmationDialog for delete
- [Source: ux-design-specification.md#Type Scale] — Display for campaign name, Body for descriptions, Caption for metadata
- [Source: ux-design-specification.md#Journey 1] — Onboarding flow: create campaign → tag review → new session
- [Source: epics.md#Story 1.3] — Acceptance criteria and story definition
- [Source: prd.md#FR18-FR19] — Create, rename, delete campaigns with metadata

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- SourceKit reported "No such module 'DictlyModels'" false positives — resolved at build time by Xcode project context.
- Initial build failed: `Campaigns/` directory was not included in `project.yml` sources. Fixed by adding `- path: Campaigns` and regenerating with `xcodegen generate`.

### Completion Notes List

- Implemented `CampaignListScreen` with `@Query(sort: \Campaign.createdAt, order: .reverse)`, empty state, campaign rows (name/description/session count/date), swipe-to-delete with `.confirmationDialog`, and `+` toolbar button.
- Extracted `CampaignRowView` as a private subview to keep `CampaignListScreen.body` under 40 lines.
- Implemented `CampaignFormSheet` supporting both create (nil campaign) and edit modes via init-time `@State` seeding.
- Implemented `CampaignDetailScreen` with navigation title, session empty state (disabled "New Session" button), and a Menu toolbar item combining Edit and Delete (with `.confirmationDialog`).
- Updated `ContentView` to wrap `CampaignListScreen` in `NavigationStack`.
- Added `- path: Campaigns` to `DictlyiOS/project.yml` and ran `xcodegen generate` — build succeeded.
- Task 5 (cascade delete): `@Relationship(deleteRule: .cascade)` already defined on `Campaign.sessions`; `ModelContext.delete()` handles cascade automatically. No code changes required.
- Build verified: `xcodebuild -scheme DictlyiOS -destination 'generic/platform=iOS Simulator' -configuration Debug build` → **BUILD SUCCEEDED**.
- No unit tests required per story Dev Notes — pure SwiftUI CRUD views over SwiftData with no custom business logic.

### File List

- DictlyiOS/Campaigns/CampaignListScreen.swift (new)
- DictlyiOS/Campaigns/CampaignFormSheet.swift (new)
- DictlyiOS/Campaigns/CampaignDetailScreen.swift (new)
- DictlyiOS/App/ContentView.swift (modified)
- DictlyiOS/project.yml (modified — added Campaigns source path)
- DictlyiOS/DictlyiOS.xcodeproj/project.pbxproj (regenerated by xcodegen)

## Change Log

- 2026-04-01: Implemented Story 1.3 Campaign Management — created CampaignListScreen, CampaignFormSheet, CampaignDetailScreen; updated ContentView with NavigationStack; added Campaigns source path to project.yml; build verified successful.
