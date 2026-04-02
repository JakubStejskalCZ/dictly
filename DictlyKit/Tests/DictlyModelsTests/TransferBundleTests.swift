import XCTest
import SwiftData
@testable import DictlyModels
@testable import DictlyStorage

@MainActor
final class TransferBundleTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var tempDir: URL!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Schema(DictlySchema.all), configurations: config)
        context = container.mainContext
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        context = nil
        container = nil
    }

    // MARK: - SessionDTO Round-Trip

    func testSessionDTORoundTrip() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let session = Session(
            uuid: UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!,
            title: "Session 3",
            sessionNumber: 3,
            date: fixedDate,
            duration: 7200.0,
            locationName: "Game Store",
            summaryNote: "The party found the artifact"
        )
        session.pauseIntervals = [PauseInterval(start: 1800.0, end: 1860.0)]
        context.insert(session)

        let dto = session.toDTO()

        XCTAssertEqual(dto.uuid, session.uuid)
        XCTAssertEqual(dto.title, "Session 3")
        XCTAssertEqual(dto.sessionNumber, 3)
        XCTAssertEqual(dto.date, fixedDate)
        XCTAssertEqual(dto.duration, 7200.0)
        XCTAssertEqual(dto.locationName, "Game Store")
        XCTAssertEqual(dto.summaryNote, "The party found the artifact")
        XCTAssertEqual(dto.pauseIntervals.count, 1)
        XCTAssertEqual(dto.pauseIntervals[0].start, 1800.0)
        XCTAssertEqual(dto.pauseIntervals[0].end, 1860.0)
    }

    func testSessionDTOToJSON() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let dto = SessionDTO(
            uuid: UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!,
            title: "Session 3",
            sessionNumber: 3,
            date: fixedDate,
            duration: 7200.0,
            locationName: "Game Store",
            summaryNote: "The party found the artifact",
            pauseIntervals: [PauseInterval(start: 1800.0, end: 1860.0)]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys

        let data = try encoder.encode(dto)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SessionDTO.self, from: data)

        XCTAssertEqual(decoded, dto)
    }

    // MARK: - TagDTO Round-Trip

    func testTagDTORoundTrip() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let tag = Tag(
            uuid: UUID(),
            label: "Combat Start",
            categoryName: "Combat",
            anchorTime: 450.5,
            rewindDuration: 10.0,
            notes: "Big fight here",
            transcription: "They attacked the dragon",
            createdAt: fixedDate
        )
        context.insert(tag)

        let dto = tag.toDTO()

        XCTAssertEqual(dto.uuid, tag.uuid)
        XCTAssertEqual(dto.label, "Combat Start")
        XCTAssertEqual(dto.categoryName, "Combat")
        XCTAssertEqual(dto.anchorTime, 450.5)
        XCTAssertEqual(dto.rewindDuration, 10.0)
        XCTAssertEqual(dto.notes, "Big fight here")
        XCTAssertEqual(dto.transcription, "They attacked the dragon")
        XCTAssertEqual(dto.createdAt, fixedDate)
    }

    func testTagDTOJSONRoundTrip() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let dto = TagDTO(
            uuid: UUID(),
            label: "Combat Start",
            categoryName: "Combat",
            anchorTime: 450.5,
            rewindDuration: 10.0,
            notes: nil,
            transcription: nil,
            createdAt: fixedDate
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TagDTO.self, from: data)

        XCTAssertEqual(decoded, dto)
    }

    // MARK: - CampaignDTO Round-Trip

    func testCampaignDTORoundTrip() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let campaign = Campaign(
            uuid: UUID(),
            name: "Curse of Strahd",
            descriptionText: "Gothic horror campaign",
            createdAt: fixedDate
        )
        context.insert(campaign)

        let dto = campaign.toDTO()

        XCTAssertEqual(dto.uuid, campaign.uuid)
        XCTAssertEqual(dto.name, "Curse of Strahd")
        XCTAssertEqual(dto.descriptionText, "Gothic horror campaign")
        XCTAssertEqual(dto.createdAt, fixedDate)
    }

    // MARK: - TransferBundle JSON Round-Trip

    func testTransferBundleJSONRoundTrip() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)

        let sessionDTO = SessionDTO(
            uuid: UUID(),
            title: "Session 1",
            sessionNumber: 1,
            date: fixedDate,
            duration: 3600.0,
            locationName: nil,
            summaryNote: nil,
            pauseIntervals: []
        )
        let tagDTO = TagDTO(
            uuid: UUID(),
            label: "Plot Twist",
            categoryName: "Story",
            anchorTime: 300.0,
            rewindDuration: 5.0,
            notes: nil,
            transcription: nil,
            createdAt: fixedDate
        )
        let campaignDTO = CampaignDTO(
            uuid: UUID(),
            name: "My Campaign",
            descriptionText: "",
            createdAt: fixedDate
        )
        let bundle = TransferBundle(
            version: 1,
            session: sessionDTO,
            tags: [tagDTO],
            campaign: campaignDTO
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys

        let data = try encoder.encode(bundle)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TransferBundle.self, from: data)

        XCTAssertEqual(decoded, bundle)
    }

    func testTransferBundleJSONContainsCamelCaseKeys() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let sessionDTO = SessionDTO(
            uuid: UUID(),
            title: "Session 1",
            sessionNumber: 1,
            date: fixedDate,
            duration: 1800.0,
            locationName: nil,
            summaryNote: nil,
            pauseIntervals: []
        )
        let bundle = TransferBundle(version: 1, session: sessionDTO, tags: [], campaign: nil)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(bundle)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNotNil(json["version"], "root should have 'version' key")
        XCTAssertNotNil(json["session"], "root should have 'session' key")
        XCTAssertNotNil(json["tags"], "root should have 'tags' key")

        let sessionJson = try XCTUnwrap(json["session"] as? [String: Any])
        XCTAssertNotNil(sessionJson["sessionNumber"], "session should have camelCase 'sessionNumber'")
        XCTAssertNotNil(sessionJson["pauseIntervals"], "session should have camelCase 'pauseIntervals'")
    }

    // MARK: - Model Factory Methods (import path)

    func testSessionFromDTO() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let dto = SessionDTO(
            uuid: UUID(),
            title: "Restored Session",
            sessionNumber: 5,
            date: fixedDate,
            duration: 1800.0,
            locationName: "Library",
            summaryNote: "A quiet session",
            pauseIntervals: [PauseInterval(start: 600.0, end: 660.0)]
        )

        let session = Session.from(dto)

        XCTAssertEqual(session.uuid, dto.uuid)
        XCTAssertEqual(session.title, "Restored Session")
        XCTAssertEqual(session.sessionNumber, 5)
        XCTAssertEqual(session.date, fixedDate)
        XCTAssertEqual(session.duration, 1800.0)
        XCTAssertEqual(session.locationName, "Library")
        XCTAssertEqual(session.summaryNote, "A quiet session")
        XCTAssertEqual(session.pauseIntervals.count, 1)
        XCTAssertEqual(session.pauseIntervals[0].start, 600.0)
    }

    func testTagFromDTO() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let dto = TagDTO(
            uuid: UUID(),
            label: "Boss Fight",
            categoryName: "Combat",
            anchorTime: 900.0,
            rewindDuration: 15.0,
            notes: "Very intense",
            transcription: nil,
            createdAt: fixedDate
        )

        let tag = Tag.from(dto)

        XCTAssertEqual(tag.uuid, dto.uuid)
        XCTAssertEqual(tag.label, "Boss Fight")
        XCTAssertEqual(tag.categoryName, "Combat")
        XCTAssertEqual(tag.anchorTime, 900.0)
        XCTAssertEqual(tag.rewindDuration, 15.0)
        XCTAssertEqual(tag.notes, "Very intense")
        XCTAssertNil(tag.transcription)
    }

    func testCampaignFromDTO() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let dto = CampaignDTO(
            uuid: UUID(),
            name: "Dragon Heist",
            descriptionText: "City adventure",
            createdAt: fixedDate
        )

        let campaign = Campaign.from(dto)

        XCTAssertEqual(campaign.uuid, dto.uuid)
        XCTAssertEqual(campaign.name, "Dragon Heist")
        XCTAssertEqual(campaign.descriptionText, "City adventure")
        XCTAssertEqual(campaign.createdAt, fixedDate)
    }

    // MARK: - Edge Cases (Task 4.6)

    func testSessionWithZeroTags() throws {
        let session = Session(title: "Empty Session", sessionNumber: 1)
        context.insert(session)

        let dto = session.toDTO()
        XCTAssertEqual(dto.pauseIntervals.count, 0)

        let bundle = TransferBundle(
            version: 1,
            session: dto,
            tags: [],
            campaign: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(bundle)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TransferBundle.self, from: data)

        XCTAssertEqual(decoded.tags.count, 0)
        XCTAssertNil(decoded.campaign)
    }

    func testSessionWithManyTagsAcrossCategories() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let categories = ["Combat", "Story", "Roleplay", "Humor", "World Building"]
        let tagDTOs: [TagDTO] = (0..<25).map { i in
            TagDTO(
                uuid: UUID(),
                label: "Tag \(i)",
                categoryName: categories[i % categories.count],
                anchorTime: Double(i) * 30.0,
                rewindDuration: 5.0,
                notes: nil,
                transcription: nil,
                createdAt: fixedDate
            )
        }

        let sessionDTO = SessionDTO(
            uuid: UUID(),
            title: "Long Session",
            sessionNumber: 10,
            date: fixedDate,
            duration: 14400.0,
            locationName: nil,
            summaryNote: nil,
            pauseIntervals: []
        )
        let bundle = TransferBundle(version: 1, session: sessionDTO, tags: tagDTOs, campaign: nil)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(bundle)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TransferBundle.self, from: data)

        XCTAssertEqual(decoded.tags.count, 25)
        XCTAssertEqual(decoded, bundle)
    }

    func testAllOptionalFieldsNil() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let dto = SessionDTO(
            uuid: UUID(),
            title: "Minimal",
            sessionNumber: 1,
            date: fixedDate,
            duration: 0,
            locationName: nil,
            summaryNote: nil,
            pauseIntervals: []
        )
        let bundle = TransferBundle(version: 1, session: dto, tags: [], campaign: nil)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(bundle)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TransferBundle.self, from: data)

        XCTAssertNil(decoded.session.locationName)
        XCTAssertNil(decoded.session.summaryNote)
        XCTAssertNil(decoded.campaign)
        XCTAssertEqual(decoded, bundle)
    }

    func testTransferBundleVersionField() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let sessionDTO = SessionDTO(
            uuid: UUID(),
            title: "V1 Session",
            sessionNumber: 1,
            date: fixedDate,
            duration: 0,
            locationName: nil,
            summaryNote: nil,
            pauseIntervals: []
        )
        let bundle = TransferBundle(version: 1, session: sessionDTO, tags: [], campaign: nil)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(bundle)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["version"] as? Int, 1)
    }

    func testMultiplePauseIntervals() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let pauses = [
            PauseInterval(start: 300.0, end: 360.0),
            PauseInterval(start: 1200.0, end: 1500.0),
            PauseInterval(start: 3000.0, end: 3060.0)
        ]
        let dto = SessionDTO(
            uuid: UUID(),
            title: "Paused Session",
            sessionNumber: 2,
            date: fixedDate,
            duration: 5400.0,
            locationName: nil,
            summaryNote: nil,
            pauseIntervals: pauses
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SessionDTO.self, from: data)

        XCTAssertEqual(decoded.pauseIntervals.count, 3)
        XCTAssertEqual(decoded.pauseIntervals[1].start, 1200.0)
        XCTAssertEqual(decoded.pauseIntervals[1].end, 1500.0)
    }

    // MARK: - Serialize → Deserialize Integration (Review Fix)

    func testSerializeDeserializeIntegration() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let bundleURL = tempDir.appendingPathComponent("Integration.dictly", isDirectory: true)

        let campaign = Campaign(
            uuid: UUID(),
            name: "Test Campaign",
            descriptionText: "For integration test",
            createdAt: fixedDate
        )
        context.insert(campaign)

        let session = Session(
            uuid: UUID(),
            title: "Integration Session",
            sessionNumber: 7,
            date: fixedDate,
            duration: 5400.0,
            locationName: "Test Location",
            locationLatitude: 50.0755,
            locationLongitude: 14.4378,
            summaryNote: "Integration test note"
        )
        session.pauseIntervals = [PauseInterval(start: 600.0, end: 660.0)]
        session.campaign = campaign
        context.insert(session)

        let tag = Tag(
            uuid: UUID(),
            label: "Important Moment",
            categoryName: "Story",
            anchorTime: 300.0,
            rewindDuration: 10.0,
            notes: "Key plot point",
            createdAt: fixedDate
        )
        tag.session = session
        context.insert(tag)

        try context.save()

        let audioData = Data(repeating: 0xBB, count: 2048)
        let serializer = BundleSerializer()
        try serializer.serialize(session: session, audioData: audioData, to: bundleURL)

        let (resultBundle, resultAudio) = try serializer.deserialize(from: bundleURL)

        XCTAssertEqual(resultBundle.version, 1)
        XCTAssertEqual(resultBundle.session.uuid, session.uuid)
        XCTAssertEqual(resultBundle.session.title, "Integration Session")
        XCTAssertEqual(resultBundle.session.sessionNumber, 7)
        XCTAssertEqual(resultBundle.session.duration, 5400.0)
        XCTAssertEqual(resultBundle.session.locationName, "Test Location")
        XCTAssertEqual(resultBundle.session.locationLatitude, 50.0755)
        XCTAssertEqual(resultBundle.session.locationLongitude, 14.4378)
        XCTAssertEqual(resultBundle.session.summaryNote, "Integration test note")
        XCTAssertEqual(resultBundle.session.pauseIntervals.count, 1)
        XCTAssertEqual(resultBundle.tags.count, 1)
        XCTAssertEqual(resultBundle.tags[0].label, "Important Moment")
        XCTAssertEqual(resultBundle.tags[0].categoryName, "Story")
        XCTAssertNotNil(resultBundle.campaign)
        XCTAssertEqual(resultBundle.campaign?.name, "Test Campaign")
        XCTAssertEqual(resultAudio, audioData)
    }

    func testSessionDTOPreservesCoordinates() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let session = Session(
            uuid: UUID(),
            title: "GPS Session",
            sessionNumber: 1,
            date: fixedDate,
            duration: 1800.0,
            locationName: "Prague",
            locationLatitude: 50.0755,
            locationLongitude: 14.4378
        )
        context.insert(session)

        let dto = session.toDTO()
        XCTAssertEqual(dto.locationLatitude, 50.0755)
        XCTAssertEqual(dto.locationLongitude, 14.4378)

        let restored = Session.from(dto)
        XCTAssertEqual(restored.locationLatitude, 50.0755)
        XCTAssertEqual(restored.locationLongitude, 14.4378)
    }

    func testSessionDTONilCoordinatesRoundTrip() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_743_000_000)
        let dto = SessionDTO(
            uuid: UUID(),
            title: "No GPS",
            sessionNumber: 1,
            date: fixedDate,
            duration: 0,
            locationName: nil,
            summaryNote: nil,
            pauseIntervals: []
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SessionDTO.self, from: data)

        XCTAssertNil(decoded.locationLatitude)
        XCTAssertNil(decoded.locationLongitude)
    }
}
