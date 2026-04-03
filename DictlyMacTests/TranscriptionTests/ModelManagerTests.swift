import XCTest
@testable import DictlyMac
import DictlyModels

// MARK: - ModelManagerTests
//
// Tests for Story 5.2: Whisper Model Management.
// Covers: model registry, isDownloaded, selectModel, deleteModel, activeModelURL,
// init fallback, and UserDefaults persistence.
//
// All tests run on @MainActor since ModelManager is @MainActor.

@MainActor
final class ModelManagerTests: XCTestCase {

    var manager: ModelManager!
    var tempDir: URL!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelManagerTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Reset UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "activeWhisperModel")

        manager = ModelManager(modelsDirectory: tempDir)
    }

    override func tearDown() async throws {
        manager = nil
        UserDefaults.standard.removeObject(forKey: "activeWhisperModel")
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - 7.2: Model registry contains exactly 3 models with correct properties

    func testRegistryContainsThreeModels() {
        XCTAssertEqual(ModelManager.registry.count, 3)
    }

    func testRegistryBaseEnModel() {
        let base = ModelManager.registry.first(where: { $0.id == "base.en" })
        XCTAssertNotNil(base)
        XCTAssertEqual(base?.fileName, "ggml-base.en.bin")
        XCTAssertEqual(base?.isBundled, true)
        XCTAssertGreaterThan(base?.size ?? 0, 0)
        XCTAssertFalse(base?.quality.isEmpty ?? true)
    }

    func testRegistrySmallEnModel() {
        let small = ModelManager.registry.first(where: { $0.id == "small.en" })
        XCTAssertNotNil(small)
        XCTAssertEqual(small?.fileName, "ggml-small.en.bin")
        XCTAssertEqual(small?.isBundled, false)
        XCTAssertGreaterThan(small?.size ?? 0, 0)
    }

    func testRegistryMediumEnModel() {
        let medium = ModelManager.registry.first(where: { $0.id == "medium.en" })
        XCTAssertNotNil(medium)
        XCTAssertEqual(medium?.fileName, "ggml-medium.en.bin")
        XCTAssertEqual(medium?.isBundled, false)
        XCTAssertGreaterThan(medium?.size ?? 0, 0)
    }

    // MARK: - 7.3: isDownloaded returns false for non-existent model file

    func testIsDownloadedReturnsFalseForMissingFile() {
        let small = ModelManager.registry.first(where: { $0.id == "small.en" })!
        XCTAssertFalse(manager.isDownloaded(small))
    }

    // MARK: - 7.4: isDownloaded returns true when model file exists

    func testIsDownloadedReturnsTrueWhenFileExists() throws {
        let small = ModelManager.registry.first(where: { $0.id == "small.en" })!
        let url = manager.modelURL(for: small)
        FileManager.default.createFile(atPath: url.path, contents: Data("fake".utf8))
        XCTAssertTrue(manager.isDownloaded(small))
    }

    // MARK: - 7.5: selectModel persists to UserDefaults and updates activeModel

    func testSelectModelPersistsToUserDefaults() throws {
        let small = ModelManager.registry.first(where: { $0.id == "small.en" })!
        // Pre-create fake model file so selectModel allows it
        let url = manager.modelURL(for: small)
        FileManager.default.createFile(atPath: url.path, contents: Data("fake".utf8))

        manager.selectModel(small)

        XCTAssertEqual(manager.activeModel, "small.en")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "activeWhisperModel"), "small.en")
    }

    // MARK: - 7.6: selectModel rejects non-downloaded model

    func testSelectModelRejectsNonDownloadedModel() {
        let medium = ModelManager.registry.first(where: { $0.id == "medium.en" })!
        // medium.en file does NOT exist
        XCTAssertFalse(manager.isDownloaded(medium))

        manager.selectModel(medium)

        // activeModel should remain "base.en" (default)
        XCTAssertNotEqual(manager.activeModel, "medium.en")
    }

    // MARK: - 7.7: deleteModel removes file and resets activeModel to base.en

    func testDeleteModelRemovesFileAndResetsActiveModel() throws {
        let small = ModelManager.registry.first(where: { $0.id == "small.en" })!
        let url = manager.modelURL(for: small)
        FileManager.default.createFile(atPath: url.path, contents: Data("fake".utf8))

        // Select small as active
        manager.selectModel(small)
        XCTAssertEqual(manager.activeModel, "small.en")

        // Delete it
        try manager.deleteModel(small)

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "File should be removed")
        XCTAssertEqual(manager.activeModel, "base.en", "Active model should fall back to base.en")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "activeWhisperModel"), "base.en")
    }

    // MARK: - 7.8: deleteModel on base.en is a no-op

    func testDeleteBundledModelIsNoOp() throws {
        let base = ModelManager.registry.first(where: { $0.id == "base.en" })!
        let url = manager.modelURL(for: base)
        // Pre-create a fake base.en file in tempDir
        FileManager.default.createFile(atPath: url.path, contents: Data("fake".utf8))

        // Attempt to delete bundled model
        try manager.deleteModel(base)

        // File should still exist — deletion was skipped
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Bundled model should not be deleted")
        XCTAssertEqual(manager.activeModel, "base.en", "Active model should remain base.en")
    }

    // MARK: - 7.9: activeModelURL returns correct URL for selected model

    func testActiveModelURLReturnsCorrectURL() throws {
        let small = ModelManager.registry.first(where: { $0.id == "small.en" })!
        let url = manager.modelURL(for: small)
        FileManager.default.createFile(atPath: url.path, contents: Data("fake".utf8))

        manager.selectModel(small)

        let activeURL = manager.activeModelURL
        XCTAssertEqual(activeURL.lastPathComponent, "ggml-small.en.bin")
        XCTAssertEqual(activeURL, manager.modelURL(for: small))
    }

    // MARK: - 7.10: Init fallback — persisted model missing on disk falls back to base.en

    func testInitFallsBackToBaseEnWhenPersistedModelMissing() async throws {
        // Persist a model ID that has no corresponding file on disk
        UserDefaults.standard.set("small.en", forKey: "activeWhisperModel")

        // Create a fresh manager — small.en file does NOT exist in tempDir
        let freshManager = ModelManager(modelsDirectory: tempDir)

        XCTAssertEqual(freshManager.activeModel, "base.en", "Should fall back to base.en when persisted model is absent")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "activeWhisperModel"), "base.en")
    }
}
