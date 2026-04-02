# Story 3.3: Local Network Transfer (Bonjour Fallback)

Status: review

## Story

As a DM,
I want to transfer sessions via local Wi-Fi when AirDrop isn't working,
so that I always have a reliable way to get sessions to my Mac.

## Acceptance Criteria

1. **Given** both iPhone and Mac are on the same Wi-Fi network, **when** the Mac app is running with its Bonjour listener active, **then** the iOS app discovers the Mac via Bonjour service discovery.

2. **Given** the Mac is discovered on the local network, **when** the DM initiates a local network transfer, **then** the `.dictly` bundle is sent directly over Wi-Fi.

3. **Given** a local network transfer is in progress, **when** the DM views the transfer UI, **then** progress is displayed (sending -> complete or failed).

4. **Given** the local network transfer fails (e.g., Wi-Fi disconnects), **when** the DM views the error, **then** a specific error message and retry option are shown.

## Tasks / Subtasks

- [x] Task 1: Add `TransferError` cases for local network failures (AC: #3, #4)
  - [x] 1.1 Add `case connectionFailed`, `case transferInterrupted`, `case timeout` to `DictlyError.TransferError` in `DictlyKit/Sources/DictlyModels/DictlyError.swift`
  - [x] 1.2 Add `errorDescription` for each new case with user-friendly messages

- [x] Task 2: Create `LocalNetworkReceiver` on Mac (AC: #1)
  - [x] 2.1 Create `LocalNetworkReceiver.swift` in `DictlyMac/Import/` as `@Observable @MainActor` class
  - [x] 2.2 Create `NWListener` on a system-assigned TCP port advertising Bonjour service type `_dictly._tcp` (domain: `nil`)
  - [x] 2.3 Set `listener.service = NWListener.Service(name: "Dictly-Mac", type: "_dictly._tcp")` for discoverability
  - [x] 2.4 Implement `listener.stateUpdateHandler` — log state changes, handle `.ready` (port assigned), `.failed` (restart logic)
  - [x] 2.5 Implement `listener.newConnectionHandler` — accept incoming `NWConnection`, call `receiveBundle(on:)`
  - [x] 2.6 Implement `receiveBundle(on:)`:
    - Receive a 4-byte big-endian UInt32 length prefix, then the full `.dictly` bundle as a zip/tar archive byte stream
    - Write received data to temp directory, unarchive to `.dictly` directory
    - Publish received bundle URL via `@Observable` property `receivedBundleURL: URL?` for `ImportService` to consume
  - [x] 2.7 Implement `receiverState` observable: `.idle`, `.listening`, `.receiving(progress: Double)`, `.received`, `.failed(Error)`
  - [x] 2.8 Add `os.Logger` messages (subsystem: `com.dictly.mac`, category: `transfer`)
  - [x] 2.9 Start listener automatically on app launch (call from `DictlyMacApp.swift` or inject via `@Environment`)

- [x] Task 3: Create `LocalNetworkSender` on iOS (AC: #1, #2, #3, #4)
  - [x] 3.1 Create `LocalNetworkSender.swift` in `DictlyiOS/Transfer/` as `@Observable @MainActor` class
  - [x] 3.2 Create `NWBrowser` for service type `_dictly._tcp` with `NWParameters.tcp`
  - [x] 3.3 Implement `browser.stateUpdateHandler` — handle `.ready`, `.failed`
  - [x] 3.4 Implement `browser.browseResultsChangedHandler` — populate `@Observable` property `discoveredPeers: [NWBrowser.Result]`
  - [x] 3.5 Implement `startBrowsing()` and `stopBrowsing()` lifecycle methods
  - [x] 3.6 Implement `send(session:to:)`:
    - Prepare bundle via `BundleSerializer` (reuse same logic as `TransferService._prepareBundleSync`)
    - Archive the `.dictly` directory into a data blob (zip or tar)
    - Create `NWConnection` to the selected `NWBrowser.Result` endpoint
    - Send 4-byte big-endian UInt32 length prefix, then the archive data
    - Track progress via `NWConnection.send` completion
  - [x] 3.7 Implement `senderState` observable: `.idle`, `.browsing`, `.connecting`, `.sending(progress: Double)`, `.completed`, `.failed(Error)`
  - [x] 3.8 Handle connection errors — set `.failed` with `DictlyError.transfer(.connectionFailed)` or `.transfer(.transferInterrupted)` as appropriate
  - [x] 3.9 Add `os.Logger` messages (subsystem: `com.dictly.ios`, category: `transfer`)
  - [x] 3.10 Cleanup: cancel browser, cancel connection, remove temp bundle on completion/failure

- [x] Task 4: Update `TransferPrompt` to offer local network option (AC: #1, #2, #3, #4)
  - [x] 4.1 Add `@State private var localNetworkSender = LocalNetworkSender()` to `TransferPrompt`
  - [x] 4.2 In `.idle` state, add a secondary "Send via Wi-Fi" button below the AirDrop button (uses `DictlyTypography.body`, `DictlyColors.textSecondary` styling — same as "Transfer Later")
  - [x] 4.3 When "Send via Wi-Fi" is tapped, start browsing and show a peer picker:
    - If no peers found after 5 seconds, show "No Mac found on network" with retry
    - If peers found, show list of discovered Mac names for selection
    - On peer selection, call `localNetworkSender.send(session:to:)`
  - [x] 4.4 Show transfer progress during send: reuse existing `preparingView` for `.connecting` state, add progress bar for `.sending(progress:)` state
  - [x] 4.5 Show `.completed` state — reuse existing green checkmark + auto-dismiss
  - [x] 4.6 Show `.failed` state — reuse existing error view with "Retry" and "Transfer Later"
  - [x] 4.7 Add VoiceOver accessibility labels on new Wi-Fi transfer elements

- [x] Task 5: Info.plist and entitlements (AC: #1)
  - [x] 5.1 Add `NSLocalNetworkUsageDescription` to iOS `Info.plist`: "Dictly uses the local network to discover your Mac for session transfer."
  - [x] 5.2 Add `NSBonjourServices` array to iOS `Info.plist` with value `["_dictly._tcp"]`
  - [x] 5.3 Add `NSLocalNetworkUsageDescription` to Mac `Info.plist`: "Dictly uses the local network to receive sessions from your iPhone."
  - [x] 5.4 Add `NSBonjourServices` array to Mac `Info.plist` with value `["_dictly._tcp"]`

- [x] Task 6: Unit tests (AC: #1, #2, #3, #4)
  - [x] 6.1 Create `LocalNetworkSenderTests.swift` in `DictlyiOS/Tests/TransferTests/`
  - [x] 6.2 Test `senderState` transitions: `.idle` -> `.browsing` -> `.connecting` -> `.sending` -> `.completed`
  - [x] 6.3 Test `senderState` failure path: `.idle` -> `.browsing` -> `.connecting` -> `.failed`
  - [x] 6.4 Test that `stopBrowsing()` cancels the browser and resets state
  - [x] 6.5 Test bundle preparation for local network (verify temp `.dictly` directory created)
  - [x] 6.6 Create `LocalNetworkReceiverTests.swift` in `DictlyMacTests/ImportTests/`
  - [x] 6.7 Test `receiverState` transitions: `.idle` -> `.listening` -> `.receiving` -> `.received`
  - [x] 6.8 Test that `receivedBundleURL` is set when a bundle is fully received
  - [x] 6.9 Test new `DictlyError.TransferError` cases have non-nil `errorDescription`

## Dev Notes

### Network Framework Architecture

This story uses Apple's **Network framework** (`import Network`) — NOT `MultipeerConnectivity`. The Network framework provides lower-level control, works within App Store sandbox constraints, and avoids the UI chrome that MultipeerConnectivity forces.

**Architecture:**
- **Mac (Receiver):** `NWListener` advertises `_dictly._tcp` Bonjour service on the local network. Listens for incoming TCP connections. When a connection arrives, receives the `.dictly` bundle data.
- **iOS (Sender):** `NWBrowser` discovers `_dictly._tcp` services on the local network. When the DM selects a Mac, creates an `NWConnection` to that endpoint and sends the `.dictly` bundle data.

### Transfer Protocol (Simple Length-Prefixed)

Use a minimal framing protocol — no HTTP, no custom protocol negotiation:

```swift
// Sender side
let archiveData: Data = // zip/tar of .dictly directory
var length = UInt32(archiveData.count).bigEndian
let header = Data(bytes: &length, count: 4)
connection.send(content: header, completion: .contentProcessed { error in ... })
connection.send(content: archiveData, isComplete: true, completion: .contentProcessed { error in ... })

// Receiver side
connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { data, _, _, error in
    guard let data = data else { return }
    let length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    // Then receive `length` bytes...
}
```

### Bundle Archiving for Transfer

AirDrop can send directory bundles natively. TCP sockets cannot. The `.dictly` bundle directory must be archived into a single data blob for network transfer:

```swift
// Archive: use FileManager to create a zip of the .dictly directory
// Use NSFileCoordinator or a simple zip utility
// Option 1: Foundation's built-in zip (iOS 16+/macOS 13+):
//   Use `Archive` from the `ZIPFoundation` SPM package if Foundation lacks zip API
// Option 2: Tar the directory manually (just concatenate audio.aac + session.json with metadata header)
//
// RECOMMENDED: Use a simple custom format:
// [4 bytes: session.json length][session.json bytes][remaining bytes: audio.aac]
// This avoids adding a zip dependency and leverages the known .dictly bundle structure.
```

**Preferred approach — custom two-part format** (no external dependencies):

```swift
// Sender: serialize .dictly contents into a flat stream
let sessionJSON = try Data(contentsOf: bundleURL.appendingPathComponent("session.json"))
let audioData = try Data(contentsOf: bundleURL.appendingPathComponent("audio.aac"))
var jsonLength = UInt32(sessionJSON.count).bigEndian
let header = Data(bytes: &jsonLength, count: 4)
let payload = header + sessionJSON + audioData

// Receiver: reconstruct .dictly directory from stream
let jsonLength = // first 4 bytes
let sessionJSON = payload[4..<(4 + jsonLength)]
let audioData = payload[(4 + jsonLength)...]
// Write to temp .dictly directory
```

This means the over-the-wire protocol is:
```
[4 bytes: total payload length][4 bytes: session.json length][session.json][audio.aac]
```

### Bonjour Service Type

- Service type: `_dictly._tcp` — must be registered in `Info.plist` on both platforms
- The Mac listener advertises with a human-readable name (e.g., the Mac's computer name via `Host.current().localizedName`)
- The iOS browser shows discovered names in the peer picker UI

### Info.plist Requirements (CRITICAL)

Both iOS and Mac apps MUST have these keys or local network access will be silently denied:

```xml
<!-- Info.plist -->
<key>NSLocalNetworkUsageDescription</key>
<string>Dictly uses the local network to transfer sessions between your devices.</string>
<key>NSBonjourServices</key>
<array>
    <string>_dictly._tcp</string>
</array>
```

### NWListener Setup (Mac Receiver)

```swift
import Network

@Observable
@MainActor
final class LocalNetworkReceiver {
    private var listener: NWListener?
    private let logger = Logger(subsystem: "com.dictly.mac", category: "transfer")

    func startListening() throws {
        let params = NWParameters.tcp
        listener = try NWListener(using: params)
        listener?.service = NWListener.Service(type: "_dictly._tcp")
        listener?.stateUpdateHandler = { [weak self] state in
            // Handle .ready, .failed, .cancelled
        }
        listener?.newConnectionHandler = { [weak self] connection in
            // Accept and receive bundle data
        }
        listener?.start(queue: .main)
    }
}
```

### NWBrowser Setup (iOS Sender)

```swift
import Network

@Observable
@MainActor
final class LocalNetworkSender {
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private let logger = Logger(subsystem: "com.dictly.ios", category: "transfer")

    func startBrowsing() {
        browser = NWBrowser(for: .bonjour(type: "_dictly._tcp", domain: nil), using: .tcp)
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor in
                self?.discoveredPeers = Array(results)
            }
        }
        browser?.start(queue: .main)
    }
}
```

### Integration with Existing TransferPrompt

The existing `TransferPrompt` handles AirDrop via `TransferService`. Add a **secondary** "Send via Wi-Fi" button in the `.idle` state. Do NOT replace AirDrop — local network is the **fallback**. The UI flow:

1. `.idle` — AirDrop button (primary, prominent) + "Send via Wi-Fi" (secondary) + "Transfer Later"
2. Tapping "Send via Wi-Fi" starts browsing, shows peer picker
3. Selecting a peer starts the transfer
4. Progress, success, and failure states reuse existing `TransferPrompt` visual patterns

### Integration with ImportService (Mac)

`LocalNetworkReceiver` publishes `receivedBundleURL` when a bundle is fully received. The Mac app should observe this and feed it to the existing `ImportService` (story 3.4) for unpacking and deduplication. For story 3.3, just verify the bundle is received and written to disk correctly — import logic is story 3.4's scope.

### Bundle Preparation — Reuse TransferService Pattern

The bundle preparation logic (reading audio, calling `BundleSerializer.serialize()`) is already implemented in `TransferService._prepareBundleSync()`. For `LocalNetworkSender`, either:
1. Extract bundle preparation into a shared helper function (preferred if clean)
2. Duplicate the preparation logic in `LocalNetworkSender` (acceptable — it's ~30 lines)

Do NOT make `_prepareBundleSync` public on `TransferService` — the two services have different lifecycles.

### Progress Tracking

`NWConnection.send` provides completion callbacks but not byte-level progress. For large bundles (~115 MB), consider chunked sending to provide progress updates:

```swift
// Send in chunks (e.g., 64 KB) for progress reporting
let chunkSize = 64 * 1024
var offset = 0
while offset < payload.count {
    let end = min(offset + chunkSize, payload.count)
    let chunk = payload[offset..<end]
    let isLast = end == payload.count
    connection.send(content: chunk, isComplete: isLast, completion: .contentProcessed { error in
        // Update progress: Double(end) / Double(payload.count)
    })
    offset = end
}
```

### Error Handling

- **No peers found:** After 5-second timeout, show "No Mac found on your network. Make sure Dictly is open on your Mac and both devices are on the same Wi-Fi."
- **Connection refused:** `DictlyError.transfer(.connectionFailed)` — "Could not connect to Mac. Check that Dictly is running."
- **Transfer interrupted (Wi-Fi disconnect):** `DictlyError.transfer(.transferInterrupted)` — "Transfer interrupted. Check your Wi-Fi connection and try again."
- **Timeout:** `DictlyError.transfer(.timeout)` — "Transfer timed out."
- All errors show retry + "Transfer Later" options (reuse existing failed view pattern)

### What NOT to Do

- **Do NOT** use `MultipeerConnectivity` — it forces system UI (peer picker) and is less flexible. Use `Network` framework directly.
- **Do NOT** implement Mac import logic — that's story 3.4. Just receive and write the bundle to disk.
- **Do NOT** register the `.dictly` UTI — that's story 3.4.
- **Do NOT** modify `BundleSerializer` — it's complete from story 3.1.
- **Do NOT** use `@StateObject` or `ObservableObject` — use `@Observable` (project convention).
- **Do NOT** hardcode colors, fonts, or spacing — use `DictlyTheme` tokens.
- **Do NOT** use `URLSession` or HTTP — this is a direct TCP connection via Network framework.
- **Do NOT** add encryption in MVP — platform-level local network security is sufficient.
- **Do NOT** remove or break existing AirDrop functionality — local network is an additive fallback.

### Existing Code to Reuse

| What | Where | How |
|------|-------|-----|
| `BundleSerializer` | `DictlyKit/Sources/DictlyStorage/BundleSerializer.swift` | Call `serialize(session:audioData:to:)` to create bundle |
| `AudioFileManager` | `DictlyKit/Sources/DictlyStorage/AudioFileManager.swift` | Use `audioStorageDirectory()` to locate audio files |
| `TransferBundle` + DTOs | `DictlyKit/Sources/DictlyModels/TransferBundle.swift` | Session, Tag, Campaign DTOs with `toDTO()` extensions |
| `DictlyError.transfer(...)` | `DictlyKit/Sources/DictlyModels/DictlyError.swift` | Existing `.networkUnavailable`, `.peerNotFound`, `.bundleCorrupted` + new cases |
| `TransferService._prepareBundleSync` pattern | `DictlyiOS/Transfer/TransferService.swift` | Reuse bundle preparation logic (read audio, call serializer, create temp dir) |
| `TransferPrompt` | `DictlyiOS/Transfer/TransferPrompt.swift` | Add Wi-Fi button to existing idle state; reuse progress/success/error views |
| `DictlyTheme` (Colors, Typography, Spacing) | `DictlyKit/Sources/DictlyTheme/` | All UI tokens |
| `Session.audioFilePath` | `DictlyKit/Sources/DictlyModels/Session.swift` | Audio file location for bundle packaging |

### Project Structure Notes

New files:

```
DictlyiOS/Transfer/
├── TransferService.swift                    # EXISTING — AirDrop
├── TransferPrompt.swift                     # MODIFIED — add Wi-Fi button + peer picker
├── ActivityViewControllerRepresentable.swift # EXISTING — unchanged
└── LocalNetworkSender.swift                 # NEW: NWBrowser + NWConnection sender

DictlyMac/Import/
└── LocalNetworkReceiver.swift               # NEW: NWListener receiver

DictlyiOS/Tests/TransferTests/
├── TransferServiceTests.swift               # EXISTING — unchanged
└── LocalNetworkSenderTests.swift            # NEW: sender state + browsing tests

DictlyMacTests/ImportTests/
└── LocalNetworkReceiverTests.swift          # NEW: receiver state + listening tests
```

Modified files:
- `DictlyiOS/Transfer/TransferPrompt.swift` — add "Send via Wi-Fi" button + peer picker UI
- `DictlyiOS/Resources/Info.plist` — add `NSLocalNetworkUsageDescription` + `NSBonjourServices`
- `DictlyMac/Resources/Info.plist` — add `NSLocalNetworkUsageDescription` + `NSBonjourServices`
- `DictlyKit/Sources/DictlyModels/DictlyError.swift` — add new `TransferError` cases
- `DictlyMac/App/DictlyMacApp.swift` — start `LocalNetworkReceiver` on launch

### Testing Standards

- Use `XCTest` with `@MainActor` (project convention)
- `LocalNetworkSender` tests: mock `NWBrowser` behavior is difficult — focus on state machine transitions using dependency injection or test-only initializers
- `LocalNetworkReceiver` tests: test state transitions and data reassembly logic
- Cannot test actual Bonjour discovery in unit tests — manual testing required for integration
- Test new `DictlyError.TransferError` cases for `errorDescription` non-nil
- Use temporary directories for bundle creation/cleanup verification
- Clean up temp directories in `tearDown`

### Previous Story (3.2) Learnings

- `Task.detached` conflicts with `@MainActor`-isolated types in Swift 6 — avoid `Task.detached`; use `Task {}` which inherits actor isolation
- Share sheet binding setter was no-op when using `Binding(get:set:)` — be careful with custom bindings for `.sheet(isPresented:)` when the underlying state is driven by an external service
- `TransferPrompt` auto-dismiss uses `.onChange(of:)` + `Task.sleep` pattern (not `.task`) to allow cancellation — reuse same pattern for local network `.completed` state
- `prepareBundle` was made `private` to prevent race conditions from double-tap — apply same access control to `LocalNetworkSender`
- Wrong SF Symbol used initially (`airplayaudio` for AirDrop) — use `wifi` or `arrow.up.right.circle` for Wi-Fi transfer to distinguish from AirDrop's `square.and.arrow.up`

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 3, Story 3.3 acceptance criteria]
- [Source: _bmad-output/planning-artifacts/architecture.md — API & Communication Patterns, local network fallback]
- [Source: _bmad-output/planning-artifacts/architecture.md — Project Structure: LocalNetworkSender.swift, LocalNetworkReceiver.swift]
- [Source: _bmad-output/planning-artifacts/architecture.md — FR24 mapping to TransferService.swift]
- [Source: _bmad-output/planning-artifacts/prd.md — FR24 local network transfer, Transfer Mechanism section]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — TransferPrompt component, success/error feedback patterns]
- [Source: DictlyiOS/Transfer/TransferService.swift — existing AirDrop transfer implementation, bundle prep pattern]
- [Source: DictlyiOS/Transfer/TransferPrompt.swift — existing transfer UI to extend with Wi-Fi option]
- [Source: DictlyKit/Sources/DictlyModels/DictlyError.swift — existing TransferError enum to extend]
- [Source: _bmad-output/implementation-artifacts/3-2-airdrop-transfer-from-ios.md — previous story learnings and review findings]
- [Source: Apple Developer Documentation — Network framework: NWListener, NWBrowser, NWConnection]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Fixed missing `handleBrowserStateChange` method in `LocalNetworkSender` (compiler error on first build)
- Fixed missing `import Network` in `TransferPrompt.swift` (compiler error on NWBrowser type)
- Mac `DictlyMacTests` cannot be run locally without a development signing certificate (iCloud entitlement on host app requires team provisioning). Mac test target builds cleanly (`** TEST BUILD SUCCEEDED **`). This is a pre-existing project constraint.

### Completion Notes List

- Implemented full `LocalNetworkReceiver` on Mac using NWListener with `_dictly._tcp` Bonjour service; uses custom two-part wire format `[4 bytes: total len][4 bytes: json len][json][audio]`; publishes `receivedBundleURL` for ImportService (story 3.4) to consume; auto-restarts on failure
- Implemented full `LocalNetworkSender` on iOS using NWBrowser + NWConnection; chunked sending (64KB chunks) for progress reporting; reuses `BundleSerializer` pattern from `TransferService`; full cleanup on completion/failure
- Updated `TransferPrompt` with secondary "Send via Wi-Fi" bordered button in idle state; full Wi-Fi flow replaces `actionArea` when `senderState != .idle`; 5-second no-peers timeout; peer picker with Mac computer names; reuses existing `completedView` + auto-dismiss pattern; full VoiceOver support
- Added `DictlyMacTests` target to Mac `project.yml`; added `Import` directory to DictlyMac app sources; regenerated both Xcode projects with XcodeGen
- 129 iOS tests pass (18 new `LocalNetworkSenderTests`); 212 DictlyKit tests pass; Mac test target compiles cleanly
- ACs satisfied: #1 Bonjour discovery (NWBrowser/NWListener _dictly._tcp), #2 direct Wi-Fi bundle send, #3 progress UI (browsing→connecting→sending(progress:)→completed), #4 error messages + retry for all failure cases

### File List

- `DictlyKit/Sources/DictlyModels/DictlyError.swift` (modified)
- `DictlyMac/Import/LocalNetworkReceiver.swift` (new)
- `DictlyMac/App/DictlyMacApp.swift` (modified)
- `DictlyMac/Resources/Info.plist` (modified)
- `DictlyMac/project.yml` (modified)
- `DictlyMac/DictlyMac.xcodeproj/project.pbxproj` (regenerated)
- `DictlyiOS/Transfer/LocalNetworkSender.swift` (new)
- `DictlyiOS/Transfer/TransferPrompt.swift` (modified)
- `DictlyiOS/Resources/Info.plist` (modified)
- `DictlyiOS/Tests/TransferTests/LocalNetworkSenderTests.swift` (new)
- `DictlyMacTests/ImportTests/LocalNetworkReceiverTests.swift` (new)
- `DictlyiOS/DictlyiOS.xcodeproj/project.pbxproj` (regenerated)

### Change Log

- 2026-04-02: Implemented story 3.3 — local network transfer via Bonjour/NWFramework (LocalNetworkReceiver on Mac, LocalNetworkSender on iOS, TransferPrompt Wi-Fi UI, Info.plist keys, unit tests)
