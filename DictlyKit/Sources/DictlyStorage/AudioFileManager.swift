import Foundation
import os
import DictlyModels

private let logger = Logger(subsystem: "com.dictly", category: "storage")

/// Stateless utility for managing audio files in the app sandbox.
/// All methods are static — no instance needed.
public struct AudioFileManager {

    // MARK: - Directory

    /// Returns the app sandbox subdirectory used for audio recordings,
    /// creating it if it does not yet exist.
    public static func audioStorageDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let recordingsDir = appSupport.appendingPathComponent("Recordings", isDirectory: true)
        if !FileManager.default.fileExists(atPath: recordingsDir.path) {
            do {
                try FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
                logger.info("AudioFileManager: created Recordings directory at \(recordingsDir.path, privacy: .public)")
            } catch {
                logger.error("AudioFileManager: failed to create Recordings directory — \(error)")
            }
        }
        return recordingsDir
    }

    // MARK: - Size

    /// Returns the size in bytes of the file at the given path.
    /// Throws `DictlyError.storage(.fileNotFound)` if the file does not exist.
    public static func fileSize(at path: String) throws -> Int64 {
        guard FileManager.default.fileExists(atPath: path) else {
            logger.error("AudioFileManager: fileSize — file not found at \(path, privacy: .private)")
            throw DictlyError.storage(.fileNotFound)
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let size = (attributes[.size] as? Int64) ?? 0
        logger.debug("AudioFileManager: fileSize \(size, privacy: .public) bytes for path (private)")
        return size
    }

    /// Sums the audio file sizes for all sessions that have a non-nil `audioFilePath`.
    /// Missing files are skipped gracefully (logged, not thrown).
    public static func totalAudioStorageSize(sessions: [Session]) -> Int64 {
        var total: Int64 = 0
        for session in sessions {
            guard let path = session.audioFilePath else { continue }
            do {
                total += try fileSize(at: path)
            } catch {
                logger.warning("AudioFileManager: skipping missing file for session '\(session.title, privacy: .private)' — \(error)")
            }
        }
        logger.info("AudioFileManager: total audio storage \(total, privacy: .public) bytes across \(sessions.count, privacy: .public) sessions")
        return total
    }

    // MARK: - Delete

    /// Removes the audio file at the given path.
    /// Throws `DictlyError.storage(.fileNotFound)` if the file does not exist.
    public static func deleteAudioFile(at path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            logger.error("AudioFileManager: deleteAudioFile — file not found at \(path, privacy: .private)")
            throw DictlyError.storage(.fileNotFound)
        }
        try FileManager.default.removeItem(atPath: path)
        logger.info("AudioFileManager: deleted audio file (path private)")
    }

    // MARK: - Formatting

    /// Returns a human-readable size string using `ByteCountFormatter` with `.file` style.
    /// Example output: "0 bytes", "512 KB", "115 MB", "2.3 GB"
    public static func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
