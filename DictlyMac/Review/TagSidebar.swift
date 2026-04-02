import SwiftUI
import DictlyModels
import DictlyTheme

/// Scrollable sidebar listing all tags in a session, sorted by `anchorTime`.
///
/// Includes a placeholder search field at top (non-functional; full filtering in story 4.4).
/// Handles empty state when the session has no tags.
struct TagSidebar: View {
    let session: Session
    @Binding var selectedTag: Tag?

    var body: some View {
        VStack(spacing: 0) {
            // Placeholder search field (non-functional — story 4.4 implements filtering)
            HStack(spacing: DictlySpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DictlyColors.textSecondary)
                    .accessibilityHidden(true)
                Text("Search tags")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, DictlySpacing.md)
            .padding(.vertical, DictlySpacing.sm)
            .background(DictlyColors.surface)
            .overlay(alignment: .bottom) {
                Divider()
            }

            if sortedTags.isEmpty {
                emptyState
            } else {
                tagList
            }
        }
        .background(DictlyColors.background)
    }

    // MARK: - Subviews

    private var tagList: some View {
        List(sortedTags, id: \.uuid, selection: $selectedTag) { tag in
            TagSidebarRow(tag: tag)
                .tag(tag)
        }
        .listStyle(.sidebar)
    }

    private var emptyState: some View {
        VStack(spacing: DictlySpacing.md) {
            Spacer()
            Text("No tags in this session. Place retroactive tags by scrubbing the waveform.")
                .font(DictlyTypography.caption)
                .foregroundStyle(DictlyColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DictlySpacing.md)
            Spacer()
        }
        .accessibilityLabel("No tags in this session. Place retroactive tags by scrubbing the waveform.")
    }

    // MARK: - Helpers

    private var sortedTags: [Tag] {
        session.tags.sorted { $0.anchorTime < $1.anchorTime }
    }
}
