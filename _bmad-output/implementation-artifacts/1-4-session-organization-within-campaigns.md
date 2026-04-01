# Story 1.4: Session Organization Within Campaigns

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a DM,
I want sessions automatically organized under campaigns with auto-numbering and metadata,
So that I can track my session history at a glance.

## Acceptance Criteria

1. **Given** a campaign with no sessions **When** the DM views the campaign detail **Then** an empty state message is shown with guidance to start recording
2. **Given** a campaign with existing sessions **When** the DM views the session list **Then** sessions are listed chronologically with date, duration, tag count, and title
3. **Given** a new session is created **When** it is added to a campaign **Then** it receives the next auto-incremented session number **And** the title defaults to "Session N" and is editable
4. **Given** location permission is granted on iOS **When** a session starts **Then** the current location is captured once and stored as session metadata

## Tasks / Subtasks

- [ ] Task 1: Implement `SessionListRow.swift` — reusable session row component (AC: #2)
  - [ ] 1.1 Create `DictlyiOS/Campaigns/SessionListRow.swift` displaying session title, date, duration (formatted), and tag count
  - [ ] 1.2 Use `DictlyTypography.body` for session title, `DictlyTypography.caption` for metadata (date, duration, tag count)
  - [ ] 1.3 Format duration as `Xh Ym` (e.g., "3h 42m") — use `Duration` or manual formatting, never raw `TimeInterval` display
  - [ ] 1.4 Show tag count as "N tags" with pluralization
  - [ ] 1.5 Show location name if available (optional, caption style)

- [ ] Task 2: Update `CampaignDetailScreen.swift` — add session list with empty state (AC: #1, #2)
  - [ ] 2.1 Add `@Query` filtered to sessions belonging to this campaign, sorted by `date` descending
  - [ ] 2.2 When sessions exist: display `List` of `SessionListRow` views (replacing empty state section)
  - [ ] 2.3 Keep existing empty state for when `sessions.isEmpty` — current message and disabled "New Session" button are correct per UX spec
  - [ ] 2.4 Add swipe-to-delete on session rows with `.confirmationDialog` before deletion
  - [ ] 2.5 Add session title editing via context menu or tap-to-edit interaction

- [ ] Task 3: Implement session auto-numbering and default title (AC: #3)
  - [ ] 3.1 Create a helper method to compute the next session number: query max `sessionNumber` for the campaign's sessions + 1 (or 1 if no sessions)
  - [ ] 3.2 Default title format: "Session N" where N is the auto-incremented number
  - [ ] 3.3 Title is editable — allow inline rename via `SessionFormSheet.swift` or context menu action
  - [ ] 3.4 Create `DictlyiOS/Campaigns/SessionFormSheet.swift` as a `.sheet` for editing session title (and future metadata)

- [ ] Task 4: Implement session creation placeholder (AC: #3)
  - [ ] 4.1 Enable the "New Session" button in `CampaignDetailScreen` — on tap, create a new `Session` with auto-numbered title, current date, duration 0, and insert into campaign
  - [ ] 4.2 The new session should appear immediately in the session list via `@Query` reactivity
  - [ ] 4.3 Note: This is a **placeholder** for session creation — actual recording-initiated session creation will be Story 2.x. This allows testing the session list UI with real data.

- [ ] Task 5: Verify data integrity (AC: #1, #2, #3)
  - [ ] 5.1 Verify that deleting a session removes it from the campaign's sessions array (SwiftData relationship)
  - [ ] 5.2 Verify that deleting a campaign cascades and removes all child sessions (already implemented in Campaign model)
  - [ ] 5.3 Verify auto-numbering handles gaps correctly (e.g., if session 2 is deleted, next session is still max+1, not gap-filling)

## Dev Notes

### Architecture Compliance

- **Campaigns/ is pure CRUD** — "Campaigns/ is pure SwiftData @Query views — no business logic beyond CRUD" [Source: architecture.md#iOS Target Boundaries]
- **SwiftData access**: Use `@Query` for lists, `@Environment(\.modelContext)` for mutations. No custom data access layer. [Source: architecture.md#Data Boundary]
- **State management**: `@State` for view-local state (sheet presentation, form text fields). No `@Observable` service needed — SwiftData handles reactivity via `@Query`. [Source: architecture.md#SwiftUI Patterns]
- **Navigation**: iOS uses `NavigationStack` with programmatic `NavigationPath`. Sessions within campaign detail are a second level — max 3 levels deep per UX spec. [Source: architecture.md#SwiftUI Patterns, ux-design-specification.md#Navigation Patterns]
- **No `ObservableObject`/`@StateObject`** — use `@Observable` only if needed (not needed here). [Source: architecture.md#Enforcement Guidelines]
- **Error UI**: Confirmation only for destructive actions (delete session). Everything else is instant. [Source: ux-design-specification.md#Interaction Patterns]
- **DictlyKit boundary**: Session model is in `DictlyModels` — import `DictlyModels` and `DictlyTheme` in views. No modifications to `DictlyKit` needed for this story.

### SwiftUI Patterns — Critical Details

**View composition:**
- Extract subview when `body` exceeds ~40 lines or a section is reused [Source: architecture.md#SwiftUI Patterns]
- Use `@ViewBuilder` or computed properties for extracted subviews — never `AnyView` [Source: architecture.md#Anti-Patterns]

**@Query filtering for sessions within a campaign:**
- SwiftData `@Query` does not support dynamic predicates easily. Use one of these approaches:
  - Option A: Access `campaign.sessions` directly (relationship already loaded) and sort in the view
  - Option B: Use `@Query` with a `#Predicate` filtering by `campaign` — requires careful init-time setup
  - **Recommended: Option A** — `campaign.sessions` is a relationship array, sort it with `.sorted(by:)`. This avoids `@Query` predicate complexity and is consistent with the CRUD-only pattern in Campaigns/.

**Form sheets:**
- iOS: Use `.sheet` for create/edit forms [Source: ux-design-specification.md#Modal and Overlay Patterns]
- `.confirmationDialog` for destructive actions (delete session) [Source: ux-design-specification.md#Modal and Overlay Patterns]

**Empty states:**
- No sessions in campaign: "Start your first session — place your phone on the table and hit record" with "New Session" button [Source: ux-design-specification.md#Empty States]
- Warm, encouraging tone — never feel like an error [Source: ux-design-specification.md#Empty States]

**Typography usage:**
- Body (17pt Regular): Session titles [Source: ux-design-specification.md#Type Scale]
- Caption (13pt Regular): Date, duration, tag count, location [Source: ux-design-specification.md#Type Scale]

**Standard SwiftUI components to use (NOT custom):**
- `List` for session list [Source: ux-design-specification.md#Standard Components]
- `Form` for session edit form [Source: ux-design-specification.md#Standard Components]
- `.sheet` for form presentation [Source: ux-design-specification.md#Standard Components]
- `.confirmationDialog` for delete confirmation [Source: ux-design-specification.md#Standard Components]

### Session Model — Already Implemented

The `Session` SwiftData model exists at `DictlyKit/Sources/DictlyModels/Session.swift`:

```swift
@Model
public final class Session {
    public var uuid: UUID
    public var title: String
    public var sessionNumber: Int
    public var date: Date
    public var duration: TimeInterval
    public var locationName: String?
    public var locationLatitude: Double?
    public var locationLongitude: Double?
    public var summaryNote: String?
    @Relationship(deleteRule: .cascade) public var tags: [Tag]
    @Relationship(inverse: \Campaign.sessions) public var campaign: Campaign?
}
```

Key fields for this story:
- `title` — editable, defaults to "Session N"
- `sessionNumber` — auto-incremented per campaign
- `date` — session creation date
- `duration` — `TimeInterval` in seconds (will be 0 for placeholder sessions; real duration set by recording engine in Story 2.x)
- `tags` — relationship array; `tags.count` gives tag count
- `locationName` — optional string for display
- `campaign` — inverse relationship back to parent Campaign

**Campaign → Session relationship** (in `Campaign.swift`):
```swift
@Relationship(deleteRule: .cascade) public var sessions: [Session]
```

### File Structure After Completion

```
DictlyiOS/Campaigns/
├── CampaignListScreen.swift        # Existing — no changes
├── CampaignDetailScreen.swift      # MODIFIED — add session list, enable New Session button
├── CampaignFormSheet.swift         # Existing — no changes
├── SessionListRow.swift            # NEW — session row component
└── SessionFormSheet.swift          # NEW — edit session title
```

### What This Story Does NOT Include

- **Location capture** (AC #4): The acceptance criteria mentions location permission and capture. However, location capture requires `CLLocationManager`, `Info.plist` keys, and is triggered when a session recording starts (Story 2.x). For this story, `locationName` will remain nil on placeholder sessions. Location capture will be implemented in Story 2.1/2.3 when the recording engine creates sessions. **This is a known deferral — AC #4 is not implementable without the recording engine.**
- Audio recording or playback (Story 2.x)
- Session navigation to a session detail/review screen (Story 2.x+)
- "New Session" creating a real recording session — this story creates a placeholder session for testing the list UI
- Tag management UI (Story 1.5)
- Mac-side session views (separate epic)

### Previous Story Intelligence (Story 1.3)

**Key learnings from Story 1.3:**
- `CampaignDetailScreen` already exists with empty state for sessions — modify it, don't recreate
- `CampaignFormSheet` supports both create and edit modes via optional `Campaign` init — follow same pattern for `SessionFormSheet`
- `CampaignRowView` was extracted as a `private struct` to keep body under 40 lines — do the same for `SessionListRow` but as a separate file since it's in the architecture file map
- `@Query(sort:order:)` works well for top-level lists; for filtered child data, use the relationship array directly
- `DictlyTypography`, `DictlyColors`, `DictlySpacing` are the correct theme tokens — import `DictlyTheme`
- `project.yml` already includes `- path: Campaigns` — no changes needed for new files in this directory
- `xcodebuild` IS available (Xcode 16.2) — use for build verification
- SwiftData `@Model` macros require Xcode for compilation — use `xcodebuild` for verification, not `swift build`
- Trimming whitespace on text inputs before save prevents phantom content (learned from CampaignFormSheet review)

**Existing code patterns to follow:**
- `CampaignListScreen` uses `@Query` at the top level + `ForEach` + extracted row view
- `CampaignDetailScreen` uses `let campaign: Campaign` (passed as value, not queried)
- `CampaignFormSheet` uses `@State` for form fields, seeded from optional model in init
- Confirmation dialogs pattern: `@State private var isShowingDeleteConfirmation = false` + `.confirmationDialog`
- Date formatting: static `DateFormatter` property on the row view struct
- Pluralization: inline ternary `"\(count) session\(count == 1 ? "" : "s")"`

### Git Intelligence

Recent commits:
- `de37c71` — feat: implement DictlyTheme design token system (Story 1.2)
- `2d4c73a` — feat: initialize Dictly project with macOS/iOS targets and shared DictlyKit package

Patterns established:
- Conventional commit messages: `feat:` prefix for new features
- Files in `DictlyiOS/Campaigns/` are already tracked
- No changes needed to `project.yml` (Campaigns path already included)

### Duration Formatting

Format `TimeInterval` (seconds) as human-readable duration:
- 0 seconds → "0m" (placeholder sessions)
- Under 1 hour → "42m"
- 1+ hours → "3h 42m"
- Never show raw seconds or `TimeInterval` values [Source: architecture.md#Timestamps]

Example helper:
```swift
private func formatDuration(_ duration: TimeInterval) -> String {
    let hours = Int(duration) / 3600
    let minutes = (Int(duration) % 3600) / 60
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    return "\(minutes)m"
}
```

### Auto-Numbering Logic

Session numbers are per-campaign, monotonically increasing, and never gap-fill:
```swift
let nextNumber = (campaign.sessions.map(\.sessionNumber).max() ?? 0) + 1
```

This ensures:
- First session in campaign → 1
- After sessions [1, 2, 3] → 4
- After deleting session 2, remaining [1, 3] → next is 4 (not 2)

### Naming Conventions

Per architecture.md naming patterns:
- Types: `PascalCase` — `SessionListRow`, `SessionFormSheet`
- File naming matches primary type — `SessionListRow.swift`
- Properties: `camelCase` — `sessionTitle`, `isShowingEditForm`
- Booleans: prefix with `is`/`has`/`should` — `isShowingDeleteConfirmation`

### Testing Approach

- This story is pure SwiftUI CRUD views backed by SwiftData relationships
- **No unit tests required** — the views are thin wrappers over SwiftData with no custom business logic
- Verify manually or via `xcodebuild` that the iOS target builds successfully
- The `Session` model is already tested via `DictlyModelsTests` from Story 1.1

### Project Structure Notes

- New files go in `DictlyiOS/Campaigns/` (already in project.yml sources)
- `CampaignDetailScreen.swift` is the only existing file modified
- No changes to `DictlyKit`, `DictlyMac`, `Package.swift`, or `project.yml`
- No `xcodegen generate` needed — Campaigns path already included

### References

- [Source: architecture.md#iOS Target Boundaries] — Campaigns/ is pure SwiftData @Query views
- [Source: architecture.md#Data Boundary] — @Query for lists, ModelContext for mutations
- [Source: architecture.md#SwiftUI Patterns] — NavigationStack, @State for view-local, @Query for data
- [Source: architecture.md#Naming Patterns] — PascalCase types, camelCase properties, boolean prefixes
- [Source: architecture.md#Project Structure] — SessionListRow.swift, SessionFormSheet.swift in DictlyiOS/Campaigns/
- [Source: architecture.md#Timestamps] — Duration formatting, never raw number display
- [Source: architecture.md#Anti-Patterns] — No AnyView, no @StateObject, no ObservableObject
- [Source: ux-design-specification.md#Empty States] — Session empty state message and action
- [Source: ux-design-specification.md#Navigation Patterns] — iOS NavigationStack, max 3 levels deep
- [Source: ux-design-specification.md#Modal and Overlay Patterns] — .sheet for forms, .confirmationDialog for delete
- [Source: ux-design-specification.md#Type Scale] — Body for titles, Caption for metadata
- [Source: ux-design-specification.md#Standard Components] — List, Form, .sheet, .confirmationDialog
- [Source: epics.md#Story 1.4] — Acceptance criteria and story definition
- [Source: prd.md#FR20-FR22] — Sessions nested under campaigns, auto-numbering, metadata, location

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
