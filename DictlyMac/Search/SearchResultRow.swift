import SwiftUI
import DictlyTheme

/// A single row in the cross-session search results list.
///
/// Layout: category color dot + tag label, session info line, transcription snippet.
struct SearchResultRow: View {
    let result: SearchResult
    let searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: DictlySpacing.xs) {
            // Tag label row with category color dot
            HStack(spacing: DictlySpacing.xs) {
                Circle()
                    .fill(categoryColor(for: result.categoryName))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)

                Text(result.tagLabel)
                    .font(DictlyTypography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(DictlyColors.textPrimary)
                    .lineLimit(1)
            }

            // Session info: "Session N — HH:MM:SS"
            Text("Session \(result.sessionNumber) — \(formatTimestamp(result.anchorTime))")
                .font(DictlyTypography.caption)
                .foregroundStyle(DictlyColors.textSecondary)

            // Transcription snippet
            if let snippet = result.transcriptionSnippet {
                snippetText(snippet)
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                    .italic()
                    .lineLimit(2)
            }
        }
        .padding(.vertical, DictlySpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Snippet Highlighting

    /// Renders the snippet with `**term**` markers highlighted using `DictlyColors.accent`.
    private func snippetText(_ snippet: String) -> Text {
        var result = Text("")
        var remaining = snippet[snippet.startIndex...]

        while !remaining.isEmpty {
            if remaining.hasPrefix("**"),
               let closeRange = remaining.dropFirst(2).range(of: "**") {
                let boldRange = remaining.index(remaining.startIndex, offsetBy: 2)..<closeRange.lowerBound
                let boldText = String(remaining[boldRange])
                result = result + Text(boldText)
                    .foregroundStyle(Color.accentColor)
                    .fontWeight(.semibold)
                let afterClose = remaining.index(closeRange.lowerBound, offsetBy: 2)
                remaining = remaining[afterClose...]
            } else {
                // Find next "**" or consume to end
                if let nextBold = remaining.range(of: "**") {
                    let plainText = String(remaining[..<nextBold.lowerBound])
                    result = result + Text(plainText)
                    remaining = remaining[nextBold.lowerBound...]
                } else {
                    result = result + Text(String(remaining))
                    break
                }
            }
        }
        return result
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var parts = ["\(result.tagLabel), Session \(result.sessionNumber), \(formatTimestamp(result.anchorTime))"]
        if let snippet = result.transcriptionSnippet {
            // Strip ** markers for accessibility
            let plain = snippet
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "…", with: "")
            parts.append(plain)
        }
        return parts.joined(separator: ". ")
    }
}
