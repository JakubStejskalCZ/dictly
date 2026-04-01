import SwiftUI
import SwiftData
import UIKit
import OSLog
import DictlyModels
import DictlyTheme

private let logger = Logger(subsystem: "com.dictly.ios", category: "tagging")

/// Main container composing `CategoryTabBar` + a `LazyVGrid` of `TagCard` items.
/// Displays template tags (session == nil) filtered by the selected category.
struct TagPalette: View {
    let session: Session
    let taggingService: TaggingService
    var isInteractive: Bool = true

    // Template tags (session == nil) — filtered in-memory for SwiftData compatibility
    @Query(sort: \Tag.label) private var allTags: [Tag]
    @Query(sort: \TagCategory.sortOrder) private var categories: [TagCategory]

    @State private var selectedCategory: TagCategory?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Computed

    private var templateTags: [Tag] {
        allTags.filter { $0.session == nil }
    }

    private var filteredTags: [Tag] {
        guard let category = selectedCategory else {
            return templateTags
        }
        return templateTags.filter { $0.categoryName == category.name }
    }

    private var tagCountPerCategory: [String: Int] {
        Dictionary(grouping: templateTags, by: \.categoryName).mapValues(\.count)
    }

    private var gridColumns: [GridItem] {
        if dynamicTypeSize >= .accessibility3 {
            return [GridItem(.flexible())]
        }
        return [GridItem(.flexible()), GridItem(.flexible())]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DictlySpacing.sm) {
            if !categories.isEmpty {
                CategoryTabBar(
                    categories: Array(categories),
                    selectedCategory: $selectedCategory,
                    tagCountPerCategory: tagCountPerCategory
                )
            }

            ScrollView(.vertical) {
                LazyVGrid(columns: gridColumns, spacing: DictlySpacing.sm) {
                    ForEach(filteredTags) { tag in
                        TagCard(
                            tag: tag,
                            categoryColor: categoryColor(for: tag),
                            categoryName: tag.categoryName,
                            onTap: {
                                guard isInteractive else { return }
                                taggingService.placeTag(
                                    label: tag.label,
                                    categoryName: tag.categoryName,
                                    session: session,
                                    context: modelContext
                                )
                                let count = session.tags.count
                                UIAccessibility.post(
                                    notification: .announcement,
                                    argument: "Tag placed. \(count) tags total."
                                )
                                logger.info("Category tab selected: \(tag.categoryName, privacy: .public)")
                            }
                        )
                    }
                }
                .padding(.bottom, DictlySpacing.sm)
            }
            .opacity(isInteractive ? 1.0 : 0.5)
        }
        .onAppear {
            if selectedCategory == nil {
                selectedCategory = categories.first
            }
            taggingService.prepareHaptic()
        }
        .onChange(of: categories.isEmpty) { _, isEmpty in
            if !isEmpty, selectedCategory == nil {
                selectedCategory = categories.first
            }
        }
    }

    // MARK: - Helpers

    private func categoryColor(for tag: Tag) -> Color {
        guard let category = categories.first(where: { $0.name == tag.categoryName }) else {
            return DictlyColors.textSecondary
        }
        return Color(hexString: category.colorHex)
    }
}
