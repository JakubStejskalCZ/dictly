import Foundation
import Observation
import os
import DictlyModels
import DictlyStorage

// MARK: - TransferState

/// Represents the current state of an AirDrop transfer operation.
enum TransferState: Equatable {
    case idle
    case preparing
    case sharing
    case completed
    case failed(Error)

    static func == (lhs: TransferState, rhs: TransferState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.preparing, .preparing): return true
        case (.sharing, .sharing): return true
        case (.completed, .completed): return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default: return false
        }
    }
}

// MARK: - TransferService

/// Manages AirDrop transfer of .dictly bundles from iOS to Mac.
///
/// Uses `@Observable` for SwiftUI integration. The caller presents
/// `UIActivityViewController` via the provided `bundleURL` observable.
///
/// State machine:
/// ```
/// idle → preparing → sharing → completed
///                            → failed(Error)
/// idle ← (user cancels share sheet)
/// ```
@Observable
@MainActor
final class TransferService {

    private let logger = Logger(subsystem: "com.dictly.ios", category: "transfer")

    // MARK: - Observable State

    /// Current transfer state. Drives UI in `TransferPrompt`.
    private(set) var transferState: TransferState = .idle

    /// URL of the temporary `.dictly` bundle directory, set during preparation.
    /// Cleared after cleanup.
    private(set) var temporaryBundleURL: URL?

    // MARK: - Public API

    /// Prepares a `.dictly` bundle from the given session and triggers the iOS share sheet.
    ///
    /// Transitions: `.idle` → `.preparing` → `.sharing` (or `.failed`)
    ///
    /// - Parameters:
    ///   - session: The session to package.
    ///   - presentationAnchor: The SwiftUI view calling this (unused at runtime — share sheet
    ///     is surfaced via `temporaryBundleURL` observable that drives a `.sheet` presentation).
    func shareViaAirDrop(session: Session) async {
        guard case .idle = transferState else {
            logger.warning("TransferService: shareViaAirDrop called while not idle (state: \(String(describing: self.transferState)))")
            return
        }

        transferState = .preparing
        logger.info("TransferService: starting AirDrop transfer for session \(session.uuid)")

        do {
            let bundleURL = try prepareBundle(for: session)
            temporaryBundleURL = bundleURL
            transferState = .sharing
            logger.info("TransferService: bundle prepared, presenting share sheet")
        } catch {
            logger.error("TransferService: bundle preparation failed — \(error)")
            transferState = .failed(error)
        }
    }

    /// Called by `ActivityViewControllerRepresentable` completion handler.
    ///
    /// - Parameters:
    ///   - completed: `true` if the user confirmed the AirDrop send.
    ///   - error: Non-nil if the activity failed.
    func handleShareCompletion(completed: Bool, error: Error?) {
        guard case .sharing = transferState else {
            logger.warning("TransferService: handleShareCompletion called in unexpected state: \(String(describing: self.transferState))")
            return
        }

        if let error = error {
            logger.error("TransferService: share failed — \(error)")
            transferState = .failed(error)
        } else if completed {
            logger.info("TransferService: share completed successfully")
            transferState = .completed
        } else {
            // User cancelled the share sheet — return to idle
            logger.info("TransferService: share cancelled by user")
            transferState = .idle
        }
        cleanupTemporaryBundle()
    }

    /// Resets state to `.idle`. Call after `.completed` or `.failed` to allow retry.
    func reset() {
        logger.info("TransferService: resetting to idle")
        cleanupTemporaryBundle()
        transferState = .idle
    }

    // MARK: - Bundle Preparation

    /// Creates a temporary `.dictly` bundle for the given session.
    ///
    /// - Parameter session: Session to serialize.
    /// - Returns: URL of the created `.dictly` directory in `FileManager.temporaryDirectory`.
    /// - Throws: `DictlyError.transfer(.bundleCorrupted)` if audio is missing or serialization fails.
    private func prepareBundle(for session: Session) throws -> URL {
        logger.info("TransferService: preparing bundle for session \(session.uuid)")
        return try _prepareBundleSync(for: session)
    }

    // MARK: - Private

    private func _prepareBundleSync(for session: Session) throws -> URL {
        // Resolve audio file
        guard let audioFilePath = session.audioFilePath else {
            logger.error("TransferService: session \(session.uuid) has no audioFilePath")
            throw DictlyError.transfer(.bundleCorrupted)
        }

        let audioURL = URL(fileURLWithPath: audioFilePath)
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            logger.error("TransferService: audio file not found at \(audioFilePath)")
            throw DictlyError.transfer(.bundleCorrupted)
        }

        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioURL)
        } catch {
            logger.error("TransferService: failed to read audio data — \(error)")
            throw DictlyError.transfer(.bundleCorrupted)
        }

        // Create temp bundle directory (remove stale if exists)
        let bundleName = "\(session.uuid.uuidString).dictly"
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(bundleName, isDirectory: true)
        if FileManager.default.fileExists(atPath: bundleURL.path) {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        // Serialize
        let serializer = BundleSerializer()
        try serializer.serialize(session: session, audioData: audioData, to: bundleURL)

        logger.info("TransferService: bundle created at \(bundleURL.path)")
        return bundleURL
    }

    /// Removes the temporary `.dictly` bundle directory if it exists.
    func cleanupTemporaryBundle() {
        guard let url = temporaryBundleURL else { return }
        do {
            try FileManager.default.removeItem(at: url)
            logger.info("TransferService: cleaned up temp bundle at \(url.path)")
        } catch {
            logger.warning("TransferService: cleanup failed — \(error)")
        }
        temporaryBundleURL = nil
    }
}
