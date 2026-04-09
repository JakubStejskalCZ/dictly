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
    @AppStorage("hasChosenTagPacks") private var hasChosenTagPacks = false
    @AppStorage("didMigrateToTagPacks") private var didMigrateToTagPacks = false
    @State private var showPackPicker = false

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
                .sheet(isPresented: $showPackPicker) {
                    TagPackPickerView(isOnboarding: true) {
                        hasChosenTagPacks = true
                    }
                    .environment(syncService)
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
                    networkReceiver.startListening()
                    if !hasChosenTagPacks {
                        showPackPicker = true
                    }
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
                .environment(syncService)
                .environment(transcriptionEngine.modelManager)
                .environment(transcriptionEngine.whisperBridge)
        }
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

private let logger = Logger(subsystem: "com.dictly.mac", category: "tagging")
