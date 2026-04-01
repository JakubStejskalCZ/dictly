import XCTest
@testable import DictlyStorage
@testable import DictlyModels

final class AudioFileManagerTests: XCTestCase {

    // MARK: - audioStorageDirectory

    // 7.5 — Returns a valid URL and creates the directory if missing
    func testAudioStorageDirectoryReturnsValidURL() {
        let url = AudioFileManager.audioStorageDirectory()
        XCTAssertFalse(url.path.isEmpty, "audioStorageDirectory should return a non-empty path")
        XCTAssertTrue(url.path.hasSuffix("Recordings"), "path should end with 'Recordings'")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "directory should exist after calling audioStorageDirectory")
    }

    func testAudioStorageDirectoryIsIdempotent() {
        // Calling twice should not throw and should return the same directory
        let url1 = AudioFileManager.audioStorageDirectory()
        let url2 = AudioFileManager.audioStorageDirectory()
        XCTAssertEqual(url1, url2, "audioStorageDirectory should return the same URL on repeated calls")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url1.path))
    }

    // MARK: - fileSize

    // 7.1 — Returns correct size for a temp file
    func testFileSizeReturnsCorrectSize() throws {
        let url = makeTempFile(content: "Hello, Dictly!")
        defer { try? FileManager.default.removeItem(at: url) }

        let size = try AudioFileManager.fileSize(at: url.path)
        let expectedSize = Int64("Hello, Dictly!".utf8.count)
        XCTAssertEqual(size, expectedSize)
    }

    // 7.1 — Throws fileNotFound for a missing file
    func testFileSizeThrowsForMissingFile() {
        let missingPath = "/tmp/dictly_test_missing_\(UUID().uuidString).m4a"
        XCTAssertThrowsError(try AudioFileManager.fileSize(at: missingPath)) { error in
            guard case DictlyError.storage(.fileNotFound) = error else {
                XCTFail("Expected DictlyError.storage(.fileNotFound), got \(error)")
                return
            }
        }
    }

    // MARK: - totalAudioStorageSize

    // 7.2 — Correctly sums sizes across sessions with audio
    func testTotalAudioStorageSizeSumsCorrectly() throws {
        let file1 = makeTempFile(content: String(repeating: "A", count: 100))
        let file2 = makeTempFile(content: String(repeating: "B", count: 200))
        defer {
            try? FileManager.default.removeItem(at: file1)
            try? FileManager.default.removeItem(at: file2)
        }

        let sessions = [
            makeSession(audioFilePath: file1.path),
            makeSession(audioFilePath: file2.path),
        ]

        let total = AudioFileManager.totalAudioStorageSize(sessions: sessions)
        XCTAssertEqual(total, 300, "totalAudioStorageSize should sum sizes of both files")
    }

    // 7.2 — Ignores sessions with nil audioFilePath
    func testTotalAudioStorageSizeIgnoresNilPaths() {
        let sessions = [
            makeSession(audioFilePath: nil),
            makeSession(audioFilePath: nil),
        ]
        let total = AudioFileManager.totalAudioStorageSize(sessions: sessions)
        XCTAssertEqual(total, 0, "totalAudioStorageSize should return 0 for sessions with no audio")
    }

    // 7.2 — Gracefully skips missing files (no throw)
    func testTotalAudioStorageSizeSkipsMissingFiles() {
        let missingPath = "/tmp/dictly_missing_\(UUID().uuidString).m4a"
        let sessions = [makeSession(audioFilePath: missingPath)]
        let total = AudioFileManager.totalAudioStorageSize(sessions: sessions)
        XCTAssertEqual(total, 0, "Missing files should be skipped gracefully, returning 0")
    }

    // MARK: - deleteAudioFile

    // 7.3 — Removes the file at the given path
    func testDeleteAudioFileRemovesFile() throws {
        let url = makeTempFile(content: "audio data")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        try AudioFileManager.deleteAudioFile(at: url.path)

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "File should be removed after deleteAudioFile")
    }

    // 7.3 — Throws fileNotFound for a path that doesn't exist
    func testDeleteAudioFileThrowsForMissingFile() {
        let missingPath = "/tmp/dictly_test_delete_\(UUID().uuidString).m4a"
        XCTAssertThrowsError(try AudioFileManager.deleteAudioFile(at: missingPath)) { error in
            guard case DictlyError.storage(.fileNotFound) = error else {
                XCTFail("Expected DictlyError.storage(.fileNotFound), got \(error)")
                return
            }
        }
    }

    // MARK: - formattedSize

    // 7.4 — Correct output for 0 bytes
    func testFormattedSizeZeroBytes() {
        let result = AudioFileManager.formattedSize(0)
        // ByteCountFormatter outputs "Zero KB" or "0 bytes" depending on locale/platform
        XCTAssertFalse(result.isEmpty, "formattedSize(0) should return a non-empty string")
    }

    // 7.4 — Kilobyte range
    func testFormattedSizeKilobytes() {
        let result = AudioFileManager.formattedSize(512 * 1024) // 512 KB
        XCTAssertTrue(result.contains("KB") || result.contains("kB") || result.lowercased().contains("kb"),
                      "512 KB should format to KB range, got: \(result)")
    }

    // 7.4 — Megabyte range
    func testFormattedSizeMegabytes() {
        let result = AudioFileManager.formattedSize(115 * 1024 * 1024) // 115 MB
        XCTAssertTrue(result.contains("MB"), "115 MB should format to MB range, got: \(result)")
    }

    // 7.4 — Gigabyte range
    func testFormattedSizeGigabytes() {
        let result = AudioFileManager.formattedSize(2 * 1024 * 1024 * 1024) // 2 GB
        XCTAssertTrue(result.contains("GB"), "2 GB should format to GB range, got: \(result)")
    }

    // MARK: - Helpers

    private func makeTempFile(content: String) -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dictly_test_\(UUID().uuidString).m4a")
        let data = content.data(using: .utf8)!
        FileManager.default.createFile(atPath: url.path, contents: data)
        return url
    }

    private func makeSession(audioFilePath: String?) -> Session {
        let session = Session(
            title: "Test Session",
            sessionNumber: 1,
            audioFilePath: audioFilePath
        )
        return session
    }
}
