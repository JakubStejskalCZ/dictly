import SwiftUI
import SwiftData
import OSLog
import DictlyModels
import DictlyStorage

@main
struct DictlyMacApp: App {
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
    @State private var networkReceiver = LocalNetworkReceiver()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(syncService)
                .environment(networkReceiver)
                .task {
                    do {
                        try DefaultTagSeeder.seedIfNeeded(context: container.mainContext)
                    } catch {
                        logger.error("Failed to seed default tags: \(error)")
                    }
                    syncService.startObserving(context: container.mainContext)
                    networkReceiver.startListening()
                }
        }
        .modelContainer(container)

        Settings {
            PreferencesWindow()
                .modelContainer(container)
        }
    }
}

private let logger = Logger(subsystem: "com.dictly.mac", category: "tagging")
