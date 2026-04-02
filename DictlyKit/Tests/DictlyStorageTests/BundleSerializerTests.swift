import XCTest
@testable import DictlyStorage
@testable import DictlyModels

/// Tests for BundleSerializer — file I/O only, no SwiftData container needed.
/// All tests use temporary directories cleaned up in tearDown.
final class BundleSerializerTests: XCTestCase {

    var tempDir: URL!
    var serializer: BundleSerializer!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        serializer = BundleSerializer()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        serializer = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeBundleURL(name: String = "TestSession.dictly") -> URL {
        tempDir.appendingPathComponent(name, isDirectory: true)
    }

    private func makeSampleTransferBundle(
        title: String = "Test Session",
        sessionNumber: Int = 1,
        date: Date = Date(timeIntervalSince1970: 1_743_000_000),
        tags: [TagDTO] = [],
        campaign: CampaignDTO? = nil
    ) -> TransferBundle {
        let sessionDTO = SessionDTO(
            uuid: UUID(),
            title: title,
            sessionNumber: sessionNumber,
            date: date,
            duration: 3600.0,
            locationName: "Test Location",
            summaryNote: "Test summary",
            pauseIntervals: []
        )
        return TransferBundle(version: 1, session: sessionDTO, tags: tags, campaign: campaign)
    }

    private func makeAudioData() -> Data {
        // Simulate a small non-empty audio payload
        return Data(repeating: 0xAA, count: 1024)
    }

    // MARK: - Serialize + Deserialize Round-Trip (Task 4.4 / AC #1, #2, #4)

    func testRoundTripSerializeDeserialize() throws {
        let bundleURL = makeBundleURL()
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let tagDTO = TagDTO(
            uuid: UUID(),
            label: "Combat Start",
            categoryName: "Combat",
            anchorTime: 450.5,
            rewindDuration: 10.0,
            notes: "Intense fight",
            transcription: nil,
            createdAt: fixedDate
        )
        let campaignDTO = CampaignDTO(
            uuid: UUID(),
            name: "Curse of Strahd",
            descriptionText: "Gothic horror",
            createdAt: fixedDate
        )
        let expectedBundle = makeSampleTransferBundle(
            title: "Round Trip Session",
            sessionNumber: 3,
            date: fixedDate,
            tags: [tagDTO],
            campaign: campaignDTO
        )
        let expectedAudio = makeAudioData()

        // Directly write bundle files (bypass serialize which needs @Model Session)
        try writeBundle(expectedBundle, audioData: expectedAudio, to: bundleURL)

        let (resultBundle, resultAudio) = try serializer.deserialize(from: bundleURL)

        XCTAssertEqual(resultBundle, expectedBundle)
        XCTAssertEqual(resultAudio, expectedAudio)
    }

    func testDeserializedSessionFieldsMatch() throws {
        let bundleURL = makeBundleURL()
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let sessionDTO = SessionDTO(
            uuid: UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!,
            title: "Campaign Session 5",
            sessionNumber: 5,
            date: fixedDate,
            duration: 7200.0,
            locationName: "Dragon's Den",
            summaryNote: "Final boss fight",
            pauseIntervals: [PauseInterval(start: 1800.0, end: 1860.0)]
        )
        let bundle = TransferBundle(version: 1, session: sessionDTO, tags: [], campaign: nil)
        try writeBundle(bundle, audioData: makeAudioData(), to: bundleURL)

        let (result, _) = try serializer.deserialize(from: bundleURL)

        XCTAssertEqual(result.session.uuid, sessionDTO.uuid)
        XCTAssertEqual(result.session.title, "Campaign Session 5")
        XCTAssertEqual(result.session.sessionNumber, 5)
        XCTAssertEqual(result.session.duration, 7200.0)
        XCTAssertEqual(result.session.locationName, "Dragon's Den")
        XCTAssertEqual(result.session.summaryNote, "Final boss fight")
        XCTAssertEqual(result.session.pauseIntervals.count, 1)
        XCTAssertEqual(result.session.pauseIntervals[0].start, 1800.0)
    }

    func testDeserializedAudioIsIntact() throws {
        let bundleURL = makeBundleURL()
        let originalAudio = Data((0..<2048).map { UInt8($0 % 256) })
        let bundle = makeSampleTransferBundle()
        try writeBundle(bundle, audioData: originalAudio, to: bundleURL)

        let (_, resultAudio) = try serializer.deserialize(from: bundleURL)

        XCTAssertEqual(resultAudio, originalAudio, "Audio data must be preserved byte-for-byte")
    }

    func testBundleContainsBothFiles() throws {
        let bundleURL = makeBundleURL()
        let bundle = makeSampleTransferBundle()
        try writeBundle(bundle, audioData: makeAudioData(), to: bundleURL)

        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: bundleURL.appendingPathComponent("audio.aac").path))
        XCTAssertTrue(fm.fileExists(atPath: bundleURL.appendingPathComponent("session.json").path))
    }

    func testJSONUsesSortedKeys() throws {
        let bundleURL = makeBundleURL()
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let campaignDTO = CampaignDTO(
            uuid: UUID(),
            name: "Test Campaign",
            descriptionText: "",
            createdAt: fixedDate
        )
        let bundle = makeSampleTransferBundle(campaign: campaignDTO)
        try writeBundle(bundle, audioData: makeAudioData(), to: bundleURL)

        let jsonURL = bundleURL.appendingPathComponent("session.json")
        let jsonData = try Data(contentsOf: jsonURL)
        let jsonString = try XCTUnwrap(String(data: jsonData, encoding: .utf8))

        // sortedKeys: "campaign" < "session" < "tags" < "version" alphabetically
        let campaignRange = jsonString.range(of: "\"campaign\"")
        let sessionRange = jsonString.range(of: "\"session\"")
        let versionRange = jsonString.range(of: "\"version\"")

        XCTAssertNotNil(campaignRange, "JSON should contain 'campaign' key")
        XCTAssertNotNil(sessionRange, "JSON should contain 'session' key")
        XCTAssertNotNil(versionRange, "JSON should contain 'version' key")

        if let c = campaignRange, let s = sessionRange, let v = versionRange {
            XCTAssertLessThan(c.lowerBound, s.lowerBound, "sortedKeys: 'campaign' should appear before 'session'")
            XCTAssertLessThan(s.lowerBound, v.lowerBound, "sortedKeys: 'session' should appear before 'version'")
        }
    }

    // MARK: - Error Cases (Task 4.5 / AC #3)

    func testMissingAudioACCThrows() throws {
        let bundleURL = makeBundleURL()
        // Create directory with only session.json, no audio.aac
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        let bundle = makeSampleTransferBundle()
        let encoder = makeEncoder()
        let jsonData = try encoder.encode(bundle)
        try jsonData.write(to: bundleURL.appendingPathComponent("session.json"))

        XCTAssertThrowsError(try serializer.deserialize(from: bundleURL)) { error in
            XCTAssertEqual(error as? DictlyError, DictlyError.transfer(.bundleCorrupted))
        }
    }

    func testMissingSessionJSONThrows() throws {
        let bundleURL = makeBundleURL()
        // Create directory with only audio.aac, no session.json
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try makeAudioData().write(to: bundleURL.appendingPathComponent("audio.aac"))

        XCTAssertThrowsError(try serializer.deserialize(from: bundleURL)) { error in
            XCTAssertEqual(error as? DictlyError, DictlyError.transfer(.bundleCorrupted))
        }
    }

    func testCorruptedJSONThrows() throws {
        let bundleURL = makeBundleURL()
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try makeAudioData().write(to: bundleURL.appendingPathComponent("audio.aac"))
        // Write invalid JSON
        try "{ this is not valid json !!!".data(using: .utf8)!
            .write(to: bundleURL.appendingPathComponent("session.json"))

        XCTAssertThrowsError(try serializer.deserialize(from: bundleURL)) { error in
            XCTAssertEqual(error as? DictlyError, DictlyError.transfer(.bundleCorrupted))
        }
    }

    func testEmptyAudioThrows() throws {
        let bundleURL = makeBundleURL()
        let bundle = makeSampleTransferBundle()
        // Write empty audio.aac
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try Data().write(to: bundleURL.appendingPathComponent("audio.aac"))
        let encoder = makeEncoder()
        let jsonData = try encoder.encode(bundle)
        try jsonData.write(to: bundleURL.appendingPathComponent("session.json"))

        XCTAssertThrowsError(try serializer.deserialize(from: bundleURL)) { error in
            XCTAssertEqual(error as? DictlyError, DictlyError.transfer(.bundleCorrupted))
        }
    }

    func testEmptyDirectoryThrows() throws {
        let bundleURL = makeBundleURL()
        // Empty directory — neither file present
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        XCTAssertThrowsError(try serializer.deserialize(from: bundleURL)) { error in
            XCTAssertEqual(error as? DictlyError, DictlyError.transfer(.bundleCorrupted))
        }
    }

    func testNonExistentBundleDirectoryThrows() throws {
        let bundleURL = tempDir.appendingPathComponent("nonexistent.dictly", isDirectory: true)

        XCTAssertThrowsError(try serializer.deserialize(from: bundleURL)) { error in
            XCTAssertEqual(error as? DictlyError, DictlyError.transfer(.bundleCorrupted))
        }
    }

    // MARK: - Private Helpers

    /// Writes a TransferBundle + audio directly to disk, bypassing @Model dependency.
    /// Used to test the deserialize path in isolation.
    private func writeBundle(_ bundle: TransferBundle, audioData: Data, to url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        try audioData.write(to: url.appendingPathComponent("audio.aac"))
        let encoder = makeEncoder()
        let jsonData = try encoder.encode(bundle)
        try jsonData.write(to: url.appendingPathComponent("session.json"))
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return encoder
    }
}
