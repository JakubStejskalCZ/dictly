import SwiftUI
import SwiftData
import DictlyModels
import DictlyTheme

/// Scrollable sidebar listing tags in a session with live search and category filtering.
///
/// When `searchService.isSearchActive` is true, the tag list is replaced with cross-session
/// `SearchResultsView`. Category filter pills remain visible in both modes.
///
/// When `isCrossSessionMode` is true (and no search is active), all tags across the current
/// campaign are shown, grouped by session with section headers.
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
    @State private var highlightedTagID: UUID?
    @State private var tagToDelete: Tag?
    @State private var showDeleteAlert: Bool = false
    @State private var isCrossSessionMode: Bool = false

    // True when the session belongs to a campaign (cross-session mode is available)
    private var hasCampaign: Bool { session.campaign != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
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

            // Cross-session mode toggle — only shown when session is in a campaign
            if hasCampaign {
                Divider()
                Picker("View Mode", selection: $isCrossSessionMode) {
                    Text("Session").tag(false)
                    Text("Campaign").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DictlySpacing.md)
                .padding(.vertical, DictlySpacing.sm)
                .accessibilityLabel(isCrossSessionMode
                    ? "Viewing all tags in campaign. Switch to Session to see current session only."
                    : "Viewing current session tags. Switch to Campaign to browse all sessions.")
            }

            Divider()

            // Category filter pills
            if !categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DictlySpacing.sm) {
                        // "All" pill
                        let totalCount = isCrossSessionMode ? crossSessionTotalTagCount : session.tags.count
                        CategoryFilterPill(
                            label: "All",
                            color: nil,
                            isActive: activeCategories.isEmpty,
                            onTap: { activeCategories = [] }
                        )
                        .accessibilityLabel("All categories. \(totalCount) tags total.")
                        .accessibilityAddTraits(activeCategories.isEmpty ? .isSelected : [])

                        // Per-category pills
                        ForEach(categories) { category in
                            let count = isCrossSessionMode
                                ? crossSessionCategoryCount(for: category.name)
                                : session.tags.filter { $0.categoryName == category.name }.count
                            let isActive = activeCategories.contains(category.name)
                            CategoryFilterPill(
                                label: category.name,
                                color: Color(hexString: category.colorHex),
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
                // Search takes priority over browsing mode
                SearchResultsView(
                    searchResults: searchService.searchResults,
                    searchText: searchText,
                    isSearching: searchService.isSearching,
                    onResultSelected: { result in
                        onResultSelected?(result)
                    }
                )
            } else if isCrossSessionMode {
                crossSessionContent
            } else {
                let tags = filteredTags
                let totalCount = session.tags.count
                if tags.isEmpty {
                    emptyState(hasFilters: !searchText.trimmingCharacters(in: .whitespaces).isEmpty || !activeCategories.isEmpty, hasTags: totalCount > 0, isCrossSession: false)
                } else {
                    tagList(tags: tags, totalCount: totalCount)
                }
            }
        }
        .background(DictlyColors.background)
        // Reset searchText and clear cross-session search on session change
        .onChange(of: sessionID) { _, _ in
            searchText = ""
            highlightedTagID = nil
            isCrossSessionMode = false
            searchService.clearSearch()
        }
        // Sync highlightedTagID when selectedTag changes externally (e.g., waveform tap or deletion)
        .onChange(of: selectedTag) { _, newTag in
            highlightedTagID = newTag?.uuid
        }
        // Notify VoiceOver when filter changes
        .onChange(of: activeCategories) { _, _ in
            AccessibilityNotification.LayoutChanged().post()
        }
        // Notify VoiceOver when mode changes
        .onChange(of: isCrossSessionMode) { _, _ in
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

    // MARK: - Cross-Session Data

    /// All sessions in the campaign, sorted oldest-first, each with their filtered tags.
    private var crossSessionGroups: [(session: Session, tags: [Tag])] {
        guard let campaign = session.campaign else { return [] }
        return campaign.sessions
            .sorted { $0.date < $1.date }
            .compactMap { s in
                var tags = s.tags.sorted { lhs, rhs in
                    lhs.anchorTime < rhs.anchorTime
                }
                if !activeCategories.isEmpty {
                    tags = tags.filter { activeCategories.contains($0.categoryName) }
                }
                guard !tags.isEmpty else { return nil }
                return (session: s, tags: tags)
            }
    }

    private var crossSessionTotalTagCount: Int {
        session.campaign?.sessions.reduce(0) { $0 + $1.tags.count } ?? session.tags.count
    }

    private func crossSessionCategoryCount(for name: String) -> Int {
        session.campaign?.sessions.reduce(0) { $0 + $1.tags.filter { $0.categoryName == name }.count } ?? 0
    }

    // MARK: - Cross-Session Content

    @ViewBuilder
    private var crossSessionContent: some View {
        let groups = crossSessionGroups
        if groups.isEmpty {
            emptyState(
                hasFilters: !activeCategories.isEmpty,
                hasTags: crossSessionTotalTagCount > 0,
                isCrossSession: true
            )
        } else {
            List {
                ForEach(groups, id: \.session.uuid) { group in
                    Section {
                        ForEach(group.tags, id: \.uuid) { tag in
                            TagSidebarRow(tag: tag, isSelected: highlightedTagID == tag.uuid)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    highlightedTagID = tag.uuid
                                    selectedTag = tag
                                }
                                .contextMenu {
                                    Button {
                                        highlightedTagID = tag.uuid
                                        selectedTag = tag
                                    } label: {
                                        Label("Edit Label", systemImage: "pencil")
                                    }
                                    Button {
                                        highlightedTagID = tag.uuid
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
                    } header: {
                        sessionSectionHeader(group.session, tagCount: group.tags.count)
                    }
                }
            }
            .listStyle(.sidebar)
            .onKeyPress(phases: .down) { keyPress in
                let flat = groups.flatMap { $0.tags }
                switch keyPress.key {
                case .upArrow:   navigateTag(in: flat, delta: -1); return .handled
                case .downArrow: navigateTag(in: flat, delta:  1); return .handled
                default: return .ignored
                }
            }
            .accessibilityLabel("Campaign tags grouped by session")
        }
    }

    private func sessionSectionHeader(_ s: Session, tagCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(s.title)
                .font(DictlyTypography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DictlyColors.textPrimary)
                .lineLimit(1)
            HStack(spacing: DictlySpacing.xs) {
                Text(s.date.formatted(date: .abbreviated, time: .omitted))
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                Text("·")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                Text(formatDuration(s.duration))
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                    .monospacedDigit()
                Text("·")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                Text("\(tagCount) tag\(tagCount == 1 ? "" : "s")")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
            }
        }
        .padding(.vertical, DictlySpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(s.title), \(s.date.formatted(date: .abbreviated, time: .omitted)), \(formatDuration(s.duration)), \(tagCount) tags")
    }

    // MARK: - Filter Logic

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

    // MARK: - Toggle

    private func toggleCategory(_ name: String) {
        if activeCategories.contains(name) {
            activeCategories.remove(name)
        } else {
            activeCategories.insert(name)
        }
    }

    // MARK: - Delete

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
        List(tags, id: \.uuid) { tag in
            TagSidebarRow(tag: tag, isSelected: highlightedTagID == tag.uuid)
                .contentShape(Rectangle())
                .onTapGesture {
                    highlightedTagID = tag.uuid
                    selectedTag = tag
                }
                .contextMenu {
                    Button {
                        highlightedTagID = tag.uuid
                        selectedTag = tag
                    } label: {
                        Label("Edit Label", systemImage: "pencil")
                    }
                    .accessibilityHint("Selects tag and opens detail panel for editing")

                    Button {
                        highlightedTagID = tag.uuid
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
        .onKeyPress(phases: .down) { keyPress in
            switch keyPress.key {
            case .upArrow:   navigateTag(in: tags, delta: -1); return .handled
            case .downArrow: navigateTag(in: tags, delta:  1); return .handled
            default: return .ignored
            }
        }
        .accessibilityLabel("Showing \(tags.count) of \(totalCount) tags")
    }

    private func navigateTag(in tags: [Tag], delta: Int) {
        guard !tags.isEmpty else { return }
        if let current = tags.firstIndex(where: { $0.uuid == highlightedTagID }) {
            let next = max(0, min(tags.count - 1, current + delta))
            highlightedTagID = tags[next].uuid
            selectedTag = tags[next]
        } else {
            let seed = delta > 0 ? tags.first! : tags.last!
            highlightedTagID = seed.uuid
            selectedTag = seed
        }
    }

    private func emptyState(hasFilters: Bool, hasTags: Bool, isCrossSession: Bool) -> some View {
        VStack(spacing: DictlySpacing.md) {
            Spacer()
            if hasFilters && hasTags {
                Text("No matching tags. Try adjusting your filters.")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DictlySpacing.md)
            } else if isCrossSession {
                Text("No tags found in this campaign. Start a session and add tags to build your archive.")
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
                : isCrossSession
                    ? "No tags found in this campaign."
                    : "No tags in this session. Place retroactive tags by scrubbing the waveform."
        )
    }
}

// MARK: - CategoryFilterPill

/// A single pill button for category filtering.
///
/// Category pills (color non-nil) use the category colour as background fill —
/// 0.7 opacity when inactive, 1.0 when active — with white text.
/// The "All" pill (color nil) uses DictlyColors.surface background with a border
/// when active, and clear background when inactive.
private struct CategoryFilterPill: View {
    let label: String
    let color: Color?
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(DictlyTypography.caption)
                .foregroundStyle(color != nil ? Color.white : DictlyColors.textPrimary)
                .padding(.horizontal, DictlySpacing.sm)
                .padding(.vertical, DictlySpacing.xs)
                .background(pillBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            color == nil && isActive ? DictlyColors.border : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var pillBackground: Color {
        if let color {
            return color.opacity(isActive ? 1.0 : 0.7)
        }
        // "All" pill always shows a surface background; active state is indicated by the border overlay.
        return DictlyColors.surface
    }
}
