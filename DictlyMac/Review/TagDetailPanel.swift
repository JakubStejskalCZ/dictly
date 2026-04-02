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
    @Environment(\.modelContext) private var modelContext

    @State private var editingLabel: String = ""
    @FocusState private var isEditingLabel: Bool
    @State private var editingNotes: String = ""
    @FocusState private var isEditingNotes: Bool
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
            }
        }
        .onChange(of: selectedTag?.uuid) { _, _ in
            isEditingLabel = false
            isEditingNotes = false
            showCategoryPicker = false
            if let tag = selectedTag {
                editingLabel = tag.label
                editingNotes = tag.notes ?? ""
            } else {
                editingLabel = ""
                editingNotes = ""
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

            // Transcription placeholder (story 5.x)
            VStack(alignment: .leading, spacing: DictlySpacing.xs) {
                Text("Transcription")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                RoundedRectangle(cornerRadius: 6)
                    .fill(DictlyColors.surface)
                    .frame(height: 80)
                    .overlay(
                        Text(tag.transcription ?? "Transcription will appear here after processing.")
                            .font(DictlyTypography.body)
                            .foregroundStyle(DictlyColors.textSecondary)
                            .padding(DictlySpacing.sm),
                        alignment: .topLeading
                    )
            }

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
        tag.notes = trimmed.isEmpty ? nil : editingNotes
        AccessibilityNotification.Announcement("Notes saved").post()
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
