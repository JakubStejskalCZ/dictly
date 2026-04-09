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
    @State private var importService = ImportService()
    @State private var transcriptionEngine = TranscriptionEngine()

    /// Tracks whether the current import originated from the network receiver,
    /// so we can call `networkReceiver.reset()` after the import settles.
    @State private var pendingNetworkImport = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(syncService)
                .environment(networkReceiver)
                .environment(importService)
                .environment(transcriptionEngine)
                .environment(transcriptionEngine.modelManager)
                .environment(transcriptionEngine.whisperBridge)
                .frame(minWidth: 900, minHeight: 500)
                .task {
                    do {
                        try DefaultTagSeeder.deduplicateCategories(context: container.mainContext)
                        try DefaultTagSeeder.seedIfNeeded(context: container.mainContext)
                    } catch {
                        logger.error("Failed to seed default tags: \(error)")
                    }
                    syncService.startObserving(context: container.mainContext)
                    networkReceiver.startListening()
                }
                // AirDrop / Finder file open
                .onOpenURL { url in
                    importService.importBundle(from: url, context: container.mainContext)
                }
                // Local network receive (story 3.3 integration)
                .onChange(of: networkReceiver.receivedBundleURL) { _, newURL in
                    guard let bundleURL = newURL else { return }
                    pendingNetworkImport = true
                    importService.importBundle(from: bundleURL, context: container.mainContext)
                }
                // Reset receiver after network import reaches a terminal state
                .onChange(of: importService.importState) { _, state in
                    guard pendingNetworkImport else { return }
                    switch state {
                    case .completed, .failed:
                        networkReceiver.reset()
                        pendingNetworkImport = false
                    case .idle:
                        // Triggered after skipDuplicate() or banner dismiss
                        networkReceiver.reset()
                        pendingNetworkImport = false
                    default:
                        break
                    }
                }
        }
        .defaultSize(width: 1200, height: 700)
        .modelContainer(container)

        Settings {
            PreferencesWindow()
                .modelContainer(container)
                .environment(transcriptionEngine.modelManager)
                .environment(transcriptionEngine.whisperBridge)
        }
    }
}

private let logger = Logger(subsystem: "com.dictly.mac", category: "tagging")
