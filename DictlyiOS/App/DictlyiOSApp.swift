import SwiftUI
import SwiftData
import OSLog
import DictlyModels

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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    do {
                        try DefaultTagSeeder.seedIfNeeded(context: container.mainContext)
                    } catch {
                        logger.error("Failed to seed default tags: \(error)")
                    }
                }
        }
        .modelContainer(container)
    }
}

private let logger = Logger(subsystem: "com.dictly.ios", category: "tagging")
