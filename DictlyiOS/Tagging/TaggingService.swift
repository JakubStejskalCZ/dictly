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

    /// Creates a new `Tag` anchored to the current recording time, appends it to
    /// `session.tags`, fires haptic feedback, and persists to SwiftData.
    /// Must complete within 200ms — no blocking work on the main thread.
    func placeTag(label: String, categoryName: String, session: Session, context: ModelContext) {
        // Fire haptic immediately — primary confirmation channel
        hapticGenerator.impactOccurred()

        let anchorTime = sessionRecorder.elapsedTime
        let newTag = Tag(
            label: label,
            categoryName: categoryName,
            anchorTime: anchorTime,
            rewindDuration: 0,
            createdAt: Date()
        )

        context.insert(newTag)
        session.tags.append(newTag)

        do {
            try context.save()
        } catch {
            logger.error("Failed to place tag: \(error, privacy: .public)")
        }

        logger.info("Tag placed: \(label, privacy: .public) in \(categoryName, privacy: .public) at \(anchorTime, privacy: .public)")
    }

    /// Re-warms the Taptic Engine. Call when the recording palette becomes visible.
    func prepareHaptic() {
        hapticGenerator.prepare()
    }
}
