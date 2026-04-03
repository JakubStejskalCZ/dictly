# Story 7.4: Mac Session Sidebar — Campaign Grouping

Status: done

## Story

As a DM with multiple campaigns,
I want sessions in the Mac sidebar to be grouped by campaign,
so that the archive feels organised and I can orient myself in the session list without reading dates.

## Context

The Mac sidebar currently displays all imported sessions as a flat list sorted by date. The UX spec (Journey 2) describes the Mac entry point as "Campaign view — session list" — implying the campaign → session hierarchy. With multiple campaigns (e.g. "Ashlands", "Curse of Strahd", "One-Shots"), a flat list of 30+ sessions with no grouping makes the archive feel disorganised and undermines the "archive earns its value" experience principle.

This is a structural UX gap: the campaign organisation that exists on iOS (CampaignDetailScreen) has no equivalent on Mac. The fix is `Section` headers per campaign in the existing `NavigationSplitView` sidebar — no new navigation level required.

## Acceptance Criteria

1. **Given** the Mac app has sessions from more than one campaign **When** the sidebar renders **Then** sessions are grouped under campaign name section headers, each campaign's sessions sorted newest-first within the group

2. **Given** a session that has no campaign (imported without campaign context) **When** the sidebar renders **Then** it appears under an "Uncampaigned" section header at the bottom of the list

3. **Given** only one campaign exists **When** the sidebar renders **Then** the campaign section header is still shown (single-campaign view is consistent with multi-campaign view)

4. **Given** a session is selected in a grouped sidebar **When** `SessionReviewScreen` renders **Then** behaviour is identical to the current flat-list selection — no functional regression

5. **Given** the sidebar is in the grouped view **When** no sessions exist at all **Then** the existing empty state message is shown ("No sessions yet. Import a session from iOS to get started.")

6. All existing Mac tests pass 100%

## Tasks / Subtasks

- [x] Task 1: Group sessions by campaign in `ContentView` (AC: #1, #2, #3, #5)
  - [x] 1.1 In `DictlyMac/App/ContentView.swift`, replace the flat `@Query(sort: \Session.date, order: .reverse) private var sessions: [Session]` with a `@Query(sort: \Campaign.createdAt, order: .forward) private var campaigns: [Campaign]` plus `@Query` for uncampaigned sessions
  - [x] 1.2 Compute grouped structure:
    ```swift
    private var groupedSessions: [(title: String, sessions: [Session])] {
        var groups: [(title: String, sessions: [Session])] = campaigns
            .filter { !$0.sessions.isEmpty }
            .map { ($0.name, $0.sessions.sorted { $0.date > $1.date }) }
        let uncampaigned = sessions.filter { $0.campaign == nil }
        if !uncampaigned.isEmpty {
            groups.append(("Uncampaigned", uncampaigned.sorted { $0.date > $1.date }))
        }
        return groups
    }
    ```
  - [x] 1.3 Update `sessionList` to use `ForEach(groupedSessions, id: \.title)` with `Section(header:)` per group
  - [x] 1.4 Section header view: campaign name in `DictlyTypography.caption` / `.fontWeight(.semibold)` / `DictlyColors.textSecondary` — match the style used in `TagSidebar`'s `sessionSectionHeader`
  - [x] 1.5 Keep the existing `sessions.isEmpty` empty-state check — update it to check `groupedSessions.isEmpty`
  - [x] 1.6 Keep `List(selection: $selectedSession)` binding — grouped `List` with `Section` supports selection identically

- [x] Task 2: Accessibility (AC: #1)
  - [x] 2.1 Add `.accessibilityLabel` to each section header: `"\(campaignName) campaign, \(sessions.count) sessions"`

- [x] Task 3: Regression check (AC: #4, #6)
  - [x] 3.1 Verify that selecting a session in the grouped list correctly populates `SessionReviewScreen`
  - [x] 3.2 Verify search result navigation (`handleSearchResultSelected`) still selects the correct session
  - [x] 3.3 Run all existing Mac tests — must pass 100%

## Dev Notes

- The change is entirely in `DictlyMac/App/ContentView.swift` `sessionList` computed property and the `@Query` declarations
- `Session.campaign` is an optional relationship — sessions without a campaign should not crash the grouping
- The `NavigationSplitView` column width (`min: 200, ideal: 240`) may need a slight increase (e.g. `ideal: 260`) to accommodate campaign section headers without truncation — adjust as needed
- Do not add a campaign-level detail screen (that would be a separate story) — section headers only
- `TagSidebar.swift`'s `sessionSectionHeader()` is a reference implementation for section header styling

## Dev Agent Record

### Implementation Plan

Replaced the flat `@Query sessions` with a dual-query approach: `@Query campaigns` (sorted by `createdAt` ascending) + existing `@Query sessions` retained for uncampaigned filtering. Introduced `groupedSessions` computed property mirroring the spec exactly. Rebuilt `sessionList` as a grouped `List(selection:)` with `ForEach` over groups and `Section` per campaign. Section header styled with `DictlyTypography.caption` / `.fontWeight(.semibold)` / `DictlyColors.textSecondary`, matching `TagSidebar.sessionSectionHeader`. Accessibility label added inline. `NavigationSplitView` ideal width bumped from 240 → 260.

Also fixed a pre-existing build issue: `Export/ExportSheet.swift` existed but its folder was absent from `DictlyMac/project.yml` sources, causing a compile error. Added `Export` path and regenerated the project via `xcodegen`.

Fixed two pre-existing test failures in `RetroactiveTagTests` and `TagEditingTests` where tests used `.whitespaces` instead of `.whitespacesAndNewlines`, causing `\n` characters in test strings to escape trimming and break assertions.

### Completion Notes

- All tasks and subtasks completed ✅
- `ContentView.swift` updated: dual `@Query`, `groupedSessions` computed property, grouped `List` with `Section` headers, accessibility labels, empty-state guard updated
- `DictlyMac/project.yml` updated: `Export` folder added to DictlyMac target sources
- New test file: `DictlyMacTests/SidebarTests/SidebarCampaignGroupingTests.swift` — 9 tests covering AC #1, #2, #3, #5 and model-layer integrity
- Fixed 2 pre-existing test bugs (`.whitespaces` → `.whitespacesAndNewlines`) in `RetroactiveTagTests` and `TagEditingTests`
- Full test suite: 0 failures, exit_code=0

## File List

- `DictlyMac/App/ContentView.swift` — modified (campaign grouping implementation)
- `DictlyMac/project.yml` — modified (added Export source path)
- `DictlyMacTests/SidebarTests/SidebarCampaignGroupingTests.swift` — created (9 new tests for AC #1, #2, #3, #5)
- `DictlyMacTests/ReviewTests/RetroactiveTagTests.swift` — modified (fixed `.whitespaces` → `.whitespacesAndNewlines`)
- `DictlyMacTests/ReviewTests/TagEditingTests.swift` — modified (fixed `.whitespaces` → `.whitespacesAndNewlines`)

## Review Findings

- [x] [Review][Patch] ForEach id collision — `ForEach(groupedSessions, id: \.title)` uses campaign name as identity; two campaigns with identical names produce duplicate IDs causing undefined SwiftUI rendering. Fixed: `groupedSessions` now returns `(id: UUID, title: String, sessions: [Session])` using `campaign.uuid` as ID and a fixed sentinel UUID for "Uncampaigned"; `ForEach` updated to `id: \.id`. [ContentView.swift:52-61, 88]
- [x] [Review][Patch] Section header color `textSecondary` → `textPrimary` — Reference implementation `TagSidebar.sessionSectionHeader` uses `DictlyColors.textPrimary` for header title text; spec task bullet contradicts this. Fixed to match reference. [ContentView.swift:115]
- [x] [Review][Patch] `groupedSessions` computed twice per render — called in both the `ForEach` and the `.overlay` condition. Extracted to `let groups = groupedSessions` in `sessionList`. [ContentView.swift:86-109]
- [x] [Review][Defer] `selectedSession` not cleared when session disappears — if a campaign is deleted or a selected session is moved, the detail panel stays populated with no sidebar highlight. Pre-existing behavior pattern; out of scope for this story. — deferred, pre-existing
- [x] [Review][Defer] SwiftData relationship lazy faulting during import — `$0.sessions.sorted` on a campaign relationship could return incomplete results if faulted on a background context during concurrent import. Pre-existing SwiftData architectural constraint. — deferred, pre-existing
- [x] [Review][Defer] Export path added to `project.yml` — intentional fix for a pre-existing build issue (ExportSheet.swift existed but its folder was missing from sources). Not introduced by this story. — deferred, pre-existing

## Change Log

- 2026-04-03: Implemented campaign grouping in Mac sidebar, fixed project.yml missing Export path, fixed 2 pre-existing test bugs, added 9 new grouping tests — all 381+ tests pass
- 2026-04-03: Code review — applied 3 patches: UUID-based ForEach IDs, section header color textPrimary, single groupedSessions computation; 3 items deferred (pre-existing)
