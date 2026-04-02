import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Dictly")
            .font(.largeTitle)
            .overlay(alignment: .top) {
                ImportProgressView()
            }
    }
}

#Preview {
    ContentView()
}
