import SwiftUI
import SwiftData
import DictlyModels
import DictlyStorage
import DictlyTheme

struct SettingsScreen: View {
    @AppStorage("rewindDuration") private var rewindDuration: Double = 10.0

    @Query private var allSessions: [Session]

    private var sessionsWithAudio: [Session] {
        allSessions.filter { $0.audioFilePath != nil }
    }

    private var totalStorageText: String {
        let bytes = AudioFileManager.totalAudioStorageSize(sessions: sessionsWithAudio)
        return AudioFileManager.formattedSize(bytes)
    }

    var body: some View {
        Form {
            Section {
                Picker("Rewind Duration", selection: $rewindDuration) {
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("15 seconds").tag(15.0)
                    Text("20 seconds").tag(20.0)
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Rewind duration")
            } header: {
                Text("Tagging")
            } footer: {
                Text("How far back each tag captures before the moment you tap.")
            }
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
