import SwiftUI
import DictlyModels
import DictlyTheme

/// Contextual detail area displayed below the waveform timeline.
///
/// When `tag` is nil, shows a placeholder prompt. When a tag is selected,
/// displays tag info in a two-column layout (collapses to single column at < 1100pt).
struct TagDetailPanel: View {
    let tag: Tag?

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let tag {
                    tagDetailContent(tag: tag, isNarrow: geometry.size.width < 600)
                        .animation(.easeInOut(duration: 0.2), value: tag.uuid)
                } else {
                    noSelectionPlaceholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DictlyColors.background)
        .animation(.easeInOut(duration: 0.2), value: tag?.uuid)
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
            // Tag label (editable TextField — story 4.5 activates editing)
            VStack(alignment: .leading, spacing: DictlySpacing.xs) {
                Text("Label")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                Text(tag.label.isEmpty ? "Untitled Tag" : tag.label)
                    .font(DictlyTypography.h3)
                    .foregroundStyle(DictlyColors.textPrimary)
            }

            // Category badge
            categoryBadge(for: tag.categoryName)

            // Timestamp
            VStack(alignment: .leading, spacing: DictlySpacing.xs) {
                Text("Timestamp")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                Text(formatTimestamp(tag.anchorTime))
                    .font(DictlyTypography.monospacedDigits)
                    .foregroundStyle(DictlyColors.textPrimary)
            }

            // Transcription placeholder (stories 4.5/4.7)
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

            // Notes placeholder (stories 4.7)
            VStack(alignment: .leading, spacing: DictlySpacing.xs) {
                Text("Notes")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                RoundedRectangle(cornerRadius: 6)
                    .fill(DictlyColors.surface)
                    .frame(height: 60)
                    .overlay(
                        Text(tag.notes ?? "Add notes here.")
                            .font(DictlyTypography.body)
                            .foregroundStyle(DictlyColors.textSecondary)
                            .padding(DictlySpacing.sm),
                        alignment: .topLeading
                    )
            }
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

}
