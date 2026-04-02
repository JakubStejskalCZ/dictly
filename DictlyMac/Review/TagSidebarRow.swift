import SwiftUI
import DictlyModels
import DictlyTheme

/// A single row in the tag sidebar showing category color, label, and timestamp.
///
/// VoiceOver label: "[Category]: [Label] at [timestamp]"
struct TagSidebarRow: View {
    let tag: Tag

    var body: some View {
        HStack(spacing: DictlySpacing.sm) {
            Circle()
                .fill(categoryColor(for: tag.categoryName))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(tag.label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DictlyColors.textPrimary)
                    .lineLimit(1)

                Text(formatTimestamp(tag.anchorTime))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(DictlyColors.textSecondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, DictlySpacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tag.categoryName): \(tag.label) at \(formatTimestamp(tag.anchorTime))")
    }

    // MARK: - Helpers

    private func categoryColor(for name: String) -> Color {
        switch name.lowercased() {
        case "story":    return DictlyColors.TagCategory.story
        case "combat":   return DictlyColors.TagCategory.combat
        case "roleplay": return DictlyColors.TagCategory.roleplay
        case "world":    return DictlyColors.TagCategory.world
        case "meta":     return DictlyColors.TagCategory.meta
        default:         return DictlyColors.textSecondary
        }
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
