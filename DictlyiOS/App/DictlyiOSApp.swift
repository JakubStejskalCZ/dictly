import SwiftUI
import SwiftData
import OSLog
import DictlyModels
import DictlyStorage

@main
struct DictlyiOSApp: App {
    private let container: ModelContainer = {
        let schema = Schema(DictlySchema.all)
        let config = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    @State private var syncService = CategorySyncService()
    @State private var sessionRecorder = SessionRecorder()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(syncService)
                .environment(sessionRecorder)
                .task {
                    do {
                        try DefaultTagSeeder.deduplicateCategories(context: container.mainContext)
                        try DefaultTagSeeder.seedIfNeeded(context: container.mainContext)
                    } catch {
                        logger.error("Failed to seed default tags: \(error)")
                    }
                    removeOrphanedSessions(context: container.mainContext)
                    syncService.startObserving(context: container.mainContext)
                    SessionRecorder.recoverOrphanedRecordings(context: container.mainContext)
                }
        }
        .modelContainer(container)
    }
}

/// Removes sessions left behind by the old deletion logic that only cleared audio metadata.
private func removeOrphanedSessions(context: ModelContext) {
    let descriptor = FetchDescriptor<Session>(
        predicate: #Predicate { $0.audioFilePath == nil && $0.duration == 0 }
    )
    guard let orphans = try? context.fetch(descriptor), !orphans.isEmpty else { return }
    for session in orphans {
        context.delete(session)
    }
    try? context.save()
    logger.info("Removed \(orphans.count) orphaned session(s)")
}

private let logger = Logger(subsystem: "com.dictly.ios", category: "tagging")
