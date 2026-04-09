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
                    syncService.startObserving(context: container.mainContext)
                    SessionRecorder.recoverOrphanedRecordings(context: container.mainContext)
                }
        }
        .modelContainer(container)
    }
}

private let logger = Logger(subsystem: "com.dictly.ios", category: "tagging")
