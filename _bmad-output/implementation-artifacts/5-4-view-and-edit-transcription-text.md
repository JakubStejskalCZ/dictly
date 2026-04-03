# Story 5.4: View & Edit Transcription Text

Status: done

## Story

As a DM,
I want to view transcriptions alongside tags and correct garbled fantasy names,
So that my session archive has accurate searchable text.

## Acceptance Criteria

1. **Given** a tag with completed transcription
   **When** the tag is selected in the detail panel
   **Then** the transcription text is displayed in the transcription block below the tag header

2. **Given** a transcription with errors (e.g., "Grim Thor" instead of "Grimthor")
   **When** the DM clicks into the transcription text
   **Then** the text becomes editable inline

3. **Given** the DM edits a transcription
   **When** they click away (blur)
   **Then** the corrected text auto-saves to SwiftData

4. **Given** a tag without transcription
   **When** it is selected in the detail panel
   **Then** the transcription area shows "Transcription not yet run." with an inline "Transcribe" button

## Tasks / Subtasks

- [x] Task 1: Replace read-only transcription display with inline-editable TextEditor (AC: #1, #2, #3)
  - [x] 1.1 In `DictlyMac/Review/TagDetailPanel.swift`, locate the `transcriptionBlock()` method — specifically the "complete" state branch (currently `Text(text)` with `.textSelection(.enabled)` around line 270)
  - [x] 1.2 Add a `@State private var editingTranscription: String = ""` property to `TagDetailPanel` for local edit buffer
  - [x] 1.3 Add a `@FocusState private var isTranscriptionFocused: Bool` property to track edit mode
  - [x] 1.4 Replace `Text(text)` in the "complete" state with a `TextEditor(text: $editingTranscription)` that activates on click/focus
  - [x] 1.5 Style the TextEditor to match the existing notes editing pattern: `.font(.body)`, `.scrollContentBackground(.hidden)`, border on focus via `strokeBorder`
  - [x] 1.6 Sync `editingTranscription` from `tag.transcription` in `.onAppear` and `.onChange(of: selectedTag?.uuid)`
  - [x] 1.7 Commit edits on blur: `@FocusState` + `.onChange(of: isTranscriptionFocused)` writes `tag.transcription = editingTranscription`
  - [x] 1.8 SwiftData auto-saves on property mutation — no manual `modelContext.save()` call needed

- [x] Task 2: Ensure transcription display is always visible when present (AC: #1)
  - [x] 2.1 TextEditor with `.frame(minHeight: 60, maxHeight: 200)` — no truncation
  - [x] 2.2 Scrolls within detail panel via `maxHeight: 200` constraint — long text is scrollable
  - [x] 2.3 TextEditor uses `.font(DictlyTypography.body)` consistent with UX spec

- [x] Task 3: Preserve existing transcription states (AC: #4)
  - [x] 3.1 "No transcription" state (nil) unchanged — still shows "Transcribe" button
  - [x] 3.2 "In progress" state unchanged — still shows `ProgressView()` with "Transcribing…" label
  - [x] 3.3 "Error" state unchanged — still shows error badge with "Retry" button
  - [x] 3.4 Only the "complete" state (`tag.transcription != nil`) changes from read-only to editable

- [x] Task 4: Handle edge cases for transcription editing (AC: #2, #3)
  - [x] 4.1 Clearing text saves `""` via `commitTranscription` — guard uses `(tag.transcription ?? "")` comparison, preserving empty string distinction from nil
  - [x] 4.2 New transcription for non-editing tag shows correctly on selection — buffer loads from model in `onChange(of: selectedTag?.uuid)`
  - [x] 4.3 Tag switch commits pending edit — `onChange(of: selectedTag?.uuid)` fetches old tag by UUID and writes `editingTranscription` if changed
  - [x] 4.4 Batch transcription update visible on next selection — buffer syncs from `tag.transcription ?? ""` when tag is selected

- [x] Task 5: Write unit/UI tests (AC: #1–#4)
  - [x] 5.1 Created `DictlyMacTests/ReviewTests/TagDetailPanelTests.swift` (new file)
  - [x] 5.2 Test: `testTagWithTranscription_hasNonNilTranscription` and `testTagWithTranscription_bufferInitialisedFromModel`
  - [x] 5.3 Test: `testCommitTranscriptionLogic_savesEditedText` and `testCommitTranscription_persistsMultipleEdits`
  - [x] 5.4 Test: `testTagWithoutTranscription_hasNilTranscription` and `testTagNilTranscription_distinctFromEmptyString`
  - [x] 5.5 Test: `testTagSwitch_committsPendingEditToOldTag` and `testTagSwitch_newTagBufferLoadsCorrectTranscription`
  - [x] 5.6 Test: `testClearingTranscriptionText_savesEmptyString` and `testClearingTranscription_doesNotRevertToNil`
  - [x] 5.7 All 245 DictlyKit tests pass (0 regressions) — `swift test` in DictlyKit
  - [x] 5.8 Mac test target builds cleanly: `** TEST BUILD SUCCEEDED **`
  - [x] 5.9 DictlyKit tests include TranscriptionEngine model tests — all pass

### Review Findings

- [x] [Review][Patch] Remove `isTranscriptionFocused` guard from `onChange(of: selectedTag?.uuid)` commit block — edit silently dropped if OS clears focus before onChange fires [TagDetailPanel.swift:66]
- [x] [Review][Patch] Sync `editingTranscription` when `tag.transcription` changes externally — buffer goes stale after re-transcription completes on currently-selected tag [TagDetailPanel.swift:283]
- [x] [Review][Defer] Delete tag while transcription editor focused may write to deleted model object [TagDetailPanel.swift:433] — deferred, pre-existing pattern matches notes commit; alert dialog naturally dismisses focus before delete fires
- [x] [Review][Defer] Tests cannot cover private `commitTranscription` guard (selectedTag stale-capture path) — deferred, Swift private method limitation; model-layer tests are correct per project convention

## Dev Notes

### Architecture Compliance

- **Module boundary:** All changes are in `DictlyMac/Review/TagDetailPanel.swift`. No changes to `DictlyKit`, `DictlyiOS`, or `DictlyMac/Transcription/`. This is a pure UI change within the Mac review module.
- **State management:** Use `@State` for the local edit buffer (`editingTranscription`) and `@FocusState` for detecting blur. The `TranscriptionEngine` is accessed via `@Environment(TranscriptionEngine.self)` (already injected). No new `@Observable` classes needed.
- **SwiftData saves:** Writing `tag.transcription = editingTranscription` auto-saves via SwiftData context. No manual save calls needed.
- **Error handling:** No new error types. Editing is a direct property write — if SwiftData fails, the existing SwiftData error propagation handles it.
- **Logging:** No new logging required for text editing. The existing `os.Logger` in TranscriptionEngine covers transcription operations.
- **Anti-patterns:** No `ObservableObject`/`@StateObject`. No `AnyView`. No `Result` return types. No custom save logic wrapping SwiftData.

### Existing Code to Reuse / Extend

- **`TagDetailPanel.swift`** at `DictlyMac/Review/TagDetailPanel.swift` — The ONLY file to modify. Contains `transcriptionBlock()` method with 4 states: in-progress, complete (currently read-only), error, and no-transcription. The "complete" state at ~line 268–278 is the target for editing.
- **Notes editing pattern** in the same file (~lines 186–225) — Already implements inline `TextEditor` with auto-save on blur for tag notes. Copy this pattern exactly for transcription editing: `@State` buffer, sync on tag selection change, commit on blur via `@FocusState`.
- **`Tag.swift`** at `DictlyKit/Sources/DictlyModels/Tag.swift` — `transcription: String?` property. Write directly to this. No validation, no computed properties, no side effects.
- **`TranscriptionEngine.swift`** at `DictlyMac/Transcription/TranscriptionEngine.swift` — Provides `isTranscribing`, `currentTagId`, `tagErrors[UUID]`, and `batchErrors` state. Used to determine which transcription state to render. **Do not modify this file.**
- **`DictlyMacApp.swift`** at `DictlyMac/App/DictlyMacApp.swift` — Already injects `TranscriptionEngine`, `ModelManager`, `WhisperBridge`, and SwiftData `ModelContainer` into the environment. **Do not modify this file.**

### Implementation Strategy

The change is minimal — replace a `Text()` view with a `TextEditor` in one branch of the `transcriptionBlock()` method. Follow the notes editing pattern already in the same file:

1. Add `@State private var editingTranscription: String = ""`
2. Add `@FocusState private var isTranscriptionFocused: Bool`
3. In the "complete" state, replace `Text(text)` with:
   ```swift
   TextEditor(text: $editingTranscription)
       .font(.body)
       .scrollContentBackground(.hidden)
       .focused($isTranscriptionFocused)
       .onChange(of: isTranscriptionFocused) { _, focused in
           if !focused {
               tag.transcription = editingTranscription
           }
       }
   ```
4. Sync buffer when selected tag changes:
   ```swift
   .onChange(of: selectedTag) { oldTag, newTag in
       // Commit pending edit to old tag
       if let old = oldTag, isTranscriptionFocused {
           old.transcription = editingTranscription
       }
       // Load new tag's transcription
       editingTranscription = newTag?.transcription ?? ""
   }
   ```

### UX Requirements from Design Spec

- **Inline editing:** Transcription text is editable in place — no separate edit screen, no modal, no "Edit" button. Click into text to start editing. [Source: ux-design-specification.md — "Inline editing everywhere on Mac"]
- **Auto-save on blur:** Transcription saves when user clicks away. No explicit save button. [Source: ux-design-specification.md — "Transcription and notes auto-save on blur"]
- **Focus border:** Text fields gain a border on focus to indicate editing mode. [Source: ux-design-specification.md — TagDetailPanel states: "Editing (text fields gain border on focus, save on blur)"]
- **Empty state:** "Transcription not yet run." with inline "Transcribe" button. [Source: ux-design-specification.md — Empty States table]
- **Anti-pattern:** Do NOT show a "wall of transcription" — transcription is per-tag, not continuous. Each tag's ~30-second segment has its own transcription text. [Source: ux-design-specification.md — "Otter.ai wall of transcription" anti-pattern]

### Previous Story Intelligence (5-3)

Key learnings from Story 5.3 that directly impact this story:
- **TagDetailPanel already has `let session: Session` parameter** — added in Story 5.3. Maintain this signature.
- **TagDetailPanel already has `@Environment(TranscriptionEngine.self)`** — use it for transcription state checks but do NOT modify TranscriptionEngine.
- **Transcription block has 4 mutually exclusive states** — only modify the "complete" state. Leave in-progress, error, and no-transcription states untouched.
- **`tag.transcription = result` auto-saves via SwiftData** — same mechanism applies to user edits. No explicit save needed.
- **`@MainActor` on TranscriptionEngine** — all property access from SwiftUI views is safe.
- **Pre-existing test failures:** 2 pre-existing failures in `RetroactiveTagTests` and `TagEditingTests` (whitespace validation) — these are unrelated, do not attempt to fix.
- **Build process:** Re-run xcodegen after adding new source files to `project.yml`. This story likely doesn't add new files, so xcodegen may not be needed.
- **`@Observable final class` pattern** for all service classes. Not relevant here since no new classes are created.

### Git Intelligence

Recent commit patterns: `feat(transcription):`, `fix(transcription):`. Use `feat(transcription):` for this story's commits. The story involves only UI changes in TagDetailPanel, so commit scope is narrow.

### Anti-Patterns to Avoid

- Do NOT create a separate "edit mode" toggle button — text becomes editable on click/focus directly (inline editing, per UX spec)
- Do NOT use `NSTextView` wrapper unless `TextEditor` proves insufficient — prefer native SwiftUI first
- Do NOT add a "Save" button — auto-save on blur is the specified pattern
- Do NOT modify `TranscriptionEngine.swift` — editing is a direct SwiftData model write, not an engine operation
- Do NOT set `tag.transcription = nil` when user clears text — nil means "never transcribed", empty string means "user cleared it"
- Do NOT add undo/redo management — standard macOS text editing already provides Cmd+Z via SwiftUI TextEditor
- Do NOT block editing while batch transcription is running on other tags — user should be able to edit any already-transcribed tag freely
- Do NOT add real-time validation or character limits to transcription text — it's free-form correction of whisper output
- Do NOT add any new `DictlyError` cases — editing is a simple property write

### Project Structure Notes

Files to modify:
```
DictlyMac/Review/TagDetailPanel.swift    # Convert transcription display from read-only to editable inline
```

Files to create (tests):
```
DictlyMacTests/ReviewTests/TagDetailPanelTests.swift  # Tests for transcription editing (may extend existing file)
```

No other files should be created or modified. This is a targeted, single-file change.

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 5, Story 5.4]
- [Source: _bmad-output/planning-artifacts/architecture.md — FR39 (view transcription), FR40 (edit transcription) → TagDetailPanel.swift]
- [Source: _bmad-output/planning-artifacts/architecture.md — @Observable state management, @State for view-local state, @FocusState]
- [Source: _bmad-output/planning-artifacts/architecture.md — SwiftData auto-save on property mutation]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — TagDetailPanel anatomy: transcription block (editable inline)]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — "Inline editing everywhere on Mac" principle]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — "Transcription and notes auto-save on blur"]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Editing state: "text fields gain border on focus, save on blur"]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Empty state: "Transcription not yet run." + Transcribe button]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Anti-pattern: "Otter.ai wall of transcription"]
- [Source: _bmad-output/planning-artifacts/prd.md — FR39 view transcription per tag, FR40 edit transcription text]
- [Source: _bmad-output/implementation-artifacts/5-3-per-tag-and-batch-transcription.md — TagDetailPanel modifications, transcription block states, previous story patterns]
- [Source: DictlyMac/Review/TagDetailPanel.swift — current transcriptionBlock() implementation, notes editing pattern]
- [Source: DictlyKit/Sources/DictlyModels/Tag.swift — transcription: String? property]
- [Source: DictlyMac/Transcription/TranscriptionEngine.swift — isTranscribing, currentTagId, tagErrors state]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

No blockers. Single-file UI change as specified. Pre-existing signing constraint (known from Story 5.3) prevented runtime test execution but `** TEST BUILD SUCCEEDED **` confirms compilation. DictlyKit 245 tests: 0 failures.

### Completion Notes List

- Replaced `Text(text)` read-only display in the "complete" transcription state with `TextEditor(text: $editingTranscription)` following the existing notes editing pattern exactly.
- Added `@State private var editingTranscription: String = ""` and `@FocusState private var isTranscriptionFocused: Bool` to `TagDetailPanel`.
- Sync logic: `editingTranscription` loads from `tag.transcription ?? ""` in both `.onAppear` and `.onChange(of: selectedTag?.uuid)`.
- Blur-to-save: `commitTranscription(tag:)` writes `tag.transcription = editingTranscription` via SwiftData auto-save. No manual `modelContext.save()` needed.
- Tag-switch commit: `onChange(of: selectedTag?.uuid)` fetches old tag by UUID and writes pending edit before switching, mirroring the existing notes commit pattern.
- Empty string handling: `commitTranscription` preserves empty string (does not revert to nil) — nil means "never transcribed", empty means "user cleared".
- All 3 other transcription states (in-progress, error, no-transcription) unchanged.
- TextEditor styled with `.frame(minHeight: 60, maxHeight: 200)`, `.scrollContentBackground(.hidden)`, focus border via `.strokeBorder`, matching UX spec.
- Created `TagDetailPanelTests.swift` with 14 tests covering all ACs and edge cases.

### File List

- DictlyMac/Review/TagDetailPanel.swift (modified)
- DictlyMacTests/ReviewTests/TagDetailPanelTests.swift (created)

### Change Log

- 2026-04-03: Story 5.4 implemented — replaced read-only transcription display with inline-editable TextEditor; added blur-to-save, tag-switch commit, empty string handling; created TagDetailPanelTests.swift with 14 tests.
