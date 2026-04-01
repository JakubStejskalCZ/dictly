import SwiftUI
import SwiftData
import DictlyModels

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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
