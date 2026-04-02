# Story 4.1: Mac Session Review Layout

Status: ready-for-dev

## Story

As a DM,
I want a three-panel review layout with sidebar, waveform area, and detail area,
so that I can see all my session data organized for efficient review.

## Acceptance Criteria

1. **Given** the DM opens a session on Mac, **when** the session review screen loads, **then** a `NavigationSplitView` displays: left sidebar (260pt) with tag list, main area with toolbar and waveform timeline placeholder, and a detail area below the waveform.

2. **Given** the toolbar area, **when** the session is displayed, **then** session name, campaign name, duration, tag count, and action buttons (Transcribe All, Export MD, Session Notes) are visible.

3. **Given** no tag is selected, **when** the detail area is visible, **then** a placeholder prompt is shown: "Select a tag to view details".

4. **Given** a window at minimum size (900x500pt), **when** the layout adapts, **then** the sidebar collapses to icons and the detail area stacks vertically.

5. **Given** the sidebar toggle, **when** the DM hides the sidebar, **then** the waveform and detail area expand to fill the available width.

## Tasks / Subtasks

- [ ] Task 1: Create `SessionReviewScreen.swift` — main three-panel layout (AC: #1, #4, #5)
  - [ ] 1.1 Create `SessionReviewScreen.swift` in `DictlyMac/Review/`
  - [ ] 1.2 Accept a `Session` parameter (the session to review)
  - [ ] 1.3 Use `NavigationSplitView` with `sidebar` and `detail` columns
  - [ ] 1.4 Sidebar: 260pt default width, contains `TagSidebar` (placeholder `List` for now — story 4.4 implements full tag sidebar)
  - [ ] 1.5 Detail/main area: vertical layout with toolbar section at top, waveform placeholder in middle, `TagDetailPanel` placeholder at bottom
  - [ ] 1.6 Add `@State private var selectedTag: Tag?` for tag selection binding
  - [ ] 1.7 Sidebar toggle uses `NavigationSplitView`'s native collapse — no custom toggle needed
  - [ ] 1.8 Use `DictlyTheme` tokens for all colors, typography, and spacing

- [ ] Task 2: Create toolbar section in `SessionReviewScreen` (AC: #2)
  - [ ] 2.1 Display session title (`.title3` semibold), campaign name (`.caption` muted), duration (formatted as `Xh Ym`), tag count
  - [ ] 2.2 Add three action buttons: "Transcribe All", "Export MD", "Session Notes" — disabled/non-functional stubs for now (implemented in later stories)
  - [ ] 2.3 Use `HStack` with leading metadata and trailing action buttons
  - [ ] 2.4 Duration formatting: use `Duration.TimeFormatStyle` or manual formatting — never raw `TimeInterval` display

- [ ] Task 3: Create waveform placeholder (AC: #1)
  - [ ] 3.1 Add a `RoundedRectangle` placeholder in the waveform area with "Waveform Timeline" centered text
  - [ ] 3.2 Use `DictlyTheme.Colors.surfaceSecondary` background
  - [ ] 3.3 Minimum height 120pt, flexible width (fills available space)
  - [ ] 3.4 This placeholder will be replaced by `SessionWaveformTimeline` in story 4.2

- [ ] Task 4: Create `TagDetailPanel.swift` — placeholder detail area (AC: #3)
  - [ ] 4.1 Create `TagDetailPanel.swift` in `DictlyMac/Review/`
  - [ ] 4.2 Accept `Tag?` binding — when `nil`, show placeholder: "Select a tag to view details" (centered, muted text)
  - [ ] 4.3 When a tag is selected, show: tag label (editable `TextField`), category badge (colored pill with category name), timestamp (`anchorTime` formatted as `MM:SS` or `H:MM:SS`), placeholder areas for transcription and notes (populated in stories 4.5/4.7)
  - [ ] 4.4 Use two-column layout per UX spec: left column (tag info, transcription placeholder, notes placeholder), right column (related tags placeholder — "Related tags across sessions" with placeholder text)
  - [ ] 4.5 At narrow windows (<1100pt width), collapse to single-column (related tags column hides)
  - [ ] 4.6 Animate appearance on tag selection (`.animation(.easeInOut(duration: 0.2))`)
  - [ ] 4.7 Use `DictlyTheme` tokens for all styling

- [ ] Task 5: Create `TagSidebar.swift` — basic sidebar with tag list (AC: #1, #5)
  - [ ] 5.1 Create `TagSidebar.swift` in `DictlyMac/Review/`
  - [ ] 5.2 Accept `Session` and `Binding<Tag?>` for selection
  - [ ] 5.3 Display a scrollable `List` of tags from `session.tags`, sorted by `anchorTime`
  - [ ] 5.4 Each row: color dot (category color from `TagCategory` lookup), tag label, formatted timestamp
  - [ ] 5.5 Selection highlights row and updates `selectedTag` binding
  - [ ] 5.6 Placeholder search field at top (non-functional — story 4.4 implements full filtering)
  - [ ] 5.7 Empty state: "No tags in this session. Place retroactive tags by scrubbing the waveform."

- [ ] Task 6: Create `TagSidebarRow.swift` — individual tag row (AC: #1)
  - [ ] 6.1 Create `TagSidebarRow.swift` in `DictlyMac/Review/`
  - [ ] 6.2 Display: colored circle (8pt, matched to `categoryName` via `TagCategoryColors`), tag label (14pt medium), timestamp (11pt caption, muted)
  - [ ] 6.3 VoiceOver accessibility label: "[Category]: [Label] at [timestamp]"

- [ ] Task 7: Wire `SessionReviewScreen` into Mac app navigation (AC: #1)
  - [ ] 7.1 Update `ContentView.swift` to navigate from campaign/session list to `SessionReviewScreen`
  - [ ] 7.2 Since `CampaignSidebar` and `SessionListView` don't exist yet, create a minimal temporary session picker: query all `Session` objects via `@Query`, display in a `List`, navigate to `SessionReviewScreen` on selection
  - [ ] 7.3 Keep `ImportProgressView` overlay working (already in `ContentView`)
  - [ ] 7.4 Ensure the `NavigationSplitView` in `SessionReviewScreen` works within the app's window structure

- [ ] Task 8: Responsive layout handling (AC: #4)
  - [ ] 8.1 Use `GeometryReader` or `.frame(minWidth:)` to detect window size
  - [ ] 8.2 At minimum size (900x500pt), `NavigationSplitView` sidebar auto-collapses natively — verify this works
  - [ ] 8.3 Detail area (TagDetailPanel): when window width <1100pt, collapse related tags column to single-column
  - [ ] 8.4 Set `.frame(minWidth: 900, minHeight: 500)` on the `WindowGroup` scene

- [ ] Task 9: Accessibility (AC: #1, #2, #3, #4, #5)
  - [ ] 9.1 All interactive elements have VoiceOver accessibility labels
  - [ ] 9.2 Tag sidebar rows: "[Category]: [Label] at [timestamp]"
  - [ ] 9.3 Toolbar buttons: descriptive labels ("Transcribe all tags", "Export as Markdown", "Session notes")
  - [ ] 9.4 Placeholder states: "No tag selected. Select a tag from the sidebar to view details."
  - [ ] 9.5 Waveform placeholder: "Waveform timeline placeholder. Available after waveform rendering is implemented."

- [ ] Task 10: Unit tests (AC: #1, #2, #3)
  - [ ] 10.1 Create `SessionReviewScreenTests.swift` in `DictlyMacTests/ReviewTests/`
  - [ ] 10.2 Test that `SessionReviewScreen` can be initialized with a `Session`
  - [ ] 10.3 Test `TagDetailPanel` shows placeholder when tag is nil
  - [ ] 10.4 Test `TagSidebar` displays tags sorted by `anchorTime`
  - [ ] 10.5 Test `TagSidebarRow` formats timestamp correctly (seconds → `MM:SS` / `H:MM:SS`)
  - [ ] 10.6 Test empty state shown when session has no tags
  - [ ] 10.7 Use in-memory `ModelContainer` with `ModelConfiguration(isStoredInMemoryOnly: true)` for SwiftData tests
  - [ ] 10.8 Use `@MainActor` on all test classes (project convention)

## Dev Notes

### Core Architecture

This is the **foundational layout story** for Epic 4 — all subsequent stories (4.2–4.7) build on this layout. The key output is `SessionReviewScreen.swift` with a `NavigationSplitView` that establishes the three-zone structure: tag sidebar, waveform timeline, and detail panel.

This story creates **structural placeholders** for components that later stories implement:
- Waveform placeholder → replaced by `SessionWaveformTimeline` in story 4.2
- Basic tag list → full `TagSidebar` with filtering in story 4.4
- Tag detail placeholders → full editing in stories 4.5, 4.7
- Action button stubs → wired to `TranscriptionEngine` (Epic 5), `MarkdownExporter` (Epic 6)

### NavigationSplitView Pattern

The Mac review screen uses `NavigationSplitView` with two columns:

```swift
NavigationSplitView {
    TagSidebar(session: session, selectedTag: $selectedTag)
        .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 320)
} detail: {
    VStack(spacing: 0) {
        // Toolbar section
        SessionToolbar(session: session)
        // Waveform area (placeholder now, replaced in 4.2)
        WaveformPlaceholder()
        // Detail panel (contextual)
        TagDetailPanel(tag: selectedTag)
    }
}
```

The sidebar and detail are the two `NavigationSplitView` columns. The waveform and detail panel live together in the `detail` column as a vertical stack.

### Tag Category Color Lookup

Tags store `categoryName: String`, not a relationship to `TagCategory`. To get the color:

```swift
// Query TagCategory by name to get colorHex
let categoryName = tag.categoryName
let descriptor = FetchDescriptor<TagCategory>(
    predicate: #Predicate<TagCategory> { $0.name == categoryName }
)
let category = try? context.fetch(descriptor).first
let color = category.map { Color(hex: $0.colorHex) } ?? DictlyTheme.Colors.textMuted
```

Alternatively, `DictlyTheme` already defines default category colors — use `DictlyTheme.Colors.category(for:)` if such a helper exists, or create a small lookup based on `TagCategory` model data. Check `DictlyKit/Sources/DictlyTheme/Colors.swift` for existing category color helpers.

### Timestamp Formatting

Tag `anchorTime` is `TimeInterval` (seconds from session start). Format for display:

```swift
func formatTimestamp(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%d:%02d", minutes, secs)
}
```

### Window Minimum Size

Set minimum window size in `DictlyMacApp.swift` on the `WindowGroup`:

```swift
WindowGroup {
    ContentView()
        // ... existing modifiers
}
.defaultSize(width: 1200, height: 700)
.windowResizability(.contentMinSize)
// ContentView should set .frame(minWidth: 900, minHeight: 500)
```

### Temporary Session Navigation

Since `CampaignSidebar` and `SessionListView` don't exist yet, `ContentView` needs a temporary way to navigate to sessions. Create a minimal session picker using `@Query`:

```swift
struct ContentView: View {
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @State private var selectedSession: Session?
    
    var body: some View {
        NavigationSplitView {
            List(sessions, selection: $selectedSession) { session in
                // minimal row
            }
        } detail: {
            if let session = selectedSession {
                SessionReviewScreen(session: session)
            } else {
                Text("Select a session")
            }
        }
        .overlay(alignment: .top) {
            ImportProgressView()
        }
    }
}
```

**Important:** This creates a two-level `NavigationSplitView` structure (outer: session picker, inner: SessionReviewScreen's sidebar). This is intentional — `ContentView`'s outer navigation provides campaign/session browsing (placeholder now), and `SessionReviewScreen`'s inner split provides the tag sidebar. Alternatively, `SessionReviewScreen` could use a plain `HStack` with manual sidebar instead of nested `NavigationSplitView` — evaluate which feels more natural. Nested `NavigationSplitView` may cause issues; prefer a flat approach where the outer `NavigationSplitView` has three columns (campaign sidebar | session list | session review detail) OR where `SessionReviewScreen` uses an `HSplitView` instead.

**Recommended approach:** Use the outer `NavigationSplitView` in `ContentView` for campaign/session navigation, and inside `SessionReviewScreen` use an `HSplitView` for the tag sidebar + main content split. This avoids nested `NavigationSplitView` issues.

### What NOT to Do

- **Do NOT** use `NavigationSplitView` inside `SessionReviewScreen` if `ContentView` already uses one — nested `NavigationSplitView` causes unpredictable behavior on macOS. Use `HSplitView` for the inner tag sidebar split instead.
- **Do NOT** implement waveform rendering — this story creates a placeholder only. Story 4.2 handles Core Audio waveform.
- **Do NOT** implement tag editing (rename, recategorize, delete) — story 4.5 handles this. Only display tag info in the detail panel.
- **Do NOT** implement audio playback — story 4.3 handles `AudioPlayer`.
- **Do NOT** implement tag filtering or search — story 4.4 handles full sidebar filtering.
- **Do NOT** implement transcription or notes editing — stories 4.7 and Epic 5 handle these.
- **Do NOT** use `@StateObject` or `ObservableObject` — use `@Observable` exclusively.
- **Do NOT** hardcode colors, fonts, or spacing — use `DictlyTheme` tokens.
- **Do NOT** use `AnyView` — use `@ViewBuilder` or conditional views.
- **Do NOT** add `#if os()` in DictlyKit — all review code lives in the Mac target.
- **Do NOT** modify `ImportService`, `ImportProgressView`, or `LocalNetworkReceiver` — they are complete from Epic 3.

### Existing Code to Reuse

| What | Where | How |
|------|-------|-----|
| `Session` model | `DictlyKit/Sources/DictlyModels/Session.swift` | Properties: `uuid`, `title`, `sessionNumber`, `date`, `duration`, `summaryNote`, `audioFilePath`, `tags` relationship |
| `Tag` model | `DictlyKit/Sources/DictlyModels/Tag.swift` | Properties: `uuid`, `label`, `categoryName`, `anchorTime`, `rewindDuration`, `notes`, `transcription` |
| `Campaign` model | `DictlyKit/Sources/DictlyModels/Campaign.swift` | Properties: `uuid`, `name`, `descriptionText`, `sessions` relationship |
| `TagCategory` model | `DictlyKit/Sources/DictlyModels/TagCategory.swift` | Properties: `name`, `colorHex`, `iconName`, `sortOrder`, `isDefault` |
| `DictlyTheme` | `DictlyKit/Sources/DictlyTheme/` | `Colors.swift`, `Typography.swift`, `Spacing.swift`, `Animation.swift` |
| `DictlySchema` | `DictlyKit/Sources/DictlyModels/DictlySchema.swift` | Schema for `ModelContainer` setup |
| `ImportProgressView` | `DictlyMac/Import/ImportProgressView.swift` | Overlay banner — keep working in ContentView |
| `ImportService` | `DictlyMac/Import/ImportService.swift` | Already wired — do not modify |
| `DictlyMacApp` | `DictlyMac/App/DictlyMacApp.swift` | Add window size constraints if needed |

### Project Structure Notes

New files:

```
DictlyMac/Review/
├── SessionReviewScreen.swift   # NEW: Main three-panel review layout
├── TagDetailPanel.swift        # NEW: Contextual detail area below waveform
├── TagSidebar.swift            # NEW: Basic tag list sidebar
└── TagSidebarRow.swift         # NEW: Individual tag row

DictlyMacTests/ReviewTests/
└── SessionReviewScreenTests.swift  # NEW: Layout and component tests
```

Modified files:
- `DictlyMac/App/ContentView.swift` — replace placeholder "Dictly" text with session navigation + `SessionReviewScreen`
- `DictlyMac/App/DictlyMacApp.swift` — add `.defaultSize()` and minimum window size

### Testing Standards

- Use `XCTest` with `@MainActor` (project convention)
- In-memory `ModelContainer`: `ModelConfiguration(isStoredInMemoryOnly: true)`
- Create test `Session` and `Tag` objects with known `anchorTime` values to verify sorting and timestamp formatting
- Mac test target may not run locally without signing certificate (pre-existing constraint from Epics 2-3) — verify test target builds cleanly
- Test UI state transitions: no selection → tag selected → different tag selected

### Previous Story (3.4) Learnings

- `@Observable @MainActor` is the pattern for all service classes — any new service classes in this story must follow
- `@Environment` for injecting services into SwiftUI views — `ImportService` is already injected this way
- `DictlyTheme` tokens must be used for all UI — no hardcoded values (story 3.4 review caught this)
- `.animation()` modifiers needed for state transitions — add explicitly (story 3.4 review found missing animations)
- Mac test builds succeed but cannot execute without signing cert — document this and focus on verifying build success

### Git Intelligence

Recent commits follow `feat(scope):` / `fix(scope):` / `test(scope):` / `docs(bmad):` conventional commit format. Epic 3 (Transfer & Import) is complete. This is the first story in Epic 4 (Session Review & Annotation).

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 4, Story 4.1 acceptance criteria]
- [Source: _bmad-output/planning-artifacts/architecture.md — Project Structure: SessionReviewScreen.swift, TagDetailPanel.swift, TagSidebar.swift, TagSidebarRow.swift in DictlyMac/Review/]
- [Source: _bmad-output/planning-artifacts/architecture.md — Mac Target Boundaries: Review/ owns waveform rendering, audio playback, and tag editing]
- [Source: _bmad-output/planning-artifacts/architecture.md — FR27-FR36 mapping to DictlyMac/Review/]
- [Source: _bmad-output/planning-artifacts/architecture.md — SwiftUI Patterns: @Observable, @State, @Query, NavigationSplitView]
- [Source: _bmad-output/planning-artifacts/architecture.md — Data Flow: Mac Review Flow]
- [Source: _bmad-output/planning-artifacts/prd.md — FR27 (timeline), FR28 (click to jump), FR29 (filter), FR30-FR32 (edit/change/delete), FR33 (retroactive), FR34 (notes), FR35 (session summary), FR36 (full scrub)]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Mac Modified Three-Panel layout: 260pt sidebar, toolbar, waveform, detail below waveform]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Mac Window Adaptation: 900x500pt minimum, 1200x700pt standard, sidebar collapsible]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Component 4 (SessionWaveformTimeline) and Component 5 (TagDetailPanel) specifications]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Empty States: "No tags in this session" and placeholder prompt]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Navigation Rules: Mac NavigationSplitView with sidebar]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Design Rationale: Three-panel familiar to Mac users]
- [Source: DictlyKit/Sources/DictlyModels/Session.swift — Session model properties and Tag relationship]
- [Source: DictlyKit/Sources/DictlyModels/Tag.swift — Tag model with anchorTime, categoryName, label]
- [Source: DictlyKit/Sources/DictlyModels/TagCategory.swift — colorHex, iconName for category display]
- [Source: DictlyKit/Sources/DictlyTheme/ — Colors, Typography, Spacing, Animation tokens]
- [Source: DictlyMac/App/ContentView.swift — current placeholder with ImportProgressView overlay]
- [Source: DictlyMac/App/DictlyMacApp.swift — existing ModelContainer, ImportService, LocalNetworkReceiver setup]
- [Source: _bmad-output/implementation-artifacts/3-4-mac-import-with-deduplication.md — previous story learnings: @Observable @MainActor pattern, DictlyTheme enforcement, animation modifiers]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
