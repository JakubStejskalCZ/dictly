import Foundation
import os
import DictlyModels

/// Packs and unpacks .dictly bundle directories.
///
/// A .dictly bundle is a flat directory containing exactly two files:
///   - audio.aac   — the session recording (AAC 64kbps mono / .m4a content)
///   - session.json — JSON-encoded TransferBundle (session + tags + campaign)
///
/// Usage:
///   - Serialize: `BundleSerializer().serialize(session:audioData:to:)`
///   - Deserialize: `BundleSerializer().deserialize(from:)`
public struct BundleSerializer {

    private let logger = Logger(subsystem: "com.dictly", category: "transfer")

    public init() {}

    // MARK: - Serialize

    /// Creates a .dictly bundle directory at `url` from a session and its raw audio data.
    ///
    /// Writes `audio.aac` and `session.json` inside the given directory URL.
    /// The caller is responsible for ensuring the session's `tags` relationship is loaded
    /// (i.e. the session must be accessed from its ModelContext).
    ///
    /// - Parameters:
    ///   - session: The Session to package.
    ///   - audioData: Raw audio bytes (AAC 64kbps mono).
    ///   - url: Destination .dictly directory URL (will be created if absent).
    /// - Throws: `DictlyError.transfer(.bundleCorrupted)` if writing fails.
    public func serialize(session: Session, audioData: Data, to url: URL) throws {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            logger.error("BundleSerializer: failed to create bundle directory at \(url.path): \(error)")
            throw DictlyError.transfer(.bundleCorrupted)
        }

        let bundle = TransferBundle(
            version: 1,
            session: session.toDTO(),
            tags: session.tags.map { $0.toDTO() },
            campaign: session.campaign?.toDTO()
        )

        let encoder = makeEncoder()

        let jsonData: Data
        do {
            jsonData = try encoder.encode(bundle)
        } catch {
            logger.error("BundleSerializer: JSON encoding failed: \(error)")
            throw DictlyError.transfer(.bundleCorrupted)
        }

        do {
            try audioData.write(to: url.appendingPathComponent("audio.aac"))
        } catch {
            logger.error("BundleSerializer: failed to write audio.aac: \(error)")
            throw DictlyError.transfer(.bundleCorrupted)
        }

        do {
            try jsonData.write(to: url.appendingPathComponent("session.json"))
        } catch {
            logger.error("BundleSerializer: failed to write session.json: \(error)")
            throw DictlyError.transfer(.bundleCorrupted)
        }
    }

    // MARK: - Deserialize

    /// Reads a .dictly bundle directory and returns the decoded metadata and audio bytes.
    ///
    /// Validates that both `audio.aac` and `session.json` are present and non-empty
    /// before attempting to decode.
    ///
    /// - Parameter url: Path to the .dictly bundle directory.
    /// - Returns: A tuple of `(TransferBundle, Data)` — decoded session metadata and raw audio.
    /// - Throws: `DictlyError.transfer(.bundleCorrupted)` for missing files, invalid JSON, or empty audio.
    public func deserialize(from url: URL) throws -> (TransferBundle, Data) {
        let fm = FileManager.default
        let audioURL = url.appendingPathComponent("audio.aac")
        let jsonURL = url.appendingPathComponent("session.json")

        // Validate audio.aac exists
        guard fm.fileExists(atPath: audioURL.path) else {
            logger.error("BundleSerializer: missing audio.aac in bundle at \(url.path)")
            throw DictlyError.transfer(.bundleCorrupted)
        }

        // Validate session.json exists
        guard fm.fileExists(atPath: jsonURL.path) else {
            logger.error("BundleSerializer: missing session.json in bundle at \(url.path)")
            throw DictlyError.transfer(.bundleCorrupted)
        }

        // Read audio data
        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioURL)
        } catch {
            logger.error("BundleSerializer: failed to read audio.aac: \(error)")
            throw DictlyError.transfer(.bundleCorrupted)
        }

        // Validate audio is non-empty
        guard !audioData.isEmpty else {
            logger.error("BundleSerializer: audio.aac is empty in bundle at \(url.path)")
            throw DictlyError.transfer(.bundleCorrupted)
        }

        // Read session.json
        let jsonData: Data
        do {
            jsonData = try Data(contentsOf: jsonURL)
        } catch {
            logger.error("BundleSerializer: failed to read session.json: \(error)")
            throw DictlyError.transfer(.bundleCorrupted)
        }

        // Decode TransferBundle
        let decoder = makeDecoder()
        let bundle: TransferBundle
        do {
            bundle = try decoder.decode(TransferBundle.self, from: jsonData)
        } catch {
            logger.error("BundleSerializer: JSON decoding failed: \(error)")
            throw DictlyError.transfer(.bundleCorrupted)
        }

        return (bundle, audioData)
    }

    // MARK: - Private Helpers

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
