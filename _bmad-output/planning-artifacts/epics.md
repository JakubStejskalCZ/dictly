---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
status: complete
completedAt: '2026-04-01'
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
---

# Dictly - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for Dictly, decomposing the requirements from the PRD, UX Design, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: DM can create a new recording session within an existing campaign
FR2: DM can record audio continuously for 4+ hours with the screen locked
FR3: DM can pause and resume a recording without losing data or creating a new file
FR4: DM can record using the built-in microphone or an external microphone (e.g., DJI Mic)
FR5: DM can see a visual indicator that recording is active (timer or waveform)
FR6: System continues recording through phone calls and system interruptions, resuming automatically or prompting to resume
FR7: DM can place a tag with a single tap during recording
FR8: Each tag automatically anchors to a configurable time window before the tap (default ~10 seconds; options: 5s/10s/15s/20s)
FR9: DM can select from a palette of tag categories organized by active category (Story, Combat, Roleplay, World, Meta)
FR10: DM can create a custom tag with short text input during recording
FR11: DM receives haptic feedback confirming tag placement
FR12: DM can see a running count of tags placed during the current session
FR13: DM can configure which tag categories are active before starting a session
FR14: DM can create, rename, and delete custom tag categories
FR15: DM can create, rename, and delete tags within categories
FR16: DM can reorder tag categories and tags within the palette
FR17: System provides a default set of D&D-oriented tag categories and tags on first use
FR18: DM can create, rename, and delete campaigns
FR19: DM can set campaign metadata (name, description)
FR20: Sessions are automatically nested under campaigns with auto-numbering and editable titles
FR21: DM can view session metadata (date, duration, tag count, title, location)
FR22: System captures location metadata per session (optional, with user permission)
FR23: DM can transfer a recording with all metadata from iPhone to Mac via AirDrop
FR24: DM can transfer a recording with all metadata from iPhone to Mac via local network
FR25: Transfer includes audio file, tag data, session metadata, and campaign association as a bundled package
FR26: Mac app detects and handles re-import of an already-imported session (deduplication)
FR27: DM can view a timeline with audio waveform and color-coded tag markers
FR28: DM can click a tag marker to jump audio playback to that moment
FR29: DM can filter tags by category in the tag sidebar
FR30: DM can edit a tag's label after the session
FR31: DM can change a tag's category after the session
FR32: DM can delete tags after the session
FR33: DM can place new tags retroactively by scrubbing through the audio
FR34: DM can add, edit, and delete text notes on individual tags
FR35: DM can add a session-level summary note
FR36: DM can scrub through the full audio recording (not just tagged segments)
FR37: Mac app transcribes tagged audio segments locally using WhisperX
FR38: DM can trigger transcription per-tag or as a batch for all tags in a session
FR39: DM can view transcription text alongside each tag
FR40: DM can edit and correct transcription text manually
FR41: DM can perform full-text search across all transcriptions and tag labels across all sessions in a campaign
FR42: DM can browse tags filtered by category across all sessions in a campaign
FR43: Search results link directly to the tagged audio moment for playback
FR44: DM can browse a chronological session list within a campaign
FR45: DM can export transcribed tags and notes from a session as markdown
FR46: DM can export transcribed tags and notes from multiple sessions or a full campaign as markdown
FR47: DM can configure the default rewind duration (5s/10s/15s/20s)
FR48: DM can configure audio recording quality settings
FR49: DM can manage storage (view space used, delete old recordings)

### NonFunctional Requirements

NFR1: Tag placement response < 200ms (haptic + visual feedback) during recording
NFR2: Recording start/stop < 1 second
NFR3: Audio playback jump (tag click) < 500ms
NFR4: Waveform rendering smooth at 60fps during scrub
NFR5: Full-text search across 10+ sessions < 1 minute
NFR6: WhisperX transcription — minutes per segment acceptable, batch runs in background
NFR7: AirDrop/local network transfer (~115 MB) < 2 minutes
NFR8: App launch to recording < 5 seconds
NFR9: Recording durability — loss of < 5 seconds of audio on crash (frequent disk flush)
NFR10: Recording endurance — 4+ hours continuous with screen locked
NFR11: Tag data persistence — zero tag loss (written to disk immediately on placement)
NFR12: Import integrity — zero data corruption on transfer (verify on import)
NFR13: Session data isolation — corruption in one session cannot affect other sessions
NFR14: Zero network calls in MVP — no analytics, no telemetry, no cloud
NFR15: All data remains on user's devices (iPhone + Mac) — core brand promise
NFR16: Microphone access only during active recording
NFR17: Location access only at session start (if permitted)
NFR18: VoiceOver support — standard iOS/macOS VoiceOver compatibility on all custom components
NFR19: Dynamic Type — support system font size preferences, tag palette adapts layout at larger sizes
NFR20: Color independence — tag categories distinguishable without color alone (use labels/icons/shapes in addition to color)
NFR21: WhisperX compatibility — support current stable whisper.cpp release with Metal/Core ML
NFR22: External microphone — support any Core Audio-compatible input device
NFR23: AirDrop — standard AirDrop protocol via UTI/file type registration for .dictly bundles
NFR24: Markdown export — standard CommonMark-compatible output
NFR25: Reduce Motion — respect UIAccessibility.isReduceMotionEnabled, replace animations with instant state changes

### Additional Requirements

- Architecture specifies a **starter template**: Two App Targets (DictlyiOS + DictlyMac) + Shared DictlyKit Swift Package in a single Xcode workspace — this drives Epic 1 Story 1
- SwiftData with @Model macro for persistence (Tag, Session, Campaign, TagCategory entities)
- whisper.cpp (C/C++) with Metal and Core ML instead of WhisperX Python — native performance, Mac App Store sandbox compatible
- Custom UTI (.dictly) flat directory bundle format for transfer (audio.aac + session.json)
- @Observable for all service classes (not ObservableObject) — SwiftUI native observation
- Core Spotlight (CSSearchableIndex) for full-text search indexing across sessions
- NSUbiquitousKeyValueStore for automatic bidirectional tag category sync between iOS and Mac (category metadata only, not recordings)
- DictlyError enum with associated values defined in DictlyKit for consistent error handling across both apps
- OSLog/Logger framework for structured local debugging with per-module categories
- Ship with base.en whisper model (~150 MB), offer downloadable small.en and medium.en models
- ModelManager for whisper model download, storage, and selection on Mac
- SearchIndexer in DictlyKit/DictlyStorage for shared Core Spotlight indexing logic
- CategorySyncService in DictlyKit/DictlyStorage for iCloud KVS category sync
- Feature-based folder structure within each app target (Recording, Tagging, Review, etc.)
- Module-based organization in shared package (Models, Theme, Storage, Export)
- XCTest for unit/integration tests on shared package, XCUITest for UI testing per target
- UTI registered on both platforms so AirDrop/Finder recognizes Dictly bundles
- Bonjour service discovery + direct Wi-Fi transfer as fallback for AirDrop
- AAC 64kbps mono audio format consistent from iOS recording through Mac playback and whisper.cpp input

### UX Design Requirements

UX-DR1: Implement DictlyTheme shared Swift package with base palette colors (light: #FAF8F5/#F2EDE7/#1C1917/#78716C/#E7E0D8; dark: #1A1816/#292524/#F5F0EB/#A8A29E/#3D3835), tag category colors (Story #D97706, Combat #DC2626, Roleplay #7C3AED, World #059669, Meta #4B7BE5), and accent/state colors (recording #EF4444, success #16A34A, warning #F59E0B, destructive #DC2626)
UX-DR2: Implement typography scale using SF Pro system fonts with platform-specific sizes (iOS: Display 34pt, H1 28pt, H2 22pt, H3 17pt, Body 17pt, Caption 13pt, Tag Label 15pt; Mac: Display 28pt, H1 24pt, H2 20pt, H3 16pt, Body 14pt, Caption 12pt, Tag Label 13pt) — all honoring Dynamic Type
UX-DR3: Implement 8pt grid spacing system with tokens: space-xs 4pt, space-sm 8pt, space-md 16pt, space-lg 24pt, space-xl 32pt, space-2xl 48pt
UX-DR4: Build TagCard custom component (iOS) — color stripe left edge, tag label + category name, pressed state with scale 0.96 + category color glow + haptic, minimum 48x48pt tap target, VoiceOver label "[Tag name], [Category]. Double-tap to place tag."
UX-DR5: Build LiveWaveform custom component (iOS) — horizontal bar chart sampling AVAudioEngine audio levels at ~15fps, 48pt height, "LIVE"/"PAUSED" label, recording-red bars, VoiceOver announces recording state
UX-DR6: Build CategoryTabBar custom component (iOS) — horizontally scrollable pill-shaped tabs with colored dot (6pt) + category name, active tab with darker background, fade edges on scroll, VoiceOver "[Category name] filter. [X] tags available."
UX-DR7: Build SessionWaveformTimeline custom component (Mac) — Core Audio waveform rendering with colored circle tag markers + vertical lines, draggable playhead with diamond cap, tag hover tooltips, 60fps scrubbing, zoom support, arrow key navigation between markers
UX-DR8: Build TagDetailPanel custom component (Mac) — header with editable tag label + category badge + timestamp, WhisperX transcription block (editable inline), notes area (free-form editable), action row (Edit Label, Change Category, Delete Tag), related tags column (cross-session search results), auto-save on blur
UX-DR9: Build RecordingStatusBar custom component (iOS) — animated red dot + "REC" label, large tabular-nums timer (SF Mono), tag count pill badge, paused state with yellow dot + "PAUSED", VoiceOver updates every 30 seconds
UX-DR10: Build TransferPrompt component (iOS) — session summary card (duration, tag count, category breakdown), AirDrop button, "Transfer Later" secondary option, states: Ready/Transferring/Complete/Failed
UX-DR11: Implement iOS recording screen layout — header (RecordingStatusBar), compact LiveWaveform, CategoryTabBar, 2-column LazyVGrid tag card grid, dashed "+" custom tag card + "Stop Recording" bar
UX-DR12: Implement timestamp-first interaction model — on any tag tap (standard or custom), immediately capture timestamp + rewind-anchor before any label input; custom tag sheet appears after moment is already anchored
UX-DR13: Implement Mac session review layout — NavigationSplitView with left sidebar (260pt, search + category filter pills + tag list), toolbar (session name, metadata, Transcribe All/Export MD/Session Notes), waveform timeline (full-width), detail area below waveform (appears on tag selection)
UX-DR14: Implement empty states with warm encouraging tone for: no campaigns, no sessions, no tags, no search results, no transcription yet — each with explanatory message and action button
UX-DR15: Implement loading states — import progress bar, waveform skeleton placeholder, inline transcription spinner, batch transcription progress (3/28), search skeleton items — never block full UI during loading
UX-DR16: Implement tag marker shapes per category for color-blind accessibility — circle, diamond, square, triangle, hexagon (one per default category) on Mac waveform timeline
UX-DR17: Implement iOS device adaptation — 2-column tag grid at standard sizes, 1-column at largest Dynamic Type, category tabs horizontally scrollable never wrapping, waveform always full-width 48pt
UX-DR18: Implement Mac window adaptation — minimum 900x500pt (sidebar collapses to icons, detail stacks vertically), standard 1200x700pt (full three-zone layout), sidebar 260pt collapsible to 0pt
UX-DR19: Implement animation and motion tokens — tag placement scale pulse (0.95→1.0, 150ms ease-out), recording dot breathing glow (2s cycle), waveform scrubbing 60fps, standard SwiftUI navigation transitions — all respecting Reduce Motion
UX-DR20: Implement confirmation dialogs only for destructive actions (Stop Recording, Delete Tag) — all other actions instant with no confirmation

### FR Coverage Map

FR1: Epic 2 - Create new recording session
FR2: Epic 2 - 4+ hour background recording
FR3: Epic 2 - Pause/resume recording
FR4: Epic 2 - External microphone support
FR5: Epic 2 - Visual recording indicator
FR6: Epic 2 - Survive interruptions
FR7: Epic 2 - Single-tap tag placement
FR8: Epic 2 - Rewind-anchor tagging
FR9: Epic 2 - Tag category palette
FR10: Epic 2 - Custom tag creation
FR11: Epic 2 - Haptic feedback
FR12: Epic 2 - Running tag count
FR13: Epic 2 - Configure active categories
FR14: Epic 1 - Create/rename/delete tag categories
FR15: Epic 1 - Create/rename/delete tags in categories
FR16: Epic 1 - Reorder tag categories and tags
FR17: Epic 1 - Default D&D tag categories
FR18: Epic 1 - Create/rename/delete campaigns
FR19: Epic 1 - Campaign metadata
FR20: Epic 1 - Session auto-numbering
FR21: Epic 1 - Session metadata display
FR22: Epic 1 - Location metadata
FR23: Epic 3 - AirDrop transfer
FR24: Epic 3 - Local network transfer
FR25: Epic 3 - Bundled transfer package
FR26: Epic 3 - Deduplication on import
FR27: Epic 4 - Waveform timeline with markers
FR28: Epic 4 - Click tag to jump playback
FR29: Epic 4 - Filter tags by category
FR30: Epic 4 - Edit tag label
FR31: Epic 4 - Change tag category
FR32: Epic 4 - Delete tags
FR33: Epic 4 - Retroactive tag placement
FR34: Epic 4 - Tag notes
FR35: Epic 4 - Session summary note
FR36: Epic 4 - Full audio scrubbing
FR37: Epic 5 - Local whisper.cpp transcription
FR38: Epic 5 - Per-tag and batch transcription
FR39: Epic 5 - View transcription per tag
FR40: Epic 5 - Edit transcription text
FR41: Epic 6 - Full-text search across sessions
FR42: Epic 6 - Browse tags by category cross-session
FR43: Epic 6 - Search results link to audio moment
FR44: Epic 6 - Chronological session browsing
FR45: Epic 6 - Single session markdown export
FR46: Epic 6 - Multi-session/campaign markdown export
FR47: Epic 2 - Configure rewind duration
FR48: Epic 2 - Audio quality settings
FR49: Epic 1 - Storage management

## Epic List

### Epic 1: Project Setup & Campaign Organization
The DM can launch the app, create campaigns, manage tag categories with sensible D&D defaults, and organize their game structure on both platforms.
**FRs covered:** FR14, FR15, FR16, FR17, FR18, FR19, FR20, FR21, FR22, FR49
**Also covers:** Architecture starter template (Xcode workspace + DictlyKit + DictlyTheme), SwiftData models, iCloud KVS category sync, storage management

### Epic 2: Session Recording & Live Tagging
The DM can record a full 4+ hour session with the screen locked, tag moments with a single tap using the rewind-anchor interaction, receive haptic confirmation, and survive phone calls and interruptions — all without breaking table flow.
**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR6, FR7, FR8, FR9, FR10, FR11, FR12, FR13, FR47, FR48
**Also covers:** UX recording screen layout, TagCard, LiveWaveform, CategoryTabBar, RecordingStatusBar, timestamp-first interaction model

### Epic 3: Session Transfer & Import
The DM can transfer a session from iPhone to Mac via AirDrop (or local network), and the Mac app auto-recognizes the .dictly bundle, imports it under the correct campaign, and handles re-imports gracefully.
**FRs covered:** FR23, FR24, FR25, FR26
**Also covers:** .dictly custom UTI bundle format, BundleSerializer, TransferPrompt component, deduplication

### Epic 4: Session Review & Annotation
The DM can view a waveform timeline with color-coded tag markers, click any tag to jump to that moment, edit/rename/recategorize/delete tags, place retroactive tags, add notes, and work through a session review in ~12-15 minutes.
**FRs covered:** FR27, FR28, FR29, FR30, FR31, FR32, FR33, FR34, FR35, FR36
**Also covers:** SessionWaveformTimeline, TagDetailPanel, Mac three-panel layout, inline editing, tag marker shapes for accessibility

### Epic 5: Local Transcription
The DM can transcribe tagged audio segments locally using whisper.cpp with Metal/Core ML acceleration, trigger transcription per-tag or as a batch, view transcription alongside tags, and correct fantasy names or garbled text.
**FRs covered:** FR37, FR38, FR39, FR40
**Also covers:** whisper.cpp integration via WhisperBridge, ModelManager (base.en default, downloadable small.en/medium.en), batch progress UI

### Epic 6: Search, Archive & Export
The DM can search across all sessions by NPC name, location, or keyword and get instant results with transcription snippets. They can browse tags by category across sessions, click a result to jump directly to the audio moment, and export session notes as CommonMark markdown for Obsidian/wiki workflows.
**FRs covered:** FR41, FR42, FR43, FR44, FR45, FR46
**Also covers:** Core Spotlight indexing, cross-session related tags in TagDetailPanel, campaign-level export, SearchService

## Epic 1: Project Setup & Campaign Organization

The DM can launch the app, create campaigns, manage tag categories with sensible D&D defaults, and organize their game structure on both platforms.

### Story 1.1: Initialize Xcode Workspace with Shared DictlyKit Package

As a developer,
I want a properly structured Xcode workspace with two app targets and a shared Swift package,
So that all subsequent development has a consistent foundation with shared data models.

**Acceptance Criteria:**

**Given** a fresh clone of the repository
**When** the workspace is opened in Xcode
**Then** both iOS and Mac targets build successfully
**And** DictlyKit compiles with SwiftData models (Campaign, Session, Tag, TagCategory)
**And** DictlyKit contains zero `UIKit` or `AppKit` imports
**And** all models have `uuid: UUID` for stable identity
**And** unit tests exist and pass for model creation and relationships (Campaign → Session cascade, Session → Tag cascade)

### Story 1.2: Implement Design Token System (DictlyTheme)

As a developer,
I want a shared design token package with colors, typography, spacing, and animation constants,
So that both apps use a consistent visual language matching the UX specification.

**Acceptance Criteria:**

**Given** a SwiftUI view in either app target
**When** it references `DictlyTheme` colors, typography, or spacing
**Then** the correct values are applied for the current platform (iOS vs Mac)
**And** Dark Mode toggles produce the warm-toned dark palette (#1A1816 background, not system blue-black)
**And** all 5 tag category colors are defined (Story #D97706, Combat #DC2626, Roleplay #7C3AED, World #059669, Meta #4B7BE5)
**And** spacing tokens match 8pt grid (xs=4, sm=8, md=16, lg=24, xl=32, 2xl=48)

### Story 1.3: Campaign Management

As a DM,
I want to create, rename, and delete campaigns with metadata,
So that I can organize my different tabletop games.

**Acceptance Criteria:**

**Given** the DM opens the app with no campaigns
**When** they view the campaign list
**Then** an empty state message is displayed with a "Create Campaign" button

**Given** the DM taps "Create Campaign"
**When** they enter a name and optional description and save
**Then** the campaign appears in the list with the entered metadata

**Given** an existing campaign
**When** the DM renames it
**Then** the updated name is displayed immediately

**Given** an existing campaign
**When** the DM deletes it and confirms
**Then** the campaign and all its sessions are removed (cascade delete)
**And** a confirmation dialog is shown before deletion

### Story 1.4: Session Organization Within Campaigns

As a DM,
I want sessions automatically organized under campaigns with auto-numbering and metadata,
So that I can track my session history at a glance.

**Acceptance Criteria:**

**Given** a campaign with no sessions
**When** the DM views the campaign detail
**Then** an empty state message is shown with guidance to start recording

**Given** a campaign with existing sessions
**When** the DM views the session list
**Then** sessions are listed chronologically with date, duration, tag count, and title

**Given** a new session is created
**When** it is added to a campaign
**Then** it receives the next auto-incremented session number
**And** the title defaults to "Session N" and is editable

**Given** location permission is granted on iOS
**When** a session starts
**Then** the current location is captured once and stored as session metadata

### Story 1.5: Tag Category & Tag Management

As a DM,
I want to create, rename, delete, and reorder tag categories and tags with D&D-oriented defaults,
So that I can organize my tagging palette to match my campaign's needs.

**Acceptance Criteria:**

**Given** a fresh install of the app
**When** the DM opens the app for the first time
**Then** 5 default tag categories are present: Story (amber), Combat (crimson), Roleplay (violet), World (green), Meta (blue)
**And** each category contains a set of sensible default tags

**Given** the tag management screen
**When** the DM creates a new custom category
**Then** it appears in the category list and is available in the tag palette

**Given** an existing category
**When** the DM renames or deletes it
**Then** the change is reflected immediately
**And** deleting a category reassigns its tags to "Uncategorized" (not deleted)

**Given** the category list
**When** the DM reorders categories
**Then** the new order persists and is reflected in the tag palette

### Story 1.6: Tag Category Sync via iCloud Key-Value Store

As a DM,
I want my tag categories to sync automatically between my iPhone and Mac,
So that categories I create on one device appear on the other without manual effort.

**Acceptance Criteria:**

**Given** the DM creates a new tag category on iOS
**When** the Mac app is running or next launches
**Then** the new category appears on Mac with matching name, color, icon, and sort order

**Given** the DM renames a category on Mac
**When** the iOS app receives the iCloud KVS update
**Then** the category name updates on iOS

**Given** both apps modify the same category simultaneously
**When** the changes sync
**Then** the most recent change wins without data loss or crash

**Given** the sync is operating
**When** inspecting network traffic
**Then** only category metadata keys are transmitted — zero session, tag, or audio data

### Story 1.7: Storage Management

As a DM,
I want to view how much storage my recordings use and delete old ones,
So that I can manage my device space as sessions accumulate.

**Acceptance Criteria:**

**Given** the DM opens storage management
**When** there are recorded sessions
**Then** total space used is displayed along with a per-session breakdown (audio size, date)

**Given** the DM selects a session for deletion
**When** they confirm the delete action
**Then** the audio file and associated metadata are removed
**And** the storage total updates to reflect freed space

**Given** no recordings exist
**When** the DM opens storage management
**Then** a message indicates no recordings are stored

## Epic 2: Session Recording & Live Tagging

The DM can record a full 4+ hour session with the screen locked, tag moments with a single tap using the rewind-anchor interaction, receive haptic confirmation, and survive phone calls and interruptions — all without breaking table flow.

### Story 2.1: Audio Recording Engine with Background Persistence

As a DM,
I want to record audio continuously for 4+ hours with the screen locked and survive interruptions,
So that I never lose a session recording regardless of what my phone does.

**Acceptance Criteria:**

**Given** the DM starts a recording within a campaign
**When** recording begins
**Then** audio is captured in AAC 64kbps mono format
**And** recording starts within 1 second of tapping

**Given** an active recording
**When** the screen locks or the DM switches apps
**Then** recording continues uninterrupted in the background

**Given** an active recording lasting 4+ hours
**When** the session ends
**Then** the complete audio file is intact with no gaps (except explicit pauses)

**Given** the app crashes during recording
**When** the DM relaunches
**Then** at most 5 seconds of audio is lost from the end of the recording

**Given** an external microphone (e.g., DJI Mic) is connected
**When** the DM starts recording
**Then** the external mic is used as the audio input source

### Story 2.2: Pause, Resume & Phone Call Interruption Handling

As a DM,
I want to pause and resume recording and have it survive phone calls,
So that interruptions don't create separate files or lose my session continuity.

**Acceptance Criteria:**

**Given** an active recording
**When** the DM taps pause
**Then** recording stops, the state shows "PAUSED", and the timer freezes

**Given** a paused recording
**When** the DM taps resume
**Then** recording continues in the same session and file seamlessly

**Given** an active recording
**When** a phone call is received
**Then** recording auto-pauses and shows a prominent "Recording Paused" state

**Given** a phone-call-paused recording
**When** the call ends
**Then** a prominent "Resume Recording" button is displayed
**And** tapping it resumes recording in the same session

**Given** a session with pauses
**When** reviewed later on Mac
**Then** pauses appear as gaps in the timeline with all tags before and after intact

### Story 2.3: Recording Screen Layout & Status Indicators

As a DM,
I want to see that recording is active with a timer, waveform, and tag count,
So that I have confidence the session is being captured without needing to stare at my phone.

**Acceptance Criteria:**

**Given** an active recording
**When** the DM glances at the screen
**Then** a pulsing red dot with "REC", the elapsed timer, and tag count are visible at the top
**And** a compact live waveform shows real-time audio levels below

**Given** the recording is paused
**When** the DM views the screen
**Then** the dot is yellow/static with "PAUSED", the timer is frozen, and the waveform bars are gray

**Given** Reduce Motion is enabled in iOS settings
**When** recording is active
**Then** the red dot is solid (no pulse), waveform updates without animation

**Given** VoiceOver is active
**When** the status bar is focused
**Then** it reads "Recording. [Duration]. [Count] tags placed."

### Story 2.4: Tag Palette with Category Tabs & One-Tap Tagging

As a DM,
I want to tag moments with a single tap from an organized category palette,
So that I can capture what matters without breaking my flow at the table.

**Acceptance Criteria:**

**Given** an active recording with default tag categories
**When** the DM taps a category tab
**Then** the tag grid filters to show only tags in that category

**Given** the tag grid is visible
**When** the DM taps a tag card
**Then** a tag is placed within 200ms with haptic feedback and a brief scale animation
**And** the tag count badge increments

**Given** multiple tag categories
**When** the DM switches between tabs
**Then** the grid transitions smoothly to the selected category's tags

**Given** iOS accessibility largest Dynamic Type is active
**When** viewing the tag grid
**Then** the grid switches to a single-column layout with larger tag cards

**Given** VoiceOver is active
**When** a tag card is focused
**Then** it reads "[Tag name], [Category]. Double-tap to place tag."

### Story 2.5: Rewind-Anchor Tagging & Timestamp-First Interaction

As a DM,
I want each tag to capture the ~10 seconds before I tapped (not the moment of the tap),
So that the tag anchors to the actual moment I'm reacting to, not my reaction.

**Acceptance Criteria:**

**Given** recording is active with default 10-second rewind
**When** the DM taps a tag at timestamp 2:30:00
**Then** the tag's anchor time is stored as 2:29:50 (10 seconds before the tap)

**Given** the DM has configured rewind duration to 15 seconds
**When** they place a tag at timestamp 1:00:00
**Then** the anchor time is 0:59:45

**Given** the DM taps the "+" custom tag card
**When** the custom tag sheet appears
**Then** the anchor timestamp is already captured from the moment of the first tap
**And** the DM can take their time entering a label without losing the moment

**Given** a tag is placed
**When** the app is force-quit immediately after
**Then** the tag is persisted in SwiftData (zero tag loss)

**Given** iOS Settings screen
**When** the DM changes rewind duration to 5s/10s/15s/20s
**Then** the new duration applies to all subsequent tags in future sessions

### Story 2.6: Custom Tag Creation During Recording

As a DM,
I want to create a quick custom tag with a short label during recording,
So that I can tag unique moments that don't fit my preset categories.

**Acceptance Criteria:**

**Given** an active recording
**When** the DM taps the "+" custom tag card
**Then** a partial-height sheet appears with a text field and optional category picker
**And** the rewind-anchor timestamp is already locked from the initial tap

**Given** the custom tag sheet is open
**When** the DM types "Grimthor — blacksmith intro" and dismisses
**Then** a tag is created with that label at the originally captured anchor time

**Given** the custom tag sheet is open
**When** the DM taps outside the sheet or swipes down
**Then** the keyboard dismisses and the sheet closes
**And** if a label was entered, the tag is saved; if empty, the tag is discarded

### Story 2.7: Stop Recording & Session Summary

As a DM,
I want to stop the recording with a confirmation and see a session summary,
So that I know the session was captured completely before putting my phone away.

**Acceptance Criteria:**

**Given** an active recording
**When** the DM taps "Stop Recording"
**Then** a confirmation dialog appears: "End session?"

**Given** the stop confirmation dialog
**When** the DM taps "Cancel"
**Then** recording continues uninterrupted

**Given** the stop confirmation dialog
**When** the DM confirms
**Then** recording stops and a session summary is displayed showing duration, total tags, and a tag list grouped by category

**Given** the session summary
**When** the DM dismisses it
**Then** the session is saved and the DM returns to the campaign detail screen

**Given** iOS Settings
**When** the DM adjusts audio quality settings
**Then** the selected quality applies to future recordings

## Epic 3: Session Transfer & Import

The DM can transfer a session from iPhone to Mac via AirDrop (or local network), and the Mac app auto-recognizes the .dictly bundle, imports it under the correct campaign, and handles re-imports gracefully.

### Story 3.1: .dictly Bundle Format & Serialization

As a developer,
I want a custom .dictly bundle format that packages audio, tags, and session metadata,
So that transfer between iOS and Mac preserves all session data in a single file.

**Acceptance Criteria:**

**Given** a completed session with audio, tags, and metadata
**When** the `BundleSerializer` creates a .dictly bundle
**Then** the bundle contains `audio.aac` (session recording) and `session.json` (metadata, tags, campaign association)
**And** the JSON uses camelCase keys matching Swift Codable defaults

**Given** a valid .dictly bundle
**When** the `BundleSerializer` unpacks it
**Then** all Session, Tag, and Campaign association data is restored from `session.json`
**And** the audio file is extracted intact

**Given** a .dictly bundle with corrupted or missing files
**When** deserialization is attempted
**Then** a `DictlyError.transfer` is thrown with a specific cause

**Given** the DictlyKit package
**When** bundle serialization/deserialization tests run
**Then** round-trip tests pass: serialize → deserialize produces identical data

### Story 3.2: AirDrop Transfer from iOS

As a DM,
I want to send my session to my Mac via AirDrop after recording,
So that I can review it on the big screen without any file management hassle.

**Acceptance Criteria:**

**Given** a completed session on iOS
**When** the DM taps the AirDrop button on the TransferPrompt
**Then** the standard iOS AirDrop share sheet appears with the .dictly bundle ready to send

**Given** the AirDrop transfer is in progress
**When** the DM views the TransferPrompt
**Then** a progress indicator shows the transfer state (sending → complete or failed)

**Given** the transfer completes successfully
**When** the DM views the TransferPrompt
**Then** a checkmark confirmation is displayed that auto-dismisses after 2 seconds

**Given** the transfer fails
**When** the DM views the TransferPrompt
**Then** an error message with a retry button is displayed

**Given** the DM chooses "Transfer Later"
**When** they dismiss the session summary
**Then** the session is saved locally and can be transferred later from the session list

### Story 3.3: Local Network Transfer (Bonjour Fallback)

As a DM,
I want to transfer sessions via local Wi-Fi when AirDrop isn't working,
So that I always have a reliable way to get sessions to my Mac.

**Acceptance Criteria:**

**Given** both iPhone and Mac are on the same Wi-Fi network
**When** the Mac app is running with its Bonjour listener active
**Then** the iOS app discovers the Mac via Bonjour service discovery

**Given** the Mac is discovered on the local network
**When** the DM initiates a local network transfer
**Then** the .dictly bundle is sent directly over Wi-Fi

**Given** a local network transfer is in progress
**When** the DM views the transfer UI
**Then** progress is displayed (sending → complete or failed)

**Given** the local network transfer fails (e.g., Wi-Fi disconnects)
**When** the DM views the error
**Then** a specific error message and retry option are shown

### Story 3.4: Mac Import with Deduplication

As a DM,
I want my Mac to automatically recognize incoming Dictly sessions and organize them correctly,
So that import is effortless and I never accidentally duplicate a session.

**Acceptance Criteria:**

**Given** the Mac app has registered the .dictly UTI
**When** a .dictly bundle arrives via AirDrop or Finder open
**Then** the Mac app launches or foregrounds and begins import automatically

**Given** a .dictly bundle is being imported
**When** the import processes
**Then** the session appears under the correct campaign (matched by campaign UUID)
**And** audio is stored in the app sandbox
**And** all tags and metadata are written to SwiftData
**And** an import progress banner is displayed

**Given** a session that has already been imported (matching session UUID)
**When** the same .dictly bundle is imported again
**Then** a duplicate warning is shown: "Session already exists"
**And** the DM can choose to skip or replace

**Given** import completes successfully
**When** the DM views the campaign
**Then** the new session appears in the chronological session list with correct metadata

**Given** a .dictly bundle with a campaign UUID not yet on Mac
**When** the import processes
**Then** the campaign is created automatically from the bundle's campaign metadata

## Epic 4: Session Review & Annotation

The DM can view a waveform timeline with color-coded tag markers, click any tag to jump to that moment, edit/rename/recategorize/delete tags, place retroactive tags, add notes, and work through a session review in ~12-15 minutes.

### Story 4.1: Mac Session Review Layout

As a DM,
I want a three-panel review layout with sidebar, waveform, and detail area,
So that I can see all my session data organized for efficient review.

**Acceptance Criteria:**

**Given** the DM opens a session on Mac
**When** the session review screen loads
**Then** a NavigationSplitView displays: left sidebar (260pt) with tag list, main area with toolbar and waveform timeline, and a detail area below the waveform

**Given** the toolbar area
**When** the session is displayed
**Then** session name, campaign name, duration, tag count, and action buttons (Transcribe All, Export MD, Session Notes) are visible

**Given** no tag is selected
**When** the detail area is visible
**Then** a placeholder prompt is shown: "Select a tag to view details"

**Given** a window at minimum size (900x500pt)
**When** the layout adapts
**Then** the sidebar collapses to icons and the detail area stacks vertically

**Given** the sidebar toggle
**When** the DM hides the sidebar
**Then** the waveform and detail area expand to fill the available width

### Story 4.2: Waveform Timeline Rendering with Tag Markers

As a DM,
I want to see my session as a waveform with color-coded tag markers,
So that I can visually scan where the action happened at a glance.

**Acceptance Criteria:**

**Given** an imported session with audio
**When** the waveform timeline renders
**Then** the full session audio is displayed as a waveform using Core Audio / AVAudioFile data
**And** a skeleton placeholder is shown during rendering, fading to the waveform when ready

**Given** a session with tags
**When** the waveform displays
**Then** each tag appears as a colored circle marker at its anchor position on the waveform
**And** marker colors match their tag category (Story=amber, Combat=crimson, etc.)

**Given** tag markers on the waveform
**When** each default category marker renders
**Then** markers use distinct shapes per category (circle, diamond, square, triangle, hexagon) for color-blind accessibility

**Given** the DM hovers over a tag marker
**When** the tooltip appears
**Then** it shows the tag label, category, and timestamp

**Given** waveform scrubbing
**When** the DM drags or scrolls the waveform
**Then** rendering is smooth at 60fps

### Story 4.3: Audio Playback & Waveform Navigation

As a DM,
I want to click any tag or position on the waveform to jump playback there,
So that I can quickly listen to any moment in my session.

**Acceptance Criteria:**

**Given** a tag marker on the waveform
**When** the DM clicks it
**Then** the playhead jumps to that tag's anchor position and audio plays from there
**And** the jump completes within 500ms

**Given** the waveform timeline
**When** the DM clicks any position on the waveform
**Then** the playhead repositions to that point and playback begins

**Given** the playhead
**When** the DM drags it along the waveform
**Then** audio scrub preview plays as the playhead moves

**Given** playback controls
**When** the DM uses play/pause
**Then** the playhead advances in real-time along the waveform during playback

**Given** the full session audio (not just tagged segments)
**When** the DM scrubs to any position
**Then** the complete recording is available for playback

### Story 4.4: Tag Sidebar with Category Filtering

As a DM,
I want a scrollable tag list in the sidebar with category filters,
So that I can quickly find and navigate to specific tags.

**Acceptance Criteria:**

**Given** an imported session with tags
**When** the sidebar displays
**Then** all tags are listed chronologically with category color dot, label, and timestamp

**Given** category filter pills below the search bar
**When** the DM activates one or more category filters
**Then** the sidebar list shows only tags matching the selected categories
**And** waveform markers for unselected categories dim to reduced opacity

**Given** a tag in the sidebar
**When** the DM clicks it
**Then** the waveform jumps to that tag's position, the tag marker highlights, and the detail panel populates

**Given** filter state
**When** the DM switches to a different session
**Then** filters reset to show all categories

### Story 4.5: Tag Editing — Rename, Recategorize & Delete

As a DM,
I want to edit tag labels, change categories, and delete tags during review,
So that I can refine my raw in-session tags into a polished session record.

**Acceptance Criteria:**

**Given** a selected tag in the detail panel
**When** the DM clicks the tag label
**Then** the label becomes editable inline and saves on blur

**Given** a selected tag
**When** the DM clicks the category badge
**Then** a category picker appears and selecting a new category updates the tag immediately
**And** the waveform marker color and shape update to match

**Given** a selected tag
**When** the DM clicks "Delete Tag" and confirms
**Then** the tag is removed from the sidebar, waveform, and SwiftData
**And** a confirmation dialog is shown before deletion

**Given** a right-click on a tag in the sidebar
**When** the context menu appears
**Then** options include Edit Label, Change Category, and Delete Tag

### Story 4.6: Retroactive Tag Placement

As a DM,
I want to place new tags on the waveform during review by scrubbing to a moment,
So that I can tag things I missed during the live session.

**Acceptance Criteria:**

**Given** the waveform timeline during review
**When** the DM right-clicks or uses a designated interaction at a position on the waveform
**Then** a new tag is created at that position with a default label and category picker

**Given** a retroactively placed tag
**When** the DM enters a label and selects a category
**Then** the tag appears in the sidebar and as a marker on the waveform at the chosen position

**Given** a retroactively placed tag
**When** it is saved
**Then** it behaves identically to tags placed during recording (editable, deletable, searchable)

### Story 4.7: Tag Notes & Session Summary Notes

As a DM,
I want to add text notes to individual tags and write a session-level summary,
So that I can capture context that audio alone can't convey.

**Acceptance Criteria:**

**Given** a selected tag in the detail panel
**When** the DM types in the notes area
**Then** notes are saved automatically on blur (no save button needed)

**Given** a tag with existing notes
**When** the DM edits or clears the notes
**Then** changes persist immediately to SwiftData

**Given** the session toolbar
**When** the DM clicks "Session Notes"
**Then** a session-level summary note editor appears
**And** the DM can write a 1-2 line session summary

**Given** a tag with notes
**When** the tag appears in search results or sidebar
**Then** the presence of notes is indicated (e.g., a small icon)

## Epic 5: Local Transcription

The DM can transcribe tagged audio segments locally using whisper.cpp with Metal/Core ML acceleration, trigger transcription per-tag or as a batch, view transcription alongside tags, and correct fantasy names or garbled text.

### Story 5.1: whisper.cpp Integration & WhisperBridge

As a developer,
I want a Swift-callable bridge to whisper.cpp with Metal/Core ML acceleration,
So that the Mac app can transcribe audio segments natively without a Python runtime.

**Acceptance Criteria:**

**Given** the whisper.cpp source is included in the project (git submodule or SPM)
**When** the Mac target builds
**Then** the WhisperBridge compiles and links successfully with whisper.cpp

**Given** an audio segment (AAC 64kbps mono, ~30 seconds)
**When** `WhisperBridge.transcribe(audioURL:modelURL:)` is called
**Then** a transcription string is returned
**And** Metal/Core ML acceleration is used on Apple Silicon

**Given** a transcription request
**When** the whisper model file is missing or corrupted
**Then** a `DictlyError.transcription` is thrown with a specific cause

**Given** the transcription engine
**When** processing a segment
**Then** it runs on a background thread and does not block the UI

### Story 5.2: Whisper Model Management

As a DM,
I want to choose which transcription model to use and download better models if I want,
So that I can balance transcription quality against disk space and processing time.

**Acceptance Criteria:**

**Given** a fresh install of the Mac app
**When** the app launches
**Then** the `base.en` model (~150 MB) is bundled and ready to use

**Given** the Mac Preferences window
**When** the DM views the transcription settings
**Then** available models are listed: base.en (bundled), small.en (~500 MB), medium.en (~1.5 GB)
**And** downloaded models show a checkmark, others show a download button with size

**Given** the DM clicks download on a model
**When** the download progresses
**Then** a progress bar shows download status
**And** on completion the model becomes selectable as the active model

**Given** a downloaded model
**When** the DM selects it as active
**Then** all future transcriptions use the selected model

**Given** the DM deletes a downloaded model
**When** the deletion completes
**Then** the space is freed and the app falls back to the bundled base.en model

### Story 5.3: Per-Tag & Batch Transcription

As a DM,
I want to transcribe individual tags or all tags at once,
So that I can get text versions of my tagged moments efficiently.

**Acceptance Criteria:**

**Given** a tag without transcription in the detail panel
**When** the DM clicks the inline "Transcribe" button
**Then** the transcription engine processes the tag's audio segment (~30 seconds around the anchor)
**And** an inline spinner shows progress
**And** the transcription text appears when complete

**Given** the session toolbar "Transcribe All" button
**When** the DM clicks it
**Then** all unprocessed tags in the session are queued for transcription
**And** a batch progress indicator shows (e.g., "3/28 tags transcribed")

**Given** batch transcription is running
**When** the DM continues reviewing tags, editing labels, or navigating
**Then** the UI remains fully responsive — transcription runs in the background

**Given** a tag transcription fails
**When** the error is displayed
**Then** a per-tag error badge with "Retry" button appears
**And** other tags continue processing unaffected

### Story 5.4: View & Edit Transcription Text

As a DM,
I want to view transcriptions alongside tags and correct garbled fantasy names,
So that my session archive has accurate searchable text.

**Acceptance Criteria:**

**Given** a tag with completed transcription
**When** the tag is selected in the detail panel
**Then** the transcription text is displayed in the transcription block below the tag header

**Given** a transcription with errors (e.g., "Grim Thor" instead of "Grimthor")
**When** the DM clicks into the transcription text
**Then** the text becomes editable inline

**Given** the DM edits a transcription
**When** they click away (blur)
**Then** the corrected text auto-saves to SwiftData

**Given** a tag without transcription
**When** it is selected in the detail panel
**Then** the transcription area shows "Transcription not yet run." with an inline "Transcribe" button

## Epic 6: Search, Archive & Export

The DM can search across all sessions by NPC name, location, or keyword and get instant results with transcription snippets. They can browse tags by category across sessions, click a result to jump directly to the audio moment, and export session notes as CommonMark markdown.

### Story 6.1: Core Spotlight Indexing

As a developer,
I want tags and transcriptions indexed via Core Spotlight,
So that full-text search is fast across 10+ sessions and integrates with macOS Spotlight.

**Acceptance Criteria:**

**Given** a tag is created or imported on either platform
**When** the tag is persisted to SwiftData
**Then** a `CSSearchableItem` is created with the tag label, transcription, notes, category, session ID, and timestamp

**Given** a transcription is completed or edited
**When** the text changes
**Then** the corresponding Spotlight index entry is updated

**Given** a tag or session is deleted
**When** the deletion completes
**Then** the corresponding Spotlight index entries are removed

**Given** macOS Spotlight
**When** the user searches for a Dictly tag term
**Then** matching Dictly items appear in system Spotlight results

### Story 6.2: Full-Text Search Across Sessions

As a DM,
I want to search by keyword across all my sessions and see results with transcription snippets,
So that I can find any moment from any session in seconds during prep.

**Acceptance Criteria:**

**Given** the Mac sidebar search bar
**When** the DM types a query (e.g., "Grimthor")
**Then** results appear from across all sessions in the campaign
**And** each result shows: tag label, session number, timestamp, and a highlighted transcription snippet

**Given** search results
**When** the DM clicks a result
**Then** the corresponding session opens with that tag selected, waveform jumps to position, and detail panel populates

**Given** a search with no matches
**When** the results area displays
**Then** a message shows "No results for '[query]'. Try a different term or browse by category."
**And** category filter pills are shown as an alternative

**Given** 10+ sessions with transcriptions
**When** a search is performed
**Then** results return within acceptable time (< 1 minute, ideally sub-second)

**Given** the DM clears the search
**When** the search bar is emptied
**Then** the view returns to the current session's tag list

### Story 6.3: Cross-Session Tag Browsing & Related Tags

As a DM,
I want to browse tags by category across all sessions and see related tags when reviewing,
So that I can discover connections across my campaign's history.

**Acceptance Criteria:**

**Given** the Mac app campaign view
**When** the DM selects a category filter in cross-session mode
**Then** all tags of that category across all sessions in the campaign are displayed chronologically

**Given** a tag selected in the detail panel
**When** the related tags column loads
**Then** it shows other tags across all sessions that mention similar terms (based on label and transcription text search)

**Given** a related tag in the detail panel
**When** the DM clicks it
**Then** the corresponding session opens with that tag selected

**Given** a chronological session list within a campaign
**When** the DM browses sessions
**Then** sessions are listed with date, title, duration, and tag count

### Story 6.4: Markdown Export — Single Session & Campaign

As a DM,
I want to export my session notes as markdown for use in Obsidian, wikis, or LLMs,
So that Dictly integrates into my existing prep workflow.

**Acceptance Criteria:**

**Given** the session toolbar "Export MD" button
**When** the DM clicks it
**Then** a markdown file is generated containing: session title, date, duration, all tags grouped by category with labels, timestamps, transcriptions, and notes

**Given** the export sheet
**When** the DM selects "Export Campaign"
**Then** a markdown file is generated containing all sessions in the campaign with the same tag/transcription/notes structure

**Given** the exported markdown
**When** opened in any CommonMark-compatible viewer (Obsidian, GitHub, VS Code)
**Then** the formatting renders correctly with proper headings, lists, and structure

**Given** export completes
**When** the file is saved
**Then** a system notification appears and the file is revealed in Finder
