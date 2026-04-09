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
    @AppStorage("hasChosenTagPacks") private var hasChosenTagPacks = false
    @AppStorage("didMigrateToTagPacks") private var didMigrateToTagPacks = false
    @State private var showPackPicker = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(syncService)
                .environment(sessionRecorder)
                .sheet(isPresented: $showPackPicker) {
                    TagPackPickerView(isOnboarding: true) {
                        hasChosenTagPacks = true
                    }
                    .environment(syncService)
                    .interactiveDismissDisabled()
                }
                .task {
                    do {
                        try DefaultTagSeeder.deduplicateCategories(context: container.mainContext)
                    } catch {
                        logger.error("Failed to deduplicate categories: \(error)")
                    }
                    if !didMigrateToTagPacks {
                        do {
                            try DefaultTagSeeder.removeAllDefaultData(context: container.mainContext)
                            hasChosenTagPacks = false
                            didMigrateToTagPacks = true
                        } catch {
                            logger.error("Failed to migrate tag data: \(error)")
                        }
                    }
                    removeOrphanedSessions(context: container.mainContext)
                    syncService.startObserving(context: container.mainContext)
                    SessionRecorder.recoverOrphanedRecordings(context: container.mainContext)
                    if !hasChosenTagPacks {
                        showPackPicker = true
                    }
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
