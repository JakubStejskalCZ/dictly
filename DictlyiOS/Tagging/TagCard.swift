import SwiftUI
import DictlyModels
import DictlyTheme

/// Tappable tag button displayed in the recording tag grid.
/// Shows a color stripe (left edge), tag label, and category name.
/// Fires `onTap` on press with a scale pulse and haptic feedback (owned by TaggingService).
struct TagCard: View {
    let tag: Tag
    let categoryColor: Color
    let categoryName: String
    let onTap: () -> Void

    @ScaledMetric private var stripeWidth: CGFloat = DictlySpacing.xs
    @ScaledMetric private var innerPadding: CGFloat = DictlySpacing.sm
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left color stripe
                Rectangle()
                    .fill(categoryColor)
                    .frame(width: stripeWidth)

                // Tag content
                VStack(alignment: .leading, spacing: 2) {
                    Text(tag.label)
                        .font(DictlyTypography.tagLabel)
                        .foregroundStyle(DictlyColors.textPrimary)
                        .lineLimit(2)
                    Text(categoryName)
                        .font(DictlyTypography.caption)
                        .foregroundStyle(DictlyColors.textSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, innerPadding)
                .padding(.vertical, innerPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: DictlySpacing.minTapTarget)
            .frame(maxWidth: .infinity)
            .background(DictlyColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(TagCardButtonStyle(categoryColor: categoryColor, reduceMotion: reduceMotion))
        .accessibilityLabel("\(tag.label), \(categoryName). Double-tap to place tag.")
    }
}

// MARK: - Button Style

private struct TagCardButtonStyle: ButtonStyle {
    let categoryColor: Color
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? DictlyAnimation.tagPlacementStartScale : 1.0)
            .shadow(
                color: configuration.isPressed ? categoryColor.opacity(0.4) : .clear,
                radius: configuration.isPressed ? 8 : 0
            )
            .animation(DictlyAnimation.tagPlacement(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}
