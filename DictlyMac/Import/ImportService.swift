import Foundation
import SwiftData
import os
import DictlyModels
import DictlyStorage

// MARK: - ImportState

enum ImportState: Equatable {
    case idle
    case importing(progress: Double)
    case completed(sessionTitle: String)
    case duplicate(sessionTitle: String)
    case failed(Error)

    static func == (lhs: ImportState, rhs: ImportState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.importing(let l), .importing(let r)): return l == r
        case (.completed(let l), .completed(let r)): return l == r
        case (.duplicate(let l), .duplicate(let r)): return l == r
        case (.failed, .failed):
            return false
        default: return false
        }
    }
}

// MARK: - ImportService

/// Orchestrates the import of `.dictly` bundles from AirDrop, Finder, and local network.
///
/// Entry points:
/// - `importBundle(from:context:)` — called from `onOpenURL` (AirDrop/Finder) or network receiver
/// - `replaceExisting(from:context:)` — called when user chooses "Replace" after a duplicate warning
/// - `skipDuplicate()` — called when user chooses "Skip" after a duplicate warning
/// - `retry()` — called when user wants to retry after a failure
@Observable
@MainActor
final class ImportService {

    private let logger = Logger(subsystem: "com.dictly.mac", category: "import")

    // MARK: - Observable State

    /// Current import state. Drives `ImportProgressView`.
    private(set) var importState: ImportState = .idle

    // MARK: - Private

    /// Stored for retry and replace-duplicate flows.
    private var lastBundleURL: URL?
    private var lastContext: ModelContext?

    // MARK: - Public API

    /// Begins importing a `.dictly` bundle from the given URL.
    ///
    /// Sets `importState` to `.importing(progress: 0.0)` immediately,
    /// then performs dedup check and import asynchronously.
    func importBundle(from url: URL, context: ModelContext) {
        if case .importing = importState {
            logger.warning("ImportService: import already in progress, ignoring new request for '\(url.lastPathComponent)'")
            return
        }
        logger.info("ImportService: importBundle — \(url.lastPathComponent)")
        lastBundleURL = url
        lastContext = context
        importState = .importing(progress: 0.0)
        Task {
            await performImport(from: url, context: context)
        }
    }

    /// Replaces an existing session with the one in the given bundle.
    ///
    /// Deletes the existing session (cascade deletes its tags) and its audio file,
    /// then re-imports from the same bundle URL.
    func replaceExisting(from url: URL, context: ModelContext) {
        if case .importing = importState {
            logger.warning("ImportService: import already in progress, ignoring replace request")
            return
        }
        logger.info("ImportService: replaceExisting — \(url.lastPathComponent)")
        lastBundleURL = url
        lastContext = context
        importState = .importing(progress: 0.0)
        Task {
            do {
                let (bundle, _) = try BundleSerializer().deserialize(from: url)
                let sessionUUID = bundle.session.uuid
                let descriptor = FetchDescriptor<Session>(
                    predicate: #Predicate<Session> { session in
                        session.uuid == sessionUUID
                    }
                )
                let existing = try context.fetch(descriptor)
                for session in existing {
                    if let audioPath = session.audioFilePath {
                        try? AudioFileManager.deleteAudioFile(at: audioPath)
                        logger.info("ImportService: deleted existing audio file for '\(session.title)'")
                    }
                    context.delete(session)
                    logger.info("ImportService: deleted existing session '\(session.title)'")
                }
                try context.save()
                await performImport(from: url, context: context)
            } catch {
                logger.error("ImportService: replaceExisting failed — \(error)")
                importState = .failed(error)
            }
        }
    }

    /// Convenience variant for replace-duplicate flow using the stored last bundle URL and context.
    func replaceExistingDuplicate() {
        guard let url = lastBundleURL, let context = lastContext else {
            logger.warning("ImportService: replaceExistingDuplicate — no stored bundle URL or context")
            return
        }
        replaceExisting(from: url, context: context)
    }

    /// Resets `importState` to `.idle` without making any data changes.
    /// Called when user skips a duplicate.
    func skipDuplicate() {
        logger.info("ImportService: skipDuplicate — state → .idle")
        importState = .idle
    }

    /// Resets `importState` to `.idle`. Used to dismiss completed/failed banners.
    func dismiss() {
        logger.info("ImportService: dismiss — state → .idle")
        importState = .idle
    }

    /// Retries the last import using the stored URL and context.
    func retry() {
        guard let url = lastBundleURL, let context = lastContext else {
            logger.warning("ImportService: retry — no stored bundle URL or context")
            return
        }
        importBundle(from: url, context: context)
    }

    // MARK: - Private Implementation

    private func performImport(from url: URL, context: ModelContext) async {
        logger.info("ImportService: performImport starting — \(url.lastPathComponent)")
        do {
            // 1. Deserialize bundle
            let (bundle, audioData) = try BundleSerializer().deserialize(from: url)
            logger.info("ImportService: deserialized bundle — session '\(bundle.session.title)'")

            // 2. Dedup check
            let sessionUUID = bundle.session.uuid
            let descriptor = FetchDescriptor<Session>(
                predicate: #Predicate<Session> { session in
                    session.uuid == sessionUUID
                }
            )
            let existing = try context.fetch(descriptor)
            guard existing.isEmpty else {
                logger.info("ImportService: duplicate detected — '\(bundle.session.title)' already exists")
                importState = .duplicate(sessionTitle: bundle.session.title)
                return
            }

            importState = .importing(progress: 0.3)

            // 3. Campaign resolution
            let campaign = try resolveCampaign(from: bundle, context: context)

            importState = .importing(progress: 0.5)

            // 4. Create session + tags
            let session = Session.from(bundle.session)
            let tags = bundle.tags.map { Tag.from($0) }
            session.tags = tags
            session.campaign = campaign

            importState = .importing(progress: 0.7)

            // 5. Store audio file
            let storageDir = try AudioFileManager.audioStorageDirectory()
            let audioDestination = storageDir.appendingPathComponent("\(session.uuid).m4a")
            try audioData.write(to: audioDestination)
            session.audioFilePath = audioDestination.path
            logger.info("ImportService: audio stored at \(audioDestination.lastPathComponent)")

            importState = .importing(progress: 0.9)

            // 6. Persist to SwiftData
            context.insert(session)
            try context.save()
            logger.info("ImportService: session '\(bundle.session.title)' saved to SwiftData")

            // 7. Batch-index all imported tags in Spotlight (fire-and-forget — import succeeds regardless)
            let tagsForIndex = tags
            Task {
                do {
                    try await SearchIndexer().indexTags(tagsForIndex)
                } catch {
                    logger.error("ImportService: spotlight batch indexing failed — \(error)")
                }
            }

            // 9. Clean up source bundle if it resides in a temp directory
            let tempDir = FileManager.default.temporaryDirectory.standardizedFileURL
            if url.standardizedFileURL.path.hasPrefix(tempDir.path) {
                try? FileManager.default.removeItem(at: url)
                logger.info("ImportService: source bundle cleaned up")
            } else {
                logger.info("ImportService: source bundle not in temp directory, skipping cleanup")
            }

            importState = .completed(sessionTitle: bundle.session.title)
            logger.info("ImportService: import completed — '\(bundle.session.title)'")

        } catch {
            logger.error("ImportService: performImport failed — \(error)")
            importState = .failed(error)
        }
    }

    private func resolveCampaign(from bundle: TransferBundle, context: ModelContext) throws -> Campaign? {
        guard let campaignDTO = bundle.campaign else {
            logger.info("ImportService: bundle has no campaign — session will be unassigned")
            return nil
        }

        let campaignUUID = campaignDTO.uuid
        let descriptor = FetchDescriptor<Campaign>(
            predicate: #Predicate<Campaign> { campaign in
                campaign.uuid == campaignUUID
            }
        )
        let existing = try context.fetch(descriptor)

        if let campaign = existing.first {
            logger.info("ImportService: reusing existing campaign '\(campaignDTO.name)'")
            return campaign
        } else {
            let newCampaign = Campaign.from(campaignDTO)
            context.insert(newCampaign)
            logger.info("ImportService: created new campaign '\(campaignDTO.name)'")
            return newCampaign
        }
    }
}
