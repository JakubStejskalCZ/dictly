import SwiftUI
import SwiftData
import DictlyModels
import DictlyStorage
import DictlyTheme

struct StorageManagementView: View {
    @Query(sort: \Session.date, order: .reverse) private var allSessions: [Session]
    @Environment(\.modelContext) private var modelContext

    @State private var sessionToDelete: Session?
    @State private var isShowingDeleteConfirmation = false

    private var sessionsWithAudio: [Session] {
        allSessions.filter { $0.audioFilePath != nil }
    }

    private var totalStorageBytes: Int64 {
        AudioFileManager.totalAudioStorageSize(sessions: sessionsWithAudio)
    }

    var body: some View {
        Form {
            if sessionsWithAudio.isEmpty {
                emptyStateSection
            } else {
                totalStorageSection
                recordingsSection
            }
        }
        .navigationTitle("Storage Management")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete Recording?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Recording", role: .destructive) {
                if let session = sessionToDelete {
                    deleteRecording(for: session)
                }
            }
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
        } message: {
            if let session = sessionToDelete {
                Text("The audio recording for \"\(session.title)\" will be permanently deleted. Session notes and tags will be preserved.")
            }
        }
    }

    // MARK: - Sections

    private var emptyStateSection: some View {
        Section {
            VStack(spacing: DictlySpacing.md) {
                Image(systemName: "waveform.slash")
                    .font(.system(size: 44))
                    .foregroundStyle(DictlyColors.textSecondary)
                Text("No recordings are stored")
                    .font(DictlyTypography.h3)
                    .foregroundStyle(DictlyColors.textPrimary)
                Text("Recordings will appear here once you record a session. You can delete old recordings to free up space on your device.")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DictlySpacing.lg)
        }
    }

    private var totalStorageSection: some View {
        Section("Total Storage Used") {
            HStack {
                Label("Audio Recordings", systemImage: "waveform")
                Spacer()
                Text(AudioFileManager.formattedSize(totalStorageBytes))
                    .foregroundStyle(DictlyColors.textSecondary)
                    .font(DictlyTypography.body)
            }
        }
    }

    private var recordingsSection: some View {
        Section("Recordings") {
            ForEach(sessionsWithAudio) { session in
                SessionStorageRow(session: session)
            }
            .onDelete { offsets in
                guard let index = offsets.first else { return }
                sessionToDelete = sessionsWithAudio[index]
                isShowingDeleteConfirmation = true
            }
        }
    }

    // MARK: - Actions

    private func deleteRecording(for session: Session) {
        if let filename = session.audioFilePath {
            let resolvedPath: String
            if filename.hasPrefix("/") {
                resolvedPath = filename
            } else {
                let dir = (try? AudioFileManager.audioStorageDirectory())?.path ?? ""
                resolvedPath = dir.isEmpty ? filename : (dir + "/" + filename)
            }
            do {
                try AudioFileManager.deleteAudioFile(at: resolvedPath)
            } catch {
                // File may already be missing — proceed to delete session
            }
        }
        modelContext.delete(session)
        try? modelContext.save()
        sessionToDelete = nil
    }
}

// MARK: - Session Storage Row

private struct SessionStorageRow: View {
    let session: Session

    private var fileSizeText: String {
        guard let filename = session.audioFilePath else { return "—" }
        let resolvedPath: String
        if filename.hasPrefix("/") {
            resolvedPath = filename
        } else {
            let dir = (try? AudioFileManager.audioStorageDirectory())?.path ?? ""
            resolvedPath = dir.isEmpty ? filename : (dir + "/" + filename)
        }
        guard let size = try? AudioFileManager.fileSize(at: resolvedPath) else { return "File missing" }
        return AudioFileManager.formattedSize(size)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DictlySpacing.xs) {
            Text(session.title)
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textPrimary)
            HStack(spacing: DictlySpacing.sm) {
                if let campaign = session.campaign {
                    Text(campaign.name)
                        .font(DictlyTypography.caption)
                        .foregroundStyle(DictlyColors.textSecondary)
                    Text("·")
                        .font(DictlyTypography.caption)
                        .foregroundStyle(DictlyColors.textSecondary)
                }
                Text(session.date, style: .date)
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                Spacer()
                Text(fileSizeText)
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
            }
        }
        .padding(.vertical, DictlySpacing.xs)
    }
}
