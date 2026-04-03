# Story 6.4: Markdown Export — Single Session & Campaign

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a DM,
I want to export my session notes as markdown for use in Obsidian, wikis, or LLMs,
so that Dictly integrates into my existing prep workflow.

## Acceptance Criteria

1. **Given** the session toolbar "Export MD" button **When** the DM clicks it **Then** a markdown file is generated containing: session title, date, duration, all tags grouped by category with labels, timestamps, transcriptions, and notes

2. **Given** the export sheet **When** the DM selects "Export Campaign" **Then** a markdown file is generated containing all sessions in the campaign with the same tag/transcription/notes structure

3. **Given** the exported markdown **When** opened in any CommonMark-compatible viewer (Obsidian, GitHub, VS Code) **Then** the formatting renders correctly with proper headings, lists, and structure

4. **Given** export completes **When** the file is saved **Then** a system notification appears and the file is revealed in Finder

## Tasks / Subtasks

- [ ] Task 1: Implement `MarkdownExporter` in DictlyKit (AC: #1, #2, #3)
  - [ ] 1.1 Update `DictlyKit/Package.swift` — add `DictlyModels` as a dependency of the `DictlyExport` target so `MarkdownExporter` can reference `Session`, `Tag`, and `Campaign` model types
  - [ ] 1.2 Add a `DictlyExportTests` test target to `Package.swift` with dependency on `DictlyExport` and `DictlyModels`
  - [ ] 1.3 Replace the placeholder `DictlyExport.swift` enum with `MarkdownExporter.swift` in `DictlyKit/Sources/DictlyExport/`
  - [ ] 1.4 Implement `public struct MarkdownExporter` with a `static func exportSession(_ session: Session) -> String` method that produces CommonMark output:
    - H1: session title
    - Metadata line: date (abbreviated), duration (h:mm:ss), tag count, location (if present)
    - Session summary note (if present) as a blockquote
    - Tags grouped by category under H2 headings, sorted by `anchorTime` within each group
    - Each tag: `**[HH:MM:SS] Label**` followed by transcription text (if present) and notes (if present, prefixed with `> Note:`)
    - Categories sorted alphabetically
  - [ ] 1.5 Implement `static func exportCampaign(_ campaign: Campaign) -> String` that produces CommonMark output:
    - H1: campaign name
    - Campaign description (if non-empty)
    - Each session as an H2 section (sorted chronologically by `date`), using the same per-session structure as `exportSession` but with H2/H3/H4 heading levels shifted down one level
  - [ ] 1.6 Implement `static func suggestedFilename(for session: Session) -> String` — returns `"Session N - Title.md"` (sanitized for filesystem)
  - [ ] 1.7 Implement `static func suggestedFilename(for campaign: Campaign) -> String` — returns `"Campaign - Name.md"` (sanitized for filesystem)
  - [ ] 1.8 Use a private helper `formatTimestamp(_ seconds: TimeInterval) -> String` for `HH:MM:SS` formatting (do NOT import from DictlyMac — DictlyKit must remain platform-independent)

- [ ] Task 2: Create `ExportSheet.swift` in DictlyMac/Export/ (AC: #1, #2)
  - [ ] 2.1 Create `DictlyMac/Export/ExportSheet.swift` — a SwiftUI `.sheet` view presenting export options
  - [ ] 2.2 Accept bindings: `session: Session`, `isPresented: Binding<Bool>`; derive `campaign` from `session.campaign`
  - [ ] 2.3 Show two options: "Export Session" (default, always enabled) and "Export Campaign" (enabled only when `session.campaign != nil`)
  - [ ] 2.4 On selection, generate the markdown string via `MarkdownExporter.exportSession` or `MarkdownExporter.exportCampaign`
  - [ ] 2.5 Present `NSSavePanel` to let the DM choose the save location; pre-fill with `MarkdownExporter.suggestedFilename`; set allowed content type to `.plainText` with `.md` extension
  - [ ] 2.6 Write the markdown string to the chosen URL using `String.write(to:atomically:encoding:)` with `.utf8`
  - [ ] 2.7 On success, dismiss the sheet and trigger notification + Finder reveal (Task 3)
  - [ ] 2.8 On error, show an inline error message in the sheet (do NOT use a modal alert)
  - [ ] 2.9 Register the new file in `project.pbxproj`

- [ ] Task 3: Implement post-export notification and Finder reveal (AC: #4)
  - [ ] 3.1 After successful file write, post a `UNUserNotificationContent` local notification with title "Export Complete" and body containing the filename
  - [ ] 3.2 Reveal the saved file in Finder using `NSWorkspace.shared.activateFileViewerSelecting([url])`
  - [ ] 3.3 Encapsulate notification + reveal in a helper method on `ExportSheet` or as a standalone function in `DictlyMac/Export/`

- [ ] Task 4: Wire "Export MD" button in SessionReviewScreen (AC: #1)
  - [ ] 4.1 In `SessionReviewScreen.swift` line ~224, replace the disabled `Button("Export MD") { }.disabled(true)` with a button that sets `@State private var isShowingExportSheet = false` to true
  - [ ] 4.2 Add `.sheet(isPresented: $isShowingExportSheet) { ExportSheet(session: session, isPresented: $isShowingExportSheet) }` to the view
  - [ ] 4.3 Remove the `.disabled(true)` and update the `.help` text to "Export session or campaign as Markdown"
  - [ ] 4.4 Keep the `.accessibilityLabel("Export as Markdown")`

- [ ] Task 5: Write tests (AC: #1, #2, #3, #4)
  - [ ] 5.1 Create `DictlyKit/Tests/DictlyExportTests/MarkdownExporterTests.swift`
  - [ ] 5.2 Test `exportSession` output structure: H1 title, metadata line, tags grouped by category, timestamps formatted correctly, transcription and notes included when present
  - [ ] 5.3 Test `exportSession` with a session that has no tags — should produce header + metadata + "No tags recorded" note
  - [ ] 5.4 Test `exportSession` with missing optional fields (no transcription, no notes, no location, no summary note) — should gracefully omit those sections
  - [ ] 5.5 Test `exportCampaign` output structure: H1 campaign name, sessions as H2 sorted by date, tags within each session
  - [ ] 5.6 Test `exportCampaign` with empty campaign (no sessions) — should produce header + "No sessions in this campaign" note
  - [ ] 5.7 Test CommonMark compliance: output should not contain HTML, should use standard headings (`#`), bold (`**`), blockquotes (`>`)
  - [ ] 5.8 Test `suggestedFilename` sanitization: strip characters invalid for filenames (`/`, `:`, `\`)
  - [ ] 5.9 Create `DictlyMacTests/ExportTests/ExportSheetTests.swift` — test that `ExportSheet` initializes correctly and that `MarkdownExporter` is invoked with the correct session/campaign

## Dev Notes

### Architecture Compliance

- **MarkdownExporter** lives in `DictlyKit/Sources/DictlyExport/MarkdownExporter.swift` — the shared package, NOT in the Mac target. Architecture places export logic in `DictlyExport` module so both platforms can use it in post-MVP. [Source: architecture.md#Project-Structure]
- **ExportSheet** lives in `DictlyMac/Export/ExportSheet.swift` — Mac-only UI. [Source: architecture.md#FR45-FR46]
- **DictlyExport target** currently has NO dependency on `DictlyModels` — you MUST add it in `Package.swift` before `MarkdownExporter` can import `DictlyModels`.
- **DictlyExportTests** test target does NOT exist yet — you MUST add it to `Package.swift`.
- **No SwiftData import in DictlyKit** — `MarkdownExporter` receives `Session`/`Campaign` instances but DictlyModels already imports SwiftData. DictlyExport needs only `import DictlyModels` to access the `@Model` types.
- **NSSavePanel** is AppKit (macOS-only) — use it directly in `ExportSheet.swift`. Do NOT put AppKit code in DictlyKit.
- **@Observable pattern** — if `ExportSheet` needs any observable state beyond `@State`, use `@Observable` (NOT `ObservableObject`). Likely just `@State` is sufficient here.

### Critical Implementation Details

#### Markdown Output Format — Single Session

```markdown
# Session 7 — The Return to Grimthor's Shop

**Date:** Mar 15, 2026 | **Duration:** 3:47:22 | **Tags:** 28 | **Location:** Jake's Place

> Session summary note text here (if present)

## Story

**[0:12:34] Grimthor's Promise**
Grimthor leaned forward and whispered that he would forge the blade, but only if they brought him dragon scale.

> Note: Important — ties to session 3 plot hook

**[1:45:02] The Rival Faction Hint**
A hooded figure was spotted watching from the alley.

## Combat

**[0:45:12] Ambush in the Alley**
Three rogues attacked from the shadows. Party rolled well on initiative.

## Roleplay

**[2:10:33] Tavern Negotiation**
(no transcription)

> Note: Bard convinced the innkeeper to give them free rooms
```

#### Markdown Output Format — Campaign

```markdown
# Ashlands Campaign

A dark fantasy campaign set in the volcanic Ashlands.

## Session 1 — Into the Ashlands (Jan 12, 2026)

### Story

**[0:05:22] Opening Narration**
...

## Session 2 — The First Betrayal (Jan 19, 2026)

### Story

**[0:08:11] NPC Introduction — Kira**
...
```

#### NSSavePanel Usage

```swift
let panel = NSSavePanel()
panel.allowedContentTypes = [.plainText]
panel.nameFieldStringValue = MarkdownExporter.suggestedFilename(for: session)
panel.allowsOtherFileTypes = false

let response = await panel.beginSheetModal(for: NSApp.keyWindow!)
if response == .OK, let url = panel.url {
    // Ensure .md extension
    let finalURL = url.pathExtension == "md" ? url : url.appendingPathExtension("md")
    try markdown.write(to: finalURL, atomically: true, encoding: .utf8)
}
```

**Note:** `NSSavePanel.beginSheetModal` is async on macOS 14+. Use `await` in a `Task { }`.

#### UTType for Markdown

Use `UTType.plainText` as the allowed content type. There is no built-in `UTType.markdown` in Apple frameworks. The `.md` extension is set via the `nameFieldStringValue`. If you want stricter typing, you can define a custom `UTType` but this is NOT necessary for MVP.

#### Notification

Use `UNUserNotificationCenter` for the local notification. Request authorization first (`.alert` + `.sound`). If the user denies notification permission, skip the notification silently — the Finder reveal is the primary feedback.

```swift
let content = UNMutableNotificationContent()
content.title = "Export Complete"
content.body = "Saved \(filename)"
let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
try? await UNUserNotificationCenter.current().add(request)
```

**Important:** The app must be in background for the notification banner to appear. Since the user likely stays in Dictly, the **Finder reveal is the primary feedback** and the notification is supplementary. The UX spec says: "System notification + file revealed in Finder" — both should fire.

#### Filename Sanitization

Strip characters that are invalid in macOS filenames: `/`, `:`, `\`. Replace with `-`. Trim whitespace. Example:

```swift
static func sanitizeFilename(_ name: String) -> String {
    name.replacingOccurrences(of: "[/:\\\\]", with: "-", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
```

#### Timestamp Formatting

`MarkdownExporter` needs its own `formatTimestamp` — do NOT import the one from `DictlyMac/Review/TagSidebarRow.swift` (it's a module-level function in the Mac target, not accessible from DictlyKit).

```swift
private static func formatTimestamp(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    return String(format: "%d:%02d:%02d", h, m, s)
}
```

### Existing Code to Modify

- `SessionReviewScreen.swift:224` — the disabled "Export MD" button. Replace with working button + sheet presentation.
- `DictlyKit/Package.swift:34` — add `dependencies: ["DictlyModels"]` to the `DictlyExport` target.
- `DictlyKit/Sources/DictlyExport/DictlyExport.swift` — DELETE this placeholder file (replaced by `MarkdownExporter.swift`).

### Existing Code Patterns to Follow

- **Theme tokens:** `DictlyColors.*`, `DictlyTypography.*`, `DictlySpacing.*` for any UI in ExportSheet — never hardcode values.
- **Button style:** "Export MD" is a secondary action per UX spec — use `.buttonStyle(.bordered)` (already applied to the HStack containing it).
- **Logging:** `Logger(subsystem: "com.dictly.mac", category: "export")` for export operations.
- **Accessibility:** Every interactive element gets `.accessibilityLabel`. Post `AccessibilityNotification.LayoutChanged()` on sheet presentation.
- **Fire-and-forget async:** `NSSavePanel` and file write are async — wrap in `Task { }`.
- **Error display:** Inline in sheet, NOT modal alert. See UX spec: "Errors are inline with specific cause and retry."

### What NOT To Do

- Do NOT put `MarkdownExporter` in the Mac target — it belongs in `DictlyKit/DictlyExport/` per architecture.
- Do NOT import AppKit in DictlyKit — `NSSavePanel`, `NSWorkspace`, `UNUserNotificationCenter` stay in Mac target only.
- Do NOT use `ObservableObject`/`@Published` — use `@Observable` if needed (project convention).
- Do NOT add HTML to the markdown output — CommonMark only (headings `#`, bold `**`, blockquotes `>`, lists `-`).
- Do NOT add SwiftUI `.fileExporter` modifier — it has limited control over panel options; use `NSSavePanel` directly for better UX.
- Do NOT modify SwiftData models — no schema changes needed for export.
- Do NOT create cloud/share functionality — export is local file save only per MVP scope.
- Do NOT add a preview pane to the export sheet — this is a Phase 3 enhancement per UX spec.

### Previous Story Intelligence (6-3)

**Key learnings from Story 6.3 implementation:**
- New `.swift` files MUST be manually added to `project.pbxproj` — Xcode projects require explicit file registration. Don't forget to register `ExportSheet.swift`.
- `session.campaign?.sessions` relationship traversal works reliably for accessing all sessions in a campaign — same pattern needed for campaign export.
- `formatTimestamp` is a module-level function in `TagSidebarRow.swift` — it is accessible from other files in the same DictlyMac target but NOT from DictlyKit. MarkdownExporter needs its own copy.
- `CategoryColorHelper.categoryColor(for:)` in `DictlyMac/Review/CategoryColorHelper.swift` — not needed for markdown export (no colors in text output).
- 305 tests pass with 2 pre-existing failures in RetroactiveTagTests/TagEditingTests (not caused by search/browse work). Do not attempt to fix these.
- Review fixes from 6.3: cancellation handle for in-flight async, clear stale state before new operations, nil guard for optional relationship properties.

### Git Intelligence

Recent commits follow conventional commit format: `feat(scope):`, `fix(scope):`.

Last 5 commits:
1. `e198273` — `fix(review): address feedback for cross-session tag browsing [story 6-3]`
2. `2b4a869` — `feat(review): implement cross-session tag browsing and related tags`
3. `dddd065` — `feat(story): create 6-3-cross-session-tag-browsing-and-related-tags specification`
4. `d4627bb` — `fix(search): address review feedback for full-text search across sessions`
5. `404bf91` — `feat(search): implement full-text search across sessions`

**Suggested commit message for this story:** `feat(export): implement markdown export for single session and campaign`

### Project Structure Notes

```
DictlyKit/
  Package.swift                           # MODIFY — add DictlyModels dep to DictlyExport, add DictlyExportTests
  Sources/DictlyExport/
    DictlyExport.swift                    # DELETE — placeholder
    MarkdownExporter.swift                # NEW — session/campaign → CommonMark markdown
  Tests/DictlyExportTests/
    MarkdownExporterTests.swift           # NEW — unit tests for export logic

DictlyMac/Export/
  ExportSheet.swift                       # NEW — NSSavePanel-based export UI (replace .gitkeep)

DictlyMac/Review/
  SessionReviewScreen.swift               # MODIFY — enable "Export MD" button, wire to ExportSheet

DictlyMacTests/ExportTests/
  ExportSheetTests.swift                  # NEW — integration tests for export flow

project.pbxproj                           # MODIFY — register ExportSheet.swift, ExportSheetTests.swift
```

### References

- [Source: architecture.md#Project-Structure] — DictlyExport module in DictlyKit for shared export logic
- [Source: architecture.md#FR45-FR46] — MarkdownExporter handles FR45 (single session) and FR46 (campaign)
- [Source: architecture.md#Requirements-Mapping] — FR45/FR46 map to DictlyMac/Export/ + DictlyKit/DictlyExport/
- [Source: architecture.md#Architectural-Boundaries] — DictlyKit exposes models, theme, storage, export; no platform imports
- [Source: epics.md#Story-6.4] — Acceptance criteria, user story
- [Source: prd.md#FR45] — Export transcribed tags and notes from a session as markdown
- [Source: prd.md#FR46] — Export transcribed tags and notes from multiple sessions or full campaign as markdown
- [Source: prd.md#NFR-Markdown-Export] — Standard CommonMark-compatible output
- [Source: ux-design-specification.md#Mac-Layout] — Toolbar: "Export MD" as secondary action button (surface + border)
- [Source: ux-design-specification.md#Feedback-Patterns] — Export complete: system notification + file revealed in Finder
- [Source: ux-design-specification.md#Button-Hierarchy-Mac] — "Export MD" is secondary action style
- [Source: ux-design-specification.md#Journey-3] — Post-session review flow ends with "Export as markdown"
- [Source: 6-3-cross-session-tag-browsing-and-related-tags.md] — Previous story learnings, project.pbxproj registration, relationship traversal patterns

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
