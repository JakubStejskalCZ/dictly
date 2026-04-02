import XCTest
import SwiftData
@testable import DictlyModels
@testable import DictlyStorage

/// End-to-end integration tests covering Epic 3 acceptance criteria.
/// Tests the full data flow across Stories 3.1 through 3.4:
/// bundle format & serialization, transfer preparation, and import with deduplication.
///
/// UI-layer tests (AirDrop share sheet, Bonjour discovery, TransferPrompt states)
/// are covered in platform-specific test targets (DictlyiOS/Tests, DictlyMacTests).
/// These tests validate the shared data layer that underpins all four stories.
@MainActor
final class Epic3E2ETests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var tempDir: URL!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Schema(DictlySchema.all), configurations: config)
        context = container.mainContext
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Epic3E2ETests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        context = nil
        container = nil
        if let tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }

    // MARK: - Helpers

    /// Creates a fully populated Session with campaign, tags, and audio path for testing.
    private func makeTestSession(
        uuid: UUID = UUID(),
        title: String = "Session 3",
        sessionNumber: Int = 3,
        date: Date = Date(),
        duration: TimeInterval = 7200,
        locationName: String? = "Game Store",
        locationLatitude: Double? = 47.6062,
        locationLongitude: Double? = -122.3321,
        summaryNote: String? = "The party found the artifact",
        pauseIntervals: [PauseInterval] = [PauseInterval(start: 1800, end: 1860)]
    ) -> Session {
        let session = Session(
            uuid: uuid,
            title: title,
            sessionNumber: sessionNumber,
            date: date,
            duration: duration,
            locationName: locationName,
            locationLatitude: locationLatitude,
            locationLongitude: locationLongitude,
            summaryNote: summaryNote
        )
        session.pauseIntervals = pauseIntervals
        return session
    }

    private func makeTestCampaign(
        uuid: UUID = UUID(),
        name: String = "Curse of Strahd",
        descriptionText: String = "Gothic horror campaign"
    ) -> Campaign {
        Campaign(uuid: uuid, name: name, descriptionText: descriptionText)
    }

    private func makeTestTags(count: Int = 3) -> [Tag] {
        let categories = ["Combat", "Story", "Roleplay", "World", "Meta"]
        return (0..<count).map { i in
            Tag(
                label: "Tag \(i + 1)",
                categoryName: categories[i % categories.count],
                anchorTime: TimeInterval(i * 120 + 60),
                rewindDuration: 10,
                notes: i == 0 ? "Important moment" : nil,
                transcription: i == 1 ? "The dragon appeared..." : nil
            )
        }
    }

    /// Creates a valid .dictly bundle on disk and returns the URL.
    private func createTestBundle(
        session: Session,
        audioData: Data = Data("fake-aac-audio-data-for-testing".utf8)
    ) throws -> URL {
        let bundleURL = tempDir.appendingPathComponent("\(session.uuid.uuidString).dictly")
        let serializer = BundleSerializer()
        try serializer.serialize(session: session, audioData: audioData, to: bundleURL)
        return bundleURL
    }

    /// Simulates the full import flow that ImportService performs on the Mac.
    private func importBundle(
        from url: URL,
        into context: ModelContext
    ) throws -> (session: Session, campaign: Campaign?) {
        let serializer = BundleSerializer()
        let (bundle, audioData) = try serializer.deserialize(from: url)

        // Deduplication check
        let targetUUID = bundle.session.uuid
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.uuid == targetUUID }
        )
        let existing = try context.fetch(descriptor)
        if !existing.isEmpty {
            throw DictlyError.import(.duplicateDetected)
        }

        // Campaign resolution
        var resolvedCampaign: Campaign?
        if let campaignDTO = bundle.campaign {
            let campaignUUID = campaignDTO.uuid
            let campaignDescriptor = FetchDescriptor<Campaign>(
                predicate: #Predicate<Campaign> { $0.uuid == campaignUUID }
            )
            let existingCampaigns = try context.fetch(campaignDescriptor)
            if let found = existingCampaigns.first {
                resolvedCampaign = found
            } else {
                let newCampaign = Campaign.from(campaignDTO)
                context.insert(newCampaign)
                resolvedCampaign = newCampaign
            }
        }

        // Create session and tags
        let newSession = Session.from(bundle.session)
        context.insert(newSession)

        let tags = bundle.tags.map { Tag.from($0) }
        for tag in tags {
            context.insert(tag)
            newSession.tags.append(tag)
        }

        if let campaign = resolvedCampaign {
            newSession.campaign = campaign
        }

        // Audio storage
        let audioDir = tempDir.appendingPathComponent("AudioStorage")
        try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        let audioDestination = audioDir.appendingPathComponent("\(newSession.uuid).aac")
        try audioData.write(to: audioDestination)
        newSession.audioFilePath = audioDestination.path

        try context.save()
        return (newSession, resolvedCampaign)
    }

    // MARK: - Story 3.1: .dictly Bundle Format & Serialization

    // AC#1: Bundle contains audio.aac + session.json with camelCase keys
    func testBundleCreation_containsAudioAndSessionJSON() throws {
        let campaign = makeTestCampaign()
        let session = makeTestSession()
        let tags = makeTestTags(count: 2)

        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)
        for tag in tags {
            context.insert(tag)
            session.tags.append(tag)
        }
        try context.save()

        let audioData = Data("test-audio-content".utf8)
        let bundleURL = try createTestBundle(session: session, audioData: audioData)

        // Verify bundle directory structure
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: bundleURL.appendingPathComponent("audio.aac").path),
                       "Bundle must contain audio.aac")
        XCTAssertTrue(fm.fileExists(atPath: bundleURL.appendingPathComponent("session.json").path),
                       "Bundle must contain session.json")

        // Verify JSON uses camelCase keys
        let jsonData = try Data(contentsOf: bundleURL.appendingPathComponent("session.json"))
        let jsonString = String(data: jsonData, encoding: .utf8)!
        XCTAssertTrue(jsonString.contains("\"sessionNumber\""), "JSON must use camelCase keys")
        XCTAssertTrue(jsonString.contains("\"anchorTime\""), "JSON must use camelCase keys")
        XCTAssertTrue(jsonString.contains("\"categoryName\""), "JSON must use camelCase keys")
        XCTAssertTrue(jsonString.contains("\"rewindDuration\""), "JSON must use camelCase keys")
        XCTAssertTrue(jsonString.contains("\"descriptionText\""), "JSON must use camelCase keys")
        XCTAssertTrue(jsonString.contains("\"version\""), "JSON must include version field")
    }

    // AC#2: Valid bundle unpacks completely with all data intact
    func testBundleUnpack_restoresAllData() throws {
        let campaign = makeTestCampaign()
        let session = makeTestSession()
        let tags = makeTestTags(count: 3)

        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)
        for tag in tags {
            context.insert(tag)
            session.tags.append(tag)
        }
        try context.save()

        let audioData = Data("audio-bytes-for-testing".utf8)
        let bundleURL = try createTestBundle(session: session, audioData: audioData)

        // Deserialize
        let serializer = BundleSerializer()
        let (bundle, restoredAudio) = try serializer.deserialize(from: bundleURL)

        // Audio data intact
        XCTAssertEqual(restoredAudio, audioData, "Audio data must be identical after round-trip")

        // Session metadata intact
        XCTAssertEqual(bundle.session.uuid, session.uuid)
        XCTAssertEqual(bundle.session.title, session.title)
        XCTAssertEqual(bundle.session.sessionNumber, session.sessionNumber)
        XCTAssertEqual(bundle.session.duration, session.duration)
        XCTAssertEqual(bundle.session.locationName, session.locationName)
        XCTAssertEqual(bundle.session.locationLatitude, session.locationLatitude)
        XCTAssertEqual(bundle.session.locationLongitude, session.locationLongitude)
        XCTAssertEqual(bundle.session.summaryNote, session.summaryNote)
        XCTAssertEqual(bundle.session.pauseIntervals.count, 1)
        XCTAssertEqual(bundle.session.pauseIntervals[0].start, 1800)
        XCTAssertEqual(bundle.session.pauseIntervals[0].end, 1860)

        // Tags intact
        XCTAssertEqual(bundle.tags.count, 3, "All tags must be preserved")
        for (i, tagDTO) in bundle.tags.sorted(by: { $0.anchorTime < $1.anchorTime }).enumerated() {
            let originalTag = tags.sorted(by: { $0.anchorTime < $1.anchorTime })[i]
            XCTAssertEqual(tagDTO.uuid, originalTag.uuid)
            XCTAssertEqual(tagDTO.label, originalTag.label)
            XCTAssertEqual(tagDTO.categoryName, originalTag.categoryName)
            XCTAssertEqual(tagDTO.anchorTime, originalTag.anchorTime)
            XCTAssertEqual(tagDTO.rewindDuration, originalTag.rewindDuration)
            XCTAssertEqual(tagDTO.notes, originalTag.notes)
            XCTAssertEqual(tagDTO.transcription, originalTag.transcription)
        }

        // Campaign intact
        XCTAssertNotNil(bundle.campaign, "Campaign must be preserved")
        XCTAssertEqual(bundle.campaign?.uuid, campaign.uuid)
        XCTAssertEqual(bundle.campaign?.name, campaign.name)
        XCTAssertEqual(bundle.campaign?.descriptionText, campaign.descriptionText)

        // Version field
        XCTAssertEqual(bundle.version, 1)
    }

    // AC#3: Corrupted bundles throw DictlyError.transfer(.bundleCorrupted)
    func testCorruptedBundle_missingAudio_throwsBundleCorrupted() throws {
        let bundleURL = tempDir.appendingPathComponent("corrupt.dictly")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        // Only write session.json, no audio.aac
        try Data("{}".utf8).write(to: bundleURL.appendingPathComponent("session.json"))

        let serializer = BundleSerializer()
        XCTAssertThrowsError(try serializer.deserialize(from: bundleURL)) { error in
            XCTAssertEqual(error as? DictlyError, DictlyError.transfer(.bundleCorrupted))
        }
    }

    func testCorruptedBundle_missingJSON_throwsBundleCorrupted() throws {
        let bundleURL = tempDir.appendingPathComponent("corrupt2.dictly")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        // Only write audio.aac, no session.json
        try Data("audio".utf8).write(to: bundleURL.appendingPathComponent("audio.aac"))

        let serializer = BundleSerializer()
        XCTAssertThrowsError(try serializer.deserialize(from: bundleURL)) { error in
            XCTAssertEqual(error as? DictlyError, DictlyError.transfer(.bundleCorrupted))
        }
    }

    func testCorruptedBundle_invalidJSON_throwsBundleCorrupted() throws {
        let bundleURL = tempDir.appendingPathComponent("corrupt3.dictly")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try Data("audio".utf8).write(to: bundleURL.appendingPathComponent("audio.aac"))
        try Data("not-valid-json!!!".utf8).write(to: bundleURL.appendingPathComponent("session.json"))

        let serializer = BundleSerializer()
        XCTAssertThrowsError(try serializer.deserialize(from: bundleURL)) { error in
            XCTAssertEqual(error as? DictlyError, DictlyError.transfer(.bundleCorrupted))
        }
    }

    func testCorruptedBundle_emptyAudio_throwsBundleCorrupted() throws {
        let bundleURL = tempDir.appendingPathComponent("corrupt4.dictly")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try Data().write(to: bundleURL.appendingPathComponent("audio.aac"))
        try Data("{}".utf8).write(to: bundleURL.appendingPathComponent("session.json"))

        let serializer = BundleSerializer()
        XCTAssertThrowsError(try serializer.deserialize(from: bundleURL)) { error in
            XCTAssertEqual(error as? DictlyError, DictlyError.transfer(.bundleCorrupted))
        }
    }

    func testCorruptedBundle_emptyJSON_throwsBundleCorrupted() throws {
        let bundleURL = tempDir.appendingPathComponent("corrupt5.dictly")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try Data("audio".utf8).write(to: bundleURL.appendingPathComponent("audio.aac"))
        try Data().write(to: bundleURL.appendingPathComponent("session.json"))

        let serializer = BundleSerializer()
        XCTAssertThrowsError(try serializer.deserialize(from: bundleURL)) { error in
            XCTAssertEqual(error as? DictlyError, DictlyError.transfer(.bundleCorrupted))
        }
    }

    // AC#3: Serializing empty audio throws
    func testSerialize_emptyAudioData_throwsBundleCorrupted() throws {
        let session = makeTestSession()
        context.insert(session)
        try context.save()

        let bundleURL = tempDir.appendingPathComponent("empty-audio.dictly")
        let serializer = BundleSerializer()
        XCTAssertThrowsError(try serializer.serialize(session: session, audioData: Data(), to: bundleURL)) { error in
            XCTAssertEqual(error as? DictlyError, DictlyError.transfer(.bundleCorrupted))
        }
    }

    // AC#4: Round-trip test — serialize then deserialize produces identical data
    func testRoundTrip_serializeDeserialize_identicalData() throws {
        let campaign = makeTestCampaign()
        let session = makeTestSession()
        let tags = makeTestTags(count: 5)

        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)
        for tag in tags {
            context.insert(tag)
            session.tags.append(tag)
        }
        try context.save()

        let originalAudio = Data(repeating: 0xAB, count: 1024)
        let bundleURL = try createTestBundle(session: session, audioData: originalAudio)

        let serializer = BundleSerializer()
        let (bundle, restoredAudio) = try serializer.deserialize(from: bundleURL)

        // Audio identical
        XCTAssertEqual(restoredAudio, originalAudio)

        // DTO round-trip via model factory methods
        let restoredSession = Session.from(bundle.session)
        XCTAssertEqual(restoredSession.uuid, session.uuid)
        XCTAssertEqual(restoredSession.title, session.title)
        XCTAssertEqual(restoredSession.sessionNumber, session.sessionNumber)
        XCTAssertEqual(restoredSession.duration, session.duration)
        XCTAssertEqual(restoredSession.locationName, session.locationName)
        XCTAssertEqual(restoredSession.locationLatitude, session.locationLatitude)
        XCTAssertEqual(restoredSession.locationLongitude, session.locationLongitude)
        XCTAssertEqual(restoredSession.summaryNote, session.summaryNote)
        XCTAssertEqual(restoredSession.pauseIntervals, session.pauseIntervals)

        let restoredTags = bundle.tags.map { Tag.from($0) }
        XCTAssertEqual(restoredTags.count, tags.count)
        for restoredTag in restoredTags {
            let original = tags.first { $0.uuid == restoredTag.uuid }
            XCTAssertNotNil(original, "Each restored tag must match an original")
            XCTAssertEqual(restoredTag.label, original?.label)
            XCTAssertEqual(restoredTag.categoryName, original?.categoryName)
            XCTAssertEqual(restoredTag.anchorTime, original?.anchorTime)
            XCTAssertEqual(restoredTag.rewindDuration, original?.rewindDuration)
            XCTAssertEqual(restoredTag.notes, original?.notes)
            XCTAssertEqual(restoredTag.transcription, original?.transcription)
        }

        if let campaignDTO = bundle.campaign {
            let restoredCampaign = Campaign.from(campaignDTO)
            XCTAssertEqual(restoredCampaign.uuid, campaign.uuid)
            XCTAssertEqual(restoredCampaign.name, campaign.name)
            XCTAssertEqual(restoredCampaign.descriptionText, campaign.descriptionText)
        } else {
            XCTFail("Campaign should be present in bundle")
        }
    }

    // Edge case: session with zero tags
    func testRoundTrip_sessionWithZeroTags() throws {
        let session = makeTestSession()
        context.insert(session)
        try context.save()

        let bundleURL = try createTestBundle(session: session)

        let serializer = BundleSerializer()
        let (bundle, _) = try serializer.deserialize(from: bundleURL)

        XCTAssertEqual(bundle.tags.count, 0, "Bundle should have zero tags")
        XCTAssertNil(bundle.campaign, "Bundle should have no campaign")
    }

    // Edge case: session with no campaign
    func testRoundTrip_sessionWithNoCampaign() throws {
        let session = makeTestSession()
        let tags = makeTestTags(count: 2)
        context.insert(session)
        for tag in tags {
            context.insert(tag)
            session.tags.append(tag)
        }
        try context.save()

        let bundleURL = try createTestBundle(session: session)

        let serializer = BundleSerializer()
        let (bundle, _) = try serializer.deserialize(from: bundleURL)

        XCTAssertNil(bundle.campaign, "Campaign should be nil when session has no campaign")
        XCTAssertEqual(bundle.tags.count, 2)
    }

    // Edge case: session with optional fields nil
    func testRoundTrip_sessionWithNilOptionalFields() throws {
        let session = Session(
            title: "Minimal Session",
            sessionNumber: 1,
            duration: 300,
            locationName: nil,
            locationLatitude: nil,
            locationLongitude: nil,
            summaryNote: nil
        )
        context.insert(session)
        try context.save()

        let bundleURL = try createTestBundle(session: session)

        let serializer = BundleSerializer()
        let (bundle, _) = try serializer.deserialize(from: bundleURL)

        XCTAssertNil(bundle.session.locationName)
        XCTAssertNil(bundle.session.locationLatitude)
        XCTAssertNil(bundle.session.locationLongitude)
        XCTAssertNil(bundle.session.summaryNote)
        XCTAssertEqual(bundle.session.pauseIntervals.count, 0)
    }

    // MARK: - Story 3.2: AirDrop Transfer from iOS (Data Layer)

    // AC#1: Bundle preparation creates valid .dictly directory for AirDrop
    func testTransferPreparation_createsBundleInTempDirectory() throws {
        let campaign = makeTestCampaign()
        let session = makeTestSession()
        let tags = makeTestTags(count: 2)

        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)
        for tag in tags {
            context.insert(tag)
            session.tags.append(tag)
        }
        try context.save()

        // Simulate TransferService._prepareBundleSync: read audio, serialize bundle
        let audioData = Data("simulated-aac-audio-bytes".utf8)
        let bundleName = UUID().uuidString + ".dictly"
        let bundleURL = tempDir.appendingPathComponent(bundleName)

        let serializer = BundleSerializer()
        try serializer.serialize(session: session, audioData: audioData, to: bundleURL)

        // Bundle exists and is a valid directory
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleURL.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue, "Bundle must be a directory")

        // Can be deserialized (validates it's a valid bundle for transfer)
        let (bundle, audio) = try serializer.deserialize(from: bundleURL)
        XCTAssertEqual(bundle.session.uuid, session.uuid)
        XCTAssertEqual(audio, audioData)
    }

    // AC#4/5: Transfer failure doesn't corrupt session data (session remains in SwiftData)
    func testTransferFailure_sessionDataUntouched() throws {
        let campaign = makeTestCampaign()
        let session = makeTestSession()
        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)
        try context.save()

        // Simulate failed transfer — attempt to create bundle then clean up
        let bundleURL = tempDir.appendingPathComponent("failed-transfer.dictly")
        let audioData = Data("audio".utf8)
        try BundleSerializer().serialize(session: session, audioData: audioData, to: bundleURL)

        // Simulate cleanup after failure (as TransferService does)
        try FileManager.default.removeItem(at: bundleURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: bundleURL.path), "Temp bundle should be cleaned up")

        // Session still intact in SwiftData
        let sessions = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].uuid, session.uuid)
        XCTAssertEqual(sessions[0].campaign?.name, campaign.name)
    }

    // MARK: - Story 3.3: Local Network Transfer (Data Layer)

    // AC#2: Wire protocol — bundle can be serialized to payload and reconstructed
    func testWireProtocol_bundlePayloadRoundTrip() throws {
        let campaign = makeTestCampaign()
        let session = makeTestSession()
        let tags = makeTestTags(count: 2)

        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)
        for tag in tags {
            context.insert(tag)
            session.tags.append(tag)
        }
        try context.save()

        let audioData = Data(repeating: 0xCD, count: 2048)
        let bundleURL = try createTestBundle(session: session, audioData: audioData)

        // Simulate sender: read bundle files and create wire payload
        // Wire format: [4 bytes: json length][session.json][audio.aac]
        let sessionJSON = try Data(contentsOf: bundleURL.appendingPathComponent("session.json"))
        let bundleAudio = try Data(contentsOf: bundleURL.appendingPathComponent("audio.aac"))

        var jsonLength = UInt32(sessionJSON.count).bigEndian
        let header = Data(bytes: &jsonLength, count: 4)
        let payload = header + sessionJSON + bundleAudio

        // Simulate receiver: reconstruct bundle from wire payload
        let receivedDir = tempDir.appendingPathComponent("received.dictly")
        try FileManager.default.createDirectory(at: receivedDir, withIntermediateDirectories: true)

        let receivedJsonLength = payload.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let receivedJSON = payload[4..<(4 + Int(receivedJsonLength))]
        let receivedAudio = payload[(4 + Int(receivedJsonLength))...]

        try receivedJSON.write(to: receivedDir.appendingPathComponent("session.json"))
        try receivedAudio.write(to: receivedDir.appendingPathComponent("audio.aac"))

        // Deserialize reconstructed bundle
        let serializer = BundleSerializer()
        let (bundle, restoredAudio) = try serializer.deserialize(from: receivedDir)

        XCTAssertEqual(bundle.session.uuid, session.uuid)
        XCTAssertEqual(bundle.session.title, session.title)
        XCTAssertEqual(bundle.tags.count, 2)
        XCTAssertNotNil(bundle.campaign)
        XCTAssertEqual(bundle.campaign?.uuid, campaign.uuid)
        XCTAssertEqual(restoredAudio, audioData)
    }

    // AC#3 + AC#4: TransferError cases have descriptive error messages
    func testTransferError_allNetworkCases_haveDescriptions() {
        let errors: [(DictlyError, String)] = [
            (.transfer(.connectionFailed), "Could not connect to Mac. Check that Dictly is running."),
            (.transfer(.transferInterrupted), "Transfer interrupted. Check your Wi-Fi connection and try again."),
            (.transfer(.timeout), "Transfer timed out."),
            (.transfer(.networkUnavailable), "Network unavailable for transfer."),
            (.transfer(.peerNotFound), "Transfer peer not found."),
            (.transfer(.bundleCorrupted), "Transfer bundle is corrupted."),
        ]

        for (error, expected) in errors {
            XCTAssertEqual(error.errorDescription, expected, "Missing or wrong description for \(error)")
        }
    }

    // MARK: - Story 3.4: Mac Import with Deduplication

    // AC#2: Imported session appears under correct campaign with all metadata, tags in SwiftData
    func testImport_sessionAppearsUnderCorrectCampaign() throws {
        let campaign = makeTestCampaign()
        let session = makeTestSession()
        let tags = makeTestTags(count: 3)

        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)
        for tag in tags {
            context.insert(tag)
            session.tags.append(tag)
        }
        try context.save()

        let audioData = Data("import-test-audio".utf8)
        let bundleURL = try createTestBundle(session: session, audioData: audioData)

        // Clear the database to simulate Mac with no data
        for s in try context.fetch(FetchDescriptor<Session>()) { context.delete(s) }
        for c in try context.fetch(FetchDescriptor<Campaign>()) { context.delete(c) }
        for t in try context.fetch(FetchDescriptor<Tag>()) { context.delete(t) }
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Campaign>()), 0)

        // Import
        let (importedSession, importedCampaign) = try importBundle(from: bundleURL, into: context)

        // Session exists in SwiftData
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 1)
        XCTAssertEqual(importedSession.uuid, session.uuid)
        XCTAssertEqual(importedSession.title, session.title)
        XCTAssertEqual(importedSession.sessionNumber, session.sessionNumber)
        XCTAssertEqual(importedSession.duration, session.duration)
        XCTAssertEqual(importedSession.locationName, session.locationName)
        XCTAssertEqual(importedSession.summaryNote, session.summaryNote)
        XCTAssertEqual(importedSession.pauseIntervals.count, 1)

        // Tags exist
        XCTAssertEqual(importedSession.tags.count, 3)
        for tag in importedSession.tags {
            let original = tags.first { $0.uuid == tag.uuid }
            XCTAssertNotNil(original)
            XCTAssertEqual(tag.label, original?.label)
            XCTAssertEqual(tag.categoryName, original?.categoryName)
        }

        // Campaign correct
        XCTAssertNotNil(importedCampaign)
        XCTAssertEqual(importedCampaign?.uuid, campaign.uuid)
        XCTAssertEqual(importedCampaign?.name, campaign.name)
        XCTAssertEqual(importedSession.campaign?.uuid, campaign.uuid)
    }

    // AC#2: Audio stored in sandbox
    func testImport_audioStoredOnDisk() throws {
        let session = makeTestSession()
        context.insert(session)
        try context.save()

        let audioData = Data(repeating: 0xFF, count: 512)
        let bundleURL = try createTestBundle(session: session, audioData: audioData)

        // Clear DB
        for s in try context.fetch(FetchDescriptor<Session>()) { context.delete(s) }
        try context.save()

        let (importedSession, _) = try importBundle(from: bundleURL, into: context)

        // Audio file exists at stored path
        XCTAssertNotNil(importedSession.audioFilePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: importedSession.audioFilePath!))

        // Audio content matches
        let storedAudio = try Data(contentsOf: URL(fileURLWithPath: importedSession.audioFilePath!))
        XCTAssertEqual(storedAudio, audioData, "Stored audio must match original")
    }

    // AC#3: Duplicate detection — same session UUID triggers duplicate error
    func testImport_duplicateDetection_throwsDuplicateDetected() throws {
        let sessionUUID = UUID()
        let session = makeTestSession(uuid: sessionUUID)
        context.insert(session)
        try context.save()

        let bundleURL = try createTestBundle(session: session)

        // Clear and re-insert as if already imported
        for s in try context.fetch(FetchDescriptor<Session>()) { context.delete(s) }
        try context.save()

        // First import succeeds
        let (_, _) = try importBundle(from: bundleURL, into: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 1)

        // Re-create bundle for second import (first import's bundle is same file)
        // Second import with same UUID should detect duplicate
        XCTAssertThrowsError(try importBundle(from: bundleURL, into: context)) { error in
            XCTAssertEqual(error as? DictlyError, DictlyError.import(.duplicateDetected),
                           "Re-importing same session UUID must throw duplicateDetected")
        }

        // Session count unchanged
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 1,
                       "Duplicate import must not create additional sessions")
    }

    // AC#3: Skip duplicate — no changes to data
    func testImport_skipDuplicate_noChanges() throws {
        let session = makeTestSession()
        context.insert(session)
        try context.save()

        let bundleURL = try createTestBundle(session: session)

        // Clear and import once
        for s in try context.fetch(FetchDescriptor<Session>()) { context.delete(s) }
        try context.save()
        let (_, _) = try importBundle(from: bundleURL, into: context)

        let sessionCountBefore = try context.fetchCount(FetchDescriptor<Session>())
        let tagCountBefore = try context.fetchCount(FetchDescriptor<Tag>())

        // Attempt re-import — catch duplicate error and skip
        do {
            let (_, _) = try importBundle(from: bundleURL, into: context)
            XCTFail("Should have thrown duplicateDetected")
        } catch {
            // Skip: just don't do anything — data should be unchanged
        }

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), sessionCountBefore)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Tag>()), tagCountBefore)
    }

    // AC#3: Replace duplicate — old session deleted, new session created
    func testImport_replaceDuplicate_replacesExistingSession() throws {
        let sessionUUID = UUID()
        let campaignUUID = UUID()

        // Create original session and bundle
        let campaign = makeTestCampaign(uuid: campaignUUID)
        let session = makeTestSession(uuid: sessionUUID, title: "Original Title")
        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)
        try context.save()

        let bundleURL = try createTestBundle(session: session)

        // Clear and import once
        for s in try context.fetch(FetchDescriptor<Session>()) { context.delete(s) }
        for c in try context.fetch(FetchDescriptor<Campaign>()) { context.delete(c) }
        try context.save()

        let (_, _) = try importBundle(from: bundleURL, into: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 1)

        // Now create a modified bundle with updated title
        let modifiedSession = makeTestSession(uuid: sessionUUID, title: "Updated Title")
        let modifiedCampaign = makeTestCampaign(uuid: campaignUUID, name: "Curse of Strahd")
        context.insert(modifiedCampaign)
        context.insert(modifiedSession)
        modifiedSession.campaign = modifiedCampaign
        try context.save()

        let updatedBundleURL = tempDir.appendingPathComponent("updated.dictly")
        try BundleSerializer().serialize(session: modifiedSession, audioData: Data("new-audio".utf8), to: updatedBundleURL)

        // Remove the old modified session from context
        context.delete(modifiedSession)
        context.delete(modifiedCampaign)
        try context.save()

        // Simulate replace: delete existing, then re-import
        let targetUUID = sessionUUID
        let existingDescriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.uuid == targetUUID }
        )
        let existingSessions = try context.fetch(existingDescriptor)
        for existing in existingSessions {
            context.delete(existing)
        }
        try context.save()

        // Re-import
        let (replaced, _) = try importBundle(from: updatedBundleURL, into: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 1,
                       "Replace should result in exactly one session")
        XCTAssertEqual(replaced.uuid, sessionUUID)
        XCTAssertEqual(replaced.title, "Updated Title")
    }

    // AC#4: Imported session appears in chronological list with correct metadata
    func testImport_multipleSessionsChronological() throws {
        let campaignUUID = UUID()

        // Create and serialize two sessions from different dates
        let campaign = makeTestCampaign(uuid: campaignUUID)
        context.insert(campaign)

        let now = Date()
        let session1 = makeTestSession(
            title: "Session 1",
            sessionNumber: 1,
            date: now.addingTimeInterval(-86400),
            duration: 3600
        )
        let session2 = makeTestSession(
            title: "Session 2",
            sessionNumber: 2,
            date: now,
            duration: 5400
        )
        context.insert(session1)
        context.insert(session2)
        campaign.sessions.append(session1)
        campaign.sessions.append(session2)
        try context.save()

        let bundle1URL = try createTestBundle(session: session1)
        let bundle2URL = try createTestBundle(session: session2)

        // Clear DB
        for s in try context.fetch(FetchDescriptor<Session>()) { context.delete(s) }
        for c in try context.fetch(FetchDescriptor<Campaign>()) { context.delete(c) }
        try context.save()

        // Import both
        let (imported1, _) = try importBundle(from: bundle1URL, into: context)
        let (imported2, _) = try importBundle(from: bundle2URL, into: context)

        // Verify chronological ordering
        let allSessions = try context.fetch(
            FetchDescriptor<Session>(sortBy: [SortDescriptor(\Session.date, order: .reverse)])
        )
        XCTAssertEqual(allSessions.count, 2)
        XCTAssertEqual(allSessions[0].title, "Session 2", "Newest session should be first")
        XCTAssertEqual(allSessions[1].title, "Session 1", "Older session should be second")

        // Both under same campaign
        XCTAssertEqual(imported1.campaign?.uuid, campaignUUID)
        XCTAssertEqual(imported2.campaign?.uuid, campaignUUID)
        XCTAssertEqual(imported1.campaign?.uuid, imported2.campaign?.uuid,
                       "Both sessions should share the same campaign")
    }

    // AC#5: Campaign auto-created from bundle if not on Mac
    func testImport_campaignAutoCreated_whenNotOnMac() throws {
        let campaignUUID = UUID()
        let campaign = makeTestCampaign(uuid: campaignUUID, name: "Dragon Heist")
        let session = makeTestSession()
        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)
        try context.save()

        let bundleURL = try createTestBundle(session: session)

        // Clear everything — Mac has no campaigns
        for s in try context.fetch(FetchDescriptor<Session>()) { context.delete(s) }
        for c in try context.fetch(FetchDescriptor<Campaign>()) { context.delete(c) }
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Campaign>()), 0, "Mac should have no campaigns")

        // Import
        let (importedSession, importedCampaign) = try importBundle(from: bundleURL, into: context)

        // Campaign was auto-created
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Campaign>()), 1)
        XCTAssertNotNil(importedCampaign)
        XCTAssertEqual(importedCampaign?.uuid, campaignUUID)
        XCTAssertEqual(importedCampaign?.name, "Dragon Heist")
        XCTAssertEqual(importedSession.campaign?.uuid, campaignUUID)
    }

    // AC#5 supplement: Campaign reused when already on Mac
    func testImport_campaignReused_whenAlreadyOnMac() throws {
        let campaignUUID = UUID()

        // Pre-existing campaign on Mac
        let macCampaign = Campaign(uuid: campaignUUID, name: "Curse of Strahd", descriptionText: "Mac version")
        context.insert(macCampaign)
        try context.save()

        // Create session with same campaign UUID on iOS
        let iosCampaign = makeTestCampaign(uuid: campaignUUID)
        let session = makeTestSession()
        context.insert(iosCampaign)
        context.insert(session)
        iosCampaign.sessions.append(session)
        try context.save()

        let bundleURL = try createTestBundle(session: session)

        // Remove the iOS-side data (but keep macCampaign)
        context.delete(session)
        context.delete(iosCampaign)
        try context.save()

        // Import should reuse existing Mac campaign
        let (importedSession, importedCampaign) = try importBundle(from: bundleURL, into: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Campaign>()), 1,
                       "Should reuse existing campaign, not create a new one")
        XCTAssertEqual(importedCampaign?.uuid, campaignUUID)
        XCTAssertEqual(importedSession.campaign?.uuid, campaignUUID)
    }

    // AC#2: Import error cases — DictlyError.import has proper descriptions
    func testImportError_allCases_haveDescriptions() {
        let errors: [(DictlyError, String)] = [
            (.import(.invalidFormat), "Invalid import format."),
            (.import(.duplicateDetected), "Duplicate session detected."),
            (.import(.missingData), "Required data missing from import."),
        ]

        for (error, expected) in errors {
            XCTAssertEqual(error.errorDescription, expected, "Missing or wrong description for \(error)")
        }
    }

    // MARK: - Cross-Story E2E: Full Transfer & Import Lifecycle

    /// Tests the complete iOS → Mac data flow:
    /// 1. Create session with campaign, tags, and audio (Stories 1.x, 2.x)
    /// 2. Serialize to .dictly bundle (Story 3.1)
    /// 3. Simulate wire transfer — payload creation and reconstruction (Story 3.3)
    /// 4. Import on Mac with campaign auto-creation (Story 3.4)
    /// 5. Verify all data intact after full round-trip
    func testFullTransferLifecycle_iOSToMac() throws {
        // === iOS Side: Create rich session data ===
        let campaignUUID = UUID()
        let sessionUUID = UUID()

        let campaign = Campaign(uuid: campaignUUID, name: "Tomb of Annihilation", descriptionText: "Jungle hex crawl")
        let session = Session(
            uuid: sessionUUID,
            title: "Session 7",
            sessionNumber: 7,
            date: Date(),
            duration: 10800,
            locationName: "Rick's Basement",
            locationLatitude: 40.7128,
            locationLongitude: -74.0060,
            summaryNote: "TPK in the final room"
        )
        session.pauseIntervals = [
            PauseInterval(start: 3600, end: 3660),
            PauseInterval(start: 7200, end: 7320)
        ]

        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)

        let combatTag = Tag(
            label: "Initiative",
            categoryName: "Combat",
            anchorTime: 450.5,
            rewindDuration: 10,
            notes: "Dragon fight begins"
        )
        let storyTag = Tag(
            label: "Plot Twist",
            categoryName: "Story",
            anchorTime: 5400.0,
            rewindDuration: 15,
            transcription: "The NPC reveals the secret..."
        )
        let worldTag = Tag(
            label: "Location",
            categoryName: "World",
            anchorTime: 900.0,
            rewindDuration: 5
        )
        context.insert(combatTag)
        context.insert(storyTag)
        context.insert(worldTag)
        session.tags.append(combatTag)
        session.tags.append(storyTag)
        session.tags.append(worldTag)
        try context.save()

        // === Step 1: Serialize to .dictly bundle (Story 3.1) ===
        let audioData = Data(repeating: 0xAA, count: 4096)
        let bundleURL = try createTestBundle(session: session, audioData: audioData)

        // === Step 2: Simulate wire transfer (Story 3.3) ===
        let sessionJSON = try Data(contentsOf: bundleURL.appendingPathComponent("session.json"))
        let bundleAudio = try Data(contentsOf: bundleURL.appendingPathComponent("audio.aac"))

        var jsonLength = UInt32(sessionJSON.count).bigEndian
        let header = Data(bytes: &jsonLength, count: 4)
        let wirePayload = header + sessionJSON + bundleAudio

        // === Step 3: Reconstruct on Mac receiver (Story 3.3) ===
        let receivedDir = tempDir.appendingPathComponent("mac-received.dictly")
        try FileManager.default.createDirectory(at: receivedDir, withIntermediateDirectories: true)

        let rxJsonLen = wirePayload.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        try wirePayload[4..<(4 + Int(rxJsonLen))].write(to: receivedDir.appendingPathComponent("session.json"))
        try wirePayload[(4 + Int(rxJsonLen))...].write(to: receivedDir.appendingPathComponent("audio.aac"))

        // === Step 4: Clear DB and import on Mac (Story 3.4) ===
        for s in try context.fetch(FetchDescriptor<Session>()) { context.delete(s) }
        for c in try context.fetch(FetchDescriptor<Campaign>()) { context.delete(c) }
        for t in try context.fetch(FetchDescriptor<Tag>()) { context.delete(t) }
        try context.save()

        let (imported, importedCampaign) = try importBundle(from: receivedDir, into: context)

        // === Step 5: Verify everything is intact ===

        // Session metadata
        XCTAssertEqual(imported.uuid, sessionUUID)
        XCTAssertEqual(imported.title, "Session 7")
        XCTAssertEqual(imported.sessionNumber, 7)
        XCTAssertEqual(imported.duration, 10800)
        XCTAssertEqual(imported.locationName, "Rick's Basement")
        XCTAssertEqual(imported.locationLatitude, 40.7128)
        XCTAssertEqual(imported.locationLongitude, -74.0060)
        XCTAssertEqual(imported.summaryNote, "TPK in the final room")
        XCTAssertEqual(imported.pauseIntervals.count, 2)
        XCTAssertEqual(imported.pauseIntervals[0].start, 3600)
        XCTAssertEqual(imported.pauseIntervals[1].end, 7320)

        // Tags
        XCTAssertEqual(imported.tags.count, 3)
        let importedCombat = imported.tags.first { $0.categoryName == "Combat" }
        XCTAssertNotNil(importedCombat)
        XCTAssertEqual(importedCombat?.label, "Initiative")
        XCTAssertEqual(importedCombat?.anchorTime, 450.5)
        XCTAssertEqual(importedCombat?.notes, "Dragon fight begins")

        let importedStory = imported.tags.first { $0.categoryName == "Story" }
        XCTAssertNotNil(importedStory)
        XCTAssertEqual(importedStory?.transcription, "The NPC reveals the secret...")

        let importedWorld = imported.tags.first { $0.categoryName == "World" }
        XCTAssertNotNil(importedWorld)
        XCTAssertEqual(importedWorld?.label, "Location")

        // Campaign auto-created
        XCTAssertNotNil(importedCampaign)
        XCTAssertEqual(importedCampaign?.uuid, campaignUUID)
        XCTAssertEqual(importedCampaign?.name, "Tomb of Annihilation")
        XCTAssertEqual(importedCampaign?.descriptionText, "Jungle hex crawl")
        XCTAssertEqual(imported.campaign?.uuid, campaignUUID)

        // Audio stored correctly
        XCTAssertNotNil(imported.audioFilePath)
        let storedAudio = try Data(contentsOf: URL(fileURLWithPath: imported.audioFilePath!))
        XCTAssertEqual(storedAudio, audioData)

        // SwiftData counts
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Campaign>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Tag>()), 3)
    }

    /// Tests importing multiple sessions into the same campaign over multiple transfers.
    func testMultipleTransfers_sameCampaign() throws {
        let campaignUUID = UUID()
        let campaign = makeTestCampaign(uuid: campaignUUID)

        // Create and serialize 3 sessions
        var bundleURLs: [URL] = []
        for i in 1...3 {
            let session = makeTestSession(
                title: "Session \(i)",
                sessionNumber: i,
                duration: TimeInterval(i * 3600)
            )
            let tag = Tag(
                label: "Tag for S\(i)",
                categoryName: "Story",
                anchorTime: TimeInterval(i * 60),
                rewindDuration: 10
            )
            context.insert(campaign)
            context.insert(session)
            context.insert(tag)
            campaign.sessions.append(session)
            session.tags.append(tag)
            try context.save()

            let url = try createTestBundle(session: session)
            bundleURLs.append(url)

            // Clean up for next iteration
            context.delete(session)
            context.delete(tag)
            try context.save()
        }
        context.delete(campaign)
        try context.save()

        // Import all 3 on Mac
        for url in bundleURLs {
            let (_, _) = try importBundle(from: url, into: context)
        }

        // All 3 sessions exist
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 3)

        // All under same campaign (auto-created once, reused for subsequent imports)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Campaign>()), 1)
        let campaigns = try context.fetch(FetchDescriptor<Campaign>())
        XCTAssertEqual(campaigns[0].uuid, campaignUUID)
        XCTAssertEqual(campaigns[0].sessions.count, 3)

        // Each session has its tag
        for session in campaigns[0].sessions {
            XCTAssertEqual(session.tags.count, 1)
        }
    }

    /// Tests that importing a session with many tags across all categories works correctly.
    func testImport_sessionWithManyTags_allCategories() throws {
        let session = makeTestSession()
        context.insert(session)

        let categories = ["Story", "Combat", "Roleplay", "World", "Meta"]
        var allTags: [Tag] = []
        for (catIdx, category) in categories.enumerated() {
            for j in 1...5 {
                let tag = Tag(
                    label: "\(category) Tag \(j)",
                    categoryName: category,
                    anchorTime: TimeInterval(catIdx * 500 + j * 60),
                    rewindDuration: TimeInterval(j * 2),
                    notes: j == 1 ? "Note for \(category)" : nil,
                    transcription: j == 2 ? "Transcription for \(category)" : nil
                )
                context.insert(tag)
                session.tags.append(tag)
                allTags.append(tag)
            }
        }
        try context.save()

        let bundleURL = try createTestBundle(session: session)

        // Clear and import
        for s in try context.fetch(FetchDescriptor<Session>()) { context.delete(s) }
        for t in try context.fetch(FetchDescriptor<Tag>()) { context.delete(t) }
        try context.save()

        let (imported, _) = try importBundle(from: bundleURL, into: context)

        XCTAssertEqual(imported.tags.count, 25, "All 25 tags (5 categories x 5 tags) must be imported")

        // Verify category distribution
        for category in categories {
            let categoryTags = imported.tags.filter { $0.categoryName == category }
            XCTAssertEqual(categoryTags.count, 5, "\(category) should have 5 tags")
        }

        // Verify notes and transcriptions preserved
        let tagsWithNotes = imported.tags.filter { $0.notes != nil }
        XCTAssertEqual(tagsWithNotes.count, 5, "One tag per category should have notes")
        let tagsWithTranscription = imported.tags.filter { $0.transcription != nil }
        XCTAssertEqual(tagsWithTranscription.count, 5, "One tag per category should have transcription")
    }

    /// Tests the cascade delete behavior after import — deleting imported campaign cascades.
    func testImportedData_cascadeDelete() throws {
        let campaign = makeTestCampaign()
        let session = makeTestSession()
        let tags = makeTestTags(count: 3)

        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)
        for tag in tags {
            context.insert(tag)
            session.tags.append(tag)
        }
        try context.save()

        let bundleURL = try createTestBundle(session: session)

        // Clear and import
        for s in try context.fetch(FetchDescriptor<Session>()) { context.delete(s) }
        for c in try context.fetch(FetchDescriptor<Campaign>()) { context.delete(c) }
        for t in try context.fetch(FetchDescriptor<Tag>()) { context.delete(t) }
        try context.save()

        let (_, importedCampaign) = try importBundle(from: bundleURL, into: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Tag>()), 3)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Campaign>()), 1)

        // Delete campaign — should cascade
        context.delete(importedCampaign!)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Campaign>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 0, "Session should cascade-delete")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Tag>()), 0, "Tags should cascade-delete")
    }

    // MARK: - Edge Cases

    /// Bundle version must be 1 — unsupported versions throw bundleCorrupted.
    func testDeserialize_unsupportedVersion_throwsBundleCorrupted() throws {
        let session = makeTestSession()
        context.insert(session)
        try context.save()

        // Create valid bundle, then manually overwrite session.json with version: 99
        let bundleURL = try createTestBundle(session: session)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        let bundle = TransferBundle(
            version: 99,
            session: session.toDTO(),
            tags: [],
            campaign: nil
        )
        let jsonData = try encoder.encode(bundle)
        try jsonData.write(to: bundleURL.appendingPathComponent("session.json"))

        let serializer = BundleSerializer()
        XCTAssertThrowsError(try serializer.deserialize(from: bundleURL)) { error in
            XCTAssertEqual(error as? DictlyError, DictlyError.transfer(.bundleCorrupted),
                           "Unsupported bundle version must throw bundleCorrupted")
        }
    }

    /// GPS coordinates survive the full round-trip through transfer.
    func testRoundTrip_gpsCoordinatesPreserved() throws {
        let session = makeTestSession(
            locationLatitude: 51.5074,
            locationLongitude: -0.1278
        )
        context.insert(session)
        try context.save()

        let bundleURL = try createTestBundle(session: session)

        let serializer = BundleSerializer()
        let (bundle, _) = try serializer.deserialize(from: bundleURL)

        XCTAssertEqual(bundle.session.locationLatitude!, 51.5074, accuracy: 0.0001)
        XCTAssertEqual(bundle.session.locationLongitude!, -0.1278, accuracy: 0.0001)

        let restored = Session.from(bundle.session)
        XCTAssertEqual(restored.locationLatitude!, 51.5074, accuracy: 0.0001)
        XCTAssertEqual(restored.locationLongitude!, -0.1278, accuracy: 0.0001)
    }

    /// Dates encoded as ISO 8601 survive round-trip with second precision.
    func testRoundTrip_datesPreservedAsISO8601() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14
        let session = makeTestSession(date: fixedDate)
        let tag = Tag(
            label: "Timed Tag",
            categoryName: "Meta",
            anchorTime: 100,
            rewindDuration: 5,
            createdAt: fixedDate
        )
        context.insert(session)
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        let bundleURL = try createTestBundle(session: session)

        // Verify ISO 8601 in raw JSON
        let jsonData = try Data(contentsOf: bundleURL.appendingPathComponent("session.json"))
        let jsonString = String(data: jsonData, encoding: .utf8)!
        XCTAssertTrue(jsonString.contains("2023-11-14T"), "Dates must be ISO 8601 encoded")

        let serializer = BundleSerializer()
        let (bundle, _) = try serializer.deserialize(from: bundleURL)

        // Dates match within 1 second (ISO 8601 has second precision)
        XCTAssertEqual(bundle.session.date.timeIntervalSince1970, fixedDate.timeIntervalSince1970,
                       accuracy: 1.0, "Session date must survive ISO 8601 round-trip")
        XCTAssertEqual(bundle.tags[0].createdAt.timeIntervalSince1970, fixedDate.timeIntervalSince1970,
                       accuracy: 1.0, "Tag createdAt must survive ISO 8601 round-trip")
    }

    /// JSON keys are sorted for deterministic output.
    func testSerialize_jsonKeysSorted() throws {
        let session = makeTestSession()
        context.insert(session)
        try context.save()

        let bundleURL = try createTestBundle(session: session)
        let jsonData = try Data(contentsOf: bundleURL.appendingPathComponent("session.json"))
        let jsonString = String(data: jsonData, encoding: .utf8)!

        // In sorted output, "session" comes before "tags" and "version" comes last
        let sessionRange = jsonString.range(of: "\"session\"")!
        let tagsRange = jsonString.range(of: "\"tags\"")!
        let versionRange = jsonString.range(of: "\"version\"")!
        XCTAssertTrue(sessionRange.lowerBound < tagsRange.lowerBound, "Keys should be sorted")
        XCTAssertTrue(tagsRange.lowerBound < versionRange.lowerBound, "Keys should be sorted")
    }
}
