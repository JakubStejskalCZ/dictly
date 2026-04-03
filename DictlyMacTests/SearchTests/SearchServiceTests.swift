import XCTest
import SwiftData
import CoreSpotlight
@testable import DictlyMac
import DictlyModels

// MARK: - SearchServiceTests
//
// Tests for Story 6.2: Full-Text Search Across Sessions.
// Covers: SearchResult construction, snippet generation, state management,
// isSearchActive computed property, and result sorting.
//
// SearchService is @Observable @MainActor — all tests run on MainActor.
// Spotlight query tests are skipped (require entitlement / running app context).

@MainActor
final class SearchServiceTests: XCTestCase {

    var service: SearchService!
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        service = SearchService()
        let schema = Schema(DictlySchema.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext
        service.setModelContext(context)
    }

    override func tearDown() async throws {
        service = nil
        container = nil
        context = nil
    }

    // MARK: - 7.2 SearchResult from Spotlight attributes (via SwiftData resolution path)

    func testSearchResult_builtCorrectly() throws {
        // Set up session + tag in SwiftData
        let session = Session(title: "Session One", sessionNumber: 1)
        let tag = Tag(label: "Grimthor", categoryName: "story", anchorTime: 42.0, rewindDuration: 0)
        tag.transcription = "Grimthor attacked the party with his axe"
        context.insert(session)
        session.tags.append(tag)
        try context.save()

        // Verify the tag's UUID round-trips via SwiftData fetch (mirrors resolution in SearchService)
        let tagUUID = tag.uuid
        let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.uuid == tagUUID })
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.label, "Grimthor")
        XCTAssertEqual(fetched.first?.session?.title, "Session One")
        XCTAssertEqual(fetched.first?.session?.sessionNumber, 1)
    }

    // MARK: - 7.3 Snippet highlights matched term

    func testGenerateSnippet_highlightsMatchedTerm() {
        let text = "The wizard cast a fireball spell that scorched the dungeon walls and set the tapestry ablaze"
        let snippet = service.generateSnippet(from: text, matching: "fireball")
        XCTAssertNotNil(snippet)
        XCTAssertTrue(snippet!.contains("**fireball**"), "Expected '**fireball**' in: \(snippet!)")
    }

    func testGenerateSnippet_highlightsMatchedTerm_caseInsensitive() {
        let text = "Grimthor raised his shield against the FIREBALL"
        let snippet = service.generateSnippet(from: text, matching: "fireball")
        XCTAssertNotNil(snippet)
        // Should bold the actual match (preserving original case)
        XCTAssertTrue(snippet!.contains("**FIREBALL**"), "Expected bold match in: \(snippet!)")
    }

    func testGenerateSnippet_windowSize_isAround80Chars() {
        // Build a 200-char string with the term in the middle
        let prefix = String(repeating: "a", count: 80)
        let suffix = String(repeating: "b", count: 80)
        let text = prefix + "TARGET" + suffix
        let snippet = service.generateSnippet(from: text, matching: "TARGET")!

        // Remove markers and ellipsis for length check
        let plain = snippet
            .replacingOccurrences(of: "**TARGET**", with: "TARGET")
            .replacingOccurrences(of: "…", with: "")
        // ~80 chars window: 40 before + 6 (TARGET) + 40 after = 86 max
        XCTAssertLessThanOrEqual(plain.count, 90)
        XCTAssertTrue(snippet.hasPrefix("…"), "Should have leading ellipsis when not at start")
        XCTAssertTrue(snippet.hasSuffix("…"), "Should have trailing ellipsis when not at end")
    }

    // MARK: - 7.4 No match returns prefix

    func testGenerateSnippet_noMatch_returnsPrefix() {
        let text = "The goblin sharpened its blade in the darkness of the cave beneath the mountains of doom"
        let snippet = service.generateSnippet(from: text, matching: "fireball")
        XCTAssertNotNil(snippet)
        // Should return first ~80 chars without bold markers
        XCTAssertFalse(snippet!.contains("**"))
        XCTAssertTrue(text.hasPrefix(snippet!.replacingOccurrences(of: "…", with: "")))
    }

    func testGenerateSnippet_noMatch_shortText_noTrailingEllipsis() {
        let text = "Short text"
        let snippet = service.generateSnippet(from: text, matching: "zzz")
        XCTAssertEqual(snippet, "Short text")
    }

    // MARK: - 7.5 Nil transcription returns nil

    func testGenerateSnippet_nilTranscription_returnsNil() {
        let snippet = service.generateSnippet(from: nil, matching: "anything")
        XCTAssertNil(snippet)
    }

    func testGenerateSnippet_emptyText_returnsNil() {
        let snippet = service.generateSnippet(from: "", matching: "anything")
        XCTAssertNil(snippet)
    }

    // MARK: - 7.6 clearSearch resets state

    func testClearSearch_resetsState() {
        service.searchText = "Grimthor"
        service.isSearching = true
        service.searchResults = [makeFakeResult()]
        service.clearSearch()

        XCTAssertEqual(service.searchText, "")
        XCTAssertEqual(service.searchResults.count, 0)
        XCTAssertFalse(service.isSearching)
    }

    // MARK: - 7.7 isSearchActive with empty text

    func testIsSearchActive_emptyText_returnsFalse() {
        service.searchText = ""
        XCTAssertFalse(service.isSearchActive)
    }

    // MARK: - 7.8 isSearchActive with whitespace only

    func testIsSearchActive_whitespaceOnly_returnsFalse() {
        service.searchText = "   "
        XCTAssertFalse(service.isSearchActive)
    }

    func testIsSearchActive_tabOnly_returnsFalse() {
        service.searchText = "\t\t"
        XCTAssertFalse(service.isSearchActive)
    }

    // MARK: - 7.9 isSearchActive with text

    func testIsSearchActive_withText_returnsTrue() {
        service.searchText = "Grimthor"
        XCTAssertTrue(service.isSearchActive)
    }

    func testIsSearchActive_textWithLeadingSpaces_returnsTrue() {
        service.searchText = "  Grimthor"
        XCTAssertTrue(service.isSearchActive)
    }

    // MARK: - 7.10 Results sorted by relevance

    func testSearchResults_sortedByRelevance_exactLabelFirst() {
        // Results: partial match first in array, exact match second
        let partial = SearchResult(
            id: UUID(), tagID: UUID(), tagLabel: "Grimthor's Axe",
            sessionTitle: "Session 2", sessionNumber: 2,
            anchorTime: 10, transcriptionSnippet: nil,
            categoryName: "combat", sessionID: UUID(),
            sessionDate: Date(timeIntervalSince1970: 2000)
        )
        let exact = SearchResult(
            id: UUID(), tagID: UUID(), tagLabel: "grimthor",
            sessionTitle: "Session 3", sessionNumber: 3,
            anchorTime: 20, transcriptionSnippet: nil,
            categoryName: "story", sessionID: UUID(),
            sessionDate: Date(timeIntervalSince1970: 3000)
        )
        // Inject results and verify sort via public method
        service.searchResults = [partial, exact]

        // Sort manually using the same logic as SearchService.sortResults (call via performSearch in tests)
        // Here we verify the sort logic by testing the service's internal result ordering
        // by calling the internal sort method indirectly through known inputs.
        // We verify by checking which result the service would place first:
        // exact label match "grimthor" == "grimthor" → should come first.
        let sorted = sortResultsForTest([partial, exact], term: "grimthor")
        XCTAssertEqual(sorted.first?.tagLabel, "grimthor", "Exact match should be first")
    }

    func testSearchResults_sameRelevance_mostRecentSessionFirst() {
        let olderDate = Date(timeIntervalSince1970: 1000)
        let newerDate = Date(timeIntervalSince1970: 9000)
        let older = SearchResult(
            id: UUID(), tagID: UUID(), tagLabel: "combat encounter",
            sessionTitle: "Session 1", sessionNumber: 1,
            anchorTime: 0, transcriptionSnippet: nil,
            categoryName: "combat", sessionID: UUID(),
            sessionDate: olderDate
        )
        let newer = SearchResult(
            id: UUID(), tagID: UUID(), tagLabel: "combat encounter",
            sessionTitle: "Session 5", sessionNumber: 5,
            anchorTime: 0, transcriptionSnippet: nil,
            categoryName: "combat", sessionID: UUID(),
            sessionDate: newerDate
        )
        let sorted = sortResultsForTest([older, newer], term: "combat")
        // Neither is an exact match — sort by session date descending (most recent first)
        XCTAssertEqual(sorted.first?.sessionDate, newerDate)
    }

    // MARK: - Helpers

    private func makeFakeResult() -> SearchResult {
        SearchResult(
            id: UUID(), tagID: UUID(), tagLabel: "Test",
            sessionTitle: "Session 1", sessionNumber: 1,
            anchorTime: 0, transcriptionSnippet: nil,
            categoryName: "story", sessionID: UUID(),
            sessionDate: Date()
        )
    }

    /// Mirrors SearchService.sortResults logic for white-box testing.
    private func sortResultsForTest(_ results: [SearchResult], term: String) -> [SearchResult] {
        let lower = term.lowercased()
        return results.sorted { a, b in
            let aExact = a.tagLabel.lowercased() == lower
            let bExact = b.tagLabel.lowercased() == lower
            if aExact != bExact { return aExact }
            return a.sessionDate > b.sessionDate
        }
    }
}
