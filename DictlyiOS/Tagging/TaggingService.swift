import UIKit
import OSLog
import Observation
import SwiftData
import DictlyModels
import DictlyStorage

private let logger = Logger(subsystem: "com.dictly.ios", category: "tagging")

/// `@Observable @MainActor` service that handles tag placement during recording.
/// Creates new `Tag` records in SwiftData, appends them to the active session,
/// and fires haptic feedback on every placement.
@Observable @MainActor
final class TaggingService {

    // MARK: - Private

    private let sessionRecorder: SessionRecorder
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var capturedAnchor: (anchorTime: TimeInterval, actualRewind: TimeInterval)?

    // MARK: - Init

    init(sessionRecorder: SessionRecorder) {
        self.sessionRecorder = sessionRecorder
        hapticGenerator.prepare()
    }

    // MARK: - Tag Placement

    /// Creates a new `Tag` anchored to the recording time rewound by `rewindDuration`,
    /// appends it to `session.tags`, fires haptic feedback, and persists to SwiftData.
    /// Must complete within 200ms — no blocking work on the main thread.
    /// Returns `true` if the tag was persisted successfully.
    @discardableResult
    func placeTag(label: String, categoryName: String, rewindDuration: TimeInterval, session: Session, context: ModelContext) -> Bool {
        // Fire haptic immediately — primary confirmation channel
        hapticGenerator.impactOccurred()

        let elapsedTime = sessionRecorder.elapsedTime
        let clampedRewind = max(0, rewindDuration)
        let anchorTime = max(0, elapsedTime - clampedRewind)
        let actualRewind = elapsedTime - anchorTime
        let newTag = Tag(
            label: label,
            categoryName: categoryName,
            anchorTime: anchorTime,
            rewindDuration: actualRewind,
            createdAt: Date()
        )

        context.insert(newTag)
        session.tags.append(newTag)

        do {
            try context.save()
            logger.info("Tag placed: \(label, privacy: .public) in \(categoryName, privacy: .public) at \(anchorTime, privacy: .public) (rewound \(actualRewind, privacy: .public)s from \(elapsedTime, privacy: .public))")
            let tagForIndex = newTag
            Task {
                do {
                    try await SearchIndexer().indexTag(tagForIndex)
                } catch {
                    logger.error("Failed to index tag in Spotlight: \(error, privacy: .public)")
                }
            }
            return true
        } catch {
            logger.error("Failed to place tag: \(error, privacy: .public)")
            session.tags.removeAll { $0.uuid == newTag.uuid }
            context.delete(newTag)
            return false
        }
    }

    /// Re-warms the Taptic Engine. Call when the recording palette becomes visible.
    func prepareHaptic() {
        hapticGenerator.prepare()
    }

    // MARK: - Custom Tag Anchor Capture (Story 2.6)

    /// Captures the current rewind-anchor timestamp at the moment of the "+" tap (timestamp-first).
    /// Fires haptic immediately. The captured anchor is used later by `placeTagWithCapturedAnchor`.
    func captureAnchor(rewindDuration: TimeInterval) {
        let elapsedTime = sessionRecorder.elapsedTime
        let clampedRewind = max(0, rewindDuration)
        let anchorTime = max(0, elapsedTime - clampedRewind)
        let actualRewind = elapsedTime - anchorTime
        capturedAnchor = (anchorTime: anchorTime, actualRewind: actualRewind)
        hapticGenerator.impactOccurred()
        logger.info("Anchor captured at \(anchorTime, privacy: .public) (rewound \(actualRewind, privacy: .public)s) for custom tag")
    }

    /// Creates a tag using the previously captured anchor time instead of the current elapsed time.
    /// The caller must have called `captureAnchor` first. Returns `false` if no anchor is captured
    /// or if persistence fails.
    @discardableResult
    func placeTagWithCapturedAnchor(label: String, categoryName: String, session: Session, context: ModelContext) -> Bool {
        guard let anchor = capturedAnchor else {
            logger.error("placeTagWithCapturedAnchor called without captured anchor")
            return false
        }

        let newTag = Tag(
            label: label,
            categoryName: categoryName,
            anchorTime: anchor.anchorTime,
            rewindDuration: anchor.actualRewind,
            createdAt: Date()
        )
        context.insert(newTag)
        session.tags.append(newTag)

        do {
            try context.save()
            capturedAnchor = nil
            logger.info("Custom tag placed: \(label, privacy: .public) in \(categoryName, privacy: .public) at \(anchor.anchorTime, privacy: .public) (rewound \(anchor.actualRewind, privacy: .public)s)")
            let tagForIndex = newTag
            Task {
                do {
                    try await SearchIndexer().indexTag(tagForIndex)
                } catch {
                    logger.error("Failed to index custom tag in Spotlight: \(error, privacy: .public)")
                }
            }
            return true
        } catch {
            logger.error("Failed to place custom tag: \(error, privacy: .public)")
            session.tags.removeAll { $0.uuid == newTag.uuid }
            context.delete(newTag)
            return false
        }
    }

    /// Discards the captured anchor without creating a tag. Call when the custom tag sheet
    /// is dismissed without saving.
    func discardCapturedAnchor() {
        capturedAnchor = nil
        logger.info("Captured anchor discarded (custom tag cancelled)")
    }
}
