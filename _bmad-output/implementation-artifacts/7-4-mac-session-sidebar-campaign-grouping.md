# Story 7.4: Mac Session Sidebar — Campaign Grouping

Status: ready-for-dev

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

- [ ] Task 1: Group sessions by campaign in `ContentView` (AC: #1, #2, #3, #5)
  - [ ] 1.1 In `DictlyMac/App/ContentView.swift`, replace the flat `@Query(sort: \Session.date, order: .reverse) private var sessions: [Session]` with a `@Query(sort: \Campaign.createdAt, order: .forward) private var campaigns: [Campaign]` plus `@Query` for uncampaigned sessions
  - [ ] 1.2 Compute grouped structure:
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
  - [ ] 1.3 Update `sessionList` to use `ForEach(groupedSessions, id: \.title)` with `Section(header:)` per group
  - [ ] 1.4 Section header view: campaign name in `DictlyTypography.caption` / `.fontWeight(.semibold)` / `DictlyColors.textSecondary` — match the style used in `TagSidebar`'s `sessionSectionHeader`
  - [ ] 1.5 Keep the existing `sessions.isEmpty` empty-state check — update it to check `groupedSessions.isEmpty`
  - [ ] 1.6 Keep `List(selection: $selectedSession)` binding — grouped `List` with `Section` supports selection identically

- [ ] Task 2: Accessibility (AC: #1)
  - [ ] 2.1 Add `.accessibilityLabel` to each section header: `"\(campaignName) campaign, \(sessions.count) sessions"`

- [ ] Task 3: Regression check (AC: #4, #6)
  - [ ] 3.1 Verify that selecting a session in the grouped list correctly populates `SessionReviewScreen`
  - [ ] 3.2 Verify search result navigation (`handleSearchResultSelected`) still selects the correct session
  - [ ] 3.3 Run all existing Mac tests — must pass 100%

## Dev Notes

- The change is entirely in `DictlyMac/App/ContentView.swift` `sessionList` computed property and the `@Query` declarations
- `Session.campaign` is an optional relationship — sessions without a campaign should not crash the grouping
- The `NavigationSplitView` column width (`min: 200, ideal: 240`) may need a slight increase (e.g. `ideal: 260`) to accommodate campaign section headers without truncation — adjust as needed
- Do not add a campaign-level detail screen (that would be a separate story) — section headers only
- `TagSidebar.swift`'s `sessionSectionHeader()` is a reference implementation for section header styling
