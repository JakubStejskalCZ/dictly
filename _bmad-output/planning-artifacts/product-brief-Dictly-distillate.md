---
title: "Product Brief Distillate: Dictly"
type: llm-distillate
source: "product-brief-Dictly.md"
created: "2026-03-31"
purpose: "Token-efficient context for downstream PRD creation"
---

# Product Brief Distillate: Dictly

## Scope Signals — MVP Boundaries

- MVP is iOS recorder + Mac companion, fully local, no cloud/backend/auth
- Mac app uses WhisperX (local) for transcription — not Apple Speech framework
- Transfer from iPhone to Mac via AirDrop or local network (not iCloud Drive)
- MVP scoped to in-person sessions only; online/hybrid is explicitly out
- Single DM phone recording only — no multi-device/player tagging in MVP
- "Searchable archive" not "knowledge base" — no NLP entity extraction, no auto-linking NPCs/locations
- Users export transcribed markdown and take it to LLMs or Obsidian for further processing
- Audio-only — no video recording
- No collaborative annotation in MVP
- Campaign limit: undefined for MVP (personal use), needs decision for public launch

## Technical Context

- iOS recording: AVAudioRecorder/AVAudioEngine, AAC 64kbps mono (~115 MB per 4-hour session)
- Background recording requires careful iOS Audio Session configuration — validate 4-hour reliability with screen lock and interruptions early
- Rewind tag default: ~10 seconds before tap (configurable: 5s/10s/15s/20s) — the exact default needs validation through use
- Tag palette UX: large tappable buttons, organized by active category, single-tap placement, under 2 seconds interaction, no confirmation dialog
- Mac app: timeline view with color-coded tag markers, waveform display, tag sidebar, notes panel
- WhisperX accuracy in TTRPG environments (3–6 speakers, crosstalk, dice rolling, background music) is the #1 technical risk — spike test with real session audio before committing
- Storage: app sandbox + potential iCloud Drive integration for backup
- Auth strategy (post-MVP): Apple Sign-In primary, email/password fallback
- Backend (post-MVP): lightweight REST API, PostgreSQL for metadata, S3-compatible object storage
- E2E encryption (post-MVP Vault): AES-256-GCM, keys in iOS Keychain + iCloud Keychain

## Competitive Intelligence

- **SessionKeeper** ($3.99–$24.99/mo): AI session summaries, campaign wiki. No real-time tagging or bookmarking. Closest competitor but different interaction model.
- **Archivist** (~$60/mo): Premium AI transcription/summary. Expensive. No tagging.
- **Saga20, RollSummary, Scrybe Quill, CharGen**: Various AI summarizers processing full audio post-session. None offer in-session interaction.
- **World Anvil, QuestPad, Critical Notes, RPG Notebook**: Campaign management/wiki tools with no audio integration.
- **General-purpose tools** (Voice Memos, Otter.ai, Ferrite): Basic bookmarking exists but lacks session structure, tag categories, and the rewind-anchor behavior.
- All TTRPG competitors follow "record everything, process after" — Dictly's real-time tagging is genuinely differentiated.
- Dictly's $5/mo target (post-MVP) is below SessionKeeper Hero ($10) and far below Archivist ($60).

## Market Data

- TTRPG market: $3–13B+ globally, growing steadily
- D&D Beyond: 13M+ registered users
- AI summarization space is crowding (7+ tools launched 2024–2026) — UX differentiation matters more than AI capability
- Actual TAM is narrower than total TTRPG market: DMs running in-person sessions who own iPhone + Mac — bottom-up estimate needed for commercial planning

## User & Monetization Details

- Primary user: DM/GM running in-person sessions, weekly or biweekly, 3–6 players
- Players are 5:1 majority — natural viral loop (1 DM shows Dictly to 3–6 players per session)
- Free tier (post-MVP): unlimited recording/tagging, local storage, metadata sync, temporary recap links (30-day expiry)
- Premium "Vault" (~$5/mo): E2E encrypted cloud backup, full audio streaming on web, permanent share links, AI features
- Unit economics: free users cost near-zero (metadata only, ~25 GB for 10K users x 50 sessions). Premium heavy user at 10 GB costs ~$0.20/mo — healthy margins at $5/mo
- Cost scales with revenue, not free user count

## Rejected Ideas (do not re-propose)

- Web app for MVP — explicitly deferred to post-MVP
- Cloud/backend for MVP — fully local architecture chosen deliberately
- Multi-device recording in MVP — single DM phone is the right scope
- Video recording — audio-only is the right focus
- Real-time collaboration during sessions — not in scope
- Heavy audio editing in companion app — not in scope
- NLP-based auto-linking of entities — users handle this via markdown export + LLM

## Open Questions (unresolved)

- Ideal default rewind duration: 10s feels right but configurable per-tag or only globally?
- How to handle very long campaigns (100+ sessions) — archive/search UX considerations
- Free tier campaign limit for public launch (unlimited? 3? 5?)
- Export formats for recaps: just MP3, or also transcripts, markdown, PDF?
- Should the rewind window be visualized/adjustable per-tag after the fact?
- Collaborative annotation (multiple party members editing notes) — post-MVP scope but needs design thinking

## Growth & Partnership Opportunities

- DM-to-player viral loop is the primary organic growth mechanism
- Obsidian integration (markdown export / plugin) — large overlapping TTRPG user base
- Campaign management platform integrations (World Anvil, Kanka, D&D Beyond)
- Actual-play podcast/streaming community — high-willingness-to-pay segment, natural distribution channel
- Apple Watch quick-tag — zero-footprint table presence, press-worthy differentiator
- Community-driven tag category templates (e.g., "Critical Role template", "one-shot template")

## Positioning Notes

- Frame as "campaign memory" not "voice recorder" — memory implies relationship, recorder implies utility
- Privacy-first is a primary brand pillar: "your sessions never leave your devices"
- Emotional angle: Dictly lets DMs be fully present at the table — reduces cognitive load and post-session guilt about lost moments
- The compounding archive is the retention story: after 10 sessions it's useful, after 50 it's irreplaceable
