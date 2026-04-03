import SwiftUI
import DictlyTheme

/// Compact list of related tags from other sessions, shown in the TagDetailPanel right column.
///
/// Populated by `SearchService.performRelatedSearch(for:)` — shows tags across all sessions
/// that mention similar terms to the selected tag's label.
struct RelatedTagsView: View {
    let relatedTags: [SearchResult]
    let isLoading: Bool
    let tagLabel: String
    var onSelected: ((SearchResult) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DictlySpacing.sm) {
            Text("Other mentions of \"\(tagLabel)\"")
                .font(DictlyTypography.caption)
                .foregroundStyle(DictlyColors.textSecondary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)

            if isLoading {
                HStack(spacing: DictlySpacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading…")
                        .font(DictlyTypography.caption)
                        .foregroundStyle(DictlyColors.textSecondary)
                }
                .padding(.vertical, DictlySpacing.sm)
                .accessibilityLabel("Loading related tags")
            } else if relatedTags.isEmpty {
                Text("No related tags found across other sessions")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                    .padding(.vertical, DictlySpacing.sm)
                    .accessibilityLabel("No related tags found across other sessions")
            } else {
                LazyVStack(alignment: .leading, spacing: DictlySpacing.xs) {
                    ForEach(relatedTags) { result in
                        RelatedTagRow(result: result, onSelected: onSelected)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Related tags across sessions")
    }
}

// MARK: - RelatedTagRow

private struct RelatedTagRow: View {
    let result: SearchResult
    var onSelected: ((SearchResult) -> Void)?

    var body: some View {
        Button {
            onSelected?(result)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: DictlySpacing.xs) {
                Circle()
                    .fill(categoryColor(for: result.categoryName))
                    .frame(width: 6, height: 6)
                    .padding(.top, 3)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(result.tagLabel)
                        .font(DictlyTypography.body)
                        .foregroundStyle(DictlyColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: DictlySpacing.xs) {
                        Text(result.sessionTitle)
                            .font(DictlyTypography.caption)
                            .foregroundStyle(DictlyColors.textSecondary)
                            .lineLimit(1)
                        Text("·")
                            .font(DictlyTypography.caption)
                            .foregroundStyle(DictlyColors.textSecondary)
                        Text(formatTimestamp(result.anchorTime))
                            .font(DictlyTypography.caption)
                            .foregroundStyle(DictlyColors.textSecondary)
                            .monospacedDigit()
                    }
                }

                Spacer()
            }
            .padding(.vertical, DictlySpacing.xs)
            .padding(.horizontal, DictlySpacing.sm)
            .background(DictlyColors.surface.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(result.tagLabel), \(result.sessionTitle), \(formatTimestamp(result.anchorTime))")
        .accessibilityHint("Navigate to this tag")
    }
}
