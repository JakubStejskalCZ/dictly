import SwiftUI
import DictlyStorage
import DictlyTheme

struct ModelManagementView: View {
    @Environment(ModelManager.self) private var modelManager
    @Environment(WhisperBridge.self) private var whisperBridge

    @State private var modelToDelete: WhisperModel?
    @State private var isShowingDeleteAlert = false
    @State private var operationError: Error?
    @State private var operationErrorTitle: String = "Failed"
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
        .alert(operationErrorTitle, isPresented: $isShowingErrorAlert) {
            Button("OK", role: .cancel) { operationError = nil }
        } message: {
            Text(operationError?.localizedDescription ?? "An unknown error occurred.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: DictlySpacing.xs) {
                Text("Transcription Models")
                    .font(DictlyTypography.h3)
                Text("Select the Whisper model used for transcription. Larger models are more accurate but require more disk space.")
                    .font(DictlyTypography.body)
                    .foregroundStyle(DictlyColors.textSecondary)
            }
            Spacer()
        }
        .padding(DictlySpacing.md)
        .background(DictlyColors.surface)
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
                operationErrorTitle = "Download Failed"
                operationError = error
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
            operationErrorTitle = "Delete Failed"
            operationError = error
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
        HStack(spacing: DictlySpacing.sm) {
            selectionIndicator
            modelInfo
            Spacer()
            actionButton
        }
        .padding(.vertical, DictlySpacing.xs)
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
                    .foregroundStyle(DictlyColors.recordingActive)
                    .font(DictlyTypography.h2)
            } else if isDownloaded || model.isBundled {
                Image(systemName: "circle")
                    .foregroundStyle(DictlyColors.textSecondary)
                    .font(DictlyTypography.h2)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.quaternary)
                    .font(DictlyTypography.h2)
            }
        }
        .frame(width: DictlySpacing.lg)
    }

    // MARK: - Model Info

    private var modelInfo: some View {
        VStack(alignment: .leading, spacing: DictlySpacing.xs) {
            HStack(spacing: DictlySpacing.xs) {
                Text(model.name)
                    .fontWeight(.medium)
                if model.isBundled {
                    Text("Bundled")
                        .font(DictlyTypography.caption)
                        .padding(.horizontal, DictlySpacing.xs)
                        .padding(.vertical, DictlySpacing.xs)
                        .background(DictlyColors.textSecondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(DictlyColors.textSecondary)
                }
            }
            HStack(spacing: DictlySpacing.sm) {
                Text(model.quality)
                    .font(DictlyTypography.body)
                    .foregroundStyle(DictlyColors.textSecondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(AudioFileManager.formattedSize(model.size))
                    .font(DictlyTypography.body)
                    .foregroundStyle(DictlyColors.textSecondary)
            }
            if isDownloading {
                if downloadProgress > 0 {
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 200)
                        .padding(.top, DictlySpacing.xs)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 200)
                        .padding(.top, DictlySpacing.xs)
                }
            }
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        if isActive {
            Text("Active")
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textSecondary)
                .frame(width: 80, alignment: .trailing)
        } else if isDownloading {
            Button("Cancel", action: onCancel)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(width: 80, alignment: .trailing)
        } else if model.isBundled {
            // Bundled model (base.en) — always present, never deletable, never downloadable
            Spacer()
                .frame(width: 80)
        } else if isDownloaded {
            HStack(spacing: DictlySpacing.sm) {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(DictlyColors.destructive)
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
