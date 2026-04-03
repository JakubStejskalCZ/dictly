# Story 5.4: View & Edit Transcription Text

Status: ready-for-dev

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

- [ ] Task 1: Replace read-only transcription display with inline-editable TextEditor (AC: #1, #2, #3)
  - [ ] 1.1 In `DictlyMac/Review/TagDetailPanel.swift`, locate the `transcriptionBlock()` method — specifically the "complete" state branch (currently `Text(text)` with `.textSelection(.enabled)` around line 270)
  - [ ] 1.2 Add a `@State private var editingTranscription: String = ""` property to `TagDetailPanel` for local edit buffer
  - [ ] 1.3 Add a `@State private var isEditingTranscription: Bool = false` property to track edit mode (or use `@FocusState`)
  - [ ] 1.4 Replace `Text(text)` in the "complete" state with a `TextEditor(text: $editingTranscription)` that activates on click/focus
  - [ ] 1.5 Style the TextEditor to match the existing notes editing pattern in TagDetailPanel (lines ~186–225): `.font(.body)`, `.scrollContentBackground(.hidden)`, consistent padding, border on focus
  - [ ] 1.6 Sync `editingTranscription` from `tag.transcription` when the selected tag changes — use `.onChange(of: selectedTag)` or `.onAppear` to populate the buffer
  - [ ] 1.7 Commit edits on blur: use `.onSubmit` or `.onChange` with a debounce, or `@FocusState` + `.onChange(of: isFocused)` to detect blur and write `tag.transcription = editingTranscription`
  - [ ] 1.8 SwiftData auto-saves on property mutation — no manual `modelContext.save()` call needed

- [ ] Task 2: Ensure transcription display is always visible when present (AC: #1)
  - [ ] 2.1 Verify the transcription block renders the full text content without truncation — use `TextEditor` with dynamic height or a minimum height constraint
  - [ ] 2.2 Ensure the transcription block scrolls within the detail panel if text is long (>5 lines)
  - [ ] 2.3 Verify the transcription text uses `.font(.body)` consistent with the UX spec

- [ ] Task 3: Preserve existing transcription states (AC: #4)
  - [ ] 3.1 Verify the "no transcription" state still shows "Transcription not yet run." placeholder with inline "Transcribe" button (already implemented in Story 5.3)
  - [ ] 3.2 Verify the "in progress" state still shows `ProgressView()` with "Transcribing..." label
  - [ ] 3.3 Verify the "error" state still shows error badge with "Retry" button
  - [ ] 3.4 Only the "complete" state changes from read-only to editable — all other states remain as-is

- [ ] Task 4: Handle edge cases for transcription editing (AC: #2, #3)
  - [ ] 4.1 If the DM clears all text (empty string), save as empty string — do not revert to nil (nil means "never transcribed", empty means "user cleared it")
  - [ ] 4.2 If a new transcription completes while the DM is editing a different tag, the newly transcribed tag should show its text correctly when selected
  - [ ] 4.3 If the DM switches tags while editing, commit the current edit before switching (write `tag.transcription = editingTranscription` on tag change)
  - [ ] 4.4 If batch transcription overwrites a tag's transcription while user is NOT editing that tag, the new text should appear when the tag is selected

- [ ] Task 5: Write unit/UI tests (AC: #1–#4)
  - [ ] 5.1 Create or extend `DictlyMacTests/ReviewTests/TagDetailPanelTests.swift`
  - [ ] 5.2 Test: selecting a tag with transcription displays the transcription text
  - [ ] 5.3 Test: editing transcription text and blurring saves to `tag.transcription`
  - [ ] 5.4 Test: selecting a tag without transcription shows "Transcription not yet run." placeholder
  - [ ] 5.5 Test: switching tags commits pending edits to the previous tag
  - [ ] 5.6 Test: clearing all transcription text saves empty string (not nil)
  - [ ] 5.7 Verify all existing DictlyKit tests still pass (245+ tests, 0 regressions)
  - [ ] 5.8 Verify existing TranscriptionEngine tests still pass (12 tests)
  - [ ] 5.9 Verify existing Epic 4 review tests still pass

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

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
