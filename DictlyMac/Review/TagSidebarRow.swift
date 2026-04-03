import SwiftUI
import DictlyModels
import DictlyTheme

/// A single row in the tag sidebar showing category color, label, timestamp, and category name.
///
/// When `isSelected` is true, the label renders in the category colour and the row
/// background is `DictlyColors.surface`; otherwise the row background is clear.
///
/// VoiceOver label: "[Category]: [Label] at [timestamp]"
struct TagSidebarRow: View {
    let tag: Tag
    let isSelected: Bool

    var body: some View {
        HStack(spacing: DictlySpacing.sm) {
            Circle()
                .fill(categoryColor(for: tag.categoryName))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(tag.label.isEmpty ? "Untitled Tag" : tag.label)
                    .font(DictlyTypography.tagLabel)
                    .foregroundStyle(isSelected ? categoryColor(for: tag.categoryName) : DictlyColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: DictlySpacing.xs) {
                    Text(formatTimestamp(tag.anchorTime))
                        .font(DictlyTypography.caption)
                        .foregroundStyle(DictlyColors.textSecondary)
                        .monospacedDigit()
                    Text("·")
                        .font(DictlyTypography.caption)
                        .foregroundStyle(DictlyColors.textSecondary)
                    Text(tag.categoryName)
                        .font(DictlyTypography.caption)
                        .foregroundStyle(DictlyColors.textSecondary)
                }
            }

            Spacer(minLength: 0)

            if let notes = tag.notes, !notes.isEmpty {
                Image(systemName: "note.text")
                    .font(.system(size: 10))
                    .foregroundStyle(DictlyColors.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, DictlySpacing.xs)
        .listRowBackground(isSelected ? DictlyColors.surface : Color.clear)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tag.categoryName): \(tag.label.isEmpty ? "Untitled Tag" : tag.label) at \(formatTimestamp(tag.anchorTime))\(!(tag.notes ?? "").isEmpty ? ", has notes" : "")")
    }

}

// MARK: - Timestamp Formatting

/// Formats a `TimeInterval` (seconds from session start) to `M:SS` or `H:MM:SS`.
func formatTimestamp(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%d:%02d", minutes, secs)
}
