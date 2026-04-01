import SwiftUI
import DictlyModels

struct ContentView: View {
    var body: some View {
        NavigationStack {
            CampaignListScreen()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Campaign.self, inMemory: true)
}
