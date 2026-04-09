import SwiftUI
import SwiftData
import DictlyModels
import DictlyStorage
import DictlyTheme

struct SettingsScreen: View {
    @AppStorage("rewindDuration") private var rewindDuration: Double = 10.0
    @AppStorage("audioQuality") private var audioQuality: String = "standard"

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
            Section {
                Picker("Audio Quality", selection: $audioQuality) {
                    Text("Standard (64 kbps)").tag("standard")
                    Text("High (128 kbps)").tag("high")
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Audio quality")
            } header: {
                Text("Recording")
            } footer: {
                Text("Applies to future recordings. Higher quality uses more storage.")
            }
            Section("Tags") {
                NavigationLink(destination: TagPackPickerView(isOnboarding: false)) {
                    Label("Tag Packs", systemImage: "tag")
                }
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
