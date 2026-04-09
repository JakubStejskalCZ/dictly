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
    /// Throws if the directory cannot be created.
    public static func audioStorageDirectory() throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let recordingsDir = appSupport.appendingPathComponent("Recordings", isDirectory: true)
        if !FileManager.default.fileExists(atPath: recordingsDir.path) {
            try FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
            logger.info("AudioFileManager: created Recordings directory")
        }
        return recordingsDir
    }

    // MARK: - Path Resolution

    /// Resolves legacy `.aac` paths to `.m4a`.
    /// iOS records M4A content that was historically saved with `.aac` extension on Mac import.
    /// `AVAudioFile` uses the extension to infer format, so `.aac` fails for M4A content.
    /// Renames the file on disk if needed and returns the valid path.
    public static func resolvedAudioPath(_ path: String) -> String {
        guard path.hasSuffix(".aac") else { return path }
        let m4aPath = String(path.dropLast(4)) + ".m4a"
        if FileManager.default.fileExists(atPath: m4aPath) {
            return m4aPath
        }
        if FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.moveItem(atPath: path, toPath: m4aPath)
            return m4aPath
        }
        return path
    }

    // MARK: - Size

    private nonisolated(unsafe) static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    /// Returns the size in bytes of the file at the given path.
    /// Throws `DictlyError.storage(.fileNotFound)` if the file does not exist.
    public static func fileSize(at path: String) throws -> Int64 {
        guard FileManager.default.fileExists(atPath: path) else {
            logger.error("AudioFileManager: fileSize — file not found at \(path, privacy: .private)")
            throw DictlyError.storage(.fileNotFound)
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
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
        do {
            try FileManager.default.removeItem(atPath: path)
            logger.info("AudioFileManager: deleted audio file (path private)")
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
            logger.error("AudioFileManager: deleteAudioFile — file not found at \(path, privacy: .private)")
            throw DictlyError.storage(.fileNotFound)
        }
    }

    // MARK: - Formatting

    /// Returns a human-readable size string using `ByteCountFormatter` with `.file` style.
    /// Example output: "0 bytes", "512 KB", "115 MB", "2.3 GB"
    public static func formattedSize(_ bytes: Int64) -> String {
        sizeFormatter.string(fromByteCount: bytes)
    }
}
