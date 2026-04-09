# Dictly — Data Models

**Generated:** 2026-04-09 | **Scan level:** Deep

---

## Entity-Relationship Overview

```
Campaign (1) ──────────────────────── (0..*) Session
                cascade delete              inverse: campaign

Session  (1) ──────────────────────── (0..*) Tag
                cascade delete              inverse: session

TagCategory  (standalone, no @Relationship)
                linked by soft string match:
                Tag.categoryName == TagCategory.name
```

**Key design decision:** `TagCategory` is intentionally decoupled from `Tag` in the SwiftData graph. There is no `@Relationship` between them. The binding is a soft string match on `categoryName`. This allows `TagCategory` records to be synced independently via iCloud KVS without creating cascading relationship conflicts across devices.

---

## @Model Classes

### Campaign

**File:** `DictlyKit/Sources/DictlyModels/Campaign.swift`

| Property | Type | Default | Notes |
|---|---|---|---|
| `uuid` | `UUID` | `UUID()` | Stable identifier |
| `name` | `String` | — | Required |
| `descriptionText` | `String` | `""` | Campaign description |
| `createdAt` | `Date` | `Date()` | Creation timestamp |
| `sessions` | `[Session]` | `[]` | `@Relationship(deleteRule: .cascade)` |

**Factory methods:** `Campaign.from(_ dto: CampaignDTO)`, `toDTO() -> CampaignDTO`

---

### Session

**File:** `DictlyKit/Sources/DictlyModels/Session.swift`

| Property | Type | Default | Notes |
|---|---|---|---|
| `uuid` | `UUID` | `UUID()` | Stable identifier |
| `title` | `String` | — | Required |
| `sessionNumber` | `Int` | — | Ordinal within campaign |
| `date` | `Date` | `Date()` | Recording date |
| `duration` | `TimeInterval` | `0` | Total duration (seconds) |
| `locationName` | `String?` | `nil` | Optional GPS place name |
| `locationLatitude` | `Double?` | `nil` | Optional latitude |
| `locationLongitude` | `Double?` | `nil` | Optional longitude |
| `summaryNote` | `String?` | `nil` | Free-text summary |
| `audioFilePath` | `String?` | `nil` | Sandbox-relative path to audio |
| `pauseIntervalsJSON` | `String?` | `nil` | JSON-encoded `[PauseInterval]` |
| `tags` | `[Tag]` | `[]` | `@Relationship(deleteRule: .cascade)` |
| `campaign` | `Campaign?` | `nil` | `@Relationship(inverse: \Campaign.sessions)` |

**Computed:** `pauseIntervals: [PauseInterval]` — get/set wrapper over `pauseIntervalsJSON`.

**Factory methods:** `Session.from(_ dto: SessionDTO)`, `toDTO() -> SessionDTO`

---

### Tag

**File:** `DictlyKit/Sources/DictlyModels/Tag.swift`

| Property | Type | Default | Notes |
|---|---|---|---|
| `uuid` | `UUID` | `UUID()` | Stable identifier |
| `label` | `String` | — | Display name |
| `categoryName` | `String` | — | Soft FK to `TagCategory.name` |
| `anchorTime` | `TimeInterval` | — | Seconds from recording start |
| `rewindDuration` | `TimeInterval` | — | Rewind context (seconds) |
| `notes` | `String?` | `nil` | Free-text notes |
| `transcription` | `String?` | `nil` | Whisper-generated text |
| `createdAt` | `Date` | `Date()` | Timestamp |
| `session` | `Session?` | `nil` | `@Relationship(inverse: \Session.tags)` |

**Factory methods:** `Tag.from(_ dto: TagDTO)`, `toDTO() -> TagDTO`

---

### TagCategory

**File:** `DictlyKit/Sources/DictlyModels/TagCategory.swift`

| Property | Type | Default | Notes |
|---|---|---|---|
| `uuid` | `UUID` | `UUID()` | Stable identifier |
| `name` | `String` | — | Category name |
| `colorHex` | `String` | — | Hex color (e.g., `"#D97706"`) |
| `iconName` | `String` | — | SF Symbol name |
| `sortOrder` | `Int` | `0` | Display order |
| `isDefault` | `Bool` | `false` | System-seeded flag |

**No relationships.** Linked to `Tag` only via string match on `categoryName`.

---

## Supporting Types

### PauseInterval

`struct PauseInterval: Codable, Equatable` — stored as JSON in `Session.pauseIntervalsJSON`.

| Property | Type | Notes |
|---|---|---|
| `start` | `TimeInterval` | When pause began |
| `end` | `TimeInterval` | When recording resumed |

### TransferBundle

`struct TransferBundle: Codable` — root envelope for `.dictly` bundle serialisation.

| Property | Type |
|---|---|
| `version` | `Int` (currently `1`) |
| `session` | `SessionDTO` |
| `tags` | `[TagDTO]` |
| `campaign` | `CampaignDTO?` |

### DictlyError

`enum DictlyError: Error, LocalizedError, Equatable` — domain error taxonomy.

| Namespace | Cases |
|---|---|
| `.recording` | `permissionDenied`, `deviceUnavailable`, `interrupted`, `audioSessionSetupFailed`, `engineStartFailed`, `fileCreationFailed`, `diskFull` |
| `.transfer` | `networkUnavailable`, `peerNotFound`, `bundleCorrupted`, `connectionFailed`, `transferInterrupted`, `timeout` |
| `.transcription` | `modelNotFound`, `modelCorrupted`, `processingFailed`, `audioConversionFailed`, `audioFileNotFound`, `downloadFailed` |
| `.storage` | `diskFull`, `permissionDenied`, `fileNotFound`, `syncFailed` |
| `.import` | `invalidFormat`, `duplicateDetected`, `missingData` |
| `.search` | `indexingFailed`, `deletionFailed` |

---

## Schema Configuration

**File:** `DictlyKit/Sources/DictlyModels/DictlySchema.swift`

```swift
public enum DictlySchema {
    public static let all: [any PersistentModel.Type] = [
        Campaign.self, Session.self, Tag.self, TagCategory.self
    ]
}
```

No `VersionedSchema` or `SchemaMigrationPlan` defined. All schema evolution has been additive.

---

## Storage Services

### AudioFileManager

Stateless utility managing audio files in `<ApplicationSupport>/Recordings/`.

| Method | Description |
|---|---|
| `audioStorageDirectory()` | Returns/creates recordings directory |
| `resolvedAudioPath(_:)` | Fixes legacy `.aac` → `.m4a` extension |
| `fileSize(at:)` | File size in bytes |
| `totalAudioStorageSize(sessions:)` | Sum across sessions |
| `deleteAudioFile(at:)` | Delete audio file |
| `formattedSize(_:)` | Human-readable size string |

### SearchIndexer

`@MainActor` class indexing `Tag` objects into CoreSpotlight (`com.dictly.tags` domain). Indexed attributes: title (label), displayName (label + session title), contentDescription (notes or category), textContent (transcription), keywords (category, session, campaign names).

### CategorySyncService

`@MainActor @Observable` class syncing `TagCategory` via iCloud KVS key `"tagCategories"`. Last-write-wins merge with ISO 8601 fractional-second timestamps. Propagates category renames to all matching `Tag.categoryName` records.

### BundleSerializer

Stateless serialiser for `.dictly` bundle directories containing `audio.aac` + `session.json`.

---

## Default Tag Seeder

Seeds 5 default D&D categories on first launch (idempotent):

| Category | Color | Icon | Default Tags |
|---|---|---|---|
| Story | Amber | `book.pages` | Plot Hook, Lore Drop, Quest Update, Foreshadowing, Revelation |
| Combat | Red | `shield` | Initiative, Epic Roll, Critical Hit, Encounter Start, Encounter End |
| Roleplay | Violet | `theatermasks` | Character Moment, NPC Introduction, Memorable Quote, In-Character Speech, Emotional Beat |
| World | Green | `globe` | Location, Item, Lore, Map Note, Environment Description |
| Meta | Blue | `info.circle` | Ruling, House Rule, Schedule, Break, Player Note |

**UUID strategy:** Deterministic UUIDs via FNV-1a-style hash from name strings to prevent duplicates across iCloud-synced devices.
