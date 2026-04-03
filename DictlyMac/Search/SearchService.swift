import Foundation
import CoreSpotlight
import SwiftData
import Observation
import os
import DictlyModels

private let logger = Logger(subsystem: "com.dictly.mac", category: "search")

// MARK: - SearchResult

/// A single cross-session search result resolved from Core Spotlight + SwiftData.
struct SearchResult: Identifiable {
    let id: UUID
    let tagID: UUID
    let tagLabel: String
    let sessionTitle: String
    let sessionNumber: Int
    let anchorTime: TimeInterval
    let transcriptionSnippet: String?
    let categoryName: String
    let sessionID: UUID
}

// MARK: - SearchService

/// Cross-session full-text search service backed by Core Spotlight.
///
/// Queries the index built by `SearchIndexer` (Story 6.1) — does not touch SwiftData
/// for text matching. SwiftData is only used to resolve Spotlight results to typed model objects.
@Observable
@MainActor
public final class SearchService {

    // MARK: - Public State

    var searchText: String = ""
    var searchResults: [SearchResult] = []
    var isSearching: Bool = false

    var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Private

    private var searchTask: Task<Void, Never>?
    private var modelContext: ModelContext?

    // MARK: - Init

    public init() {}

    /// Provide a ModelContext so Spotlight results can be resolved to full Tag/Session objects.
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Search

    /// Debounced entry point — called whenever `searchText` changes.
    func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return  // cancelled — a newer search is pending
            }
            await performSearch()
        }
    }

    /// Executes a Core Spotlight query and resolves results via SwiftData.
    func performSearch() async {
        guard isSearchActive, let context = modelContext else {
            searchResults = []
            isSearching = false
            return
        }

        let term = searchText.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        logger.info("Performing search for: \(term, privacy: .public)")

        do {
            let results = try await runSpotlightQuery(term: term, context: context)
            searchResults = results
            logger.info("Search returned \(results.count, privacy: .public) result(s) for '\(term, privacy: .public)'")
        } catch {
            logger.error("Search failed: \(error.localizedDescription, privacy: .public)")
            searchResults = []
        }

        isSearching = false
    }

    /// Clears all search state and returns the sidebar to the current session's tag list.
    func clearSearch() {
        searchTask?.cancel()
        searchTask = nil
        searchText = ""
        searchResults = []
        isSearching = false
        logger.debug("Search cleared")
    }

    // MARK: - Private: Spotlight Query

    private func runSpotlightQuery(term: String, context: ModelContext) async throws -> [SearchResult] {
        let escapedTerm = term.replacingOccurrences(of: "\"", with: "\\\"")
        let queryString = "textContent == '*\(escapedTerm)*'c || title == '*\(escapedTerm)*'c || keywords == '*\(escapedTerm)*'c"

        let queryContext = CSSearchQueryContext()
        queryContext.fetchAttributes = ["title", "displayName", "textContent", "contentDescription", "keywords"]

        let query = CSSearchQuery(queryString: queryString, queryContext: queryContext)

        var items: [CSSearchableItem] = []
        for try await result in query.results {
            items.append(result.item)
        }

        // Resolve Spotlight items to SearchResult values via SwiftData
        var resolved: [SearchResult] = []
        for item in items {
            if let result = resolveItem(item, term: term, context: context) {
                resolved.append(result)
            }
        }

        return sortResults(resolved, term: term)
    }

    // MARK: - Private: Resolution

    private func resolveItem(_ item: CSSearchableItem, term: String, context: ModelContext) -> SearchResult? {
        let attrs = item.attributeSet
        let uuidString = item.uniqueIdentifier
        guard let tagUUID = UUID(uuidString: uuidString) else {
            logger.warning("Spotlight item has invalid UUID: \(uuidString, privacy: .public)")
            return nil
        }

        // Fetch Tag from SwiftData
        let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.uuid == tagUUID })
        guard let tag = try? context.fetch(descriptor).first,
              let session = tag.session else {
            logger.warning("Could not resolve tag UUID in SwiftData")
            return nil
        }

        let tagLabel = attrs.title ?? tag.label
        let transcription = attrs.textContent ?? tag.transcription
        let snippet = generateSnippet(from: transcription, matching: term)

        return SearchResult(
            id: tagUUID,
            tagID: tagUUID,
            tagLabel: tagLabel,
            sessionTitle: session.title,
            sessionNumber: session.sessionNumber,
            anchorTime: tag.anchorTime,
            transcriptionSnippet: snippet,
            categoryName: tag.categoryName,
            sessionID: session.uuid
        )
    }

    // MARK: - Private: Snippet Generation

    /// Extracts ~80 characters around the first occurrence of `term` in `text`.
    /// Wraps the matched term with `**` markers for bold rendering in the UI.
    /// Returns nil when `text` is nil.
    func generateSnippet(from text: String?, matching term: String) -> String? {
        guard let text, !text.isEmpty else { return nil }

        let range = text.range(of: term, options: [.caseInsensitive, .diacriticInsensitive])

        if let matchRange = range {
            let matchStart = text.distance(from: text.startIndex, to: matchRange.lowerBound)
            let windowStart = max(0, matchStart - 40)
            let windowEnd = min(text.count, matchStart + term.count + 40)

            let startIndex = text.index(text.startIndex, offsetBy: windowStart)
            let endIndex = text.index(text.startIndex, offsetBy: windowEnd)
            var snippet = String(text[startIndex..<endIndex])

            // Replace the match with bold markers
            if let snippetRange = snippet.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) {
                let matched = String(snippet[snippetRange])
                snippet.replaceSubrange(snippetRange, with: "**\(matched)**")
            }

            let prefix = windowStart > 0 ? "…" : ""
            let suffix = windowEnd < text.count ? "…" : ""
            return "\(prefix)\(snippet)\(suffix)"
        } else {
            // Term not in text — return first ~80 chars as preview
            let endIndex = text.index(text.startIndex, offsetBy: min(80, text.count))
            let snippet = String(text[..<endIndex])
            let suffix = text.count > 80 ? "…" : ""
            return "\(snippet)\(suffix)"
        }
    }

    // MARK: - Private: Sorting

    /// Sorts results: exact label matches first, then by session date (most recent first).
    private func sortResults(_ results: [SearchResult], term: String) -> [SearchResult] {
        let lower = term.lowercased()
        return results.sorted { a, b in
            let aExact = a.tagLabel.lowercased() == lower
            let bExact = b.tagLabel.lowercased() == lower
            if aExact != bExact { return aExact }
            // Fall back to session number descending (most recent first)
            return a.sessionNumber > b.sessionNumber
        }
    }
}
