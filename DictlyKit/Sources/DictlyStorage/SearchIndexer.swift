import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import os
import DictlyModels

private let logger = Logger(subsystem: "com.dictly", category: "search")

/// Indexes Tag objects in Core Spotlight for system-wide full-text search.
///
/// Stateless utility — all methods use `CSSearchableIndex.default()` (the only index
/// that surfaces items in macOS system Spotlight). Call sites use fire-and-forget `Task {}`
/// and must catch errors so indexing never blocks or fails user operations.
public final class SearchIndexer {

    private static let domainIdentifier = "com.dictly.tags"

    public init() {}

    // MARK: - Public API

    /// Creates or updates the Spotlight index entry for the given tag.
    /// Re-indexing with the same `uniqueIdentifier` (tag.uuid) replaces the existing entry.
    public func indexTag(_ tag: Tag) async throws {
        let item = buildSearchableItem(for: tag)
        do {
            try await CSSearchableIndex.default().indexSearchableItems([item])
            logger.info("SearchIndexer: indexed tag '\(tag.label)' (\(tag.uuid))")
        } catch {
            logger.error("SearchIndexer: indexing failed for '\(tag.label)' — \(error)")
            throw DictlyError.search(.indexingFailed(error.localizedDescription))
        }
    }

    /// Re-indexes the tag — same as indexTag since re-indexing with the same uniqueIdentifier replaces the entry.
    public func updateTag(_ tag: Tag) async throws {
        try await indexTag(tag)
    }

    /// Removes the Spotlight index entry for the given tag UUID.
    public func removeTag(id: UUID) async throws {
        do {
            try await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id.uuidString])
            logger.info("SearchIndexer: removed tag \(id.uuidString)")
        } catch {
            logger.error("SearchIndexer: deletion failed for \(id.uuidString) — \(error)")
            throw DictlyError.search(.deletionFailed(error.localizedDescription))
        }
    }

    /// Removes all Spotlight entries for the tags belonging to a session.
    /// The `tags` array should be the session's tags at deletion time.
    public func removeAllTagsForSession(sessionID: UUID, tags: [Tag]) async throws {
        let identifiers = tags.map { $0.uuid.uuidString }
        guard !identifiers.isEmpty else {
            logger.info("SearchIndexer: no tags to remove for session \(sessionID)")
            return
        }
        do {
            try await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers)
            logger.info("SearchIndexer: removed \(identifiers.count) tags for session \(sessionID)")
        } catch {
            logger.error("SearchIndexer: session deletion failed for \(sessionID) — \(error)")
            throw DictlyError.search(.deletionFailed(error.localizedDescription))
        }
    }

    /// Removes all Dictly-managed Spotlight entries. Use for cleanup or reset.
    public func removeAllItems() async throws {
        do {
            try await CSSearchableIndex.default().deleteAllSearchableItems()
            logger.info("SearchIndexer: all items removed")
        } catch {
            logger.error("SearchIndexer: deleteAll failed — \(error)")
            throw DictlyError.search(.deletionFailed(error.localizedDescription))
        }
    }

    /// Batch-indexes an array of tags in a single Spotlight call for efficiency.
    /// Use this after bulk operations like import.
    public func indexTags(_ tags: [Tag]) async throws {
        guard !tags.isEmpty else { return }
        let items = tags.map { buildSearchableItem(for: $0) }
        do {
            try await CSSearchableIndex.default().indexSearchableItems(items)
            logger.info("SearchIndexer: batch-indexed \(items.count) tags")
        } catch {
            logger.error("SearchIndexer: batch indexing failed — \(error)")
            throw DictlyError.search(.indexingFailed(error.localizedDescription))
        }
    }

    // MARK: - Internal (testable)

    /// Builds a `CSSearchableItem` from a Tag without calling the index.
    /// Exposed as internal so unit tests can verify attribute correctness without
    /// touching the system Spotlight index.
    func buildSearchableItem(for tag: Tag) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(contentType: UTType.text)
        attrs.title = tag.label
        attrs.displayName = buildDisplayName(for: tag)
        attrs.contentDescription = tag.notes ?? tag.categoryName
        attrs.textContent = tag.transcription
        attrs.keywords = buildKeywords(for: tag)

        return CSSearchableItem(
            uniqueIdentifier: tag.uuid.uuidString,
            domainIdentifier: Self.domainIdentifier,
            attributeSet: attrs
        )
    }

    // MARK: - Private

    private func buildDisplayName(for tag: Tag) -> String {
        if let sessionTitle = tag.session?.title {
            return "\(tag.label) — \(sessionTitle)"
        }
        return tag.label
    }

    private func buildKeywords(for tag: Tag) -> [String] {
        var keywords: [String] = [tag.categoryName]
        if let sessionTitle = tag.session?.title {
            keywords.append(sessionTitle)
        }
        if let campaignName = tag.session?.campaign?.name {
            keywords.append(campaignName)
        }
        return keywords
    }
}
