# Session Recorder — Product Specification (Draft v0.1)

## 1. Vision & Problem Statement

### The Problem

Tabletop RPG sessions (D&D, Pathfinder, etc.) run 3–5+ hours. Critical information surfaces constantly — NPC names, plot hooks, rulings, lore drops, hilarious moments — and nobody remembers it all. Writing notes during play breaks immersion. Recording the whole session produces a massive audio file nobody will re-listen to.

### The Solution

An iOS voice recorder that lets players **tag important moments in real-time with a single tap**, then review, share, and search those moments later via a web companion. Think "bookmarks for session audio."

### Core Insight

The **~10-second rewind tag** is the killer feature. When you tap a tag, it anchors to ~10 seconds *before* the tap — because humans always realize something was important a few seconds after it happened. This respects how attention actually works during live play.

---

## 2. Target Users

### Primary: The DM / Game Master

- Runs the session and has the most to track
- Places the phone on the table, taps tags during play
- Reviews and annotates after the session
- Shares recaps with the party

### Secondary: Players

- Consume shared recaps and session recordings
- Browse the campaign knowledge base
- Optionally add their own notes/annotations post-session

---

## 3. Platform Overview

| Platform | Role | Description |
|----------|------|-------------|
| iOS App | Capture | Voice recording, real-time tagging, local storage |
| Web App (Desktop) | Review & Share | Session player, campaign knowledge base, recap builder, sharing |

---

## 4. iOS App — Features & UX

### 4.1 Recording

- High-quality voice recording (AAC 64kbps mono; ~115 MB per 4-hour session)
- Background recording support (screen can lock)
- Visual recording indicator (waveform or timer)
- Pause/resume capability

### 4.2 Quick-Tag System

#### Pre-Session Setup

Before recording, the user selects which **tag categories** are active for this session. This keeps the tag palette relevant and uncluttered.

#### Default Tag Categories (D&D Presets)

| Category | Example Tags |
|----------|-------------|
| **Story** | Plot hook, Lore drop, Quest update, NPC introduction |
| **Combat** | Epic roll, TPK moment, New enemy, Tactical note |
| **Roleplay** | Funny moment, Character development, Memorable quote |
| **World** | Location name, Map detail, Rule clarification, Item/loot |
| **Meta** | Session recap, DM ruling, House rule, Schedule talk |

Users can create custom categories and tags, rename defaults, or disable categories entirely.

#### Tagging UX During Recording

- The recording screen shows a **tag palette** — large, tappable buttons organized by active category (tabs or collapsible sections)
- **Single tap** places a tag instantly; no confirmation dialog, no typing required
- **"+" button** allows a quick custom tag (short text input, keyboard auto-dismisses)
- Each tag anchors to **~10 seconds before the tap** (configurable: 5s / 10s / 15s / 20s)
- The entire tagging interaction should take **under 2 seconds**
- Visual feedback: brief animation or highlight confirming tag placement
- Tag counter visible so user knows tags are accumulating

### 4.3 Post-Session Annotation

After stopping a recording:

- Timeline view with tag markers (color-coded by category)
- Tap a tag to edit its label, change its category, or add a text note
- Scrub through audio and place additional tags retroactively
- Delete or merge tags

### 4.4 Campaign & Session Organization

- **Campaigns** as top-level containers (e.g., "Curse of Strahd", "Homebrew: Ashlands")
- **Sessions** nested under campaigns, auto-numbered, with editable titles
- Campaign metadata: name, description, player names, color/icon
- Session metadata: date, duration, tag count, title

---

## 5. Web App (Desktop Companion) — Features & UX

### 5.1 Campaign Dashboard

- Home screen showing all campaigns as cards
- Each card shows: campaign name, color/artwork, session count, last played date
- Click into a campaign to see chronological session list

### 5.2 Session Player

The core screen of the web app. Three main areas:

1. **Audio waveform + timeline** (top) — with colored tag markers visible on it, color-coded by category. Visual density shows where the action was at a glance.
2. **Tag sidebar** (left) — filterable, scrollable list of all tags from the session. Click a tag to jump audio to that moment. Filter by category.
3. **Detail/notes panel** (right) — shows selected tag's label, timestamp, category, and an editable notes field for adding context post-session.

### 5.3 Campaign Knowledge Base

Aggregates tags across all sessions into a searchable index:

- **Search** — e.g., search "Grimthor" to find every session where that NPC was tagged, with direct audio links
- **Browse by category** — all lore drops across the campaign, all combat encounters, all locations
- Effectively builds a **campaign wiki for free**, just from tagging during play

### 5.4 Recap Builder

- Select a session (or range of sessions)
- The app stitches together tagged audio segments into a single recap track
- Configurable filters: include all tags, or only specific categories (e.g., Story + Roleplay, skip Meta)
- Reorder or remove segments before exporting
- Output: playable in-browser, downloadable MP3, or shareable link

### 5.5 UX Principles

- **Speed of navigation** — sessions may have 80+ tags; filtering and jumping must feel instant
- **Waveform is the anchor** — everything references back to the audio timeline
- **No forced linear listening** — every interaction is about jumping to moments, not replaying hours
- **Mobile-responsive** — players will open this on phones mid-week to look something up

### 5.6 What the Web App Does NOT Do

- No recording (that's the iOS app's job)
- No real-time collaboration during a session
- No heavy audio editing (trimming, effects, etc.)

---

## 6. Storage Architecture — Hybrid Model (Local-First, Cloud-Optional)

### 6.1 Design Philosophy

Audio files are expensive to store and contain sensitive/private conversations. The architecture is **local-first by default** with cloud features reserved for sharing and premium users.

### 6.2 What Lives Where

| Data | Location | Size |
|------|----------|------|
| Audio recordings | User's device + iCloud Drive (user's own storage) | ~115 MB per 4-hr session |
| Tags, notes, metadata | App server (your backend) | ~10–50 KB per session |
| Shared recap clips | Temporary cloud storage (your backend) | ~28 MB per 15-min recap |
| Vault audio (premium) | E2E encrypted cloud storage (your backend) | ~115 MB per session |

### 6.3 Free Tier — Local-First

- Audio files live **only on the user's iPhone and their iCloud Drive**
- Your server stores **only metadata**: tags, timestamps, session names, campaign structure, notes
- The web companion shows tag lists, notes, and the knowledge base — but **cannot stream audio** (metadata only)
- **Sharing** is available via **temporary recap links**: the app uploads only the tagged audio segments (not the full recording) to a temporary cloud bucket. Links auto-expire (configurable: 7 / 14 / 30 days)

**Server cost for free users: near zero** (~25 GB total for 10,000 users × 50 sessions each)

### 6.4 Premium Tier — "Vault"

- Full audio uploaded to cloud, **end-to-end encrypted** (encrypted on-device before upload; server cannot access content)
- Encryption keys stored on user's device + iCloud Keychain for recovery
- Enables **full audio streaming** in the web companion
- **Permanent share links** (don't expire)
- Longer retention on shared content
- Future: AI transcription of tagged segments, AI-generated session summaries

### 6.5 Encryption Details

- Audio encrypted on-device using a per-campaign key before upload
- Server stores opaque encrypted blobs — **you have zero access to audio content**
- Sharing: when a DM shares with party members, a decryption key is transmitted alongside the link (via a key-exchange mechanism, not stored on server)
- Key recovery via iCloud Keychain — if the user loses their device, keys are recoverable through Apple's infrastructure, not yours
- **Privacy guarantee**: "We literally cannot listen to your recordings" — a strong, honest privacy story

### 6.6 Sync Behavior

- Tags/metadata sync immediately after session ends (tiny payload)
- Audio upload happens over WiFi only by default (large files)
- Upload progress visible on phone so DM knows sync status
- Tags appear in web app immediately, even while audio is still uploading (or unavailable for free users)

### 6.7 Data Loss Considerations

- **Free users**: if phone is lost without iCloud backup, audio is gone. Metadata (tags, notes, campaign structure) survives on your server — this is the most *valuable* data even without audio
- **Premium users**: audio is backed up to encrypted cloud, fully recoverable

---

## 7. Monetization

### Free Tier

- Unlimited recording and tagging
- Local audio storage (device + iCloud)
- Metadata sync to web companion (tags, notes, knowledge base — no audio streaming)
- Temporary recap sharing links (auto-expire after 30 days)
- Up to N campaigns

### Premium Tier ("Vault") — ~$5/month (TBD)

- E2E encrypted cloud audio backup
- Full audio streaming in web companion
- Permanent share links
- Extended/unlimited campaign slots
- Future premium features: AI transcription of tagged segments, AI session summaries, Apple Watch quick-tag companion

### Cost Structure

- Free users cost almost nothing (metadata only)
- Premium users fund their own storage costs directly
- At $0.02/GB/month storage cost, a heavy user with 10 GB costs ~$0.20/month → healthy margins at $5/month
- **Cost scales with revenue, not with free user count** — sustainable unit economics

---

## 8. D&D-Specific Feature Ideas (Backlog)

| Feature | Priority | Description |
|---------|----------|-------------|
| NPC/Location index | Medium | Tags auto-build a searchable index across sessions |
| Session summary view | Medium | Chronological list of tagged moments as "cliff notes" |
| Recap mode | High | Plays only tagged segments back-to-back |
| Party sharing | High | Share campaign access with party members |
| AI transcription (tagged segments only) | Low (premium) | Transcribe only tagged clips, not full sessions — saves cost |
| AI session summaries | Low (premium) | Generate narrative summaries from tagged moments |
| Apple Watch quick-tag | Low | Tap your wrist under the table to place a tag |
| Home screen widget | Low | Quick-start recording with last-used campaign |
| Export to markdown/Obsidian | Medium | Export knowledge base as markdown for Obsidian/Notion users |

---

## 9. Information Architecture

```
iOS App
├── Campaigns
│   ├── [Campaign Name]
│   │   ├── New Session (→ tag category picker → recording screen)
│   │   ├── Session History
│   │   │   └── [Session] → post-session annotation view
│   │   └── Campaign Settings (tags, categories, players)
│   └── Create Campaign
└── Settings (audio quality, rewind duration, sync preferences)

Web App
├── Home / Campaign Dashboard
├── [Campaign]
│   ├── Session List
│   │   └── [Session] → Session Player (waveform + tags + notes)
│   ├── Knowledge Base (cross-session search & browse)
│   └── Recap Builder
└── Settings / Account
```

---

## 10. Technical Considerations (High-Level)

| Concern | Approach |
|---------|----------|
| iOS recording | AVAudioRecorder / AVAudioEngine, AAC 64kbps mono |
| Local storage | Files app / app sandbox + iCloud Drive integration |
| Metadata backend | Lightweight REST API (e.g., Node/Express or similar) |
| Database | PostgreSQL for metadata (tags, campaigns, sessions, users) |
| Temporary file hosting | S3-compatible object storage with lifecycle expiration policies |
| E2E encryption | AES-256-GCM, keys in iOS Keychain + iCloud Keychain |
| Web app | SPA (React or similar), responsive design |
| Audio streaming (premium) | Presigned URLs to encrypted blobs, client-side decryption |
| Auth | Apple Sign-In (primary), email/password as fallback |

---

## 11. Open Questions

- What is the ideal default rewind duration? 10 seconds feels right, but should it be configurable per-tag or globally?
- Should players be able to tag during a session from their own phones (multi-device recording)? Or is single-DM-phone the right MVP scope?
- Is there value in supporting video recording (e.g., filming the table/map) or is audio-only the right focus?
- How to handle very long campaigns (100+ sessions)? Archive/search UX considerations.
- Should the web app support collaborative annotation (multiple party members editing notes on the same session)?
- What's the right free tier limit on campaigns? Unlimited? 3? 5?
- Export formats: just MP3 for recaps, or also transcripts, markdown, PDF?

---

*This is a first-draft specification intended for use as a starting point with the BMAD method in Claude Code. All features, priorities, and technical decisions are subject to refinement.*
