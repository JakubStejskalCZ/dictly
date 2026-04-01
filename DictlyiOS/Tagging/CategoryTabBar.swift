import SwiftUI
import DictlyModels
import DictlyTheme

/// Horizontally scrollable row of pill-shaped category filter tabs.
/// Fades at the edges when content overflows.
struct CategoryTabBar: View {
    let categories: [TagCategory]
    @Binding var selectedCategory: TagCategory?
    let tagCountPerCategory: [String: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DictlySpacing.sm) {
                ForEach(sortedCategories) { category in
                    CategoryTab(
                        category: category,
                        tagCount: tagCountPerCategory[category.name] ?? 0,
                        isSelected: selectedCategory?.uuid == category.uuid,
                        onTap: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal, DictlySpacing.md)
            .padding(.vertical, DictlySpacing.sm)
        }
        .background(DictlyColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .mask(
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: DictlySpacing.md)
                Rectangle().fill(Color.black)
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: DictlySpacing.md)
            }
        )
    }

    private var sortedCategories: [TagCategory] {
        categories.sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - Category Tab

private struct CategoryTab: View {
    let category: TagCategory
    let tagCount: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DictlySpacing.xs) {
                Circle()
                    .fill(Color(hexString: category.colorHex))
                    .frame(width: 6, height: 6)
                Text(category.name)
                    .font(DictlyTypography.caption)
                    .foregroundStyle(isSelected ? DictlyColors.textPrimary : DictlyColors.textSecondary)
            }
            .padding(.horizontal, DictlySpacing.sm)
            .padding(.vertical, DictlySpacing.xs)
            .background(isSelected ? DictlyColors.background : Color.clear)
            .clipShape(Capsule())
        }
        .accessibilityLabel("\(category.name) filter. \(tagCount) tags available.")
    }
}
