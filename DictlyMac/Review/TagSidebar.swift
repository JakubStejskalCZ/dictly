import SwiftUI
import SwiftData
import DictlyModels
import DictlyTheme

/// Scrollable sidebar listing tags in a session with live search and category filtering.
///
/// When `searchService.isSearchActive` is true, the tag list is replaced with cross-session
/// `SearchResultsView`. Category filter pills remain visible in both modes.
///
/// - `searchText`: drives both local session filtering and cross-session Spotlight search.
/// - `activeCategories`: multi-select set; empty = show all, non-empty = whitelist.
struct TagSidebar: View {
    let session: Session
    let sessionID: UUID
    @Binding var selectedTag: Tag?
    @Binding var activeCategories: Set<String>
    var onResultSelected: ((SearchResult) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(SearchService.self) private var searchService
    @Query(sort: \TagCategory.sortOrder) private var categories: [TagCategory]
    @State private var searchText: String = ""
    @State private var tagToDelete: Tag?
    @State private var showDeleteAlert: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Search field (Task 1.1)
            HStack(spacing: DictlySpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DictlyColors.textSecondary)
                    .accessibilityHidden(true)
                TextField("Search tags", text: $searchText)
                    .font(DictlyTypography.caption)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search tags by name")
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DictlyColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, DictlySpacing.md)
            .padding(.vertical, DictlySpacing.sm)
            .background(DictlyColors.surface)

            Divider()

            // Category filter pills (Tasks 1.3–1.9, 6.1–6.3)
            if !categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DictlySpacing.sm) {
                        // "All" pill (Task 1.7)
                        let totalCount = session.tags.count
                        CategoryFilterPill(
                            label: "All",
                            color: nil,
                            isActive: activeCategories.isEmpty,
                            onTap: { activeCategories = [] }
                        )
                        .accessibilityLabel("All categories. \(totalCount) tags total.")
                        .accessibilityAddTraits(activeCategories.isEmpty ? .isSelected : [])

                        // Per-category pills (Task 1.4, 2.4)
                        ForEach(categories) { category in
                            let count = session.tags.filter { $0.categoryName == category.name }.count
                            let isActive = activeCategories.contains(category.name)
                            CategoryFilterPill(
                                label: category.name,
                                color: categoryColor(for: category.name),
                                isActive: isActive,
                                onTap: { toggleCategory(category.name) }
                            )
                            .accessibilityLabel("\(category.name) filter. \(count) tags.")
                            .accessibilityAddTraits(isActive ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, DictlySpacing.md)
                    .padding(.vertical, DictlySpacing.xs)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Category filters")

                Divider()
            }

            // Tag list OR cross-session search results
            if searchService.isSearchActive {
                SearchResultsView(
                    searchResults: searchService.searchResults,
                    searchText: searchText,
                    isSearching: searchService.isSearching,
                    onResultSelected: { result in
                        onResultSelected?(result)
                    }
                )
            } else {
                let tags = filteredTags
                let totalCount = session.tags.count
                if tags.isEmpty {
                    emptyState(hasFilters: !searchText.trimmingCharacters(in: .whitespaces).isEmpty || !activeCategories.isEmpty, hasTags: totalCount > 0)
                } else {
                    tagList(tags: tags, totalCount: totalCount)
                }
            }
        }
        .background(DictlyColors.background)
        // Reset searchText and clear cross-session search on session change
        .onChange(of: sessionID) { _, _ in
            searchText = ""
            searchService.clearSearch()
        }
        // Task 6.5: Notify VoiceOver when filter changes so it re-reads the updated list
        .onChange(of: activeCategories) { _, _ in
            AccessibilityNotification.LayoutChanged().post()
        }
        // Sync local searchText to SearchService and schedule debounced search
        .onChange(of: searchText) { _, newValue in
            searchService.searchText = newValue
            if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                searchService.clearSearch()
            } else {
                searchService.scheduleSearch()
            }
            AccessibilityNotification.LayoutChanged().post()
        }
        // Provide ModelContext to SearchService for tag UUID resolution
        .onAppear {
            searchService.setModelContext(modelContext)
        }
        .alert("Delete Tag?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let tag = tagToDelete {
                    deleteTagFromContextMenu(tag)
                }
            }
            Button("Cancel", role: .cancel) {
                tagToDelete = nil
            }
        } message: {
            Text("This will permanently remove this tag.")
        }
    }

    // MARK: - Filter Logic (Tasks 2.1–2.3)

    private var filteredTags: [Tag] {
        var tags = session.tags.sorted { $0.anchorTime < $1.anchorTime }
        if !activeCategories.isEmpty {
            tags = tags.filter { activeCategories.contains($0.categoryName) }
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            tags = tags.filter { $0.label.localizedCaseInsensitiveContains(trimmed) }
        }
        return tags
    }

    // MARK: - Toggle (Task 1.6)

    private func toggleCategory(_ name: String) {
        if activeCategories.contains(name) {
            activeCategories.remove(name)
        } else {
            activeCategories.insert(name)
        }
    }

    // MARK: - Delete (Task 4.5, 4.7)

    private func deleteTagFromContextMenu(_ tag: Tag) {
        if selectedTag?.uuid == tag.uuid {
            selectedTag = nil
        }
        tag.session?.tags.removeAll { $0.uuid == tag.uuid }
        modelContext.delete(tag)
        tagToDelete = nil
        AccessibilityNotification.Announcement("Tag deleted").post()
    }

    // MARK: - Subviews

    private func tagList(tags: [Tag], totalCount: Int) -> some View {
        List(tags, id: \.uuid, selection: $selectedTag) { tag in
            TagSidebarRow(tag: tag)
                .tag(tag)
                .contextMenu {
                    Button {
                        selectedTag = tag
                    } label: {
                        Label("Edit Label", systemImage: "pencil")
                    }
                    .accessibilityHint("Selects tag and opens detail panel for editing")

                    Button {
                        selectedTag = tag
                    } label: {
                        Label("Change Category", systemImage: "tag")
                    }

                    Divider()

                    Button(role: .destructive) {
                        tagToDelete = tag
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Tag", systemImage: "trash")
                    }
                }
        }
        .listStyle(.sidebar)
        // Task 6.6: Summary for VoiceOver
        .accessibilityLabel("Showing \(tags.count) of \(totalCount) tags")
    }

    private func emptyState(hasFilters: Bool, hasTags: Bool) -> some View {
        VStack(spacing: DictlySpacing.md) {
            Spacer()
            // Task 2.5: Distinguish filter-empty from session-empty
            if hasFilters && hasTags {
                Text("No matching tags. Try adjusting your filters.")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DictlySpacing.md)
            } else {
                Text("No tags in this session. Place retroactive tags by scrubbing the waveform.")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DictlySpacing.md)
            }
            Spacer()
        }
        .accessibilityLabel(
            hasFilters && hasTags
                ? "No matching tags. Try adjusting your filters."
                : "No tags in this session. Place retroactive tags by scrubbing the waveform."
        )
    }
}

// MARK: - CategoryFilterPill

/// A single pill button for category filtering.
///
/// Displays a colored dot (if `color` is non-nil) + category name.
/// Active pills use `DictlyColors.surface` background; inactive use `Color.clear`.
private struct CategoryFilterPill: View {
    let label: String
    let color: Color?
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DictlySpacing.xs) {
                // Colored dot (Task 1.4)
                if let color {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }
                Text(label)
                    .font(DictlyTypography.caption)
                    .foregroundStyle(
                        isActive ? DictlyColors.textPrimary : DictlyColors.textSecondary
                    )
            }
            .padding(.horizontal, DictlySpacing.sm)
            .padding(.vertical, DictlySpacing.xs)
            .background(
                isActive ? DictlyColors.surface : Color.clear
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isActive ? DictlyColors.border : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
