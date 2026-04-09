# Dictly — Component Inventory

**Generated:** 2026-04-09 | **Scan level:** Deep

---

## Summary

| Part | Public Views | Private Views | Total |
|------|-------------|---------------|-------|
| DictlyiOS | 18 | 17 | 35 |
| DictlyMac | 15 | 13 | 28 |
| DictlyTheme (shared) | 0 (token enums) | 0 | 4 files |

---

## DictlyiOS Components

### App Layer

| View | Category | Description |
|------|----------|-------------|
| `DictlyiOSApp` | Navigation | App entry point; ModelContainer setup, service injection |
| `ContentView` | Navigation | Root NavigationStack pushing CampaignListScreen |

### Campaign Management

| View | Category | Description |
|------|----------|-------------|
| `CampaignListScreen` | Navigation | Full-screen campaign list with empty state, create/delete |
| `CampaignDetailScreen` | Navigation | Campaign-scoped session list with toolbar actions |
| `CampaignFormSheet` | Form | Create/edit campaign name and description |
| `SessionFormSheet` | Form | Create/edit session title, date, notes |
| `SessionListRow` | Display | Session row: title, date, duration, tag count, location |

### Recording

| View | Category | Description |
|------|----------|-------------|
| `RecordingScreen` | Layout | Full-screen modal: status bar, waveform, tag palette, controls |
| `RecordingStatusBar` | Display | Animated REC/PAUSED indicator, elapsed timer, tag count badge |
| `LiveWaveform` | Display | Real-time horizontal bar-chart waveform (~15 fps) |
| `SessionSummarySheet` | Display | Post-recording summary: duration, tag count, category-grouped tags |

### Tagging

| View | Category | Description |
|------|----------|-------------|
| `TagPalette` | Layout | Category tabs + tag grid during recording |
| `CategoryTabBar` | Navigation | Scrollable category filter pills with tag-count badges |
| `TagCard` | Display | Tappable tag with color stripe, scale pulse + haptic |
| `CustomTagSheet` | Form | Free-form custom tag creation during recording |
| `TagCategoryListScreen` | Navigation | Category list with reorder, edit, delete |
| `TagCategoryFormSheet` | Form | Category editor: name, color palette, icon picker |
| `TagListScreen` | Navigation | Template tags within a category |
| `TagFormSheet` | Form | Create/edit template tag label |

### Settings

| View | Category | Description |
|------|----------|-------------|
| `SettingsScreen` | Form | Rewind duration, audio quality, storage summary |
| `StorageManagementView` | Display | Per-session audio storage list with delete controls |

### Transfer

| View | Category | Description |
|------|----------|-------------|
| `TransferPrompt` | Layout | Post-session AirDrop/Wi-Fi send with session summary |
| `ActivityViewControllerRepresentable` | Utility | UIActivityViewController bridge for share sheet |

---

## DictlyMac Components

### App Layer

| View | Category | Description |
|------|----------|-------------|
| `DictlyMacApp` | Navigation | App entry: WindowGroup, Settings scene, service injection |
| `ContentView` | Layout | Three-panel HSplitView: campaign sidebar + session review |

### Review (Core Mac Experience)

| View | Category | Description |
|------|----------|-------------|
| `SessionReviewScreen` | Layout | Three-panel review: tag sidebar, waveform, tag detail |
| `TagSidebar` | Navigation | Scrollable tag list with search, category filters, cross-session toggle |
| `TagSidebarRow` | Display | Tag row: category dot, label, timestamp, VoiceOver support |
| `TagDetailPanel` | Display | Tag detail: label, timestamps, category, transcription, notes editing |
| `SessionWaveformTimeline` | Display | Four-layer waveform with tag markers, draggable playhead, tooltips |
| `TagMarkerShapeView` | Display | Category-specific marker shapes (circle, diamond, square, triangle, hexagon) |
| `NewTagForm` | Form | Retroactive tag creation at waveform position |
| `RelatedTagsView` | Display | Cross-session related tags via SearchService |

### Import / Export

| View | Category | Description |
|------|----------|-------------|
| `ImportProgressView` | Display | Top-of-window import state banner with progress/success/failure |
| `ExportSheet` | Form | Session export format options |

### Search

| View | Category | Description |
|------|----------|-------------|
| `SearchResultsView` | Display | Cross-session search results list |
| `SearchResultRow` | Display | Search result: category dot, tag label, session, transcription snippet |

### Settings / Transcription

| View | Category | Description |
|------|----------|-------------|
| `PreferencesWindow` | Navigation | Tab-view preferences: Storage + Transcription tabs |
| `ModelManagementView` | Display | Whisper model list with download/delete and progress |

### Campaigns

| View | Category | Description |
|------|----------|-------------|
| `SessionNotesView` | Form | Session summary note editor (auto-saves on dismiss) |

---

## DictlyTheme (Shared Design System)

| File | Token Type | Description |
|------|-----------|-------------|
| `Colors.swift` | `DictlyColors` enum | Semantic colors: background, surface, text, accent, destructive (adaptive light/dark) |
| `Typography.swift` | `DictlyTypography` enum | Type scale: display, title, body, caption, tag label (platform-conditional) |
| `Spacing.swift` | `DictlySpacing` enum | 8-point grid: xs(4), sm(8), md(16), lg(24), xl(48) |
| `Animation.swift` | `DictlyAnimation` enum | Animation curves with reduce-motion overloads |
