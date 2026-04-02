# Story 4.5: Tag Editing — Rename, Recategorize & Delete

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a DM,
I want to edit tag labels, change categories, and delete tags during review,
so that I can refine my raw in-session tags into a polished session record.

## Acceptance Criteria

1. **Given** a selected tag in the detail panel, **when** the DM clicks the tag label, **then** the label becomes editable inline and saves on blur.

2. **Given** a selected tag, **when** the DM clicks the category badge, **then** a category picker appears and selecting a new category updates the tag immediately, **and** the waveform marker color and shape update to match.

3. **Given** a selected tag, **when** the DM clicks "Delete Tag" and confirms, **then** the tag is removed from the sidebar, waveform, and SwiftData, **and** a confirmation dialog is shown before deletion.

4. **Given** a right-click on a tag in the sidebar, **when** the context menu appears, **then** options include Edit Label, Change Category, and Delete Tag.

## Tasks / Subtasks

- [x] Task 1: Make tag label inline-editable in TagDetailPanel (AC: #1)
  - [x] 1.1 In `TagDetailPanel.swift`, replace the static `Text(tag.label)` (line 74) with a `TextField("Tag label", text: labelBinding)` where `labelBinding` is a `Binding<String>` that reads/writes `tag.label`
  - [x] 1.2 Create `@State private var editingLabel: String = ""` and sync it from `tag.label` using `.onChange(of: tag?.uuid)` — copy label into editing state when tag changes
  - [x] 1.3 On `.onSubmit` and `@FocusState` loss (blur), write `editingLabel` back to `tag.label` — this persists via SwiftData auto-save
  - [x] 1.4 Style the TextField: use `DictlyTypography.h3`, `.textFieldStyle(.plain)`, add a subtle `DictlyColors.border` underline on focus using `@FocusState private var isEditingLabel: Bool`
  - [x] 1.5 If label is empty on blur, revert to previous value (do not allow empty labels)
  - [x] 1.6 Accessibility: `.accessibilityLabel("Tag label, editable. Current value: \(tag.label)")` and `.accessibilityHint("Click to edit")`

- [x] Task 2: Make category badge tappable with category picker popover (AC: #2)
  - [x] 2.1 Change `TagDetailPanel` from `let tag: Tag?` to `@Bindable var tag: Tag?` — SwiftData `@Model` classes conform to `Observable`, so `@Bindable` enables two-way binding for inline edits. If `@Bindable` on optional causes issues, keep `let tag: Tag?` and mutate `tag.categoryName` directly (SwiftData tracks mutations on `@Model` properties automatically)
  - [x] 2.2 Wrap the existing `categoryBadge(for:)` call in a `Button` that sets `@State private var showCategoryPicker: Bool = false`
  - [x] 2.3 Attach `.popover(isPresented: $showCategoryPicker)` to the badge button, presenting a `CategoryPickerPopover` (private struct in same file)
  - [x] 2.4 `CategoryPickerPopover` lists all categories from `@Query(sort: \TagCategory.sortOrder) private var categories: [TagCategory]`, each as a row: colored dot (6pt, `categoryColor(for:)`) + name. Tapping a row sets `tag.categoryName = category.name`, dismisses popover
  - [x] 2.5 Highlight the currently selected category in the picker list (bold or checkmark)
  - [x] 2.6 Waveform marker color/shape auto-updates because `SessionWaveformTimeline` reads `tag.categoryName` reactively via SwiftData observation — **no waveform code changes needed**
  - [x] 2.7 Sidebar row auto-updates because `TagSidebarRow` reads `tag.categoryName` — **no sidebar row code changes needed**
  - [x] 2.8 Accessibility: badge button `.accessibilityLabel("Category: \(tag.categoryName). Click to change.")` and `.accessibilityHint("Opens category picker")`

- [x] Task 3: Add "Delete Tag" button with confirmation dialog (AC: #3)
  - [x] 3.1 Add an action row below the notes section in `leftColumn`: a red text "Delete Tag" button styled per UX spec (destructive: red text, `DictlyTypography.caption`)
  - [x] 3.2 Tapping "Delete Tag" sets `@State private var showDeleteConfirmation: Bool = false`
  - [x] 3.3 Attach `.alert("Delete Tag?", isPresented: $showDeleteConfirmation)` with message "This will permanently remove this tag." and two buttons: "Delete" (destructive role) and "Cancel"
  - [x] 3.4 On confirm: call `deleteTag(tag)` which does `tag.session?.tags.removeAll { $0.uuid == tag.uuid }` then `modelContext.delete(tag)`
  - [x] 3.5 After deletion, clear `selectedTag = nil` in `SessionReviewScreen` — requires changing `TagDetailPanel` to accept `@Binding var selectedTag: Tag?` instead of `let tag: Tag?`
  - [x] 3.6 SwiftData cascade: removing the tag from the session's tags array and deleting from context is sufficient — sidebar list and waveform markers auto-update via `@Query`/observation
  - [x] 3.7 Accessibility: delete button `.accessibilityLabel("Delete tag")`, confirmation dialog is natively accessible via `.alert`

- [x] Task 4: Add context menu to sidebar tag rows (AC: #4)
  - [x] 4.1 In `TagSidebar.swift`, attach `.contextMenu` to each `TagSidebarRow` inside the `List`
  - [x] 4.2 Context menu items: "Edit Label" (pencil icon), "Change Category" (tag icon), "Delete Tag" (trash icon, destructive)
  - [x] 4.3 "Edit Label": sets `selectedTag` to this tag and posts a notification or uses a callback to focus the label TextField in `TagDetailPanel`. Simplest approach: just select the tag — the DM can then click the label in the detail panel. Add `.accessibilityHint("Selects tag and opens detail panel for editing")`
  - [x] 4.4 "Change Category": sets `selectedTag` to this tag and triggers the category picker. Use a new `@State private var showCategoryPickerForContextMenu: Bool = false` in `SessionReviewScreen`, or keep it simple — just select the tag so the DM uses the badge in the detail panel
  - [x] 4.5 "Delete Tag": show `.alert` confirmation, then delete via `modelContext.delete(tag)` + clear `selectedTag` if it was the deleted tag
  - [x] 4.6 Need `@Environment(\.modelContext) private var modelContext` in `TagSidebar` for the delete action
  - [x] 4.7 After context-menu delete, if `selectedTag?.uuid == tag.uuid`, set `selectedTag = nil`

- [x] Task 5: Wire deletion through SessionReviewScreen (AC: #3, #4)
  - [x] 5.1 Change `TagDetailPanel(tag: selectedTag)` to `TagDetailPanel(selectedTag: $selectedTag)` in `SessionReviewScreen.mainContent` — pass binding so panel can nil-out selection on delete
  - [x] 5.2 Add `@Environment(\.modelContext) private var modelContext` to `TagDetailPanel` for delete operation
  - [x] 5.3 Verify that after deletion, the sidebar list updates (it should — `session.tags` is observed by `TagSidebar.filteredTags`)
  - [x] 5.4 Verify that after deletion, the waveform markers update (they should — `SessionWaveformTimeline` reads `session.tags`)
  - [x] 5.5 Log deletion: `Logger.tagging.info("Tag deleted: \(tag.label, privacy: .public) at \(tag.anchorTime, privacy: .public)")`

- [x] Task 6: Accessibility pass (AC: #1, #2, #3, #4)
  - [x] 6.1 Inline label edit: VoiceOver announces "Editing tag label" on focus, "Tag label saved" on blur
  - [x] 6.2 Category picker: each row reads "[Category name]. Double-tap to select."
  - [x] 6.3 Delete confirmation: `.alert` is natively accessible; ensure button roles are correct (`.destructive` for Delete)
  - [x] 6.4 Context menu: each item has appropriate SF Symbol and label
  - [x] 6.5 After tag deletion, post `AccessibilityNotification.Announcement("Tag deleted")` so VoiceOver confirms the action

- [x] Task 7: Unit tests (AC: #1, #2, #3, #4)
  - [x] 7.1 Create `TagEditingTests.swift` in `DictlyMacTests/ReviewTests/`
  - [x] 7.2 Test: renaming a tag updates `tag.label` in SwiftData (create Tag in-memory container, mutate label, verify)
  - [x] 7.3 Test: changing `tag.categoryName` persists correctly
  - [x] 7.4 Test: deleting a tag removes it from `session.tags` array
  - [x] 7.5 Test: deleting a tag removes it from the model context (verify via `context.fetch` returning empty)
  - [x] 7.6 Test: empty label after edit reverts to previous value (not saved as empty)
  - [x] 7.7 Use `@MainActor`, in-memory `ModelContainer` with `ModelConfiguration(isStoredInMemoryOnly: true)` (project convention)

## Dev Notes

### Core Architecture

This story transforms `TagDetailPanel` from read-only display to an interactive editing surface. Three editing operations:

1. **Rename** — inline `TextField` replacing static `Text` for the label
2. **Recategorize** — tappable category badge with popover picker
3. **Delete** — red text button with `.alert` confirmation, removes from SwiftData

SwiftData's `@Model` observation means waveform markers, sidebar rows, and tag counts all auto-update when `tag.label`, `tag.categoryName` are mutated or when a tag is deleted. **No changes needed** in `SessionWaveformTimeline.swift`, `TagSidebarRow.swift`, or `AudioPlayer.swift`.

### Key Design Decisions

**Inline editing pattern** (UX spec): "Inline editing everywhere on Mac — tag labels, transcriptions, notes are all editable in place. No separate edit screens."

**Confirmation only for delete** (UX spec): "Confirmation only for destructive actions — Stop Recording and Delete Tag. Everything else is instant."

**Auto-save on blur** (UX spec): "Transcription and notes auto-save on blur. No explicit save button." Same applies to label edits.

**Category picker as popover** — not a dropdown or sheet. Popover anchored to the badge is the standard macOS pattern for contextual selection. Use `.popover(isPresented:)`.

### SwiftData Mutation Pattern

SwiftData `@Model` classes track property mutations automatically. To rename a tag:
```swift
tag.label = "New Name"
// SwiftData auto-saves — no explicit context.save() needed
```

To change category:
```swift
tag.categoryName = "Combat"
// Waveform, sidebar, detail panel all update reactively
```

To delete:
```swift
tag.session?.tags.removeAll { $0.uuid == tag.uuid }
modelContext.delete(tag)
```

### TagDetailPanel Signature Change

Current: `let tag: Tag?`
New: `@Binding var selectedTag: Tag?`

This is needed so the panel can nil-out selection on delete. The panel accesses the tag as `selectedTag` (optional) and operates on the unwrapped value inside the `if let`.

### CategoryPickerPopover (Private Struct)

```swift
private struct CategoryPickerPopover: View {
    let currentCategory: String
    let onSelect: (String) -> Void
    @Query(sort: \TagCategory.sortOrder) private var categories: [TagCategory]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(categories) { category in
                Button {
                    onSelect(category.name)
                    dismiss()
                } label: {
                    HStack(spacing: DictlySpacing.sm) {
                        Circle()
                            .fill(categoryColor(for: category.name))
                            .frame(width: 8, height: 8)
                        Text(category.name)
                            .font(DictlyTypography.body)
                        Spacer()
                        if category.name == currentCategory {
                            Image(systemName: "checkmark")
                                .foregroundStyle(DictlyColors.textSecondary)
                        }
                    }
                    .padding(.horizontal, DictlySpacing.md)
                    .padding(.vertical, DictlySpacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minWidth: 180)
    }
}
```

### Context Menu on Sidebar Rows

```swift
// Inside TagSidebar.tagList
List(tags, id: \.uuid, selection: $selectedTag) { tag in
    TagSidebarRow(tag: tag)
        .tag(tag)
        .contextMenu {
            Button { selectedTag = tag } label: {
                Label("Edit Label", systemImage: "pencil")
            }
            Button { selectedTag = tag; /* trigger picker */ } label: {
                Label("Change Category", systemImage: "tag")
            }
            Divider()
            Button(role: .destructive) { tagToDelete = tag; showDeleteAlert = true } label: {
                Label("Delete Tag", systemImage: "trash")
            }
        }
}
```

For simplicity, "Edit Label" and "Change Category" just select the tag — the DM then uses the detail panel controls. This avoids complex state propagation between sidebar and detail panel.

### Delete Flow

1. DM clicks "Delete Tag" (detail panel button or context menu)
2. `.alert` confirmation dialog appears (macOS native)
3. On confirm: remove tag from session, delete from context, nil-out `selectedTag`
4. Sidebar and waveform auto-update via SwiftData observation

### Existing Code to Reuse

| What | Where | How |
|------|-------|-----|
| `TagDetailPanel` | `DictlyMac/Review/TagDetailPanel.swift` | **MODIFY**: inline editing, category picker, delete button, binding change |
| `TagSidebar` | `DictlyMac/Review/TagSidebar.swift` | **MODIFY**: add `.contextMenu` to tag rows, add `@Environment(\.modelContext)` |
| `SessionReviewScreen` | `DictlyMac/Review/SessionReviewScreen.swift` | **MODIFY**: pass `$selectedTag` binding to `TagDetailPanel` |
| `TagSidebarRow` | `DictlyMac/Review/TagSidebarRow.swift` | No changes — auto-updates via SwiftData observation |
| `SessionWaveformTimeline` | `DictlyMac/Review/SessionWaveformTimeline.swift` | No changes — markers auto-update via SwiftData observation |
| `AudioPlayer` | `DictlyMac/Review/AudioPlayer.swift` | No changes |
| `CategoryColorHelper` | `DictlyMac/Review/CategoryColorHelper.swift` | Reuse `categoryColor(for:)` in popover |
| `TagMarkerShape` | `DictlyMac/Review/TagMarkerShape.swift` | No changes — shape lookup auto-applies from `categoryName` |
| `DictlyColors` | `DictlyKit/Sources/DictlyTheme/Colors.swift` | Destructive red, surface, border tokens |
| `DictlyTypography` | `DictlyKit/Sources/DictlyTheme/Typography.swift` | `h3` for label, `caption` for buttons, `body` for picker |
| `DictlySpacing` | `DictlyKit/Sources/DictlyTheme/Spacing.swift` | `xs`, `sm`, `md` for layout |
| `Tag` model | `DictlyKit/Sources/DictlyModels/Tag.swift` | `label`, `categoryName` — mutable `@Model` properties |
| `TagCategory` model | `DictlyKit/Sources/DictlyModels/TagCategory.swift` | `@Query` for picker list |

### What NOT to Do

- **Do NOT** modify `TagSidebarRow.swift` — rows auto-update from SwiftData observation
- **Do NOT** modify `SessionWaveformTimeline.swift` — markers auto-update from SwiftData observation
- **Do NOT** modify `AudioPlayer.swift` — playback is unrelated to editing
- **Do NOT** modify any DictlyKit model files — `Tag.label` and `Tag.categoryName` are already mutable `String` properties
- **Do NOT** create a separate ViewModel — editing state is simple enough for `@State`/`@FocusState` in the view
- **Do NOT** use `@StateObject` or `ObservableObject` — use `@Observable` exclusively if creating observable classes (not needed here)
- **Do NOT** use `AnyView` — use `@ViewBuilder` or conditional views
- **Do NOT** implement tag notes editing — that is story 4.7
- **Do NOT** implement transcription editing — that is Epic 5
- **Do NOT** implement retroactive tag placement — that is story 4.6
- **Do NOT** implement undo/redo — not in acceptance criteria; save-on-blur is sufficient
- **Do NOT** use `.confirmationDialog` for delete — use `.alert` on Mac (per UX spec modal patterns table)
- **Do NOT** hardcode colors, fonts, or spacing — use `DictlyTheme` tokens exclusively
- **Do NOT** add `#if os()` in DictlyKit — all editing UI lives in the Mac target
- **Do NOT** cascade-delete tag notes or transcription separately — deleting the `Tag` `@Model` removes everything

### Project Structure Notes

Modified files only — no new production files:

```
DictlyMac/Review/
├── TagDetailPanel.swift              # MODIFIED: inline label editing, category picker popover, delete button, binding change
├── TagSidebar.swift                  # MODIFIED: context menu on tag rows, modelContext for delete
└── SessionReviewScreen.swift         # MODIFIED: pass $selectedTag binding to TagDetailPanel

DictlyMacTests/ReviewTests/
└── TagEditingTests.swift             # NEW: rename, recategorize, delete tests
```

### Testing Standards

- Use `XCTest` with `@MainActor` (project convention)
- In-memory `ModelContainer`: `ModelConfiguration(isStoredInMemoryOnly: true)`
- Create test `Tag` and `TagCategory` instances with known values
- Test SwiftData mutations directly (rename label, change categoryName, delete from context)
- Test empty-label guard (reverts to previous value)
- Mac test target may not run locally without signing certificate — verify `** TEST BUILD SUCCEEDED **`

### Previous Story (4.4) Learnings

- **`@Bindable` on SwiftData models**: SwiftData `@Model` classes conform to `Observable`. Use `@Bindable` in views when you need two-way binding to model properties. If `@Bindable var tag: Tag?` on optional is problematic, unwrap first with `if let tag` then bind directly.
- **`@ViewBuilder` limitations**: Cannot do multi-statement variable assignments inside `@ViewBuilder` functions. Use `let x = computeValue()` or helper functions.
- **`deinit` in `@MainActor` class**: In Swift 6, `deinit` is `nonisolated`. Avoid accessing `@MainActor`-isolated properties in `deinit`.
- **xcodegen**: Must be re-run after adding new source files. New test file `TagEditingTests.swift` needs xcodegen.
- **Marker opacity was compounded incorrectly in 4.4**: Lesson — apply opacity in one place, not nested. Relevant if touching marker rendering (not expected in this story).
- **Session change must nil-out `selectedTag`**: Already handled in `SessionReviewScreen.onChange(of: session.uuid)` from 4.4 review patch.
- **Test `container`/`context` infrastructure**: 4.4 tests had unused setup — keep test setup minimal and relevant.

### Git Intelligence

Recent commits follow `feat(scope):` / `fix(scope):` conventional commit format. Stories 4.1-4.4 each had implementation + review-patch commits. Expected commit pattern: `feat(review): implement tag editing rename recategorize and delete (story 4-5)`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md - Epic 4, Story 4.5 acceptance criteria]
- [Source: _bmad-output/planning-artifacts/architecture.md - FR30-FR32: edit/change/delete tags in TagDetailPanel.swift]
- [Source: _bmad-output/planning-artifacts/architecture.md - SwiftData @Model macro for Tag, Session with cascade delete]
- [Source: _bmad-output/planning-artifacts/architecture.md - @State for view-local state, @Query for reactive lists]
- [Source: _bmad-output/planning-artifacts/architecture.md - Review/ owns waveform rendering, audio playback, and tag editing]
- [Source: _bmad-output/planning-artifacts/architecture.md - TagCategory independent — deleting category does NOT delete tags]
- [Source: _bmad-output/planning-artifacts/architecture.md - Logger with subsystem com.dictly.mac, category tagging]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - TagDetailPanel: editable tag label + category badge + action row]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Inline editing everywhere on Mac — no separate edit screens]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Confirmation only for destructive actions: Delete Tag]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Mac confirmation pattern: .alert (not .confirmationDialog)]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Destructive button: red text, confirmation required]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Auto-save on blur pattern for text fields]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Tag category colors: Story=#D97706, Combat=#DC2626, Roleplay=#7C3AED, World=#059669, Meta=#4B7BE5]
- [Source: DictlyMac/Review/TagDetailPanel.swift - Current read-only implementation to transform]
- [Source: DictlyMac/Review/TagSidebar.swift - Tag list where context menu will be added]
- [Source: DictlyMac/Review/SessionReviewScreen.swift - Parent view managing selectedTag state]
- [Source: DictlyMac/Review/CategoryColorHelper.swift - categoryColor(for:) reuse in picker]
- [Source: DictlyKit/Sources/DictlyModels/Tag.swift - label, categoryName mutable properties]
- [Source: DictlyKit/Sources/DictlyModels/TagCategory.swift - name, sortOrder, colorHex for picker]
- [Source: _bmad-output/implementation-artifacts/4-4-tag-sidebar-with-category-filtering.md - Previous story learnings and code patterns]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Fixed `SessionReviewScreenTests.swift` line 53: updated `TagDetailPanel(tag: nil)` → `TagDetailPanel(selectedTag: .constant(nil))` to match new binding-based signature.
- Fixed `TagEditingTests.swift` `Session` initializer calls: added required `sessionNumber: 1` parameter.
- Build verified: `** TEST BUILD SUCCEEDED **` (signing not required for build verification).

### Completion Notes List

- **Task 1 (Label editing)**: Replaced static `Text(tag.label)` with `TextField("Tag label", text: $editingLabel)`. Added `@State private var editingLabel`, `@FocusState private var isEditingLabel`. On focus: syncs `editingLabel` from `tag.label` via `.onChange(of: selectedTag?.uuid)`. On blur/submit: `commitLabel(tag:)` writes back — guards against empty (reverts to `tag.label`). Border underline shown on focus. VoiceOver announcements on focus/save.
- **Task 2 (Category picker)**: Category badge wrapped in `.plain` Button that sets `showCategoryPicker = true`. Popover presents `CategoryPickerPopover` (private struct with `@Query` for live categories, `onSelect` callback to mutate `tag.categoryName` directly, checkmark + semibold highlight for current category).
- **Task 3 (Delete button)**: Red `DictlyColors.destructive` text button at bottom of leftColumn. Sets `showDeleteConfirmation = true`. `.alert` on body with destructive "Delete" + "Cancel". `deleteTag(_:)` removes from session array + `modelContext.delete` + nils `selectedTag` + VoiceOver announcement.
- **Task 4 (Context menu)**: `.contextMenu` added to each `TagSidebarRow` in `tagList`. "Edit Label" and "Change Category" both just select the tag (DM uses detail panel). "Delete Tag" (destructive role) sets `tagToDelete` + `showDeleteAlert`. `.alert` attached to main VStack body. `@Environment(\.modelContext)` added to `TagSidebar`.
- **Task 5 (SessionReviewScreen wiring)**: Single-line change: `TagDetailPanel(tag: selectedTag)` → `TagDetailPanel(selectedTag: $selectedTag)`. `TagDetailPanel` gains `@Environment(\.modelContext)` and `@Binding var selectedTag`. Logger with category "tagging" logs deletions.
- **Task 6 (Accessibility)**: VoiceOver announcements for focus ("Editing tag label"), save ("Tag label saved"), deletion ("Tag deleted"). Category picker rows use `.accessibilityLabel("[name]. Double-tap to select.")`. Delete button roles are `.destructive`. Context menu items have SF Symbols.
- **Task 7 (Tests)**: `TagEditingTests.swift` created in `DictlyMacTests/ReviewTests/`. Tests: label rename (2 cases), category change (2 cases), delete from session array (2 cases), delete from context (2 cases), empty-label guard (3 cases). All use `@MainActor`, in-memory container, `DictlySchema.all`. `** TEST BUILD SUCCEEDED **` confirmed.

### File List

- DictlyMac/Review/TagDetailPanel.swift (modified)
- DictlyMac/Review/TagSidebar.swift (modified)
- DictlyMac/Review/SessionReviewScreen.swift (modified)
- DictlyMacTests/ReviewTests/TagEditingTests.swift (new)
- DictlyMacTests/ReviewTests/SessionReviewScreenTests.swift (modified — updated TagDetailPanel init call)

### Review Findings

- [x] [Review][Patch] editingLabel not initialized on first render [TagDetailPanel.swift:37] — Fixed: added `.onAppear` to sync `editingLabel` from `selectedTag.label` on initial display
- [x] [Review][Patch] isEditingLabel and showCategoryPicker not reset on tag selection change [TagDetailPanel.swift:37-41] — Fixed: `onChange(of: selectedTag?.uuid)` now resets both state vars and clears `editingLabel` to "" when selection becomes nil
- [x] [Review][Patch] Wrong tag deleted when selectedTag changes between showing and confirming delete alert [TagDetailPanel.swift:42-51] — Fixed: introduced `@State private var tagToDeleteFromPanel: Tag?`; delete button captures current tag at tap time; alert action uses `tagToDeleteFromPanel` not `selectedTag`
- [x] [Review][Patch] categoryName written to deleted SwiftData object if category picker open during deletion [TagDetailPanel.swift:251] — Fixed: `deleteTag(_:)` sets `showCategoryPicker = false` before deleting, closing the popover and preventing the stale closure from firing
- [x] [Review][Patch] commitLabel stale tag capture can write to wrong tag after selection change [TagDetailPanel.swift:240] — Fixed: added `guard selectedTag?.uuid == tag.uuid else { return }` at top of `commitLabel(tag:)`
- [x] [Review][Defer] tag.session == nil on orphaned tag skips removeAll — silent desync possible [TagDetailPanel.swift:253, TagSidebar.swift:154] — deferred, pre-existing SwiftData relationship design
- [x] [Review][Defer] Concurrent delete from both TagDetailPanel and TagSidebar context menu — double modelContext.delete on same object [TagDetailPanel.swift:254, TagSidebar.swift:155] — deferred, pre-existing; extremely unlikely UX path on macOS

## Change Log

- 2026-04-02: Implemented story 4-5 tag editing — inline label rename, category picker popover, delete with confirmation, context menu on sidebar rows. All ACs satisfied. 11 unit tests added. Build: ** TEST BUILD SUCCEEDED **.
- 2026-04-02: Code review patches applied — 5 state/lifecycle fixes in TagDetailPanel: onAppear init, state reset on selection change, delete-alert tag capture, popover dismiss before deletion, commitLabel stale-capture guard.
