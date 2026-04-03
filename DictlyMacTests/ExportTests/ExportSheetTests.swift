import XCTest
@testable import DictlyMac
import SwiftData
import DictlyModels
import DictlyExport

/// Tests for Story 6.4: Markdown Export — Single Session & Campaign.
///
/// Covers: ExportSheet initialization, MarkdownExporter integration,
/// session/campaign export path selection, filename suggestion.
///
/// Note: NSSavePanel and file-write interactions are not tested here
/// (those require UI test harness). Logic tested via MarkdownExporter unit tests.

@MainActor
final class ExportSheetTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema(DictlySchema.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - ExportSheet initialization

    func testExportSheet_initializesWithSession() throws {
        let session = makeSession()
        context.insert(session)
        try context.save()

        let sheet = ExportSheet(session: session, isPresented: .constant(true))
        XCTAssertNotNil(sheet, "ExportSheet should initialize without crashing")
    }

    func testExportSheet_initializesWithSessionInCampaign() throws {
        let campaign = Campaign(name: "The Ashlands", descriptionText: "A campaign")
        let session = makeSession()
        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)
        try context.save()

        let sheet = ExportSheet(session: session, isPresented: .constant(true))
        XCTAssertNotNil(sheet, "ExportSheet should initialize when session belongs to a campaign")
    }

    // MARK: - MarkdownExporter integration

    func testMarkdownExporter_producesSessionOutput_forExportSheet() throws {
        let session = makeSession(title: "Grimthor's Return", number: 5)
        context.insert(session)
        try context.save()

        let output = MarkdownExporter.exportSession(session)
        XCTAssertTrue(output.contains("# Session 5 — Grimthor's Return"),
                      "MarkdownExporter should produce correct H1 for the session")
    }

    func testMarkdownExporter_producesCampaignOutput_whenCampaignExists() throws {
        let campaign = Campaign(name: "Ashlands Campaign", descriptionText: "Epic adventure")
        let session = makeSession(title: "The First Step", number: 1)
        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)
        try context.save()

        let output = MarkdownExporter.exportCampaign(campaign)
        XCTAssertTrue(output.contains("# Ashlands Campaign"))
        XCTAssertTrue(output.contains("## Session 1 — The First Step"))
    }

    func testMarkdownExporter_sessionFilename_matchesExpectedFormat() throws {
        let session = makeSession(title: "Into the Dark", number: 3)
        context.insert(session)
        try context.save()

        let filename = MarkdownExporter.suggestedFilename(for: session)
        XCTAssertTrue(filename.hasPrefix("Session 3 - "))
        XCTAssertTrue(filename.hasSuffix(".md"))
    }

    func testMarkdownExporter_campaignFilename_matchesExpectedFormat() throws {
        let campaign = Campaign(name: "The Dragon War")
        context.insert(campaign)
        try context.save()

        let filename = MarkdownExporter.suggestedFilename(for: campaign)
        XCTAssertEqual(filename, "Campaign - The Dragon War.md")
    }

    // MARK: - Tags in export

    func testMarkdownExporter_sessionWithTags_includesTagContent() throws {
        let session = makeSession(title: "Tagged Session", number: 1)
        let tag = Tag(label: "Big Fight", categoryName: "Combat", anchorTime: 300, rewindDuration: 5,
                      notes: "Player rolled nat 20", transcription: "They charged into battle.")
        context.insert(session)
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        let output = MarkdownExporter.exportSession(session)
        XCTAssertTrue(output.contains("Big Fight"))
        XCTAssertTrue(output.contains("They charged into battle."))
        XCTAssertTrue(output.contains("> Note: Player rolled nat 20"))
    }

    // MARK: - Helpers

    private func makeSession(title: String = "Test Session", number: Int = 1) -> Session {
        Session(
            uuid: UUID(),
            title: title,
            sessionNumber: number,
            date: Date(),
            duration: 3600
        )
    }
}
