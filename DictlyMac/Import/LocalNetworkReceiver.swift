import Foundation
import Network
import Observation
import os
import DictlyModels

// MARK: - ReceiverState

/// Represents the current state of the local network receiver.
enum ReceiverState: Equatable {
    case idle
    case listening
    case receiving(progress: Double)
    case received
    case failed(Error)

    static func == (lhs: ReceiverState, rhs: ReceiverState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.listening, .listening): return true
        case (.receiving(let l), .receiving(let r)): return l == r
        case (.received, .received): return true
        case (.failed(let l), .failed(let r)):
            return l.localizedDescription == r.localizedDescription
        default: return false
        }
    }
}

// MARK: - LocalNetworkReceiver

/// Advertises a Bonjour service (`_dictly._tcp`) on the local network and
/// receives `.dictly` bundles sent from iOS over a direct TCP connection.
///
/// The over-the-wire protocol is:
/// ```
/// [4 bytes: total payload length][4 bytes: session.json length][session.json][audio.aac]
/// ```
///
/// State machine:
/// ```
/// idle → listening → receiving(progress:) → received
///                                          → failed(Error)
/// ```
@Observable
@MainActor
final class LocalNetworkReceiver {

    private let logger = Logger(subsystem: "com.dictly.mac", category: "transfer")

    // MARK: - Observable State

    /// Current receiver state. Drives any observing UI.
    private(set) var receiverState: ReceiverState = .idle

    /// URL of the received and reconstructed `.dictly` bundle directory.
    /// Set when `receiverState` transitions to `.received`. Cleared on reset.
    private(set) var receivedBundleURL: URL?

    // MARK: - Private

    private var listener: NWListener?

    // MARK: - Public API

    /// Starts the Bonjour TCP listener on a system-assigned port.
    ///
    /// Advertises as `_dictly._tcp` with the Mac's computer name.
    /// Safe to call multiple times — no-ops if already listening.
    func startListening() {
        guard listener == nil else {
            logger.debug("LocalNetworkReceiver: already listening, skipping start")
            return
        }

        do {
            let params = NWParameters.tcp
            let newListener = try NWListener(using: params)
            newListener.service = NWListener.Service(name: macComputerName(), type: "_dictly._tcp")

            newListener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.handleListenerStateChange(state)
                }
            }

            newListener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.handleNewConnection(connection)
                }
            }

            newListener.start(queue: .main)
            listener = newListener
            logger.info("LocalNetworkReceiver: listener started")
        } catch {
            logger.error("LocalNetworkReceiver: failed to create listener — \(error)")
            receiverState = .failed(DictlyError.transfer(.connectionFailed))
        }
    }

    /// Stops the listener and resets state to `.idle`.
    func stopListening() {
        listener?.cancel()
        listener = nil
        receiverState = .idle
        logger.info("LocalNetworkReceiver: listener stopped")
    }

    /// Resets state and clears `receivedBundleURL`. Call after consuming the bundle.
    func reset() {
        receivedBundleURL = nil
        if case .received = receiverState {
            receiverState = .listening
        }
    }

    // MARK: - Listener State Handling

    private func handleListenerStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            let port = listener?.port?.rawValue ?? 0
            logger.info("LocalNetworkReceiver: listening on port \(port)")
            receiverState = .listening

        case .failed(let error):
            logger.error("LocalNetworkReceiver: listener failed — \(error)")
            receiverState = .failed(DictlyError.transfer(.connectionFailed))
            // Restart after brief delay
            listener = nil
            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run { self.startListening() }
            }

        case .cancelled:
            logger.info("LocalNetworkReceiver: listener cancelled")
            receiverState = .idle

        default:
            logger.debug("LocalNetworkReceiver: listener state changed to \(String(describing: state))")
        }
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        logger.info("LocalNetworkReceiver: new connection from \(String(describing: connection.endpoint))")
        connection.start(queue: .main)
        receiveBundle(on: connection)
    }

    private func receiveBundle(on connection: NWConnection) {
        // Step 1: receive the 4-byte total payload length prefix
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let error {
                    self.logger.error("LocalNetworkReceiver: error reading length prefix — \(error)")
                    self.receiverState = .failed(DictlyError.transfer(.transferInterrupted))
                    connection.cancel()
                    return
                }

                guard let data, data.count == 4 else {
                    self.logger.error("LocalNetworkReceiver: incomplete length prefix")
                    self.receiverState = .failed(DictlyError.transfer(.bundleCorrupted))
                    connection.cancel()
                    return
                }

                let totalLength = Int(data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
                self.logger.info("LocalNetworkReceiver: expecting \(totalLength) bytes")
                self.receiverState = .receiving(progress: 0.0)

                self.receivePayload(on: connection, expectedLength: totalLength)
            }
        }
    }

    private func receivePayload(on connection: NWConnection, expectedLength: Int) {
        var accumulated = Data()
        accumulated.reserveCapacity(expectedLength)

        func receiveChunk() {
            let remaining = expectedLength - accumulated.count
            guard remaining > 0 else {
                processPayload(accumulated, connection: connection)
                return
            }

            let maxChunk = min(remaining, 65536)
            connection.receive(minimumIncompleteLength: 1, maximumLength: maxChunk) { [weak self] data, _, isComplete, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if let error {
                        self.logger.error("LocalNetworkReceiver: receive error — \(error)")
                        self.receiverState = .failed(DictlyError.transfer(.transferInterrupted))
                        connection.cancel()
                        return
                    }

                    if let data {
                        accumulated.append(data)
                        let progress = Double(accumulated.count) / Double(expectedLength)
                        self.receiverState = .receiving(progress: progress)
                    }

                    if accumulated.count >= expectedLength || isComplete {
                        self.processPayload(accumulated, connection: connection)
                    } else {
                        receiveChunk()
                    }
                }
            }
        }

        receiveChunk()
    }

    private func processPayload(_ payload: Data, connection: NWConnection) {
        connection.cancel()

        guard payload.count >= 4 else {
            logger.error("LocalNetworkReceiver: payload too short to contain session.json length")
            receiverState = .failed(DictlyError.transfer(.bundleCorrupted))
            return
        }

        // Parse: [4 bytes: session.json length][session.json bytes][audio.aac bytes]
        let jsonLength = Int(payload[0..<4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })

        guard payload.count >= 4 + jsonLength else {
            logger.error("LocalNetworkReceiver: payload too short for session.json (expected \(jsonLength) bytes)")
            receiverState = .failed(DictlyError.transfer(.bundleCorrupted))
            return
        }

        let sessionJSON = payload[4..<(4 + jsonLength)]
        let audioData = payload[(4 + jsonLength)...]

        do {
            let bundleURL = try writeBundleToDisk(sessionJSON: sessionJSON, audioData: audioData)
            receivedBundleURL = bundleURL
            receiverState = .received
            logger.info("LocalNetworkReceiver: bundle received and written to \(bundleURL.path)")
        } catch {
            logger.error("LocalNetworkReceiver: failed to write bundle — \(error)")
            receiverState = .failed(error)
        }
    }

    // MARK: - Bundle Writing

    private func writeBundleToDisk(sessionJSON: Data, audioData: Data) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let bundleName = "received-\(UUID().uuidString).dictly"
        let bundleURL = tempDir.appendingPathComponent(bundleName, isDirectory: true)

        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try sessionJSON.write(to: bundleURL.appendingPathComponent("session.json"))
        try audioData.write(to: bundleURL.appendingPathComponent("audio.aac"))

        return bundleURL
    }

    // MARK: - Helpers

    private func macComputerName() -> String {
        Host.current().localizedName ?? "Dictly-Mac"
    }
}
