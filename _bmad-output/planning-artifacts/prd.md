---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-02b-vision
  - step-02c-executive-summary
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
classification:
  projectType: mobile_app + desktop_app
  domain: general
  complexity: medium
  projectContext: greenfield
inputDocuments:
  - _bmad-output/planning-artifacts/product-brief-Dictly.md
  - _bmad-output/planning-artifacts/product-brief-Dictly-distillate.md
  - _bmad-output/brainstorming/brainstorming-session-2026-03-31-1733.md
  - docs/session-recorder-spec.md
documentCounts:
  briefs: 2
  research: 0
  brainstorming: 1
  projectDocs: 1
workflowType: 'prd'
---

# Product Requirements Document - Dictly

**Author:** Stejk
**Date:** 2026-03-31

## Executive Summary

Dictly is a paired iOS + macOS application that gives tabletop RPG Dungeon Masters a long-term campaign memory. During in-person sessions (typically 3–5+ hours), the DM places their iPhone on the table, records audio, and taps a single button to tag important moments — NPC introductions, plot hooks, rulings, funny quotes, subtle hints. Each tag anchors to ~10 seconds before the tap, capturing the actual moment rather than the moment of recognition. After the session, the recording imports to a Mac companion app where tagged segments are transcribed locally via WhisperX, organized into a searchable session archive, and exported as markdown. No cloud processing, no subscriptions, no data leaving the user's devices.

The MVP targets a single user: one DM, in-person sessions, iOS capture + Mac review. Validation focus is on consistent personal use over 10+ sessions, sub-15-minute post-session review, and acceptable WhisperX transcription quality in noisy tabletop environments.

### What Makes This Special

Every competing TTRPG tool follows a "record everything, process after" model — dump hours of audio into an AI and hope it finds the important parts. Dictly inverts this: the DM is the signal filter. A DM knows when something is funny, when a throwaway comment will matter three sessions later, when a subtle hint lands at the table. AI can transcribe words but cannot read the room. One tap, under two seconds, no immersion break — the DM captures what matters with contextual judgment no AI can replicate.

The result: reviewing a session takes minutes instead of hours. Tagged moments accumulate into a searchable campaign archive that grows more valuable with every session. After 10 sessions it's useful; after 50 it's irreplaceable. Fully local processing and storage means "your sessions never leave your devices" — a meaningful trust advantage in a market where every competitor sends private group conversations to cloud servers.

## Project Classification

- **Project Type:** Mobile App + Desktop App (native iOS capture + native macOS companion)
- **Domain:** Consumer Entertainment & Productivity (Tabletop RPG tooling)
- **Complexity:** Medium — no regulatory concerns; key technical risks are background iOS recording reliability, WhisperX accuracy in multi-speaker tabletop environments, and cross-device transfer UX
- **Project Context:** Greenfield — new product, no existing codebase

## Success Criteria

### User Success

- **Table presence:** DM can tag moments without breaking flow — tagging interaction stays under 2 seconds, no typing, no immersion loss
- **Perfect recall:** Post-session review surfaces all key moments (NPCs, plot hooks, rulings, funny moments) within 15 minutes
- **Prep confidence:** Pre-session prep uses the Dictly archive as the primary reference — no "WTF happened last time" moments when preparing for the next session
- **Transcription quality:** WhisperX produces legible transcriptions of tagged segments in real tabletop conditions (3–6 speakers, crosstalk, dice, background music)

### Business Success

- **Personal validation:** Consistent use across 10+ sessions with the product being the primary session recall tool
- **Prep transformation:** Session prep shifts from memory reconstruction to archive review — measurably less effort, higher confidence
- **Commercial readiness:** MVP is built to App Store distribution standards from day one — ready for one-time purchase sale on iOS and Mac App Store
- **Market signal:** If it works for one DM, the interaction model is validated for broader launch

### Technical Success

- **Recording reliability:** 4+ hour background recording on iOS with screen lock, interruptions, and phone calls — zero data loss
- **Transfer friction:** AirDrop/local network transfer from iPhone to Mac completes without manual file management headaches
- **Transcription accuracy:** WhisperX produces usable (not perfect) transcriptions from tabletop audio — key names, terms, and context are recoverable
- **Search performance:** Full-text search across 10+ sessions returns results

### Measurable Outcomes

| Metric | Target | Timeframe |
|--------|--------|-----------|
| Sessions recorded | 10+ consecutive | 2–3 months |
| Post-session review time | < 15 minutes | Per session |
| Tags per session | 15–40 (validates tagging is natural) | Average |
| "WTF happened" moments during prep | Zero | After session 5+ |
| Recording failures | Zero | Across all sessions |

## User Journeys

### Journey 1: Marcus the DM — First Session with Dictly

**Who:** Marcus, a DM running a weekly homebrew campaign for 5 players. He's been relying on memory and scattered Google Docs notes. He just downloaded Dictly.

**Opening Scene:** It's 30 minutes before session. Marcus opens Dictly on his iPhone for the first time. He creates a campaign ("Ashlands"), glances at the default tag categories (Story, Combat, Roleplay, World, Meta) — they look right. He adds a custom tag "Lore Drop" under Story. Setup takes under 2 minutes.

**Rising Action:** Session starts. Phone is face-up on the table. Marcus hits record and forgets about it — until a player asks a surprising question about a shopkeeper. Marcus taps "NPC Introduction" without breaking eye contact with the player. Under 2 seconds. Two hours in, a player rolls a natural 20 on a persuasion check that derails the plot — Marcus taps "Epic Roll" and "Plot Hook" in quick succession. He tags maybe 25 moments across 4 hours. None of them interrupted his flow.

**Climax:** Session ends. Marcus stops the recording. He glances at the tag list on his phone — 25 tags, color-coded. He already feels calmer about remembering what happened.

**Resolution:** The next day, Marcus opens the Mac app, imports via AirDrop. He sees a timeline with all 25 tags laid out on the waveform. He scrubs through, listens to a few, edits a tag label from "NPC Introduction" to "Grimthor — blacksmith, owes party a favor", adds a note about the derailed plot hook. WhisperX transcribes the tagged segments. 12 minutes total. He exports the session notes as markdown for his prep folder.

### Journey 2: Marcus the DM — Pre-Session Prep (Session 8)

**Opening Scene:** It's the night before session 8. Marcus sits down to prep. He knows the party is returning to a town they visited in session 3, but he can't remember the details.

**Rising Action:** Marcus opens the Mac app and searches "Grimthor". Instantly, three tagged moments surface across sessions 3, 5, and 7 — the introduction, a promise Grimthor made, and a throwaway comment a player made about returning to his shop. Marcus listens to the 30-second clip from session 5 and reads the transcription. He remembers everything.

**Climax:** Marcus browses session 7's tags filtered by "Story" — he spots a subtle hint he tagged about a rival faction. He'd half-forgotten it. Now he weaves it into tonight's session.

**Resolution:** Prep takes 15 minutes. Marcus walks into session 8 referencing details from 5 sessions ago. Players are impressed. No "WTF happened last time" moment.

### Journey 3: Marcus the DM — Post-Session Review

**Opening Scene:** Sunday morning after a Saturday night session. Marcus opens his Mac, AirDrops the recording from his phone. Import completes in seconds.

**Rising Action:** The Mac app shows 30 tags on the timeline. Marcus works through them — he listens to a few where the label isn't enough context, edits tag names to be more descriptive, changes a miscategorized tag from "Combat" to "Roleplay". He spots a gap in the timeline where something funny happened but he forgot to tag — he scrubs to that spot, places a retroactive tag, and labels it.

**Climax:** WhisperX transcribes all tagged segments. Marcus scans the transcriptions — most are legible, a couple have garbled names (expected with fantasy names). He corrects "Grim Thor" to "Grimthor" in the notes.

**Resolution:** 14 minutes. The session is fully documented. Marcus adds a one-line session summary note and moves on with his day.

### Journey 4: Marcus the DM — Recording Interruption Recovery

**Opening Scene:** Two hours into session 6, Marcus gets a phone call. The recording pauses.

**Rising Action:** Marcus declines the call. Dictly shows a clear "Recording Paused" state with a prominent resume button.

**Climax:** Marcus taps resume. Recording continues seamlessly as part of the same session — no new file, no lost context. Tags before and after the interruption appear on the same timeline.

**Resolution:** During post-session review, the interruption shows as a small gap on the timeline. All tags and audio before and after are intact. Zero data lost.

### Journey Requirements Summary

| Journey | Key Capabilities Revealed |
|---------|--------------------------|
| First Session | Onboarding with sensible defaults, campaign creation, custom tag management, one-tap tagging during recording, tag counter/feedback |
| Pre-Session Prep | Full-text search across sessions, cross-session tag browsing, filtered tag views, audio playback of tagged segments, transcription display |
| Post-Session Review | AirDrop import, timeline/waveform view, tag editing (rename, recategorize, delete), retroactive tag placement, WhisperX transcription, manual transcription correction, markdown export |
| Interruption Recovery | Pause/resume recording, phone call handling, session continuity across interruptions, gap visualization on timeline |

## Innovation & Novel Patterns

### Detected Innovation Areas

**Rewind-Anchor Tagging:** The ~10-second rewind tag is a novel interaction pattern. Existing tools either bookmark at the current moment or process everything after the fact. Dictly anchors tags to *before* the tap — matching how human attention actually works (you realize something was important a few seconds after it happens). This is a small UX decision with outsized impact: it means every tag captures the actual moment, not the reaction.

**Human-in-the-Loop Signal Filtering:** The entire TTRPG audio tool market (SessionKeeper, Archivist, Saga20, RollSummary, Scrybe Quill) follows a "record everything, AI processes after" model. Dictly inverts this — the DM identifies what matters in real-time, and the tool captures and organizes only those moments. This produces higher-quality results (the DM has contextual judgment AI lacks), at lower cost (transcribe 30-second clips, not 4 hours), with stronger privacy (no full-session cloud upload).

### Market Context & Competitive Landscape

- 7+ AI-powered TTRPG summarization tools launched 2024–2026, all following the same "dump and process" model
- No competitor offers in-session real-time tagging or bookmarking with category structure
- General-purpose tools (Voice Memos, Otter.ai, Ferrite) have basic bookmarks but lack session structure, categories, and the rewind anchor
- Dictly's differentiation is interaction model, not AI capability — harder to commoditize

### Innovation Validation

- **Rewind duration default:** 10 seconds, configurable 5/10/15/20s — real session usage will validate the right default
- **Tagging naturalness:** Must not break DM flow — validate in real sessions before committing to broader development
- **Archive compounding:** By session 5+, search and browse must surface useful cross-session results

## Mobile App + Desktop App Specific Requirements

### Project-Type Overview

Dictly is a native Apple ecosystem product: iOS app (Swift/SwiftUI) for capture, macOS app (Swift/SwiftUI) for review. Both apps are fully local — no network dependency for core functionality. Distribution via App Store as a one-time purchase. The two apps share a common data model but serve distinct roles with no feature overlap.

### Platform Requirements

| Requirement | iOS App | Mac App |
|-------------|---------|---------|
| Language | Swift | Swift |
| UI Framework | SwiftUI | SwiftUI |
| Minimum OS | TBD (latest - 1 or - 2) | TBD (latest - 1 or - 2) |
| Distribution | App Store | Mac App Store |
| Pricing | One-time purchase | Included (universal purchase) or bundled |
| Network required | No | No |

### Device Permissions & Hardware

**iOS App:**
- **Microphone** — core recording functionality; support built-in mic and external microphones (including DJI Mic, which presents as a standard audio input)
- **Location** (optional) — capture session location for better recall ("we played at Jake's place" vs "the game store"); requested once, stored per-session as metadata, not tracked continuously
- **Background Audio** — AVAudioSession configured for long-form background recording; must survive screen lock, app switching, and phone call interruptions across 4+ hours
- **Haptic feedback** — confirm tag placement with tactile response (UIImpactFeedbackGenerator); reinforces "tag registered" without requiring visual attention

**Mac App:**
- **File system access** — read imported recordings, store session data in app sandbox
- **AirDrop / local network** — receive recordings from iOS app

### Offline & Storage Architecture

- Both apps are fully offline — no cloud dependency, no sync, no accounts
- iOS: recordings stored in app sandbox, AAC 64kbps mono (~115 MB per 4-hour session)
- Mac: imported recordings + transcriptions + session metadata stored locally
- Data transfer: AirDrop or local network (iPhone to Mac)
- No iCloud Drive integration in MVP — explicit import only

### Transfer Mechanism

- Primary: AirDrop (zero-config, fast for ~115 MB files)
- Fallback: local network transfer (Bonjour discovery, direct Wi-Fi)
- Transfer includes: audio file + tag metadata + session metadata as a bundled package
- Mac app handles import, deduplication (re-importing same session), and organization

### WhisperX Integration (Mac Only)

- WhisperX runs locally on Mac — no cloud transcription
- Transcribes only tagged segments (~30 seconds each), not full recordings
- Must handle multi-speaker tabletop audio (3–6 voices, crosstalk, dice, music)
- Transcription is triggered per-tag or batch after import
- User can edit/correct transcriptions manually

### Implementation Considerations

- **Shared data model:** Tag, Session, Campaign structures should be defined once and shared between iOS and Mac targets (Swift package or shared framework)
- **Audio engine:** AVAudioEngine for iOS recording with support for external audio inputs; consider Core Audio for Mac playback with waveform rendering
- **Background recording reliability:** Must be spike-tested early — iOS background audio session configuration, interruption handling, and 4-hour endurance are the #1 platform risk
- **App Store review:** Audio recording apps are standard on iOS; ensure clear microphone usage description and location permission rationale in Info.plist

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach:** Problem-solving MVP — validate that the tagging interaction model fundamentally changes how a DM recalls and preps for sessions. Success is personal: one DM, 10 sessions, zero "WTF happened" moments.

**Resource Requirements:** Solo developer (Swift/SwiftUI). Both apps share a common data model and language, minimizing context switching. No backend, no infrastructure, no ops — the fully local architecture is also a resource strategy.

### MVP Feature Set (Phase 1)

**Core User Journeys Supported:**
- First session setup and recording with tagging
- Post-session review, transcription, and annotation on Mac
- Pre-session prep via search and browse across sessions
- Recording interruption and recovery

**Must-Have Capabilities:**

| Capability | App | Rationale |
|-----------|-----|-----------|
| Audio recording (AAC 64kbps mono, background, pause/resume) | iOS | Core function — no recording, no product |
| One-tap tagging with rewind anchor (~10s) | iOS | Core differentiator — the entire thesis |
| Customizable tag categories (Story, Combat, Roleplay, World, Meta) | iOS | Enables organized review; sensible defaults reduce onboarding friction |
| Haptic feedback on tag | iOS | Confirms tag without visual attention — preserves table presence |
| Campaign/session organization | Both | Structure for multi-session archive |
| AirDrop/local network transfer | Both | Bridge between capture and review — must be low-friction |
| Timeline view with waveform and color-coded tag markers | Mac | Primary review interface |
| Tag editing (rename, recategorize, delete, add retroactive) | Mac | Post-session refinement of raw tags |
| Notes per tag | Mac | Context that audio alone can't capture |
| WhisperX local transcription of tagged segments | Mac | Transforms audio moments into searchable text |
| Full-text search across sessions | Mac | The compounding archive — essential for prep |
| Markdown export | Mac | Bridges Dictly into existing DM workflows (Obsidian, LLMs, wikis) |
| Location metadata per session (optional) | iOS | Low-effort recall aid — "where did we play?" |
| External mic support (DJI Mic) | iOS | Better audio = better transcriptions |

**Distribution:** iOS + Mac App Store, one-time purchase

**Explicitly NOT in MVP:**
- Cloud, accounts, backend, sync
- Web companion
- Multi-device/player tagging
- AI summaries, NLP entity extraction
- Video recording
- Apple Watch
- Push notifications
- Sharing/collaboration

### Post-MVP Roadmap

**Phase 2 (Growth) — Share & Sell:**
- Cloud sync with E2E encrypted Vault (~$5/mo subscription)
- Web companion with audio streaming and party sharing
- Temporary and permanent recap share links
- Obsidian plugin / deeper markdown integration
- Apple Watch quick-tag companion

**Phase 3 (Expansion) — Scale & Differentiate:**
- AI-generated session summaries
- Cross-platform support
- Multi-device recording (players tagging from own phones)
- Campaign management integrations (World Anvil, D&D Beyond, Kanka)
- Community-driven tag category templates
- Actual-play podcast/streaming tools

### Risk Mitigation Strategy

**Technical Risks:**

| Risk | Severity | Mitigation |
|------|----------|-----------|
| iOS background recording fails over 4+ hours | High | Test early in development with real-duration recordings; audio session configuration is well-documented but edge cases exist with phone calls and system interrupts |
| WhisperX accuracy poor on tabletop audio | High | Test with real session recordings as soon as Mac app can import; fallback is manual tag notes (product is still valuable without transcription) |
| AirDrop unreliable for ~115 MB files | Medium | Implement local network transfer as fallback; test with real file sizes early |
| WhisperX integration complexity on Mac | Medium | WhisperX is Python-based; evaluate bundling vs. requiring user install; consider mlx-whisper as a native alternative |
| Rewind duration default feels wrong | Low | Configurable per-session (5/10/15/20s); usage data informs better default |

**Market Risks:**

| Risk | Mitigation |
|------|-----------|
| DMs don't actually tag during sessions (too distracting) | Validate with real sessions immediately; the entire product thesis depends on this being natural. Large tap targets, no confirmation dialogs, haptic feedback reduce friction |
| Tagging model produces low-quality signal (too many/few tags) | Configurable rewind duration and tag categories; iterate on defaults based on real usage |
| One-time purchase doesn't fund post-MVP development | MVP validates the model; subscription Vault tier in Phase 2 provides recurring revenue |
| DM forgets to tag important moments | Archive retains full audio — retroactive tagging during post-session review covers gaps |

**Resource Risks:**

| Risk | Mitigation |
|------|-----------|
| Solo dev bandwidth | Shared Swift/SwiftUI stack minimizes context switching; no backend reduces scope; fully local = no ops burden |
| Scope creep during development | MVP boundaries are hard — everything listed as "not in MVP" stays out until 10 sessions validate the core |

## Functional Requirements

### Recording & Capture

- FR1: DM can create a new recording session within an existing campaign
- FR2: DM can record audio continuously for 4+ hours with the screen locked
- FR3: DM can pause and resume a recording without losing data or creating a new file
- FR4: DM can record using the built-in microphone or an external microphone (e.g., DJI Mic)
- FR5: DM can see a visual indicator that recording is active (timer or waveform)
- FR6: System continues recording through phone calls and system interruptions, resuming automatically or prompting to resume

### Real-Time Tagging

- FR7: DM can place a tag with a single tap during recording
- FR8: Each tag automatically anchors to a configurable time window before the tap (default ~10 seconds; options: 5s/10s/15s/20s)
- FR9: DM can select from a palette of tag categories organized by active category (Story, Combat, Roleplay, World, Meta)
- FR10: DM can create a custom tag with short text input during recording
- FR11: DM receives haptic feedback confirming tag placement
- FR12: DM can see a running count of tags placed during the current session
- FR13: DM can configure which tag categories are active before starting a session

### Tag & Category Management

- FR14: DM can create, rename, and delete custom tag categories
- FR15: DM can create, rename, and delete tags within categories
- FR16: DM can reorder tag categories and tags within the palette
- FR17: System provides a default set of D&D-oriented tag categories and tags on first use

### Campaign & Session Organization

- FR18: DM can create, rename, and delete campaigns
- FR19: DM can set campaign metadata (name, description)
- FR20: Sessions are automatically nested under campaigns with auto-numbering and editable titles
- FR21: DM can view session metadata (date, duration, tag count, title, location)
- FR22: System captures location metadata per session (optional, with user permission)

### Transfer & Import

- FR23: DM can transfer a recording with all metadata from iPhone to Mac via AirDrop
- FR24: DM can transfer a recording with all metadata from iPhone to Mac via local network
- FR25: Transfer includes audio file, tag data, session metadata, and campaign association as a bundled package
- FR26: Mac app detects and handles re-import of an already-imported session (deduplication)

### Post-Session Review & Annotation (Mac)

- FR27: DM can view a timeline with audio waveform and color-coded tag markers
- FR28: DM can click a tag marker to jump audio playback to that moment
- FR29: DM can filter tags by category in the tag sidebar
- FR30: DM can edit a tag's label after the session
- FR31: DM can change a tag's category after the session
- FR32: DM can delete tags after the session
- FR33: DM can place new tags retroactively by scrubbing through the audio
- FR34: DM can add, edit, and delete text notes on individual tags
- FR35: DM can add a session-level summary note
- FR36: DM can scrub through the full audio recording (not just tagged segments)

### Transcription

- FR37: Mac app transcribes tagged audio segments locally using WhisperX
- FR38: DM can trigger transcription per-tag or as a batch for all tags in a session
- FR39: DM can view transcription text alongside each tag
- FR40: DM can edit and correct transcription text manually

### Search & Archive

- FR41: DM can perform full-text search across all transcriptions and tag labels across all sessions in a campaign
- FR42: DM can browse tags filtered by category across all sessions in a campaign
- FR43: Search results link directly to the tagged audio moment for playback
- FR44: DM can browse a chronological session list within a campaign

### Export

- FR45: DM can export transcribed tags and notes from a session as markdown
- FR46: DM can export transcribed tags and notes from multiple sessions or a full campaign as markdown

### Settings & Configuration

- FR47: DM can configure the default rewind duration (5s/10s/15s/20s)
- FR48: DM can configure audio recording quality settings
- FR49: DM can manage storage (view space used, delete old recordings)

## Non-Functional Requirements

### Performance

| Requirement | Target | Context |
|-------------|--------|---------|
| Tag placement response | < 200ms (haptic + visual feedback) | During recording — any perceptible delay breaks the tagging interaction |
| Recording start/stop | < 1 second | Must feel instant when starting a session |
| Audio playback jump (tag click) | < 500ms | Scrubbing through tags during review must feel responsive |
| Waveform rendering | Smooth at 60fps during scrub | Timeline is the primary review interface — stuttering degrades the experience |
| Full-text search across 10+ sessions | < 1 minute | Acceptable range; sub-second is ideal but not required |
| WhisperX transcription | Minutes per segment acceptable | Depends on hardware; batch transcription runs in background |
| AirDrop/local network transfer (~115 MB) | < 2 minutes | Standard AirDrop performance; no custom optimization needed |
| App launch to recording | < 5 seconds | DM should be able to start recording quickly before session begins |

### Data Integrity & Reliability

| Requirement | Target | Context |
|-------------|--------|---------|
| Recording durability | Loss of < 5 seconds of audio on crash | Audio must be flushed to disk frequently; a crash mid-session cannot lose the entire recording |
| Recording endurance | 4+ hours continuous with screen locked | Must survive background state, screen lock, low battery warnings, and brief interruptions |
| Tag data persistence | Zero tag loss | Tags are tiny metadata — written to disk immediately on placement |
| Import integrity | Zero data corruption on transfer | Audio + metadata must arrive intact; verify on import |
| Session data isolation | Corruption in one session cannot affect other sessions | Each session's data is independent |

### Privacy

| Requirement | Target | Context |
|-------------|--------|---------|
| Network access | Zero network calls in MVP | No analytics, no telemetry, no cloud — fully offline |
| Data location | All data remains on user's devices (iPhone + Mac) | Core brand promise: "your sessions never leave your devices" |
| Microphone access | Only during active recording | No background listening; microphone permission released when not recording |
| Location access | Only at session start (if permitted) | Single location capture per session, not continuous tracking |

### Accessibility

| Requirement | Target | Context |
|-------------|--------|---------|
| VoiceOver support | Standard iOS/macOS VoiceOver compatibility | SwiftUI provides baseline accessibility; ensure tag buttons and timeline are navigable |
| Dynamic Type | Support system font size preferences | Standard SwiftUI behavior; ensure tag palette remains usable at larger sizes |
| Color independence | Tag categories distinguishable without color alone | Use labels/icons in addition to color coding for color-blind users |

### Integration

| Requirement | Target | Context |
|-------------|--------|---------|
| WhisperX compatibility | Support current stable WhisperX release | Mac app must bundle or locate WhisperX installation; handle version mismatches gracefully |
| External microphone | Support any Core Audio-compatible input device | DJI Mic and similar devices work without special configuration |
| AirDrop | Standard AirDrop protocol via UTI/file type registration | Mac app registers as handler for Dictly session bundles |
| Markdown export | Standard CommonMark-compatible output | Ensures compatibility with Obsidian, GitHub, and other markdown tools |
