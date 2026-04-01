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
    @State private var isShowingCustomTagSheet = false
    @State private var customTagSaved = false

    @AppStorage("rewindDuration") private var rewindDuration: Double = 10.0

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
                                let success = taggingService.placeTag(
                                    label: tag.label,
                                    categoryName: tag.categoryName,
                                    rewindDuration: rewindDuration,
                                    session: session,
                                    context: modelContext
                                )
                                if success {
                                    let count = session.tags.count
                                    UIAccessibility.post(
                                        notification: .announcement,
                                        argument: "Tag placed. \(count) tags total."
                                    )
                                }
                            }
                        )
                    }
                    // Custom tag "+" card — always last in grid
                    Button {
                        guard isInteractive, !isShowingCustomTagSheet else { return }
                        taggingService.captureAnchor(rewindDuration: rewindDuration)
                        isShowingCustomTagSheet = true
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 1.5, dash: [6])
                                )
                                .foregroundStyle(DictlyColors.textSecondary)
                            Image(systemName: "plus")
                                .foregroundStyle(DictlyColors.textSecondary)
                        }
                        .frame(minHeight: DictlySpacing.minTapTarget)
                    }
                    .disabled(!isInteractive)
                    .accessibilityLabel("Create custom tag")
                    .accessibilityHint("Double-tap to open tag creator")
                    .sheet(isPresented: $isShowingCustomTagSheet, onDismiss: {
                        if !customTagSaved {
                            taggingService.discardCapturedAnchor()
                        }
                        customTagSaved = false
                    }) {
                        CustomTagSheet(
                            selectedCategoryName: selectedCategory?.name ?? "Uncategorized",
                            categories: Array(categories),
                            onSave: { label, categoryName in
                                let success = taggingService.placeTagWithCapturedAnchor(
                                    label: label,
                                    categoryName: categoryName,
                                    session: session,
                                    context: modelContext
                                )
                                if success {
                                    customTagSaved = true
                                    let count = session.tags.count
                                    UIAccessibility.post(
                                        notification: .announcement,
                                        argument: "Tag placed. \(count) tags total."
                                    )
                                }
                            }
                        )
                    }
                }
                .padding(.bottom, DictlySpacing.sm)
            }
        }
        .opacity(isInteractive ? 1.0 : 0.5)
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
