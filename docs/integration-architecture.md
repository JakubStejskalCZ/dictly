# Dictly — Integration Architecture

**Generated:** 2026-04-09 | **Scan level:** Deep

---

## Overview

Dictly is a two-app system where sessions flow from iOS (capture) to Mac (review). Cross-platform communication uses two mechanisms: direct file transfer and iCloud key-value sync.

```
DictlyiOS ────────────────────────────────────> DictlyMac
          AirDrop / Bonjour TCP                 Import + Review
          (.dictly bundle)

DictlyiOS <───────────────────────────────────> DictlyMac
          iCloud KVS (bidirectional)            TagCategory sync
          (com.dictly.shared)
```

---

## Session Transfer: iOS → Mac

### Transfer Methods

| Method | Protocol | Discovery | Transport |
|--------|----------|-----------|-----------|
| **AirDrop** | Apple proprietary | Proximity-based | `UIActivityViewController` (iOS) → `.onOpenURL` handler (Mac) |
| **Bonjour TCP** | `_dictly._tcp` | `NWBrowser` (iOS) / `NWListener` (Mac) | Direct TCP with 4-byte length framing |

### Transfer Bundle Format

The `.dictly` bundle is a directory (declared as `com.dictly.dictly-bundle` UTI, conforms to `com.apple.package`) containing exactly two files:

| File | Content | Format |
|------|---------|--------|
| `audio.aac` | Session audio recording | M4A container, AAC 64 kbps mono |
| `session.json` | Session metadata | JSON-encoded `TransferBundle` |

### TransferBundle Schema

```json
{
  "version": 1,
  "session": {
    "uuid": "...",
    "title": "Session 3",
    "sessionNumber": 3,
    "date": "2026-04-09T19:30:00Z",
    "duration": 7200.0,
    "locationName": "Game Store",
    "summaryNote": null,
    "audioFilePath": null,
    "pauseIntervals": [{"start": 3600.0, "end": 3900.0}]
  },
  "tags": [
    {
      "uuid": "...",
      "label": "Plot Hook",
      "categoryName": "Story",
      "anchorTime": 1234.5,
      "rewindDuration": 10.0,
      "notes": null,
      "transcription": null,
      "createdAt": "2026-04-09T19:50:00Z"
    }
  ],
  "campaign": {
    "uuid": "...",
    "name": "Curse of Strahd",
    "descriptionText": "Gothic horror campaign",
    "createdAt": "2026-03-01T12:00:00Z"
  }
}
```

### AirDrop Flow

1. **iOS:** `TransferService` calls `BundleSerializer.serialize()` → creates `.dictly` bundle in temp directory.
2. **iOS:** `UIActivityViewController` presents the share sheet with the bundle URL.
3. **Mac:** macOS registers as handler for `com.dictly.dictly-bundle` via `CFBundleDocumentTypes` in Info.plist.
4. **Mac:** `DictlyMacApp.onOpenURL` fires → routes to `ImportService.importBundle(from:context:)`.
5. **Mac:** `ImportService` calls `BundleSerializer.deserialize()` → creates SwiftData entities → copies audio to `<ApplicationSupport>/Recordings/`.

### Bonjour TCP Flow

1. **Mac:** `LocalNetworkReceiver` starts `NWListener` on `_dictly._tcp` Bonjour service.
2. **iOS:** `LocalNetworkSender` uses `NWBrowser` to discover the Mac on the local network.
3. **iOS:** User selects the Mac → `LocalNetworkSender` establishes TCP connection.
4. **iOS:** Sends the `.dictly` bundle data with a 4-byte big-endian length prefix.
5. **Mac:** `LocalNetworkReceiver` reads the length prefix, then the full payload.
6. **Mac:** Writes received data to a temp URL → sets `receivedBundleURL`.
7. **Mac:** `DictlyMacApp.onChange(of: networkReceiver.receivedBundleURL)` triggers `ImportService.importBundle()`.
8. **Mac:** After import completes, `networkReceiver.reset()` is called.

### Import Deduplication

`ImportService` checks for existing sessions by UUID before inserting. If a session with the same UUID already exists, the import is flagged as `.duplicateDetected` and the user is notified via `ImportProgressView`.

---

## iCloud KVS Sync: TagCategory

### Architecture

Both apps use `CategorySyncService` (in DictlyKit/DictlyStorage) to sync `TagCategory` metadata via `NSUbiquitousKeyValueStore`.

| Attribute | Value |
|-----------|-------|
| **KVS Key** | `"tagCategories"` |
| **Store Identifier** | `$(TeamIdentifierPrefix)com.dictly.shared` |
| **Payload** | JSON array of `SyncableCategory` |
| **Direction** | Bidirectional (both apps push and pull) |
| **Conflict resolution** | Last-write-wins (ISO 8601 fractional-second timestamps) |
| **Size limit** | 1 MB total KVS (not a practical constraint for metadata) |

### SyncableCategory Format

```json
{
  "uuid": "...",
  "name": "Story",
  "colorHex": "#D97706",
  "iconName": "book.pages",
  "sortOrder": 0,
  "isDefault": true,
  "modifiedAt": "2026-04-09T15:30:00.123Z"
}
```

### Merge Strategy

| Condition | Action |
|-----------|--------|
| UUID found locally, cloud `modifiedAt` > local cached | Update local fields |
| UUID found locally, cloud `modifiedAt` <= local | No-op (keep local) |
| UUID not found locally | Insert new `TagCategory` |
| UUID found locally, absent from cloud | No deletion (local preserved) |
| Category name changed by cloud update | All `Tag` records with old `categoryName` updated to new name |

### Sync Lifecycle

1. `startObserving(context:)` — registers for KVS change notification, calls `synchronize()`, triggers initial pull + push.
2. `pushCategoriesToCloud()` — serialises all local categories to JSON, writes to KVS. Preserves existing `modifiedAt` timestamps.
3. `markModified(_ category:)` — stamps a category's cached timestamp with `Date()` so next push propagates it as newer.

### Entitlement Requirements

- **Release builds:** Both apps declare `com.apple.developer.ubiquity-kvstore-identifier` = `$(TeamIdentifierPrefix)com.dictly.shared`.
- **Debug builds:** Entitlements are empty — iCloud sync is disabled during development.

---

## Shared Dependencies

### DictlyKit Swift Package

Both apps depend on `DictlyKit` via a local path package reference (`../DictlyKit`). The package exposes four library targets through a single umbrella product:

| Target | Used By | Purpose |
|--------|---------|---------|
| `DictlyModels` | Both apps | SwiftData entities, DTOs, error types, schema |
| `DictlyTheme` | Both apps | Design system tokens |
| `DictlyStorage` | Both apps | Audio files, Spotlight, iCloud sync, bundle serialisation |
| `DictlyExport` | Mac (primarily) | Markdown export |

### whisper.cpp

Vendored at `Vendor/whisper.cpp/` (git submodule). Compiled as `WhisperLib` static library target in `DictlyMac/project.yml`. **Mac only** — iOS has no transcription capability.

---

## Integration Points Summary

| # | From | To | Mechanism | Data | Frequency |
|---|------|----|-----------|------|-----------|
| 1 | iOS | Mac | AirDrop | .dictly bundle | Per-session (user-initiated) |
| 2 | iOS | Mac | Bonjour TCP | .dictly bundle | Per-session (user-initiated) |
| 3 | Both | iCloud | NSUbiquitousKeyValueStore | TagCategory JSON | On category change + app launch |
| 4 | Both | DictlyKit | SPM local package | Shared code | Compile-time |
| 5 | Mac | whisper.cpp | Static lib + bridging header | C API calls | Per-tag transcription |
