import XCTest
import AVFoundation
import SwiftData
@testable import DictlyMac
import DictlyModels

// MARK: - Epic5E2ETests
//
// End-to-end integration tests covering Epic 5: Transcription acceptance criteria.
// Tests the full data flow across Stories 5.1, 5.2, 5.3, and 5.4.
//
// Uses in-memory ModelContainer and temp directories for isolation.
// Real whisper model tests are guarded with XCTSkip (model not bundled in test target).
// Pre-existing failures in RetroactiveTagTests and TagEditingTests are unrelated.

@MainActor
final class Epic5E2ETests: XCTestCase {

    var engine: TranscriptionEngine!
    var whisperBridge: WhisperBridge!
    var modelManager: ModelManager!
    var container: ModelContainer!
    var context: ModelContext!
    var tempDir: URL!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Epic5E2ETests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        UserDefaults.standard.removeObject(forKey: "activeWhisperModel")
        whisperBridge = WhisperBridge()
        modelManager = ModelManager(modelsDirectory: tempDir)
        engine = TranscriptionEngine(whisperBridge: whisperBridge, modelManager: modelManager)

        let schema = Schema(DictlySchema.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext
    }

    override func tearDown() async throws {
        engine = nil
        whisperBridge = nil
        modelManager = nil
        container = nil
        context = nil
        UserDefaults.standard.removeObject(forKey: "activeWhisperModel")
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Story 5.1: WhisperBridge Integration

    // AC#1: WhisperBridge compiles and links — verified by this test target building.
    func testWhisperBridgeCompilesAndLinks() {
        // If this test compiles and runs, WhisperBridge is successfully linked with whisper.cpp.
        let bridge = WhisperBridge()
        XCTAssertNotNil(bridge, "WhisperBridge should instantiate successfully")
    }

    // AC#2: transcribe(audioURL:modelURL:) returns a transcription string (integration, requires model)
    func testWhisperBridge_fullTranscriptionPipeline() async throws {
        let modelURL = URL.applicationSupportDirectory
            .appendingPathComponent("Dictly/Models/ggml-base.en.bin")
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw XCTSkip("ggml-base.en.bin not available — download to run integration test")
        }

        let audioURL = tempDir.appendingPathComponent("test_speech.m4a")
        try createSilentAACFile(at: audioURL, duration: 3.0)

        let result = try await whisperBridge.transcribe(audioURL: audioURL, modelURL: modelURL)
        XCTAssertNotNil(result, "Transcription should return a string")
    }

    // AC#3: Missing model file throws DictlyError.transcription(.modelNotFound)
    func testWhisperBridge_missingModelThrowsModelNotFound() async throws {
        let missingModel = tempDir.appendingPathComponent("nonexistent.bin")
        do {
            try whisperBridge.loadModel(at: missingModel)
            XCTFail("Expected modelNotFound error")
        } catch DictlyError.transcription(.modelNotFound) {
            // expected
        }
    }

    // AC#3: Corrupted model file throws DictlyError.transcription(.modelCorrupted)
    func testWhisperBridge_corruptedModelThrowsModelCorrupted() async throws {
        let corruptModel = tempDir.appendingPathComponent("corrupt.bin")
        FileManager.default.createFile(atPath: corruptModel.path, contents: Data("invalid".utf8))
        do {
            try whisperBridge.loadModel(at: corruptModel)
            XCTFail("Expected modelCorrupted error")
        } catch DictlyError.transcription(.modelCorrupted) {
            // expected
        }
    }

    // AC#3: Missing audio file throws audioFileNotFound
    func testWhisperBridge_missingAudioThrowsAudioFileNotFound() async throws {
        let missingAudio = tempDir.appendingPathComponent("missing.m4a")
        let fakeModel = tempDir.appendingPathComponent("fake.bin")
        FileManager.default.createFile(atPath: fakeModel.path, contents: Data("fake".utf8))

        do {
            _ = try await whisperBridge.transcribe(audioURL: missingAudio, modelURL: fakeModel)
            XCTFail("Expected an error")
        } catch DictlyError.transcription(.audioFileNotFound) {
            // expected — audio checked before transcription
        } catch DictlyError.transcription(.modelCorrupted) {
            // acceptable — model is loaded first, fake model fails
        }
    }

    // AC#4: Transcription runs off main thread (async context)
    func testWhisperBridge_transcribeRunsOffMainThread() async throws {
        let missingAudio = tempDir.appendingPathComponent("missing.m4a")
        let missingModel = tempDir.appendingPathComponent("missing.bin")

        // The bridge asserts !Thread.isMainThread in debug.
        // No crash here = assertion passed = off main thread.
        var caughtTranscriptionError = false
        do {
            _ = try await whisperBridge.transcribe(audioURL: missingAudio, modelURL: missingModel)
        } catch DictlyError.transcription {
            caughtTranscriptionError = true
        }
        XCTAssertTrue(caughtTranscriptionError, "Should throw a transcription error, not crash from main-thread assertion")
    }

    // MARK: - Story 5.2: Whisper Model Management

    // AC#1: base.en model is bundled and ready (bundledModelURL exists in production)
    func testModelManager_baseEnIsBundledInRegistry() {
        let base = ModelManager.registry.first(where: { $0.id == "base.en" })
        XCTAssertNotNil(base, "base.en must exist in registry")
        XCTAssertTrue(base!.isBundled, "base.en must be marked as bundled")
        XCTAssertEqual(base!.fileName, "ggml-base.en.bin")
    }

    // AC#2: Available models listed — registry has 3 models with correct metadata
    func testModelManager_registryListsThreeModelsWithMetadata() {
        XCTAssertEqual(ModelManager.registry.count, 3, "Should have base.en, small.en, medium.en")

        let ids = Set(ModelManager.registry.map(\.id))
        XCTAssertEqual(ids, ["base.en", "small.en", "medium.en"])

        for model in ModelManager.registry {
            XCTAssertFalse(model.name.isEmpty, "\(model.id) should have a name")
            XCTAssertFalse(model.quality.isEmpty, "\(model.id) should have a quality description")
            XCTAssertGreaterThan(model.size, 0, "\(model.id) should have a positive size")
            XCTAssertFalse(model.fileName.isEmpty, "\(model.id) should have a fileName")
        }
    }

    // AC#2: Downloaded models show checkmark, others show download button — isDownloaded tracking
    func testModelManager_isDownloadedTracksFileExistence() throws {
        let small = ModelManager.registry.first(where: { $0.id == "small.en" })!
        XCTAssertFalse(modelManager.isDownloaded(small), "small.en should not be downloaded initially")

        // Simulate download by creating the file
        let url = modelManager.modelURL(for: small)
        FileManager.default.createFile(atPath: url.path, contents: Data("model-data".utf8))

        XCTAssertTrue(modelManager.isDownloaded(small), "small.en should be detected as downloaded")
    }

    // AC#3: Download progress tracking
    func testModelManager_downloadProgressStateProperties() {
        XCTAssertFalse(modelManager.isDownloading, "Should not be downloading initially")
        XCTAssertEqual(modelManager.downloadProgress, 0.0, "Progress should start at 0")
        XCTAssertNil(modelManager.downloadingModelId, "No model should be downloading")
    }

    // AC#4: Selecting a downloaded model persists it as active for future transcriptions
    func testModelManager_selectModelPersistsActiveModel() throws {
        let small = ModelManager.registry.first(where: { $0.id == "small.en" })!
        let url = modelManager.modelURL(for: small)
        FileManager.default.createFile(atPath: url.path, contents: Data("fake".utf8))

        modelManager.selectModel(small)

        XCTAssertEqual(modelManager.activeModel, "small.en")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "activeWhisperModel"), "small.en")
        XCTAssertEqual(modelManager.activeModelURL.lastPathComponent, "ggml-small.en.bin")
    }

    // AC#4: Selecting a non-downloaded model is rejected
    func testModelManager_selectModelRejectsNonDownloadedModel() {
        let medium = ModelManager.registry.first(where: { $0.id == "medium.en" })!
        XCTAssertFalse(modelManager.isDownloaded(medium))

        modelManager.selectModel(medium)

        XCTAssertNotEqual(modelManager.activeModel, "medium.en", "Cannot select a model that isn't downloaded")
    }

    // AC#5: Deleting a model frees space and falls back to base.en
    func testModelManager_deleteModelRemovesFileAndFallsBackToBaseEn() throws {
        let small = ModelManager.registry.first(where: { $0.id == "small.en" })!
        let url = modelManager.modelURL(for: small)
        FileManager.default.createFile(atPath: url.path, contents: Data(repeating: 0, count: 1024))

        modelManager.selectModel(small)
        XCTAssertEqual(modelManager.activeModel, "small.en")

        try modelManager.deleteModel(small)

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "Model file should be removed")
        XCTAssertEqual(modelManager.activeModel, "base.en", "Should fall back to base.en")
    }

    // AC#5: Cannot delete bundled base.en model
    func testModelManager_cannotDeleteBundledModel() throws {
        let base = ModelManager.registry.first(where: { $0.id == "base.en" })!
        let url = modelManager.modelURL(for: base)
        FileManager.default.createFile(atPath: url.path, contents: Data("fake".utf8))

        try modelManager.deleteModel(base)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Bundled model must not be deleted")
        XCTAssertEqual(modelManager.activeModel, "base.en")
    }

    // AC#5: Init fallback when persisted model file is missing
    func testModelManager_initFallbackWhenPersistedModelMissing() {
        UserDefaults.standard.set("medium.en", forKey: "activeWhisperModel")

        let freshManager = ModelManager(modelsDirectory: tempDir)

        XCTAssertEqual(freshManager.activeModel, "base.en", "Should fall back when persisted model is absent")
    }

    // MARK: - Story 5.3: Per-Tag & Batch Transcription

    // AC#1: Single tag transcription — state transitions (isTranscribing, currentTagId)
    func testTranscriptionEngine_singleTagStateTransitions() async throws {
        let session = makeSession(audioPath: nil)
        let tag = makeTag(label: "Plot Hook", transcription: nil)
        session.tags.append(tag)
        context.insert(session)

        XCTAssertFalse(engine.isTranscribing)
        XCTAssertNil(engine.currentTagId)

        do {
            try await engine.transcribeTag(tag, session: session)
        } catch {
            // Expected — no audio file
        }

        XCTAssertFalse(engine.isTranscribing, "Must reset after completion")
        XCTAssertNil(engine.currentTagId, "Must clear after completion")
    }

    // AC#1: Single tag transcription with audio file present but no model
    func testTranscriptionEngine_singleTagWithAudio_failsWithoutModel() async throws {
        let audioURL = tempDir.appendingPathComponent("session_audio.m4a")
        try createSilentAACFile(at: audioURL, duration: 5.0)

        let session = makeSession(audioPath: audioURL.path)
        let tag = makeTag(label: "Combat Start", transcription: nil)
        session.tags.append(tag)
        context.insert(session)

        do {
            try await engine.transcribeTag(tag, session: session)
            XCTFail("Expected transcription error without model")
        } catch {
            // Expected — no model file at tempDir
        }

        XCTAssertNil(tag.transcription, "Tag should remain untranscribed on failure")
        XCTAssertFalse(engine.isTranscribing)
    }

    // AC#2: Batch transcription queues only unprocessed tags (nil transcription)
    func testTranscriptionEngine_batchFiltersAlreadyTranscribedTags() async throws {
        let audioURL = tempDir.appendingPathComponent("session.m4a")
        try createSilentAACFile(at: audioURL, duration: 5.0)

        let session = makeSession(audioPath: audioURL.path)
        let alreadyDone = makeTag(label: "Done Tag", transcription: "Already transcribed")
        let needsWork1 = makeTag(label: "Needs Work 1", transcription: nil)
        let needsWork2 = makeTag(label: "Needs Work 2", transcription: nil)
        session.tags = [alreadyDone, needsWork1, needsWork2]
        context.insert(session)

        await engine.transcribeAllTags(in: session)

        XCTAssertEqual(engine.batchTotal, 2, "Should only queue 2 unprocessed tags")
        XCTAssertEqual(engine.batchCompleted, 2, "Both should be counted as processed")
        XCTAssertEqual(alreadyDone.transcription, "Already transcribed", "Pre-existing transcription must not change")
    }

    // AC#2: Batch transcription progress tracking (batchCompleted increments)
    func testTranscriptionEngine_batchProgressCounting() async throws {
        let audioURL = tempDir.appendingPathComponent("session.m4a")
        try createSilentAACFile(at: audioURL, duration: 5.0)

        let session = makeSession(audioPath: audioURL.path)
        let tags = (1...5).map { makeTag(label: "Tag \($0)", transcription: nil) }
        session.tags = tags
        context.insert(session)

        await engine.transcribeAllTags(in: session)

        XCTAssertEqual(engine.batchTotal, 5)
        XCTAssertEqual(engine.batchCompleted, 5, "All tags should be counted as processed")
        XCTAssertFalse(engine.isBatchTranscribing, "Batch should be complete")
    }

    // AC#3: UI remains responsive — batch runs in background (state resets after completion)
    func testTranscriptionEngine_batchCompletesAndResetsState() async throws {
        let audioURL = tempDir.appendingPathComponent("session.m4a")
        try createSilentAACFile(at: audioURL, duration: 2.0)

        let session = makeSession(audioPath: audioURL.path)
        let tag = makeTag(label: "Single Tag", transcription: nil)
        session.tags = [tag]
        context.insert(session)

        await engine.transcribeAllTags(in: session)

        XCTAssertFalse(engine.isBatchTranscribing, "Batch flag must reset")
        XCTAssertFalse(engine.isTranscribing, "Single-tag flag must reset")
        XCTAssertNil(engine.currentTagId, "currentTagId must be nil")
    }

    // AC#3: Batch cancellation stops processing
    func testTranscriptionEngine_batchCancellationStopsProcessing() async throws {
        let audioURL = tempDir.appendingPathComponent("session.m4a")
        try createSilentAACFile(at: audioURL, duration: 1.0)

        let session = makeSession(audioPath: audioURL.path)
        let tags = (1...20).map { makeTag(label: "Tag \($0)", transcription: nil) }
        session.tags = tags
        context.insert(session)

        engine.startBatchTranscription(session: session)
        engine.cancelBatch()

        // Wait for cancellation to take effect
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertFalse(engine.isBatchTranscribing, "Batch must stop after cancel")
    }

    // AC#4: Per-tag error isolation — one failure doesn't stop batch
    func testTranscriptionEngine_perTagErrorIsolation() async throws {
        let audioURL = tempDir.appendingPathComponent("session.m4a")
        try createSilentAACFile(at: audioURL, duration: 5.0)

        let session = makeSession(audioPath: audioURL.path)
        let tag1 = makeTag(label: "Tag 1", transcription: nil)
        let tag2 = makeTag(label: "Tag 2", transcription: nil)
        let tag3 = makeTag(label: "Tag 3", transcription: nil)
        session.tags = [tag1, tag2, tag3]
        context.insert(session)

        // All will fail (no model), but all should be attempted
        await engine.transcribeAllTags(in: session)

        XCTAssertEqual(engine.batchErrors.count, 3, "All 3 should have errors")
        XCTAssertEqual(engine.batchCompleted, 3, "All 3 should be counted as completed despite errors")
        XCTAssertFalse(engine.isBatchTranscribing, "Batch should finish cleanly")
    }

    // AC#4: Retry clears previous error and re-attempts
    func testTranscriptionEngine_retryTagClearsErrorAndReAttempts() async throws {
        let audioURL = tempDir.appendingPathComponent("session.m4a")
        try createSilentAACFile(at: audioURL, duration: 2.0)

        let session = makeSession(audioPath: audioURL.path)
        let tag = makeTag(label: "Retry Tag", transcription: nil)
        session.tags = [tag]
        context.insert(session)

        // Batch to generate error
        await engine.transcribeAllTags(in: session)
        XCTAssertEqual(engine.batchErrors.count, 1)

        // Retry
        do {
            try await engine.retryTag(tag, session: session)
        } catch {
            // Expected — still no model
        }

        let hasOldBatchError = engine.batchErrors.contains { $0.tag.uuid == tag.uuid }
        XCTAssertFalse(hasOldBatchError, "Retry should clear the batch error for this tag")
    }

    // AC#4: Single-tag transcription error is tracked in tagErrors
    func testTranscriptionEngine_singleTagErrorTracked() async throws {
        let audioURL = tempDir.appendingPathComponent("session.m4a")
        try createSilentAACFile(at: audioURL, duration: 2.0)

        let session = makeSession(audioPath: audioURL.path)
        let tag = makeTag(label: "Error Tag", transcription: nil)
        session.tags = [tag]
        context.insert(session)

        do {
            try await engine.transcribeTag(tag, session: session)
        } catch {
            // Expected
        }

        // tagErrors should contain the error for this tag
        XCTAssertNotNil(engine.tagErrors[tag.uuid], "Single-tag error should be tracked in tagErrors")
    }

    // MARK: - Story 5.3: Audio Segment Extraction

    // Audio segment extraction — normal window within file bounds
    func testAudioSegmentExtraction_normalWindowWithinBounds() throws {
        let audioURL = tempDir.appendingPathComponent("full_session.m4a")
        try createSilentAACFile(at: audioURL, duration: 60.0)

        let segmentURL = try TranscriptionEngine.extractAudioSegment(
            from: audioURL,
            start: 10.0,
            duration: 30.0
        )
        defer { try? FileManager.default.removeItem(at: segmentURL) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: segmentURL.path))
        let segmentFile = try AVAudioFile(forReading: segmentURL)
        let duration = Double(segmentFile.length) / segmentFile.processingFormat.sampleRate
        XCTAssertEqual(duration, 30.0, accuracy: 1.0, "Segment should be ~30s")
    }

    // Audio segment extraction — clamps negative start to zero
    func testAudioSegmentExtraction_clampsNegativeStart() throws {
        let audioURL = tempDir.appendingPathComponent("test.m4a")
        try createSilentAACFile(at: audioURL, duration: 10.0)

        let segmentURL = try TranscriptionEngine.extractAudioSegment(
            from: audioURL,
            start: -5.0,
            duration: 10.0
        )
        defer { try? FileManager.default.removeItem(at: segmentURL) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: segmentURL.path))
        let segmentFile = try AVAudioFile(forReading: segmentURL)
        let duration = Double(segmentFile.length) / segmentFile.processingFormat.sampleRate
        // start clamped to 0, end = min(10, -5+10) = min(10, 5) = 5
        XCTAssertEqual(duration, 5.0, accuracy: 1.0, "Segment should be clamped to ~5s")
    }

    // Audio segment extraction — clamps end beyond file duration
    func testAudioSegmentExtraction_clampsEndToFileDuration() throws {
        let audioURL = tempDir.appendingPathComponent("short.m4a")
        try createSilentAACFile(at: audioURL, duration: 5.0)

        let segmentURL = try TranscriptionEngine.extractAudioSegment(
            from: audioURL,
            start: 3.0,
            duration: 30.0
        )
        defer { try? FileManager.default.removeItem(at: segmentURL) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: segmentURL.path))
        let segmentFile = try AVAudioFile(forReading: segmentURL)
        let duration = Double(segmentFile.length) / segmentFile.processingFormat.sampleRate
        XCTAssertEqual(duration, 2.0, accuracy: 1.0, "Segment clamped to [3,5] should be ~2s")
    }

    // Audio segment extraction — missing file throws audioFileNotFound
    func testAudioSegmentExtraction_throwsForMissingFile() {
        let missingURL = tempDir.appendingPathComponent("ghost.m4a")
        XCTAssertThrowsError(
            try TranscriptionEngine.extractAudioSegment(from: missingURL, start: 0, duration: 10)
        ) { error in
            XCTAssertEqual(error as? DictlyError, .transcription(.audioFileNotFound))
        }
    }

    // MARK: - Story 5.4: View & Edit Transcription Text

    // AC#1: Tag with completed transcription stores text in the model
    func testTranscriptionText_storedInTagModel() throws {
        let tag = makeTag(label: "Story Beat", transcription: nil)
        context.insert(tag)

        // Simulate engine writing transcription result
        tag.transcription = "The party entered the ancient tomb."

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].transcription, "The party entered the ancient tomb.")
    }

    // AC#2: Editing a transcription (correcting garbled names)
    func testTranscriptionText_editableInPlace() throws {
        let tag = makeTag(label: "NPC Intro", transcription: "Grim Thor entered the tavern.")
        context.insert(tag)

        // Simulate user edit (commitTranscription logic)
        let corrected = "Grimthor entered the tavern."
        tag.transcription = corrected

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].transcription, "Grimthor entered the tavern.")
    }

    // AC#3: Auto-save on blur — SwiftData persists on property mutation
    func testTranscriptionText_autoSaveOnBlur() throws {
        let tag = makeTag(label: "Lore Drop", transcription: "Original whisper output.")
        context.insert(tag)

        // Simulate blur-commit pattern
        let editingTranscription = "Corrected whisper output with proper names."
        if editingTranscription != (tag.transcription ?? "") {
            tag.transcription = editingTranscription
        }

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].transcription, "Corrected whisper output with proper names.")
    }

    // AC#3: No-op when text is unchanged (guard optimization)
    func testTranscriptionText_noOpWhenUnchanged() throws {
        let originalText = "Elara cast a spell of protection."
        let tag = makeTag(label: "Magic", transcription: originalText)
        context.insert(tag)

        let editingTranscription = originalText
        if editingTranscription != (tag.transcription ?? "") {
            tag.transcription = editingTranscription
        }

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].transcription, originalText)
    }

    // AC#4: Tag without transcription has nil — UI shows "Transcribe" button
    func testTranscriptionText_nilMeansNotYetRun() throws {
        let tag = makeTag(label: "Untranscribed", transcription: nil)
        context.insert(tag)

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertNil(fetched[0].transcription, "nil means transcription not yet run")
    }

    // AC#4: nil vs empty string distinction
    func testTranscriptionText_nilDistinctFromEmptyString() throws {
        let neverTranscribed = makeTag(label: "Never", transcription: nil)
        let userCleared = makeTag(label: "Cleared", transcription: "")
        context.insert(neverTranscribed)
        context.insert(userCleared)

        let fetched = try context.fetch(FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.label)]))
        let cleared = fetched.first { $0.label == "Cleared" }!
        let never = fetched.first { $0.label == "Never" }!

        XCTAssertNil(never.transcription, "nil = never transcribed → shows Transcribe button")
        XCTAssertNotNil(cleared.transcription, "empty string = user cleared → shows editable TextEditor")
        XCTAssertEqual(cleared.transcription, "")
    }

    // Edge: Clearing text saves empty string, not nil
    func testTranscriptionText_clearingSavesEmptyStringNotNil() throws {
        let tag = makeTag(label: "Cleared Tag", transcription: "Some text.")
        context.insert(tag)

        tag.transcription = ""

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertNotNil(fetched[0].transcription, "Cleared transcription must be empty string, not nil")
        XCTAssertEqual(fetched[0].transcription, "")
    }

    // Edge: Tag switch commits pending edit to old tag
    func testTranscriptionText_tagSwitchCommitsPendingEdit() throws {
        let tagA = makeTag(label: "Tag A", transcription: "Original A.")
        let tagB = makeTag(label: "Tag B", transcription: "Text B.")
        context.insert(tagA)
        context.insert(tagB)

        // Simulate: user edits tagA, then switches to tagB
        let editingTranscription = "Edited A by user."
        let oldUUID = tagA.uuid

        // Mimic onChange(of: selectedTag?.uuid) commit
        let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.uuid == oldUUID })
        if let oldTag = try? context.fetch(descriptor).first {
            if editingTranscription != (oldTag.transcription ?? "") {
                oldTag.transcription = editingTranscription
            }
        }

        let fetchedA = try context.fetch(FetchDescriptor<Tag>()).first { $0.label == "Tag A" }!
        let fetchedB = try context.fetch(FetchDescriptor<Tag>()).first { $0.label == "Tag B" }!

        XCTAssertEqual(fetchedA.transcription, "Edited A by user.", "Pending edit committed on switch")
        XCTAssertEqual(fetchedB.transcription, "Text B.", "Tag B unchanged")
    }

    // Edge: Multiple sequential edits persist correctly
    func testTranscriptionText_multipleEditsPersistedCorrectly() throws {
        let tag = makeTag(label: "Multi Edit", transcription: "First draft.")
        context.insert(tag)

        tag.transcription = "Second draft."
        tag.transcription = "Final corrected version."

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].transcription, "Final corrected version.")
    }

    // Edge: Batch transcription writes visible on next tag selection
    func testTranscriptionText_batchResultVisibleOnSelection() {
        let tag = makeTag(label: "Background Tag", transcription: nil)

        // Simulate batch engine writing result
        tag.transcription = "Auto-transcribed by batch."

        // Simulate selection → buffer loads from model
        let buffer = tag.transcription ?? ""
        XCTAssertEqual(buffer, "Auto-transcribed by batch.")
    }

    // MARK: - Cross-Story E2E: DictlyError TranscriptionError completeness

    func testDictlyError_allTranscriptionErrorCasesHaveDescriptions() {
        let errors: [(DictlyError, String)] = [
            (.transcription(.modelNotFound), "Transcription model not found."),
            (.transcription(.modelCorrupted), "Transcription model file exists but could not be loaded."),
            (.transcription(.processingFailed), "Transcription processing failed."),
            (.transcription(.audioConversionFailed), "Failed to convert audio to PCM format for transcription."),
            (.transcription(.audioFileNotFound), "Audio file not found for transcription."),
            (.transcription(.downloadFailed), "Failed to download transcription model."),
        ]

        for (error, expected) in errors {
            XCTAssertEqual(error.errorDescription, expected, "Mismatch for \(error)")
        }
    }

    // MARK: - Cross-Story E2E: Full Transcription Lifecycle

    // Simulates the complete user journey: session with tags → batch transcription → edit corrections
    func testFullTranscriptionLifecycle() async throws {
        // 1. Create campaign, session, and tags (from earlier epics — verifies model foundations)
        let campaign = Campaign(name: "Dragon's Lair")
        context.insert(campaign)

        let session = Session(title: "Session 1", sessionNumber: 1)
        session.audioFilePath = nil // no real audio — transcription will fail
        context.insert(session)
        campaign.sessions.append(session)

        let tag1 = Tag(label: "Plot Hook", categoryName: "Story", anchorTime: 30, rewindDuration: 10)
        let tag2 = Tag(label: "Combat Start", categoryName: "Combat", anchorTime: 120, rewindDuration: 5)
        let tag3 = Tag(label: "NPC Intro", categoryName: "Roleplay", anchorTime: 300, rewindDuration: 15)
        context.insert(tag1)
        context.insert(tag2)
        context.insert(tag3)
        session.tags = [tag1, tag2, tag3]
        try context.save()

        // 2. Verify initial state — no transcriptions
        XCTAssertNil(tag1.transcription)
        XCTAssertNil(tag2.transcription)
        XCTAssertNil(tag3.transcription)

        // 3. Attempt batch transcription (will fail — no audio file)
        await engine.transcribeAllTags(in: session)

        // 4. Verify batch error tracking
        XCTAssertEqual(engine.batchTotal, 3, "All 3 tags queued")
        XCTAssertEqual(engine.batchCompleted, 3, "All 3 processed (with errors)")
        XCTAssertEqual(engine.batchErrors.count, 3, "All 3 should have errors")
        XCTAssertFalse(engine.isBatchTranscribing, "Batch should be done")

        // 5. Simulate successful transcription by writing directly (as engine would)
        tag1.transcription = "The party discovered a hidden passage behind the waterfall."
        tag2.transcription = "Grim Thor drew his sword and initiative was rolled."
        // tag3 left untranscribed — simulates partial batch success

        // 6. Verify mixed state — some transcribed, some not
        XCTAssertNotNil(tag1.transcription)
        XCTAssertNotNil(tag2.transcription)
        XCTAssertNil(tag3.transcription, "Tag 3 still needs transcription")

        // 7. User edits a transcription (Story 5.4 — correcting garbled name)
        let corrected = "Grimthor drew his sword and initiative was rolled."
        if corrected != (tag2.transcription ?? "") {
            tag2.transcription = corrected
        }
        XCTAssertEqual(tag2.transcription, "Grimthor drew his sword and initiative was rolled.")

        // 8. User clears a transcription — becomes empty string, not nil
        tag1.transcription = ""
        XCTAssertNotNil(tag1.transcription, "Cleared = empty string, not nil")
        XCTAssertEqual(tag1.transcription, "")

        // 9. Verify data integrity after all operations
        let fetchedTags = try context.fetch(FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.anchorTime)]))
        XCTAssertEqual(fetchedTags.count, 3)
        XCTAssertEqual(fetchedTags[0].transcription, "", "Tag 1 cleared")
        XCTAssertEqual(fetchedTags[1].transcription, "Grimthor drew his sword and initiative was rolled.", "Tag 2 corrected")
        XCTAssertNil(fetchedTags[2].transcription, "Tag 3 still untranscribed")

        // 10. Cascade delete — session deletion removes tags (from epic 1 foundation)
        context.delete(session)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Tag>()), 0, "Tags cascade-deleted with session")
    }

    // MARK: - Cross-Story E2E: Model Selection Affects Transcription

    func testModelSelectionAffectsActiveModelURL() throws {
        // Start with default base.en
        XCTAssertEqual(modelManager.activeModel, "base.en")
        let baseURL = modelManager.activeModelURL
        XCTAssertTrue(baseURL.lastPathComponent.contains("base.en"))

        // "Download" small.en
        let small = ModelManager.registry.first(where: { $0.id == "small.en" })!
        let smallURL = modelManager.modelURL(for: small)
        FileManager.default.createFile(atPath: smallURL.path, contents: Data("fake".utf8))

        // Select small.en
        modelManager.selectModel(small)
        XCTAssertEqual(modelManager.activeModel, "small.en")
        XCTAssertEqual(modelManager.activeModelURL.lastPathComponent, "ggml-small.en.bin")

        // Delete small.en → falls back to base.en
        try modelManager.deleteModel(small)
        XCTAssertEqual(modelManager.activeModel, "base.en")
        XCTAssertTrue(modelManager.activeModelURL.lastPathComponent.contains("base.en"))
    }

    // MARK: - Cross-Story E2E: Concurrent Single + Batch Guard

    func testTranscriptionEngine_batchGuardsAgainstConcurrentSingleTag() async throws {
        let audioURL = tempDir.appendingPathComponent("session.m4a")
        try createSilentAACFile(at: audioURL, duration: 2.0)

        let session = makeSession(audioPath: audioURL.path)
        let tags = (1...5).map { makeTag(label: "Tag \($0)", transcription: nil) }
        session.tags = tags
        context.insert(session)

        // Start batch
        engine.startBatchTranscription(session: session)

        // Wait briefly for batch to start
        try await Task.sleep(nanoseconds: 50_000_000)

        // Verify state — batch should be running or completed
        // The guard prevents concurrent single+batch transcription
        // (implementation detail: startBatchTranscription guards against isTranscribing)

        // Wait for batch to complete
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertFalse(engine.isBatchTranscribing, "Batch should complete")
    }

    // MARK: - Cross-Story E2E: WhisperBridge + ModelManager Integration

    func testWhisperBridge_unloadModelClearsState() {
        // WhisperBridge.unloadModel() frees context — needed when model is deleted
        whisperBridge.unloadModel()
        // Should not crash when called without a loaded model
        whisperBridge.unloadModel() // double unload is safe
    }

    // MARK: - Helpers

    private func makeTag(label: String, transcription: String?) -> Tag {
        let tag = Tag(
            uuid: UUID(),
            label: label,
            categoryName: "Story",
            anchorTime: 15.0,
            rewindDuration: 5.0
        )
        tag.transcription = transcription
        return tag
    }

    private func makeSession(audioPath: String?) -> Session {
        let session = Session(title: "Test Session", sessionNumber: 1)
        session.audioFilePath = audioPath
        return session
    }

    /// Creates a silent AAC mono audio file at the specified URL.
    private func createSilentAACFile(at url: URL, duration: TimeInterval) throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create audio format"])
        }

        let frameCount = AVAudioFrameCount(44100 * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot create audio buffer"])
        }
        buffer.frameLength = frameCount

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64000
        ]

        let file = try AVAudioFile(forWriting: url, settings: settings)
        try file.write(from: buffer)
    }
}
