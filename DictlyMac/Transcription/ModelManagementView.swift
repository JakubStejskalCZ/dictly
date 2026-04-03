import SwiftUI
import DictlyStorage

struct ModelManagementView: View {
    @Environment(ModelManager.self) private var modelManager
    @Environment(WhisperBridge.self) private var whisperBridge

    @State private var modelToDelete: WhisperModel?
    @State private var isShowingDeleteAlert = false
    @State private var downloadError: Error?
    @State private var isShowingErrorAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            modelList
        }
        .alert("Delete Model?", isPresented: $isShowingDeleteAlert, presenting: modelToDelete) { model in
            Button("Delete", role: .destructive) {
                handleDelete(model)
            }
            Button("Cancel", role: .cancel) {
                modelToDelete = nil
            }
        } message: { model in
            Text("The \"\(model.name)\" model will be removed from disk. You can re-download it later.")
        }
        .alert("Download Failed", isPresented: $isShowingErrorAlert) {
            Button("OK", role: .cancel) { downloadError = nil }
        } message: {
            Text(downloadError?.localizedDescription ?? "An unknown error occurred.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Transcription Models")
                    .font(.headline)
                Text("Select the Whisper model used for transcription. Larger models are more accurate but require more disk space.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Model List

    private var modelList: some View {
        List(ModelManager.registry) { model in
            ModelRowView(
                model: model,
                isActive: modelManager.activeModel == model.id,
                isDownloaded: modelManager.isDownloaded(model),
                isDownloading: modelManager.isDownloading && modelManager.downloadingModelId == model.id,
                downloadProgress: modelManager.downloadProgress,
                onSelect: { modelManager.selectModel(model) },
                onDownload: { handleDownload(model) },
                onCancel: { modelManager.cancelDownload() },
                onDelete: {
                    modelToDelete = model
                    isShowingDeleteAlert = true
                }
            )
            .listRowSeparator(.visible)
        }
        .listStyle(.inset)
    }

    // MARK: - Actions

    private func handleDownload(_ model: WhisperModel) {
        Task {
            do {
                try await modelManager.downloadModel(model)
            } catch {
                downloadError = error
                isShowingErrorAlert = true
            }
        }
    }

    private func handleDelete(_ model: WhisperModel) {
        if modelManager.activeModel == model.id {
            whisperBridge.unloadModel()
        }
        do {
            try modelManager.deleteModel(model)
        } catch {
            downloadError = error
            isShowingErrorAlert = true
        }
        modelToDelete = nil
    }
}

// MARK: - ModelRowView

private struct ModelRowView: View {
    let model: WhisperModel
    let isActive: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            selectionIndicator
            modelInfo
            Spacer()
            actionButton
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if (isDownloaded || model.isBundled) && !isDownloading {
                onSelect()
            }
        }
    }

    // MARK: - Selection Indicator

    private var selectionIndicator: some View {
        Group {
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.title3)
            } else if isDownloaded || model.isBundled {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.quaternary)
                    .font(.title3)
            }
        }
        .frame(width: 24)
    }

    // MARK: - Model Info

    private var modelInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(model.name)
                    .fontWeight(.medium)
                if model.isBundled {
                    Text("Bundled")
                        .font(.caption)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                Text(model.quality)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(AudioFileManager.formattedSize(model.size))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if isDownloading {
                ProgressView(value: downloadProgress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 200)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        if isActive {
            Text("Active")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
        } else if isDownloading {
            Button("Cancel", action: onCancel)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(width: 80, alignment: .trailing)
        } else if isDownloaded {
            HStack(spacing: 8) {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Delete \(model.name)")
            }
            .frame(width: 80, alignment: .trailing)
        } else {
            Button(action: onDownload) {
                Label("Download", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(width: 100, alignment: .trailing)
        }
    }
}
