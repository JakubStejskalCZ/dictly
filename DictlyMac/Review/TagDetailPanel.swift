import SwiftUI
import SwiftData
import DictlyModels
import DictlyTheme
import os

/// Contextual detail area displayed below the waveform timeline.
///
/// When `selectedTag` is nil, shows a placeholder prompt. When a tag is selected,
/// displays tag info in a two-column layout (collapses to single column at < 600pt).
/// Supports inline label editing, category recategorization via popover, and deletion.
struct TagDetailPanel: View {
    @Binding var selectedTag: Tag?
    let session: Session
    @Environment(\.modelContext) private var modelContext
    @Environment(TranscriptionEngine.self) private var transcriptionEngine

    @State private var editingLabel: String = ""
    @FocusState private var isEditingLabel: Bool
    @State private var editingNotes: String = ""
    @FocusState private var isEditingNotes: Bool
    @State private var editingTranscription: String = ""
    @FocusState private var isTranscriptionFocused: Bool
    @State private var showCategoryPicker: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var tagToDeleteFromPanel: Tag?

    private let logger = Logger(subsystem: "com.dictly.mac", category: "tagging")

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let tag = selectedTag {
                    tagDetailContent(tag: tag, isNarrow: geometry.size.width < 600)
                        .animation(.easeInOut(duration: 0.2), value: tag.uuid)
                } else {
                    noSelectionPlaceholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DictlyColors.background)
        .animation(.easeInOut(duration: 0.2), value: selectedTag?.uuid)
        .onAppear {
            if let tag = selectedTag {
                editingLabel = tag.label
                editingNotes = tag.notes ?? ""
                editingTranscription = tag.transcription ?? ""
            }
        }
        .onChange(of: selectedTag?.uuid) { oldUUID, _ in
            // Commit in-progress notes to old tag before switching selection.
            // The stale-capture guard in commitNotes cannot protect this path because
            // selectedTag has already changed by the time onChange fires.
            if isEditingNotes, let oldUUID = oldUUID {
                let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.uuid == oldUUID })
                if let oldTag = try? modelContext.fetch(descriptor).first {
                    let trimmed = editingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                    let newNotes: String? = trimmed.isEmpty ? nil : editingNotes
                    if newNotes != oldTag.notes {
                        oldTag.notes = newNotes
                    }
                }
            }
            // Commit in-progress transcription edit to old tag before switching.
            if isTranscriptionFocused, let oldUUID = oldUUID {
                let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.uuid == oldUUID })
                if let oldTag = try? modelContext.fetch(descriptor).first {
                    if editingTranscription != (oldTag.transcription ?? "") {
                        oldTag.transcription = editingTranscription
                    }
                }
            }
            isEditingLabel = false
            isEditingNotes = false
            isTranscriptionFocused = false
            showCategoryPicker = false
            if let tag = selectedTag {
                editingLabel = tag.label
                editingNotes = tag.notes ?? ""
                editingTranscription = tag.transcription ?? ""
            } else {
                editingLabel = ""
                editingNotes = ""
                editingTranscription = ""
            }
        }
        .alert("Delete Tag?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let tag = tagToDeleteFromPanel {
                    deleteTag(tag)
                }
            }
            Button("Cancel", role: .cancel) {
                tagToDeleteFromPanel = nil
            }
        } message: {
            Text("This will permanently remove this tag.")
        }
    }

    // MARK: - No Selection Placeholder

    private var noSelectionPlaceholder: some View {
        VStack {
            Spacer()
            Text("Select a tag to view details")
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("No tag selected. Select a tag from the sidebar to view details.")
    }

    // MARK: - Tag Detail Content

    @ViewBuilder
    private func tagDetailContent(tag: Tag, isNarrow: Bool) -> some View {
        ScrollView {
            if isNarrow {
                VStack(alignment: .leading, spacing: DictlySpacing.lg) {
                    leftColumn(tag: tag)
                }
                .padding(DictlySpacing.md)
            } else {
                HStack(alignment: .top, spacing: DictlySpacing.lg) {
                    leftColumn(tag: tag)
                        .frame(maxWidth: .infinity)
                    rightColumn
                        .frame(maxWidth: .infinity)
                }
                .padding(DictlySpacing.md)
            }
        }
    }

    // MARK: - Left Column

    @ViewBuilder
    private func leftColumn(tag: Tag) -> some View {
        VStack(alignment: .leading, spacing: DictlySpacing.md) {
            // Tag label — inline editable TextField
            VStack(alignment: .leading, spacing: DictlySpacing.xs) {
                Text("Label")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                TextField("Tag label", text: $editingLabel)
                    .font(DictlyTypography.h3)
                    .foregroundStyle(DictlyColors.textPrimary)
                    .textFieldStyle(.plain)
                    .focused($isEditingLabel)
                    .onSubmit { commitLabel(tag: tag) }
                    .onChange(of: isEditingLabel) { _, focused in
                        if focused {
                            AccessibilityNotification.Announcement("Editing tag label").post()
                        } else {
                            commitLabel(tag: tag)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if isEditingLabel {
                            Rectangle()
                                .fill(DictlyColors.border)
                                .frame(height: 1)
                        }
                    }
                    .accessibilityLabel("Tag label, editable. Current value: \(tag.label)")
                    .accessibilityHint("Click to edit")
            }

            // Category badge — tappable, opens category picker popover
            Button {
                showCategoryPicker = true
            } label: {
                categoryBadge(for: tag.categoryName)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showCategoryPicker) {
                CategoryPickerPopover(currentCategory: tag.categoryName) { newCategory in
                    tag.categoryName = newCategory
                }
            }
            .accessibilityLabel("Category: \(tag.categoryName). Click to change.")
            .accessibilityHint("Opens category picker")

            // Timestamp
            VStack(alignment: .leading, spacing: DictlySpacing.xs) {
                Text("Timestamp")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                Text(formatTimestamp(tag.anchorTime))
                    .font(DictlyTypography.monospacedDigits)
                    .foregroundStyle(DictlyColors.textPrimary)
            }

            // Transcription block (Story 5.3)
            transcriptionBlock(tag: tag)

            // Notes — editable TextEditor (story 4.7)
            VStack(alignment: .leading, spacing: DictlySpacing.xs) {
                Text("Notes")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $editingNotes)
                        .font(DictlyTypography.body)
                        .scrollContentBackground(.hidden)
                        .background(DictlyColors.surface)
                        .frame(minHeight: 60, maxHeight: 150)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(isEditingNotes ? DictlyColors.border : Color.clear, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .focused($isEditingNotes)
                        .onChange(of: isEditingNotes) { _, focused in
                            if focused {
                                AccessibilityNotification.Announcement("Editing tag notes").post()
                            } else {
                                commitNotes(tag: tag)
                            }
                        }
                        .accessibilityLabel(editingNotes.isEmpty
                            ? "Tag notes, empty"
                            : "Tag notes, editable. Current notes: \(String(editingNotes.prefix(50)))")
                        .accessibilityHint("Type to add notes for this tag")

                    if editingNotes.isEmpty {
                        Text("Add notes…")
                            .font(DictlyTypography.body)
                            .foregroundStyle(DictlyColors.textSecondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .background(DictlyColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Delete Tag — destructive action with confirmation
            Button {
                tagToDeleteFromPanel = selectedTag
                showDeleteConfirmation = true
            } label: {
                Text("Delete Tag")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.destructive)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete tag")
        }
    }

    // MARK: - Transcription Block (Story 5.3)

    @ViewBuilder
    private func transcriptionBlock(tag: Tag) -> some View {
        VStack(alignment: .leading, spacing: DictlySpacing.xs) {
            Text("Transcription")
                .font(DictlyTypography.caption)
                .foregroundStyle(DictlyColors.textSecondary)

            let isTranscribingThisTag = transcriptionEngine.currentTagId == tag.uuid
            let hasError = transcriptionError(for: tag) != nil

            if isTranscribingThisTag {
                // State: transcription in progress for this tag
                HStack(spacing: DictlySpacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Transcribing…")
                        .font(DictlyTypography.body)
                        .foregroundStyle(DictlyColors.textSecondary)
                }
                .padding(DictlySpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DictlyColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityLabel("Transcription in progress")

            } else if tag.transcription != nil {
                // State: transcription complete — editable inline (Story 5.4)
                TextEditor(text: $editingTranscription)
                    .font(DictlyTypography.body)
                    .scrollContentBackground(.hidden)
                    .background(DictlyColors.surface)
                    .frame(minHeight: 60, maxHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isTranscriptionFocused ? DictlyColors.border : Color.clear, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .focused($isTranscriptionFocused)
                    .onChange(of: isTranscriptionFocused) { _, focused in
                        if focused {
                            AccessibilityNotification.Announcement("Editing transcription").post()
                        } else {
                            commitTranscription(tag: tag)
                        }
                    }
                    .accessibilityLabel(editingTranscription.isEmpty
                        ? "Transcription, empty. Click to edit."
                        : "Transcription: \(String(editingTranscription.prefix(100))). Click to edit.")
                    .accessibilityHint("Click to edit transcription text")

            } else if hasError {
                // State: transcription failed — show error badge with Retry
                let isBusy = transcriptionEngine.isTranscribing || transcriptionEngine.isBatchTranscribing
                HStack(spacing: DictlySpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Transcription failed")
                        .font(DictlyTypography.body)
                        .foregroundStyle(DictlyColors.textSecondary)
                    Spacer()
                    Button("Retry") {
                        Task {
                            try? await transcriptionEngine.retryTag(tag, session: session)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isBusy)
                    .accessibilityLabel("Retry transcription for this tag")
                    .help(isBusy ? "Transcription already in progress" : "Retry transcription for this tag")
                }
                .padding(DictlySpacing.sm)
                .background(DictlyColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            } else {
                // State: no transcription yet — show Transcribe button
                let isBusy = transcriptionEngine.isTranscribing || transcriptionEngine.isBatchTranscribing
                Button {
                    Task {
                        try? await transcriptionEngine.transcribeTag(tag, session: session)
                    }
                } label: {
                    Label("Transcribe", systemImage: "waveform")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isBusy)
                .accessibilityLabel("Transcribe this tag's audio")
                .help(isBusy ? "Transcription already in progress" : "Transcribe audio around this tag")
            }
        }
    }

    private func transcriptionError(for tag: Tag) -> Error? {
        transcriptionEngine.batchErrors.first { $0.tag.uuid == tag.uuid }?.error
            ?? transcriptionEngine.tagErrors[tag.uuid]
    }

    // MARK: - Right Column

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: DictlySpacing.xs) {
            Text("Related Tags")
                .font(DictlyTypography.caption)
                .foregroundStyle(DictlyColors.textSecondary)
            Text("Related tags across sessions")
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textSecondary)
            RoundedRectangle(cornerRadius: 6)
                .fill(DictlyColors.surface)
                .frame(height: 120)
                .overlay(
                    Text("Related tag filtering available in a future story.")
                        .font(DictlyTypography.caption)
                        .foregroundStyle(DictlyColors.textSecondary)
                        .padding(DictlySpacing.sm),
                    alignment: .topLeading
                )
        }
    }

    // MARK: - Category Badge

    private func categoryBadge(for categoryName: String) -> some View {
        let color = categoryColor(for: categoryName)
        let isKnownCategory = ["story", "combat", "roleplay", "world", "meta"]
            .contains(categoryName.lowercased())
        return Text(categoryName.isEmpty ? "Uncategorized" : categoryName)
            .font(DictlyTypography.caption)
            .foregroundStyle(isKnownCategory ? .white : DictlyColors.textPrimary)
            .padding(.horizontal, DictlySpacing.sm)
            .padding(.vertical, DictlySpacing.xs)
            .background(isKnownCategory ? color : DictlyColors.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isKnownCategory ? Color.clear : DictlyColors.border, lineWidth: 1)
            )
    }

    // MARK: - Actions

    private func commitLabel(tag: Tag) {
        // Guard against stale captures: if selection changed, the tag parameter
        // may not match the current selectedTag — skip the write to avoid mutating the wrong object.
        guard selectedTag?.uuid == tag.uuid else { return }
        let trimmed = editingLabel.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            // Revert to previous value — do not allow empty labels
            editingLabel = tag.label
        } else {
            tag.label = trimmed
            AccessibilityNotification.Announcement("Tag label saved").post()
        }
    }

    private func commitNotes(tag: Tag) {
        guard selectedTag?.uuid == tag.uuid else { return }
        let trimmed = editingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let newNotes: String? = trimmed.isEmpty ? nil : editingNotes
        guard newNotes != tag.notes else { return }
        tag.notes = newNotes
        AccessibilityNotification.Announcement("Notes saved").post()
    }

    private func commitTranscription(tag: Tag) {
        guard selectedTag?.uuid == tag.uuid else { return }
        // Empty string is valid — means user cleared the transcription.
        // nil means never transcribed; do not revert to nil on user clear.
        guard editingTranscription != (tag.transcription ?? "") else { return }
        tag.transcription = editingTranscription
        AccessibilityNotification.Announcement("Transcription saved").post()
    }

    private func deleteTag(_ tag: Tag) {
        logger.info("Tag deleted: \(tag.label, privacy: .public) at \(tag.anchorTime, privacy: .public)")
        showCategoryPicker = false
        tag.session?.tags.removeAll { $0.uuid == tag.uuid }
        modelContext.delete(tag)
        selectedTag = nil
        tagToDeleteFromPanel = nil
        AccessibilityNotification.Announcement("Tag deleted").post()
    }
}

// MARK: - CategoryPickerPopover

private struct CategoryPickerPopover: View {
    let currentCategory: String
    let onSelect: (String) -> Void
    @Query(sort: \TagCategory.sortOrder) private var categories: [TagCategory]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(categories) { category in
                Button {
                    onSelect(category.name)
                    dismiss()
                } label: {
                    HStack(spacing: DictlySpacing.sm) {
                        Circle()
                            .fill(categoryColor(for: category.name))
                            .frame(width: 8, height: 8)
                        Text(category.name)
                            .font(DictlyTypography.body)
                            .foregroundStyle(DictlyColors.textPrimary)
                            .fontWeight(category.name == currentCategory ? .semibold : .regular)
                        Spacer()
                        if category.name == currentCategory {
                            Image(systemName: "checkmark")
                                .foregroundStyle(DictlyColors.textSecondary)
                        }
                    }
                    .padding(.horizontal, DictlySpacing.md)
                    .padding(.vertical, DictlySpacing.sm)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(category.name). Double-tap to select.")
            }
        }
        .frame(minWidth: 180)
    }
}
