import SwiftUI
import SwiftData
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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(syncService)
                .task {
                    syncService.startObserving(context: container.mainContext)
                    syncService.pushCategoriesToCloud()
                }
        }
        .modelContainer(container)
    }
}
