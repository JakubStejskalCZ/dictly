import SwiftUI
import DictlyTheme

/// Displays cross-session search results as a scrollable list.
///
/// - Shows a `ProgressView` while searching.
/// - Shows an empty state with category filter suggestion when no results found.
/// - Each row taps call `onResultSelected`.
struct SearchResultsView: View {
    let searchResults: [SearchResult]
    let searchText: String
    let isSearching: Bool
    let onResultSelected: (SearchResult) -> Void

    var body: some View {
        if isSearching {
            VStack {
                Spacer()
                ProgressView("Searching…")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Searching for \(searchText)")
        } else if searchResults.isEmpty {
            emptyState
        } else {
            resultsList
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        List(searchResults) { result in
            Button {
                onResultSelected(result)
            } label: {
                SearchResultRow(result: result, searchText: searchText)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.sidebar)
        .accessibilityLabel("Search results: \(searchResults.count) found for \(searchText)")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DictlySpacing.md) {
            Spacer()
            Text("No results for \u{201C}\(searchText)\u{201D}. Try a different term or browse by category.")
                .font(DictlyTypography.caption)
                .foregroundStyle(DictlyColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DictlySpacing.md)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("No results for \(searchText). Try a different term or browse by category.")
    }
}
