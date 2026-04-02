# Story 4.7: Tag Notes & Session Summary Notes

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a DM,
I want to add text notes to individual tags and write a session-level summary,
so that I can capture context that audio alone can't convey.

## Acceptance Criteria

1. **Given** a selected tag in the detail panel, **when** the DM types in the notes area, **then** notes are saved automatically on blur (no save button needed).

2. **Given** a tag with existing notes, **when** the DM edits or clears the notes, **then** changes persist immediately to SwiftData.

3. **Given** the session toolbar, **when** the DM clicks "Session Notes", **then** a session-level summary note editor appears **and** the DM can write a 1-2 line session summary.

4. **Given** a tag with notes, **when** the tag appears in the sidebar, **then** the presence of notes is indicated (e.g., a small icon).

## Tasks / Subtasks

- [ ] Task 1: Replace tag notes placeholder with editable TextEditor in TagDetailPanel (AC: #1, #2)
  - [ ] 1.1 In `TagDetailPanel.swift`, replace the read-only `RoundedRectangle` notes placeholder (lines 178-193) with an editable `TextEditor` bound to a `@State private var editingNotes: String` variable
  - [ ] 1.2 Style the TextEditor: `DictlyTypography.body`, `DictlyColors.surface` background, `DictlyColors.border` stroke on focus, rounded corners (6pt), minimum height 60pt, grows with content (use `.frame(minHeight: 60, maxHeight: 150)`)
  - [ ] 1.3 Show placeholder text "Add notes…" when notes are empty — TextEditor doesn't have native placeholder, use a `.overlay` with `Text("Add notes…")` in `DictlyColors.textSecondary` that hides when `editingNotes` is non-empty, with `allowsHitTesting(false)` so clicks pass through
  - [ ] 1.4 Add `@FocusState private var isEditingNotes: Bool` and attach `.focused($isEditingNotes)` to the TextEditor
  - [ ] 1.5 On focus loss (`.onChange(of: isEditingNotes)` when `false`): call `commitNotes(tag:)` — same pattern as existing `commitLabel(tag:)` with stale-capture guard via `selectedTag?.uuid == tag.uuid`
  - [ ] 1.6 `commitNotes(tag:)`: if `editingNotes.trimmingCharacters(in: .whitespacesAndNewlines)` is empty, set `tag.notes = nil`; otherwise set `tag.notes = editingNotes`. SwiftData auto-persists — no explicit save needed
  - [ ] 1.7 Sync `editingNotes` from `tag.notes ?? ""` in the existing `onChange(of: selectedTag?.uuid)` block and the `onAppear` block (same pattern as `editingLabel`)
  - [ ] 1.8 Accessibility: `.accessibilityLabel("Tag notes, editable")`, `.accessibilityHint("Type to add notes for this tag")`
  - [ ] 1.9 Post `AccessibilityNotification.Announcement("Notes saved")` after commitNotes writes

- [ ] Task 2: Wire "Session Notes" toolbar button to session summary editor (AC: #3)
  - [ ] 2.1 In `SessionReviewScreen.swift`, add `@State private var isShowingSessionNotes: Bool = false`
  - [ ] 2.2 Replace the disabled "Session Notes" button (lines 201-204) with an active button that sets `isShowingSessionNotes = true`
  - [ ] 2.3 Present a `.sheet(isPresented: $isShowingSessionNotes)` containing `SessionNotesView(session: session)`
  - [ ] 2.4 Enable the button unconditionally — session notes don't depend on audio or tags
  - [ ] 2.5 Accessibility: `.accessibilityLabel("Edit session notes")`, `.help("Add or edit session summary notes")`

- [ ] Task 3: Create SessionNotesView (AC: #3)
  - [ ] 3.1 Create `DictlyMac/Campaigns/SessionNotesView.swift` (architecture specifies this location)
  - [ ] 3.2 Accept `@Bindable var session: Session` — bind directly to `session.summaryNote` via SwiftData's `@Bindable` support
  - [ ] 3.3 Layout: title "Session Notes" (`DictlyTypography.h3`), subtitle with session title + date, TextEditor for the summary note, "Done" button to dismiss
  - [ ] 3.4 TextEditor bound to a `@State private var editingNote: String` initialized from `session.summaryNote ?? ""`. On dismiss or Done: write back `session.summaryNote = editingNote.isEmpty ? nil : editingNote`
  - [ ] 3.5 Sheet size: `.frame(minWidth: 400, minHeight: 250)` — compact sheet, not full-screen
  - [ ] 3.6 Add placeholder overlay "Write a session summary…" (same pattern as Task 1.3)
  - [ ] 3.7 Style: DictlyTheme tokens throughout — `DictlyColors.surface` TextEditor background, `DictlySpacing.md` padding, `DictlyTypography.body` for text
  - [ ] 3.8 Accessibility: TextEditor `.accessibilityLabel("Session summary note")`, Done button `.accessibilityLabel("Save and close session notes")`
  - [ ] 3.9 On dismiss: post `AccessibilityNotification.Announcement("Session notes saved")` if content changed

- [ ] Task 4: Add notes indicator to TagSidebarRow (AC: #4)
  - [ ] 4.1 In `TagSidebarRow.swift`, after the `Spacer(minLength: 0)`, add a conditional `Image(systemName: "note.text")` icon that appears when `tag.notes != nil && !tag.notes!.isEmpty`
  - [ ] 4.2 Style: `.font(.system(size: 10))`, `DictlyColors.textSecondary` foreground, `.accessibilityHidden(true)` (info is supplementary)
  - [ ] 4.3 Update the existing `.accessibilityLabel` to append ", has notes" when notes exist: `"\(tag.categoryName): \(tag.label...) at \(formatTimestamp(...))` + `(tag.notes != nil && !tag.notes!.isEmpty ? ", has notes" : "")`

- [ ] Task 5: Accessibility pass (AC: #1, #2, #3, #4)
  - [ ] 5.1 TagDetailPanel notes area: VoiceOver reads "Tag notes, editable. Current notes: [first 50 chars]" or "Tag notes, empty" when no notes
  - [ ] 5.2 SessionNotesView: VoiceOver announces "Session notes editor" when sheet opens
  - [ ] 5.3 Focus management: when TagDetailPanel notes TextEditor gains focus, post "Editing tag notes"
  - [ ] 5.4 Notes indicator in sidebar: included in parent accessibility label, not separately focusable

- [ ] Task 6: Unit tests (AC: #1, #2, #3, #4)
  - [ ] 6.1 Create `DictlyMacTests/ReviewTests/TagNotesTests.swift`
  - [ ] 6.2 Test: setting `tag.notes = "some note"` persists in SwiftData context (fetch back and verify)
  - [ ] 6.3 Test: setting `tag.notes = nil` clears notes in SwiftData context
  - [ ] 6.4 Test: setting `tag.notes = "  "` (whitespace only) — verify the trimming logic would set nil
  - [ ] 6.5 Test: setting `session.summaryNote = "Session summary"` persists in SwiftData context
  - [ ] 6.6 Test: setting `session.summaryNote = nil` clears summary in SwiftData context
  - [ ] 6.7 Test: tag with notes has `notes != nil && !notes!.isEmpty` (for sidebar indicator logic)
  - [ ] 6.8 Test: tag without notes has `notes == nil` (indicator should not show)
  - [ ] 6.9 Use `@MainActor`, in-memory `ModelContainer` with `ModelConfiguration(isStoredInMemoryOnly: true)`, `DictlySchema.all` (project convention from stories 4-5 and 4-6)

## Dev Notes

### Core Architecture

This story converts two read-only placeholder areas into functional editing surfaces. The `Tag.notes` and `Session.summaryNote` properties already exist in the SwiftData models — no model changes needed. The work is purely UI: replace placeholders with editable `TextEditor` views and add the sidebar notes indicator.

### Key Design Decisions

**Auto-save on blur** (UX spec: "Inline editing everywhere on Mac — no separate edit screens"): Notes save when the TextEditor loses focus, identical to the existing label-editing pattern in `TagDetailPanel.commitLabel()`. No save button — standard macOS inline editing behavior.

**TextEditor over TextField**: Notes are multi-line free-form text. `TextEditor` supports multi-line editing natively. `TextField` with `axis: .vertical` is an alternative but `TextEditor` gives better control over min/max height and is the standard choice for multi-line macOS text input.

**Session notes as sheet, not inline**: The session summary is a session-level concern, not a tag-level one. A sheet presented from the toolbar button keeps the review flow focused. The UX spec shows "Session Notes" as a toolbar action (Journey 3: "Click 'Session Notes' → Write 1-2 line summary").

**Notes indicator in sidebar**: A small `note.text` SF Symbol after the tag label signals "this tag has notes" without cluttering the sidebar. It's supplementary — the notes are visible in the detail panel when the tag is selected.

**`summaryNote` not `summaryNotes`**: The Session model uses `summaryNote` (singular) — match this exactly when binding.

### SwiftData Auto-Save Pattern

Same as all previous stories: mutating a `@Model` property triggers SwiftData auto-persistence. No explicit `context.save()` call needed. The `commitNotes(tag:)` function sets `tag.notes` directly — SwiftData handles the rest.

```swift
// Notes save on blur — same pattern as commitLabel
private func commitNotes(tag: Tag) {
    guard selectedTag?.uuid == tag.uuid else { return }
    let trimmed = editingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    tag.notes = trimmed.isEmpty ? nil : editingNotes
}
```

### Stale-Capture Guard

Story 4-5 discovered a race condition where the tag reference could change between showing and confirming an alert. The same risk exists with notes: the user could start typing notes, switch tags, and then the blur event would fire. The `guard selectedTag?.uuid == tag.uuid` check prevents writing notes to the wrong tag. Apply this pattern in `commitNotes(tag:)`.

### Existing Code to Reuse

| What | Where | How |
|------|-------|-----|
| `TagDetailPanel` | `DictlyMac/Review/TagDetailPanel.swift` | **MODIFY**: replace notes placeholder with editable TextEditor, add `editingNotes` state, `commitNotes()` |
| `SessionReviewScreen` | `DictlyMac/Review/SessionReviewScreen.swift` | **MODIFY**: enable "Session Notes" button, add sheet presentation state |
| `TagSidebarRow` | `DictlyMac/Review/TagSidebarRow.swift` | **MODIFY**: add notes indicator icon |
| `SessionNotesView` | `DictlyMac/Campaigns/SessionNotesView.swift` | **NEW**: session-level summary note editor |
| `Tag` model | `DictlyKit/Sources/DictlyModels/Tag.swift` | **USE**: `notes: String?` property already exists |
| `Session` model | `DictlyKit/Sources/DictlyModels/Session.swift` | **USE**: `summaryNote: String?` property already exists |
| `commitLabel(tag:)` | `TagDetailPanel.swift` | **REFERENCE**: same pattern for commitNotes — stale-capture guard, trim, write |
| `DictlyColors` | `DictlyKit/Sources/DictlyTheme/Colors.swift` | Surface, border, textSecondary for TextEditor styling |
| `DictlyTypography` | `DictlyKit/Sources/DictlyTheme/Typography.swift` | `body` for notes text, `h3` for section titles, `caption` for labels |
| `DictlySpacing` | `DictlyKit/Sources/DictlyTheme/Spacing.swift` | `xs`, `sm`, `md` for layout |

### What NOT to Do

- **Do NOT** modify `Tag.swift` or `Session.swift` models — `notes` and `summaryNote` properties already exist
- **Do NOT** add explicit `context.save()` calls — SwiftData auto-persistence handles this
- **Do NOT** create a save button for notes — auto-save on blur per UX spec
- **Do NOT** implement rich text editing (bold, italic, etc.) — plain text only
- **Do NOT** implement transcription editing — that is Epic 5 (FR39, FR40)
- **Do NOT** modify the transcription placeholder in TagDetailPanel — leave it as-is for story 5.x
- **Do NOT** implement related tags in the right column — that is Epic 6 (FR42, FR43)
- **Do NOT** implement markdown export of notes — that is Epic 6 (FR45, FR46)
- **Do NOT** use `@StateObject` or `ObservableObject` — use `@State` for view-local state, `@Bindable` for SwiftData model bindings
- **Do NOT** use `AnyView` — use `@ViewBuilder` or conditional views
- **Do NOT** hardcode colors, fonts, or spacing — use `DictlyTheme` tokens exclusively
- **Do NOT** add `#if os()` in DictlyKit — all new UI lives in DictlyMac target
- **Do NOT** add undo/redo for notes editing — standard macOS TextEditor already provides this via the responder chain

### Project Structure Notes

```
DictlyMac/Review/
├── TagDetailPanel.swift         # MODIFIED: replace notes placeholder with editable TextEditor
├── SessionReviewScreen.swift    # MODIFIED: enable Session Notes button, add sheet state
├── TagSidebarRow.swift          # MODIFIED: add notes indicator icon

DictlyMac/Campaigns/
└── SessionNotesView.swift       # NEW: session summary note editor sheet

DictlyMacTests/ReviewTests/
└── TagNotesTests.swift          # NEW: notes persistence and logic tests
```

### Testing Standards

- Use `XCTest` with `@MainActor` (project convention)
- In-memory `ModelContainer`: `ModelConfiguration(isStoredInMemoryOnly: true)` with `DictlySchema.all`
- Create test `Session` and `Tag` instances with known values
- Test notes persistence via direct model property mutation + `context.fetch` verification
- Test trim/nil logic as direct property assertions
- Mac test target may not run locally without signing certificate — verify `** TEST BUILD SUCCEEDED **`

### Previous Story (4-6) Learnings

- **`@Bindable` on SwiftData models**: Use `@Bindable` for two-way binding to `@Model` properties. SessionNotesView should use `@Bindable var session: Session` for direct binding.
- **State reset on selection change**: Always reset transient editing state when `selectedTag` changes. `editingNotes` must be synced in the existing `onChange(of: selectedTag?.uuid)` block — same pattern as `editingLabel`.
- **Stale-capture guard**: Always check `selectedTag?.uuid == tag.uuid` before writing — prevents notes from being saved to the wrong tag if selection changes during editing.
- **xcodegen**: Must be re-run after adding new source files. `SessionNotesView.swift` and `TagNotesTests.swift` both need xcodegen.
- **Build with `CODE_SIGN_IDENTITY=""`**: Pre-existing constraint from story 3.3 — required for local builds.
- **NSViewRepresentable patterns**: Story 4-6 used AppKit interop for right-click. If `TextEditor` has limitations on macOS (e.g., styling), `NSTextView` via `NSViewRepresentable` is available but should not be needed for basic multi-line text.

### Git Intelligence

Recent commits follow `feat(review):` / `fix(review):` conventional commit format with `(story X-Y)` suffix. Expected commit: `feat(review): implement tag notes and session summary notes (story 4-7)`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md - Epic 4, Story 4.7 acceptance criteria]
- [Source: _bmad-output/planning-artifacts/architecture.md - FR34: DM can add, edit, and delete text notes on individual tags]
- [Source: _bmad-output/planning-artifacts/architecture.md - FR35: DM can add a session-level summary note]
- [Source: _bmad-output/planning-artifacts/architecture.md - TagDetailPanel: FR30-FR32 (edit/change/delete tags), FR34 (notes), FR35 (session summary)]
- [Source: _bmad-output/planning-artifacts/architecture.md - SessionNotesView.swift: Session-level summary notes]
- [Source: _bmad-output/planning-artifacts/architecture.md - Tag model: uuid, label, categoryName, anchorTime, rewindDuration, notes, transcription]
- [Source: _bmad-output/planning-artifacts/architecture.md - Session model: summaryNote property]
- [Source: _bmad-output/planning-artifacts/architecture.md - SwiftData @Model macro with auto-persistence]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - TagDetailPanel anatomy: notes area (free-form editable text)]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Inline editing everywhere on Mac — no separate edit screens]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Transcription and notes auto-save on blur]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Journey 3: "Add notes → Type in notes area below transcription"]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md - Journey 3: "Click 'Session Notes' → Write 1-2 line summary"]
- [Source: _bmad-output/planning-artifacts/prd.md - FR34: DM can add, edit, and delete text notes on individual tags]
- [Source: _bmad-output/planning-artifacts/prd.md - FR35: DM can add a session-level summary note]
- [Source: DictlyKit/Sources/DictlyModels/Tag.swift - notes: String? property at line 11]
- [Source: DictlyKit/Sources/DictlyModels/Session.swift - summaryNote: String? property at line 14]
- [Source: DictlyMac/Review/TagDetailPanel.swift - Notes placeholder at lines 178-193, commitLabel pattern at lines 253-265]
- [Source: DictlyMac/Review/SessionReviewScreen.swift - Disabled "Session Notes" button at lines 201-204]
- [Source: DictlyMac/Review/TagSidebarRow.swift - Current row layout, accessibilityLabel pattern]
- [Source: _bmad-output/implementation-artifacts/4-6-retroactive-tag-placement.md - Previous story learnings, review findings]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
