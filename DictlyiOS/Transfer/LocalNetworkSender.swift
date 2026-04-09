import Foundation
import Network
import Observation
import os
import DictlyModels
import DictlyStorage

// MARK: - SenderState

/// Represents the current state of a local network send operation.
enum SenderState: Equatable {
    case idle
    case browsing
    case connecting
    case sending(progress: Double)
    case completed
    case failed(Error)

    static func == (lhs: SenderState, rhs: SenderState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.browsing, .browsing): return true
        case (.connecting, .connecting): return true
        case (.sending(let l), .sending(let r)): return l == r
        case (.completed, .completed): return true
        case (.failed(let l), .failed(let r)):
            return l.localizedDescription == r.localizedDescription
        default: return false
        }
    }
}

// MARK: - LocalNetworkSender

/// Discovers Bonjour `_dictly._tcp` services on the local network and
/// sends a `.dictly` bundle directly over TCP to a selected Mac.
///
/// The over-the-wire protocol is:
/// ```
/// [4 bytes: total payload length][4 bytes: session.json length][session.json][audio.aac]
/// ```
///
/// State machine:
/// ```
/// idle → browsing → connecting → sending(progress:) → completed
///                                                    → failed(Error)
/// ```
@Observable
@MainActor
final class LocalNetworkSender {

    private let logger = Logger(subsystem: "com.dictly.ios", category: "transfer")

    // MARK: - Observable State

    /// Current sender state. Drives UI in `TransferPrompt`.
    private(set) var senderState: SenderState = .idle

    /// List of discovered Mac services on the local network.
    private(set) var discoveredPeers: [NWBrowser.Result] = []

    // MARK: - Private

    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var tempBundleURL: URL?

    // MARK: - Browsing Lifecycle

    /// Starts Bonjour service discovery for `_dictly._tcp`.
    ///
    /// Transitions: `.idle` → `.browsing`
    func startBrowsing() {
        guard case .idle = senderState else {
            logger.warning("LocalNetworkSender: startBrowsing called while not idle (state: \(String(describing: self.senderState)))")
            return
        }

        let newBrowser = NWBrowser(for: .bonjour(type: "_dictly._tcp", domain: nil), using: .tcp)

        newBrowser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handleBrowserStateChange(state)
            }
        }

        newBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                self?.discoveredPeers = Array(results)
                self?.logger.debug("LocalNetworkSender: discovered \(results.count) peer(s)")
            }
        }

        newBrowser.start(queue: .main)
        browser = newBrowser
        senderState = .browsing
        logger.info("LocalNetworkSender: started browsing for _dictly._tcp")
    }

    /// Cancels browsing and resets state to `.idle`.
    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        discoveredPeers = []
        senderState = .idle
        logger.info("LocalNetworkSender: stopped browsing")
    }

    // MARK: - Browser State Handling

    private func handleBrowserStateChange(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            logger.debug("LocalNetworkSender: browser ready")
        case .failed(let error):
            logger.error("LocalNetworkSender: browser failed — \(error)")
            senderState = .failed(DictlyError.transfer(.connectionFailed))
        case .cancelled:
            logger.debug("LocalNetworkSender: browser cancelled")
        default:
            break
        }
    }

    // MARK: - Send

    /// Prepares and sends a `.dictly` bundle to the specified peer.
    ///
    /// - Parameters:
    ///   - session: The session to package and send.
    ///   - peer: The discovered `NWBrowser.Result` representing the Mac.
    func send(session: Session, to peer: NWBrowser.Result) {
        guard case .browsing = senderState else {
            logger.warning("LocalNetworkSender: send called while not browsing (state: \(String(describing: self.senderState)))")
            return
        }

        senderState = .connecting
        logger.info("LocalNetworkSender: connecting to \(String(describing: peer.endpoint))")

        Task {
            do {
                let payload = try preparePayload(for: session)
                await connect(to: peer.endpoint, payload: payload)
            } catch {
                logger.error("LocalNetworkSender: bundle preparation failed — \(error)")
                senderState = .failed(error)
            }
        }
    }

    /// Resets state to `.idle`. Call after `.completed` or `.failed` to allow retry.
    func reset() {
        cleanup()
        senderState = .idle
        logger.info("LocalNetworkSender: reset to idle")
    }

    // MARK: - Bundle Preparation

    /// Builds the wire payload from the session.
    ///
    /// Format: `[4 bytes: session.json length][session.json][audio.aac]`
    ///
    /// - Returns: Raw payload data ready for length-prefixed framing.
    /// - Throws: `DictlyError.transfer(.bundleCorrupted)` if audio is missing.
    private func preparePayload(for session: Session) throws -> Data {
        guard let audioFilePath = session.audioFilePath else {
            logger.error("LocalNetworkSender: session \(session.uuid) has no audioFilePath")
            throw DictlyError.transfer(.bundleCorrupted)
        }

        let audioURL: URL
        if audioFilePath.hasPrefix("/") {
            audioURL = URL(fileURLWithPath: audioFilePath)
        } else {
            let dir = (try? AudioFileManager.audioStorageDirectory()) ?? FileManager.default.temporaryDirectory
            audioURL = dir.appendingPathComponent(audioFilePath)
        }
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            logger.error("LocalNetworkSender: audio file not found at \(audioURL.path)")
            throw DictlyError.transfer(.bundleCorrupted)
        }

        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioURL)
        } catch {
            logger.error("LocalNetworkSender: failed to read audio — \(error)")
            throw DictlyError.transfer(.bundleCorrupted)
        }

        // Create temp bundle to get session.json via BundleSerializer
        let bundleName = "\(session.uuid.uuidString)-lnw.dictly"
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(bundleName, isDirectory: true)
        if FileManager.default.fileExists(atPath: bundleURL.path) {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        let serializer = BundleSerializer()
        try serializer.serialize(session: session, audioData: audioData, to: bundleURL)
        tempBundleURL = bundleURL

        let sessionJSON: Data
        do {
            sessionJSON = try Data(contentsOf: bundleURL.appendingPathComponent("session.json"))
        } catch {
            cleanup()
            throw DictlyError.transfer(.bundleCorrupted)
        }

        // Wire format: [4 bytes: json length][session.json][audio.aac]
        var jsonLength = UInt32(sessionJSON.count).bigEndian
        let jsonHeader = Data(bytes: &jsonLength, count: 4)
        return jsonHeader + sessionJSON + audioData
    }

    // MARK: - Connection

    private func connect(to endpoint: NWEndpoint, payload: Data) async {
        let newConnection = NWConnection(to: endpoint, using: .tcp)

        newConnection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    self.logger.info("LocalNetworkSender: connection ready, sending payload")
                    self.sendPayload(payload, on: newConnection)
                case .failed(let error):
                    self.logger.error("LocalNetworkSender: connection failed — \(error)")
                    self.senderState = .failed(DictlyError.transfer(.connectionFailed))
                    self.cleanup()
                case .cancelled:
                    self.logger.debug("LocalNetworkSender: connection cancelled")
                default:
                    break
                }
            }
        }

        newConnection.start(queue: .main)
        connection = newConnection
    }

    // MARK: - Payload Sending (Chunked for Progress)

    private func sendPayload(_ payload: Data, on connection: NWConnection) {
        // Send 4-byte big-endian total payload length prefix first
        var totalLength = UInt32(payload.count).bigEndian
        let lengthPrefix = Data(bytes: &totalLength, count: 4)

        connection.send(content: lengthPrefix, completion: .contentProcessed { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.logger.error("LocalNetworkSender: failed sending length prefix — \(error)")
                    self.senderState = .failed(DictlyError.transfer(.transferInterrupted))
                    self.cleanup()
                    return
                }
                self.sendChunked(payload, on: connection, offset: 0)
            }
        })
    }

    private func sendChunked(_ payload: Data, on connection: NWConnection, offset: Int) {
        let chunkSize = 65536
        let end = min(offset + chunkSize, payload.count)
        let chunk = payload[offset..<end]
        let isLast = end == payload.count

        connection.send(content: chunk, isComplete: isLast, completion: .contentProcessed { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let error {
                    self.logger.error("LocalNetworkSender: send error at offset \(offset) — \(error)")
                    self.senderState = .failed(DictlyError.transfer(.transferInterrupted))
                    self.cleanup()
                    return
                }

                let progress = Double(end) / Double(payload.count)
                self.senderState = .sending(progress: progress)

                if isLast {
                    self.logger.info("LocalNetworkSender: transfer completed")
                    self.senderState = .completed
                    self.cleanup()
                } else {
                    self.sendChunked(payload, on: connection, offset: end)
                }
            }
        })
    }

    // MARK: - Cleanup

    private func cleanup() {
        browser?.cancel()
        browser = nil
        connection?.cancel()
        connection = nil
        discoveredPeers = []

        if let url = tempBundleURL {
            try? FileManager.default.removeItem(at: url)
            tempBundleURL = nil
            logger.debug("LocalNetworkSender: cleaned up temp bundle")
        }
    }
}
