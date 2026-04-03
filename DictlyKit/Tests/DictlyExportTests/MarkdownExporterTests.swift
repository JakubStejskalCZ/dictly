import XCTest
import SwiftData
import Foundation
@testable import DictlyExport
import DictlyModels

// Disambiguate from XCTest.Tag (doesn't exist, but this is defensive)
typealias DictlyTag = DictlyModels.Tag

@MainActor
final class MarkdownExporterTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Schema(DictlySchema.all), configurations: config)
        context = container.mainContext
    }

    override func tearDown() async throws {
        context = nil
        container = nil
    }

    // MARK: - Helpers

    private func makeSession(
        number: Int = 7,
        title: String = "The Return to Grimthor's Shop",
        date: Date = Date(timeIntervalSince1970: 1742000000),
        duration: TimeInterval = 13642,
        location: String? = "Jake's Place",
        summary: String? = "Session summary note text here",
        tags: [DictlyTag] = []
    ) -> Session {
        let s = Session(
            title: title,
            sessionNumber: number,
            date: date,
            duration: duration,
            locationName: location,
            summaryNote: summary
        )
        context.insert(s)
        for tag in tags {
            context.insert(tag)
            s.tags.append(tag)
        }
        return s
    }

    private func makeTag(
        label: String,
        category: String,
        anchorTime: TimeInterval,
        transcription: String? = nil,
        notes: String? = nil
    ) -> DictlyTag {
        DictlyTag(
            label: label,
            categoryName: category,
            anchorTime: anchorTime,
            rewindDuration: 0,
            notes: notes,
            transcription: transcription
        )
    }

    private func makeCampaign(name: String, description: String = "") -> Campaign {
        let c = Campaign(name: name, descriptionText: description)
        context.insert(c)
        return c
    }

    // MARK: - exportSession: output structure (AC #1, #3)

    func testExportSession_h1Title() {
        let session = makeSession(tags: [])
        let output = MarkdownExporter.exportSession(session)
        XCTAssertTrue(output.contains("# Session 7 — The Return to Grimthor's Shop"))
    }

    func testExportSession_metadataContainsDateDurationTagsLocation() {
        let tag = makeTag(label: "A", category: "Story", anchorTime: 100)
        let session = makeSession(tags: [tag])
        let output = MarkdownExporter.exportSession(session)
        XCTAssertTrue(output.contains("**Date:**"))
        XCTAssertTrue(output.contains("**Duration:**"))
        XCTAssertTrue(output.contains("**Tags:** 1"))
        XCTAssertTrue(output.contains("**Location:** Jake's Place"))
    }

    func testExportSession_summaryNoteAsBlockquote() {
        let session = makeSession(tags: [])
        let output = MarkdownExporter.exportSession(session)
        XCTAssertTrue(output.contains("> Session summary note text here"))
    }

    func testExportSession_tagGroupedByCategoryUnderH2_alphabeticalOrder() {
        let tags = [
            makeTag(label: "Ambush", category: "Combat", anchorTime: 2712),
            makeTag(label: "Grimthor's Promise", category: "Story", anchorTime: 754),
            makeTag(label: "Tavern Chat", category: "Roleplay", anchorTime: 7833)
        ]
        let session = makeSession(tags: tags)
        let output = MarkdownExporter.exportSession(session)

        let combatRange = output.range(of: "## Combat")
        let roleplaysRange = output.range(of: "## Roleplay")
        let storyRange = output.range(of: "## Story")
        XCTAssertNotNil(combatRange)
        XCTAssertNotNil(roleplaysRange)
        XCTAssertNotNil(storyRange)
        // Alphabetical: Combat before Roleplay before Story
        if let c = combatRange, let r = roleplaysRange, let s = storyRange {
            XCTAssertTrue(c.lowerBound < r.lowerBound)
            XCTAssertTrue(r.lowerBound < s.lowerBound)
        }
    }

    func testExportSession_timestampFormattedAsHMMSS() {
        // 754 seconds = 0:12:34
        let tag = makeTag(label: "Test", category: "Story", anchorTime: 754)
        let session = makeSession(tags: [tag])
        let output = MarkdownExporter.exportSession(session)
        XCTAssertTrue(output.contains("[0:12:34]"))
    }

    func testExportSession_transcriptionIncluded() {
        let tag = makeTag(label: "Pledge", category: "Story", anchorTime: 100, transcription: "He would forge the blade.")
        let session = makeSession(tags: [tag])
        let output = MarkdownExporter.exportSession(session)
        XCTAssertTrue(output.contains("He would forge the blade."))
    }

    func testExportSession_notesIncludedWithPrefix() {
        let tag = makeTag(label: "Pledge", category: "Story", anchorTime: 100, notes: "Important plot hook")
        let session = makeSession(tags: [tag])
        let output = MarkdownExporter.exportSession(session)
        XCTAssertTrue(output.contains("> Note: Important plot hook"))
    }

    func testExportSession_tagsWithinCategorySortedByAnchorTime() {
        let tags = [
            makeTag(label: "Later", category: "Story", anchorTime: 6302),  // 1:45:02
            makeTag(label: "Earlier", category: "Story", anchorTime: 754)  // 0:12:34
        ]
        let session = makeSession(tags: tags)
        let output = MarkdownExporter.exportSession(session)
        let earlierRange = output.range(of: "[0:12:34]")
        let laterRange = output.range(of: "[1:45:02]")
        XCTAssertNotNil(earlierRange)
        XCTAssertNotNil(laterRange)
        if let e = earlierRange, let l = laterRange {
            XCTAssertTrue(e.lowerBound < l.lowerBound, "Earlier tag should appear before later tag")
        }
    }

    // MARK: - exportSession: edge cases (AC #3)

    func testExportSession_noTagsProducesNoTagsNote() {
        let session = makeSession(tags: [])
        let output = MarkdownExporter.exportSession(session)
        XCTAssertTrue(output.contains("No tags recorded"), "Should include 'No tags recorded' when session has no tags")
    }

    func testExportSession_missingOptionalFieldsGracefullyOmitted() {
        let session = Session(title: "Minimal Session", sessionNumber: 1)
        context.insert(session)
        let output = MarkdownExporter.exportSession(session)
        XCTAssertTrue(output.contains("# Session 1 — Minimal Session"))
        XCTAssertFalse(output.contains("**Location:**"), "Location should be omitted when nil")
        // No summary blockquote
        let lines = output.components(separatedBy: "\n")
        let blockquoteLines = lines.filter { $0.hasPrefix(">") }
        XCTAssertTrue(blockquoteLines.isEmpty, "No blockquote when summaryNote is nil")
    }

    func testExportSession_noTranscriptionShowsPlaceholder() {
        let tag = DictlyTag(label: "Silent", categoryName: "Roleplay", anchorTime: 100, rewindDuration: 0)
        let session = makeSession(tags: [tag])
        let output = MarkdownExporter.exportSession(session)
        XCTAssertTrue(output.contains("(no transcription)"))
    }

    func testExportSession_noNotesDoesNotProduceNoteLine() {
        let tag = DictlyTag(label: "Silent", categoryName: "Roleplay", anchorTime: 100, rewindDuration: 0)
        let session = makeSession(tags: [tag])
        let output = MarkdownExporter.exportSession(session)
        XCTAssertFalse(output.contains("> Note:"))
    }

    // MARK: - exportCampaign: output structure (AC #2, #3)

    func testExportCampaign_h1CampaignName() {
        let campaign = makeCampaign(name: "Ashlands Campaign", description: "A dark fantasy campaign.")
        let output = MarkdownExporter.exportCampaign(campaign)
        XCTAssertTrue(output.contains("# Ashlands Campaign"))
    }

    func testExportCampaign_descriptionIncluded() {
        let campaign = makeCampaign(name: "Ashlands Campaign", description: "A dark fantasy campaign.")
        let output = MarkdownExporter.exportCampaign(campaign)
        XCTAssertTrue(output.contains("A dark fantasy campaign."))
    }

    func testExportCampaign_sessionsH2SortedByDate() {
        let campaign = makeCampaign(name: "Test Campaign")
        let s1 = Session(title: "First", sessionNumber: 1, date: Date(timeIntervalSince1970: 1_000_000))
        let s2 = Session(title: "Second", sessionNumber: 2, date: Date(timeIntervalSince1970: 2_000_000))
        context.insert(s1)
        context.insert(s2)
        campaign.sessions = [s2, s1] // out of order
        let output = MarkdownExporter.exportCampaign(campaign)
        let first = output.range(of: "## Session 1 — First")
        let second = output.range(of: "## Session 2 — Second")
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        if let f = first, let s = second {
            XCTAssertTrue(f.lowerBound < s.lowerBound, "Session 1 should precede Session 2 when sorted by date")
        }
    }

    func testExportCampaign_tagHeadingsShiftedToH3() {
        let campaign = makeCampaign(name: "Test Campaign")
        let tag = makeTag(label: "Event", category: "Story", anchorTime: 100)
        let session = Session(title: "Session One", sessionNumber: 1)
        context.insert(session)
        session.tags.append(tag)
        campaign.sessions.append(session)
        let output = MarkdownExporter.exportCampaign(campaign)
        XCTAssertTrue(output.contains("### Story"), "Campaign export should use H3 for category headings")
        // Ensure no standalone "## Story" (only "## Session" headings at H2)
        let lines = output.components(separatedBy: "\n")
        let h2Lines = lines.filter { $0.hasPrefix("## ") }
        let h2StoryLines = h2Lines.filter { $0 == "## Story" }
        XCTAssertTrue(h2StoryLines.isEmpty, "Category headings should be H3, not H2, in campaign export")
    }

    func testExportCampaign_emptyCampaignProducesNote() {
        let campaign = makeCampaign(name: "Empty Campaign")
        let output = MarkdownExporter.exportCampaign(campaign)
        XCTAssertTrue(output.contains("No sessions in this campaign"))
    }

    // MARK: - CommonMark compliance (AC #3)

    func testExportSession_commonMarkCompliance_noHTML() {
        let tag = makeTag(label: "Event", category: "Cat", anchorTime: 10, transcription: "text", notes: "note")
        let session = makeSession(tags: [tag])
        let output = MarkdownExporter.exportSession(session)
        XCTAssertTrue(output.contains("# "))   // H1
        XCTAssertTrue(output.contains("## "))  // H2
        XCTAssertTrue(output.contains("**"))   // bold
        // No raw HTML in non-blockquote lines
        let nonBlockquoteLines = output.components(separatedBy: "\n").filter { !$0.hasPrefix(">") }
        for line in nonBlockquoteLines {
            XCTAssertNil(line.range(of: "<[a-zA-Z]", options: .regularExpression),
                         "Line should not contain HTML tags: \(line)")
        }
    }

    // MARK: - suggestedFilename sanitization (AC #1, #2)

    func testSuggestedFilename_sessionFormat() {
        let session = makeSession()
        let filename = MarkdownExporter.suggestedFilename(for: session)
        XCTAssertTrue(filename.hasPrefix("Session 7 - "))
        XCTAssertTrue(filename.hasSuffix(".md"))
    }

    func testSuggestedFilename_campaignFormat() {
        let campaign = makeCampaign(name: "Ashlands Campaign")
        let filename = MarkdownExporter.suggestedFilename(for: campaign)
        XCTAssertEqual(filename, "Campaign - Ashlands Campaign.md")
    }

    func testSuggestedFilename_stripsForwardSlash() {
        let session = Session(title: "A/B Test", sessionNumber: 1)
        context.insert(session)
        let filename = MarkdownExporter.suggestedFilename(for: session)
        XCTAssertFalse(filename.contains("/"), "Filename must not contain forward slashes")
        XCTAssertTrue(filename.contains("A-B Test"))
    }

    func testSuggestedFilename_stripsColon() {
        let session = Session(title: "Chapter: One", sessionNumber: 2)
        context.insert(session)
        let filename = MarkdownExporter.suggestedFilename(for: session)
        XCTAssertFalse(filename.contains(":"), "Filename must not contain colons")
    }

    func testSuggestedFilename_stripsBackslash() {
        let campaign = Campaign(name: "Evil\\Campaign")
        context.insert(campaign)
        let filename = MarkdownExporter.suggestedFilename(for: campaign)
        XCTAssertFalse(filename.contains("\\"), "Filename must not contain backslashes")
    }

    func testSuggestedFilename_stripsQuestionMark() {
        let session = Session(title: "What happened?", sessionNumber: 3)
        context.insert(session)
        let filename = MarkdownExporter.suggestedFilename(for: session)
        XCTAssertFalse(filename.contains("?"), "Filename must not contain question marks")
    }

    func testSuggestedFilename_stripsAngleBrackets() {
        let campaign = Campaign(name: "Part <1>")
        context.insert(campaign)
        let filename = MarkdownExporter.suggestedFilename(for: campaign)
        XCTAssertFalse(filename.contains("<"), "Filename must not contain <")
        XCTAssertFalse(filename.contains(">"), "Filename must not contain >")
    }

    func testSuggestedFilename_emptyTitleFallsBackToUntitled() {
        let session = Session(title: "   ", sessionNumber: 1)
        context.insert(session)
        let filename = MarkdownExporter.suggestedFilename(for: session)
        XCTAssertTrue(filename.contains("Untitled"), "Whitespace-only title should fall back to 'Untitled'")
    }

    // MARK: - Multi-line blockquote correctness

    func testExportSession_multiLineSummaryNote_allLinesHaveBlockquotePrefix() {
        let session = makeSession(summary: "Line one\nLine two\nLine three", tags: [])
        let output = MarkdownExporter.exportSession(session)
        let lines = output.components(separatedBy: "\n")
        let summaryLines = lines.filter { $0.hasPrefix("> ") && !$0.contains("Note:") }
        XCTAssertEqual(summaryLines.count, 3, "All three summary lines should have '> ' prefix")
        XCTAssertTrue(summaryLines[0].contains("Line one"))
        XCTAssertTrue(summaryLines[1].contains("Line two"))
        XCTAssertTrue(summaryLines[2].contains("Line three"))
    }

    func testExportSession_multiLineTagNote_allLinesHaveBlockquotePrefix() {
        let tag = makeTag(label: "Event", category: "Story", anchorTime: 100, notes: "First note line\nSecond note line")
        let session = makeSession(summary: nil, tags: [tag])
        let output = MarkdownExporter.exportSession(session)
        let lines = output.components(separatedBy: "\n")
        let noteLines = lines.filter { $0.hasPrefix("> ") }
        XCTAssertEqual(noteLines.count, 2, "Both note lines should have '> ' prefix")
        XCTAssertTrue(noteLines[0].contains("Note: First note line"))
        XCTAssertTrue(noteLines[1].contains("Second note line"))
        XCTAssertFalse(noteLines[1].contains("Note:"), "Continuation lines should not repeat the 'Note:' prefix")
    }
}
