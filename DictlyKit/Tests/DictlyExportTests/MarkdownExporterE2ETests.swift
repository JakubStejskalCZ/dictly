import XCTest
import SwiftData
import Foundation
@testable import DictlyExport
import DictlyModels

typealias DictlyTag6_4 = DictlyModels.Tag

// MARK: - Markdown Export E2E Tests (Story 6.4)
//
// End-to-end tests for Markdown Export — Single Session & Campaign.
// Covers all acceptance criteria:
//   AC1: "Export MD" → markdown with session title, date, duration, tags grouped by category
//   AC2: "Export Campaign" → markdown with all sessions, same structure
//   AC3: CommonMark-compatible output (renders in Obsidian, GitHub, VS Code)
//   AC4: Export complete → notification + Finder reveal (logic-verified, no UI)
//
// Uses in-memory SwiftData. File I/O and NSSavePanel are not tested here
// (those require UI test harness / sandbox). Logic tested via MarkdownExporter.

@MainActor
final class MarkdownExporterE2ETests: XCTestCase {

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
        number: Int = 1,
        title: String = "Test Session",
        date: Date = Date(timeIntervalSince1970: 1742000000),
        duration: TimeInterval = 13642,
        location: String? = nil,
        summary: String? = nil
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
        return s
    }

    private func makeTag(
        label: String,
        category: String,
        anchorTime: TimeInterval,
        transcription: String? = nil,
        notes: String? = nil
    ) -> DictlyTag6_4 {
        let tag = DictlyTag6_4(
            label: label,
            categoryName: category,
            anchorTime: anchorTime,
            rewindDuration: 0,
            notes: notes,
            transcription: transcription
        )
        context.insert(tag)
        return tag
    }

    private func makeCampaign(name: String, description: String = "") -> Campaign {
        let c = Campaign(name: name, descriptionText: description)
        context.insert(c)
        return c
    }

    private func addTagsToSession(_ session: Session, tags: [DictlyTag6_4]) {
        for tag in tags {
            session.tags.append(tag)
        }
    }

    // MARK: - AC1: Session export — title, date, duration, tags grouped by category

    func testAC1_sessionExport_containsH1Title() {
        let session = makeSession(number: 7, title: "The Return to Grimthor's Shop")
        let output = MarkdownExporter.exportSession(session)

        XCTAssertTrue(output.contains("# Session 7 — The Return to Grimthor's Shop"))
    }

    func testAC1_sessionExport_containsDate() {
        let session = makeSession()
        let output = MarkdownExporter.exportSession(session)

        XCTAssertTrue(output.contains("**Date:**"), "Must show date in metadata")
    }

    func testAC1_sessionExport_containsDuration() {
        let session = makeSession(duration: 13642) // 3:47:22
        let output = MarkdownExporter.exportSession(session)

        XCTAssertTrue(output.contains("**Duration:**"), "Must show duration")
    }

    func testAC1_sessionExport_containsTagCount() {
        let session = makeSession()
        let tag = makeTag(label: "Event", category: "Story", anchorTime: 100)
        addTagsToSession(session, tags: [tag])
        let output = MarkdownExporter.exportSession(session)

        XCTAssertTrue(output.contains("**Tags:** 1"))
    }

    func testAC1_sessionExport_containsLocation() {
        let session = makeSession(location: "Jake's Place")
        let output = MarkdownExporter.exportSession(session)

        XCTAssertTrue(output.contains("**Location:** Jake's Place"))
    }

    func testAC1_sessionExport_tagsGroupedByCategory() {
        let tags = [
            makeTag(label: "Ambush", category: "Combat", anchorTime: 2712),
            makeTag(label: "Promise", category: "Story", anchorTime: 754),
            makeTag(label: "Chat", category: "Roleplay", anchorTime: 7833)
        ]
        let session = makeSession()
        addTagsToSession(session, tags: tags)
        let output = MarkdownExporter.exportSession(session)

        XCTAssertTrue(output.contains("## Combat"))
        XCTAssertTrue(output.contains("## Roleplay"))
        XCTAssertTrue(output.contains("## Story"))
    }

    func testAC1_sessionExport_categoriesAlphabeticalOrder() {
        let tags = [
            makeTag(label: "Z", category: "World", anchorTime: 1),
            makeTag(label: "A", category: "Combat", anchorTime: 2),
            makeTag(label: "M", category: "Meta", anchorTime: 3)
        ]
        let session = makeSession()
        addTagsToSession(session, tags: tags)
        let output = MarkdownExporter.exportSession(session)

        let combatPos = output.range(of: "## Combat")!.lowerBound
        let metaPos = output.range(of: "## Meta")!.lowerBound
        let worldPos = output.range(of: "## World")!.lowerBound

        XCTAssertTrue(combatPos < metaPos, "Combat before Meta alphabetically")
        XCTAssertTrue(metaPos < worldPos, "Meta before World alphabetically")
    }

    func testAC1_sessionExport_tagLabelsWithTimestamps() {
        let tag = makeTag(label: "Grimthor's Promise", category: "Story", anchorTime: 754) // 0:12:34
        let session = makeSession()
        addTagsToSession(session, tags: [tag])
        let output = MarkdownExporter.exportSession(session)

        XCTAssertTrue(output.contains("[0:12:34]"), "Timestamp formatted as H:MM:SS")
        XCTAssertTrue(output.contains("Grimthor's Promise"))
    }

    func testAC1_sessionExport_transcriptionsIncluded() {
        let tag = makeTag(label: "Promise", category: "Story", anchorTime: 100,
                          transcription: "He would forge the blade.")
        let session = makeSession()
        addTagsToSession(session, tags: [tag])
        let output = MarkdownExporter.exportSession(session)

        XCTAssertTrue(output.contains("He would forge the blade."))
    }

    func testAC1_sessionExport_notesIncluded() {
        let tag = makeTag(label: "Promise", category: "Story", anchorTime: 100,
                          notes: "Important plot hook")
        let session = makeSession()
        addTagsToSession(session, tags: [tag])
        let output = MarkdownExporter.exportSession(session)

        XCTAssertTrue(output.contains("> Note: Important plot hook"))
    }

    func testAC1_sessionExport_summaryNoteAsBlockquote() {
        let session = makeSession(summary: "Great session with epic moments")
        let output = MarkdownExporter.exportSession(session)

        XCTAssertTrue(output.contains("> Great session with epic moments"))
    }

    func testAC1_sessionExport_tagsWithinCategorySortedByTime() {
        let tags = [
            makeTag(label: "Later", category: "Story", anchorTime: 6302),  // 1:45:02
            makeTag(label: "Earlier", category: "Story", anchorTime: 754)  // 0:12:34
        ]
        let session = makeSession()
        addTagsToSession(session, tags: tags)
        let output = MarkdownExporter.exportSession(session)

        let earlierPos = output.range(of: "[0:12:34]")!.lowerBound
        let laterPos = output.range(of: "[1:45:02]")!.lowerBound
        XCTAssertTrue(earlierPos < laterPos, "Earlier tag before later tag")
    }

    func testAC1_sessionExport_noTags_showsPlaceholder() {
        let session = makeSession()
        let output = MarkdownExporter.exportSession(session)

        XCTAssertTrue(output.contains("No tags recorded"))
    }

    func testAC1_sessionExport_noTranscription_showsPlaceholder() {
        let tag = DictlyTag6_4(label: "Silent", categoryName: "Roleplay",
                               anchorTime: 100, rewindDuration: 0)
        context.insert(tag)
        let session = makeSession()
        session.tags.append(tag)
        let output = MarkdownExporter.exportSession(session)

        XCTAssertTrue(output.contains("(no transcription)"))
    }

    func testAC1_sessionExport_missingOptionals_gracefullyOmitted() {
        let session = Session(title: "Minimal", sessionNumber: 1)
        context.insert(session)
        let output = MarkdownExporter.exportSession(session)

        XCTAssertTrue(output.contains("# Session 1 — Minimal"))
        XCTAssertFalse(output.contains("**Location:**"), "No location when nil")
        let blockquotes = output.components(separatedBy: "\n").filter { $0.hasPrefix(">") }
        XCTAssertTrue(blockquotes.isEmpty, "No blockquote when no summary")
    }

    // MARK: - AC2: Campaign export

    func testAC2_campaignExport_containsH1Name() {
        let campaign = makeCampaign(name: "Ashlands Campaign", description: "A dark fantasy campaign.")
        let output = MarkdownExporter.exportCampaign(campaign)

        XCTAssertTrue(output.contains("# Ashlands Campaign"))
    }

    func testAC2_campaignExport_containsDescription() {
        let campaign = makeCampaign(name: "Ashlands", description: "Epic dark fantasy adventure.")
        let output = MarkdownExporter.exportCampaign(campaign)

        XCTAssertTrue(output.contains("Epic dark fantasy adventure."))
    }

    func testAC2_campaignExport_sessionsAsH2SortedByDate() {
        let campaign = makeCampaign(name: "Test Campaign")
        let s1 = makeSession(number: 1, title: "First", date: Date(timeIntervalSince1970: 1_000_000))
        let s2 = makeSession(number: 2, title: "Second", date: Date(timeIntervalSince1970: 2_000_000))
        campaign.sessions = [s2, s1] // out of order
        let output = MarkdownExporter.exportCampaign(campaign)

        let firstPos = output.range(of: "## Session 1 — First")!.lowerBound
        let secondPos = output.range(of: "## Session 2 — Second")!.lowerBound
        XCTAssertTrue(firstPos < secondPos, "Sessions sorted chronologically")
    }

    func testAC2_campaignExport_categoryHeadingsShiftedToH3() {
        let campaign = makeCampaign(name: "Test Campaign")
        let tag = makeTag(label: "Event", category: "Story", anchorTime: 100)
        let session = makeSession(number: 1, title: "Session One")
        session.tags.append(tag)
        campaign.sessions.append(session)
        let output = MarkdownExporter.exportCampaign(campaign)

        XCTAssertTrue(output.contains("### Story"), "Category headings H3 in campaign")
        // Ensure no standalone "## Story"
        let h2StoryLines = output.components(separatedBy: "\n")
            .filter { $0 == "## Story" }
        XCTAssertTrue(h2StoryLines.isEmpty, "No H2 category headings in campaign export")
    }

    func testAC2_campaignExport_emptyCampaign() {
        let campaign = makeCampaign(name: "Empty Campaign")
        let output = MarkdownExporter.exportCampaign(campaign)

        XCTAssertTrue(output.contains("No sessions in this campaign"))
    }

    func testAC2_campaignExport_multipleSessionsWithTags() throws {
        let campaign = makeCampaign(name: "Full Campaign", description: "A complete adventure")

        // Session 1
        let s1 = makeSession(number: 1, title: "Into the Ashlands",
                              date: Date(timeIntervalSince1970: 1_000_000), duration: 7200,
                              location: "Jake's Place")
        s1.tags.append(makeTag(label: "Opening", category: "Story", anchorTime: 322,
                               transcription: "The party enters the volcanic wasteland"))
        s1.tags.append(makeTag(label: "First Fight", category: "Combat", anchorTime: 1200))
        campaign.sessions.append(s1)

        // Session 2
        let s2 = makeSession(number: 2, title: "The First Betrayal",
                              date: Date(timeIntervalSince1970: 1_600_000), duration: 10800)
        s2.tags.append(makeTag(label: "NPC Intro", category: "Story", anchorTime: 488,
                               transcription: "Kira appeared from the shadows",
                               notes: "Key NPC — remember for session 3"))
        campaign.sessions.append(s2)
        try context.save()

        let output = MarkdownExporter.exportCampaign(campaign)

        XCTAssertTrue(output.contains("# Full Campaign"))
        XCTAssertTrue(output.contains("A complete adventure"))
        XCTAssertTrue(output.contains("## Session 1"))
        XCTAssertTrue(output.contains("## Session 2"))
        XCTAssertTrue(output.contains("Opening"))
        XCTAssertTrue(output.contains("The party enters the volcanic wasteland"))
        XCTAssertTrue(output.contains("NPC Intro"))
        XCTAssertTrue(output.contains("> Note: Key NPC"))
    }

    // MARK: - AC3: CommonMark compliance

    func testAC3_commonMark_noRawHTML() {
        let tag = makeTag(label: "Event", category: "Cat", anchorTime: 10,
                          transcription: "text", notes: "note")
        let session = makeSession()
        addTagsToSession(session, tags: [tag])
        let output = MarkdownExporter.exportSession(session)

        let nonBlockquoteLines = output.components(separatedBy: "\n").filter { !$0.hasPrefix(">") }
        for line in nonBlockquoteLines {
            XCTAssertNil(line.range(of: "<[a-zA-Z]", options: .regularExpression),
                         "No HTML tags allowed: \(line)")
        }
    }

    func testAC3_commonMark_usesStandardHeadings() {
        let tag = makeTag(label: "A", category: "Story", anchorTime: 1)
        let session = makeSession()
        addTagsToSession(session, tags: [tag])
        let output = MarkdownExporter.exportSession(session)

        XCTAssertTrue(output.contains("# "), "Uses H1")
        XCTAssertTrue(output.contains("## "), "Uses H2")
    }

    func testAC3_commonMark_usesBold() {
        let tag = makeTag(label: "Event", category: "Story", anchorTime: 100)
        let session = makeSession()
        addTagsToSession(session, tags: [tag])
        let output = MarkdownExporter.exportSession(session)

        XCTAssertTrue(output.contains("**"), "Uses bold markdown")
    }

    func testAC3_commonMark_usesBlockquotes() {
        let session = makeSession(summary: "A note")
        let output = MarkdownExporter.exportSession(session)

        XCTAssertTrue(output.contains("> "), "Uses blockquote for summary")
    }

    func testAC3_multiLineSummary_allLinesBlockquoted() {
        let session = makeSession(summary: "Line one\nLine two\nLine three")
        let output = MarkdownExporter.exportSession(session)

        let summaryLines = output.components(separatedBy: "\n")
            .filter { $0.hasPrefix("> ") && !$0.contains("Note:") }
        XCTAssertEqual(summaryLines.count, 3, "All summary lines should be blockquoted")
    }

    func testAC3_multiLineTagNote_allLinesBlockquoted() {
        let tag = makeTag(label: "Event", category: "Story", anchorTime: 100,
                          notes: "First note line\nSecond note line")
        let session = makeSession(summary: nil)
        addTagsToSession(session, tags: [tag])
        let output = MarkdownExporter.exportSession(session)

        let noteLines = output.components(separatedBy: "\n").filter { $0.hasPrefix("> ") }
        XCTAssertEqual(noteLines.count, 2)
        XCTAssertTrue(noteLines[0].contains("Note: First note line"))
    }

    // MARK: - AC4: Post-export (logic verification)

    func testAC4_suggestedFilename_sessionFormat() {
        let session = makeSession(number: 7, title: "The Return to Grimthor's Shop")
        let filename = MarkdownExporter.suggestedFilename(for: session)

        XCTAssertTrue(filename.hasPrefix("Session 7 - "))
        XCTAssertTrue(filename.hasSuffix(".md"))
    }

    func testAC4_suggestedFilename_campaignFormat() {
        let campaign = makeCampaign(name: "Ashlands Campaign")
        let filename = MarkdownExporter.suggestedFilename(for: campaign)

        XCTAssertEqual(filename, "Campaign - Ashlands Campaign.md")
    }

    func testAC4_suggestedFilename_sanitizesSpecialChars() {
        let session = Session(title: "A/B: Test?", sessionNumber: 1)
        context.insert(session)
        let filename = MarkdownExporter.suggestedFilename(for: session)

        XCTAssertFalse(filename.contains("/"))
        XCTAssertFalse(filename.contains(":"))
        XCTAssertFalse(filename.contains("?"))
    }

    func testAC4_suggestedFilename_sanitizesAngleBrackets() {
        let campaign = Campaign(name: "Part <1>")
        context.insert(campaign)
        let filename = MarkdownExporter.suggestedFilename(for: campaign)

        XCTAssertFalse(filename.contains("<"))
        XCTAssertFalse(filename.contains(">"))
    }

    func testAC4_suggestedFilename_emptyTitle_fallsBack() {
        let session = Session(title: "   ", sessionNumber: 1)
        context.insert(session)
        let filename = MarkdownExporter.suggestedFilename(for: session)

        XCTAssertTrue(filename.contains("Untitled"), "Whitespace title falls back")
    }

    func testAC4_exportedMarkdown_writableAsUTF8() {
        let tag = makeTag(label: "Unicode: ", category: "Story", anchorTime: 100,
                          transcription: "Characters: , , ")
        let session = makeSession()
        addTagsToSession(session, tags: [tag])
        let output = MarkdownExporter.exportSession(session)

        let data = output.data(using: .utf8)
        XCTAssertNotNil(data, "Markdown must be valid UTF-8")
        XCTAssertGreaterThan(data!.count, 0)
    }

    // MARK: - E2E: Full export workflows

    func testE2E_sessionExport_completeWorkflow() throws {
        let session = makeSession(
            number: 7,
            title: "The Return to Grimthor's Shop",
            duration: 13642,
            location: "Jake's Place",
            summary: "Session summary note text here"
        )

        let tags = [
            makeTag(label: "Grimthor's Promise", category: "Story", anchorTime: 754,
                    transcription: "Grimthor leaned forward and whispered that he would forge the blade.",
                    notes: "Important — ties to session 3 plot hook"),
            makeTag(label: "Rival Faction Hint", category: "Story", anchorTime: 6302,
                    transcription: "A hooded figure was spotted watching from the alley."),
            makeTag(label: "Ambush in the Alley", category: "Combat", anchorTime: 2712,
                    transcription: "Three rogues attacked from the shadows."),
            makeTag(label: "Tavern Negotiation", category: "Roleplay", anchorTime: 7833)
        ]
        addTagsToSession(session, tags: tags)
        try context.save()

        let output = MarkdownExporter.exportSession(session)

        // Verify complete structure
        XCTAssertTrue(output.contains("# Session 7 — The Return to Grimthor's Shop"))
        XCTAssertTrue(output.contains("**Date:**"))
        XCTAssertTrue(output.contains("**Duration:**"))
        XCTAssertTrue(output.contains("**Tags:** 4"))
        XCTAssertTrue(output.contains("**Location:** Jake's Place"))
        XCTAssertTrue(output.contains("> Session summary note text here"))
        XCTAssertTrue(output.contains("## Combat"))
        XCTAssertTrue(output.contains("## Roleplay"))
        XCTAssertTrue(output.contains("## Story"))
        XCTAssertTrue(output.contains("[0:12:34]"), "754s = 0:12:34")
        XCTAssertTrue(output.contains("Grimthor's Promise"))
        XCTAssertTrue(output.contains("Grimthor leaned forward"))
        XCTAssertTrue(output.contains("> Note: Important — ties to session 3 plot hook"))
        XCTAssertTrue(output.contains("(no transcription)"), "Tavern Negotiation has no transcription")

        // Filename
        let filename = MarkdownExporter.suggestedFilename(for: session)
        XCTAssertTrue(filename.hasSuffix(".md"))
    }

    func testE2E_campaignExport_completeWorkflow() throws {
        let campaign = makeCampaign(name: "Ashlands Campaign",
                                     description: "A dark fantasy campaign set in the volcanic Ashlands.")

        // Session 1
        let s1 = makeSession(number: 1, title: "Into the Ashlands",
                              date: Date(timeIntervalSince1970: 1_705_000_000))
        s1.tags.append(makeTag(label: "Opening Narration", category: "Story", anchorTime: 322,
                               transcription: "The party crossed the border into the Ashlands."))
        campaign.sessions.append(s1)

        // Session 2
        let s2 = makeSession(number: 2, title: "The First Betrayal",
                              date: Date(timeIntervalSince1970: 1_705_600_000))
        s2.tags.append(makeTag(label: "NPC Introduction — Kira", category: "Story", anchorTime: 488,
                               transcription: "A cloaked figure stepped from the shadows."))
        campaign.sessions.append(s2)
        try context.save()

        let output = MarkdownExporter.exportCampaign(campaign)

        // Structure
        XCTAssertTrue(output.contains("# Ashlands Campaign"))
        XCTAssertTrue(output.contains("A dark fantasy campaign"))
        XCTAssertTrue(output.contains("## Session 1 — Into the Ashlands"))
        XCTAssertTrue(output.contains("## Session 2 — The First Betrayal"))
        XCTAssertTrue(output.contains("### Story"), "H3 for category in campaign")
        XCTAssertTrue(output.contains("Opening Narration"))
        XCTAssertTrue(output.contains("NPC Introduction — Kira"))

        // Chronological order
        let s1Pos = output.range(of: "## Session 1")!.lowerBound
        let s2Pos = output.range(of: "## Session 2")!.lowerBound
        XCTAssertTrue(s1Pos < s2Pos)

        // Filename
        let filename = MarkdownExporter.suggestedFilename(for: campaign)
        XCTAssertEqual(filename, "Campaign - Ashlands Campaign.md")
    }

    func testE2E_largeSessionExport_manyTagsAndCategories() throws {
        let session = makeSession(number: 1, title: "Marathon Session", duration: 36000)

        let categories = ["Combat", "Story", "Roleplay", "World", "Meta"]
        for (i, category) in categories.enumerated() {
            for j in 1...5 {
                let anchorTime = TimeInterval((i * 5 + j) * 300)
                let tag = makeTag(label: "\(category) Event \(j)", category: category,
                                  anchorTime: anchorTime,
                                  transcription: "Transcription for \(category) event \(j)")
                session.tags.append(tag)
            }
        }
        try context.save()

        let output = MarkdownExporter.exportSession(session)

        XCTAssertTrue(output.contains("**Tags:** 25"))
        for category in categories {
            XCTAssertTrue(output.contains("## \(category)"), "Must have \(category) heading")
        }

        // Verify UTF-8 encoding works for large output
        let data = output.data(using: .utf8)
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data!.count, 1000, "Large export should produce substantial output")
    }

    func testAC4_suggestedFilename_backslash() {
        let campaign = Campaign(name: "Evil\\Campaign")
        context.insert(campaign)
        let filename = MarkdownExporter.suggestedFilename(for: campaign)

        XCTAssertFalse(filename.contains("\\"))
    }

    func testAC4_suggestedFilename_pipe() {
        let session = Session(title: "This|That", sessionNumber: 1)
        context.insert(session)
        let filename = MarkdownExporter.suggestedFilename(for: session)

        XCTAssertFalse(filename.contains("|"))
    }

    func testAC4_suggestedFilename_asterisk() {
        let session = Session(title: "Star*Wars", sessionNumber: 1)
        context.insert(session)
        let filename = MarkdownExporter.suggestedFilename(for: session)

        XCTAssertFalse(filename.contains("*"))
    }

    func testAC4_suggestedFilename_doubleQuote() {
        let session = Session(title: "Say \"Hello\"", sessionNumber: 1)
        context.insert(session)
        let filename = MarkdownExporter.suggestedFilename(for: session)

        XCTAssertFalse(filename.contains("\""))
    }
}
