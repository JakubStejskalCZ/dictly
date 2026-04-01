import SwiftUI
import SwiftData
import DictlyModels
import DictlyStorage
import DictlyTheme

struct SettingsScreen: View {
    @Query private var allSessions: [Session]

    private var totalStorageText: String {
        let bytes = AudioFileManager.totalAudioStorageSize(sessions: allSessions)
        return AudioFileManager.formattedSize(bytes)
    }

    var body: some View {
        Form {
            Section("Storage") {
                NavigationLink(destination: StorageManagementView()) {
                    HStack {
                        Label("Manage Recordings", systemImage: "internaldrive")
                        Spacer()
                        Text(totalStorageText)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
