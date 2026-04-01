---
title: "Product Brief: Dictly"
status: "complete"
created: "2026-03-31"
updated: "2026-03-31"
inputs:
  - docs/session-recorder-spec.md
---

# Product Brief: Dictly

## Executive Summary

Tabletop RPG sessions run 3–5+ hours. Critical details — NPC names, plot hooks, rulings, lore drops, hilarious moments — surface constantly, and nobody remembers them all. Writing notes during play breaks immersion. Recording the whole session produces a massive audio file nobody will re-listen to.

**Dictly** is your campaign's long-term memory. An iOS voice recorder paired with a Mac companion app, it solves this with one simple interaction: **tap to tag a moment**. Each tag anchors to ~10 seconds *before* the tap — because you always realize something was important a few seconds after it happened. After the session, import the recording to your Mac, where tagged moments are transcribed locally and organized into a searchable session archive. No cloud. No subscriptions. Your recordings never leave your devices.

The long-term vision is a full product with a web companion, cloud sync, sharing, and AI features — but the MVP is built for one user: a DM who wants to stop losing the best parts of their sessions.

## The Problem

A typical in-person D&D session generates dozens of important moments: a new NPC name, a key plot revelation, a house ruling, a quote the table will reference for months. Today, DMs cope in three ways — all bad:

1. **Manual notes during play** — breaks immersion, splits attention from running the game, and the DM is already juggling narrative, rules, and 3–6 players
2. **Full session recordings** — 4-hour audio files nobody will scrub through; the moments are buried in hours of crosstalk
3. **Memory alone** — details fade within days; by next session, half the nuance is gone

The result: lost continuity, repeated questions ("wait, what was that NPC's name?"), and DMs spending prep time reconstructing what happened instead of planning what's next.

## The Solution

Dictly is two apps working together:

**iOS App (Capture):** Place your phone on the table, hit record, and play. When something important happens, tap a tag button — one tap, under 2 seconds, no typing. Tags are organized by customizable categories (Story, Combat, Roleplay, World, Meta) so you can filter later. The tag anchors to ~10 seconds before your tap, capturing the actual moment, not the moment you reacted.

**Mac App (Review):** After the session, import the recording with all its metadata. The Mac app transcribes tagged segments using WhisperX running locally — no cloud processing, no data leaving the machine. Browse a timeline with color-coded tag markers, read transcriptions, add notes, and search across sessions. Over time, tagged and transcribed moments accumulate into a searchable session archive across your campaign. Transcriptions export as markdown — take them into Obsidian, feed them to an LLM, or build your own campaign wiki from real session data.

## What Makes This Different

**The ~10-second rewind tag is the core insight.** No TTRPG-specific tool offers real-time micro-bookmarking during play. Competitors (SessionKeeper ~$4–25/mo, Archivist ~$60/mo, Saga20, RollSummary) all follow a "record everything, process after" model — dump hours of audio into an AI and hope it finds the important parts. General-purpose audio tools (Voice Memos, Otter.ai) have basic bookmarking but lack session structure, tag categories, and the rewind-anchor behavior.

Dictly inverts the model: the *human* identifies what matters in real-time, and the tool captures and organizes those moments. This is faster, cheaper, more accurate, and more private than full-session AI transcription. The DM knows what's important; the AI just needs to transcribe 30-second clips, not 4 hours.

**Fully local and private.** In a market where every competitor sends your audio to a cloud server, Dictly keeps recordings on your devices. For a product that records private group conversations in people's homes, "your sessions never leave your devices" is a meaningful trust advantage — and it eliminates the #1 objection before it's raised.

## Who This Serves

**Primary: The Dungeon Master / Game Master** who runs in-person sessions. They place the phone on the table, tap tags during play, and review recordings after. A typical DM runs weekly or biweekly sessions with 3–6 players and juggles world-building, improv, rules, and narrative continuity simultaneously. They're the user who feels the pain most acutely and benefits most from organized session memory.

**Secondary (post-MVP): Players.** Consume shared recaps, browse the session archive, add their own annotations. Players benefit from the DM's tagging without doing anything during play — and every player who sees Dictly at the table is a potential future DM user.

## Success Criteria

This is a personal-use MVP. Success is concrete:

- **Consistent use:** Dictly is used in every session over a 2-month period (minimum 8 sessions)
- **Faster review:** Post-session review takes under 15 minutes, down from scrubbing raw audio or reconstructing from memory
- **Useful transcriptions:** WhisperX produces legible transcriptions of tagged segments, despite multi-speaker table audio (key validation risk — see Scope)
- **Searchable history:** By session 5+, searching a name or term surfaces relevant moments across past sessions

If the product proves its value for one DM, it validates the core interaction model for a broader launch.

## Scope

**MVP (v1) — in-person sessions, single DM, iOS + Mac:**
- iOS app: recording, real-time tagging with customizable categories, pause/resume, background recording, local storage
- Mac companion app: import recordings with metadata, timeline view with tag markers, WhisperX transcription of tagged segments, session/campaign organization, full-text search across transcribed tags
- Transfer mechanism: AirDrop or local network
- No cloud backend, no accounts, no subscription

**Key technical risks to validate early:**
- Audio quality: TTRPG environments (crosstalk, dice, music) may degrade WhisperX accuracy — test with real session audio before committing to the transcription pipeline
- Background recording: iOS has strict rules around background audio sessions — validate 4-hour recording reliability with screen lock, interruptions, and phone calls
- Transfer UX: AirDrop or local network transfer from iPhone to Mac must be low-friction or post-session review won't happen

**Explicitly NOT in MVP:**
- Web companion, cloud sync, sharing
- Multi-device recording (players tagging from their own phones)
- Automatic entity extraction or NLP-based knowledge base linking (users can take markdown exports to LLMs for this)
- AI-generated summaries
- Video recording
- Online/hybrid session support

**Post-MVP roadmap:**
- Web companion with audio streaming and party sharing
- Cloud sync with E2E encrypted "Vault" premium tier (~$5/mo)
- AI-generated session summaries
- Apple Watch quick-tag companion
- Export to markdown/Obsidian
- Obsidian plugin for DMs already using that workflow

## Vision

If Dictly works for one DM, it works for every DM. The path from personal tool to product:

1. **MVP** — Solve it for yourself. iOS + Mac, fully local.
2. **Share** — Add cloud sync, sharing, and a web companion. Let DMs share tagged recaps with their party. Every shared recap is a referral — 1 DM reaches 3–6 players every session.
3. **Scale** — Freemium model with Vault premium tier. Free users cost near-zero (metadata only). Premium users fund their own storage at healthy margins ($0.20/mo cost vs $5/mo revenue).
4. **Expand** — AI transcription and summaries, integrations with campaign tools (World Anvil, D&D Beyond, Obsidian), cross-platform support.

The moat deepens with every session: after 10 sessions, your searchable campaign archive is genuinely useful. After 50 sessions, it's irreplaceable. The longer you use Dictly, the harder it is to leave — and the more valuable the premium tier becomes for protecting that history.
