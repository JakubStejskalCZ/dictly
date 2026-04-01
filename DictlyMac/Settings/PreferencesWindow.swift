import SwiftUI
import SwiftData
import DictlyModels
import DictlyStorage
import DictlyTheme

struct PreferencesWindow: View {
    var body: some View {
        TabView {
            StoragePreferencesTab()
                .tabItem {
                    Label("Storage", systemImage: "internaldrive")
                }
        }
        .frame(minWidth: 520, minHeight: 400)
    }
}

// MARK: - Storage Preferences Tab

private struct StoragePreferencesTab: View {
    @Query(sort: \Session.date, order: .reverse) private var allSessions: [Session]
    @Environment(\.modelContext) private var modelContext

    @State private var sessionToDelete: Session?
    @State private var isShowingDeleteAlert = false

    private var sessionsWithAudio: [Session] {
        allSessions.filter { $0.audioFilePath != nil }
    }

    private var totalStorageBytes: Int64 {
        AudioFileManager.totalAudioStorageSize(sessions: allSessions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: total storage used
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Audio Recordings")
                        .font(.headline)
                    Text(AudioFileManager.formattedSize(totalStorageBytes) + " used")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if sessionsWithAudio.isEmpty {
                emptyState
            } else {
                recordingsTable
            }
        }
        .alert(
            "Delete Recording?",
            isPresented: $isShowingDeleteAlert,
            presenting: sessionToDelete
        ) { session in
            Button("Delete", role: .destructive) {
                deleteRecording(for: session)
            }
            Button("Cancel", role: .cancel) {}
        } message: { session in
            Text("The audio recording for \"\(session.title)\" will be permanently deleted. Session notes and tags will be preserved.")
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Recordings Stored")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Recordings will appear here once you record a session.\nYou can delete old recordings to free up space.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var recordingsTable: some View {
        Table(sessionsWithAudio) {
            TableColumn("Session") { session in
                Text(session.title)
            }
            TableColumn("Campaign") { session in
                Text(session.campaign?.name ?? "—")
                    .foregroundStyle(.secondary)
            }
            TableColumn("Date") { session in
                Text(session.date, style: .date)
                    .foregroundStyle(.secondary)
            }
            TableColumn("Size") { session in
                Text(fileSizeText(for: session))
                    .foregroundStyle(.secondary)
            }
            TableColumn("") { session in
                Button("Delete") {
                    sessionToDelete = session
                    isShowingDeleteAlert = true
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
            }
            .width(60)
        }
    }

    // MARK: - Helpers

    private func fileSizeText(for session: Session) -> String {
        guard let path = session.audioFilePath else { return "—" }
        guard let size = try? AudioFileManager.fileSize(at: path) else { return "File missing" }
        return AudioFileManager.formattedSize(size)
    }

    private func deleteRecording(for session: Session) {
        if let path = session.audioFilePath {
            do {
                try AudioFileManager.deleteAudioFile(at: path)
            } catch {
                // File may already be missing — proceed to clear metadata
            }
        }
        session.audioFilePath = nil
        session.duration = 0
    }
}
