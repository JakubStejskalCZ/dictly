import UIKit
import OSLog
import Observation
import SwiftData
import DictlyModels

private let logger = Logger(subsystem: "com.dictly.ios", category: "tagging")

/// `@Observable @MainActor` service that handles tag placement during recording.
/// Creates new `Tag` records in SwiftData, appends them to the active session,
/// and fires haptic feedback on every placement.
@Observable @MainActor
final class TaggingService {

    // MARK: - Private

    private let sessionRecorder: SessionRecorder
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)

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
}
