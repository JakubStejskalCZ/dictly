import SwiftUI
import SwiftData
import OSLog
import DictlyModels
import DictlyStorage
import DictlyTheme

private let logger = Logger(subsystem: "com.dictly.ios", category: "tagging")

struct TagCategoryListScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CategorySyncService.self) private var syncService
    @Query(sort: \TagCategory.sortOrder) private var categories: [TagCategory]

    @State private var isShowingCreateSheet = false
    @State private var categoryToEdit: TagCategory?
    @State private var categoryToDelete: TagCategory?
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingLastCategoryAlert = false

    var body: some View {
        List {
            ForEach(categories) { category in
                NavigationLink {
                    TagListScreen(category: category)
                } label: {
                    CategoryRowView(category: category)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        requestDelete(category)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        categoryToEdit = category
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .contextMenu {
                    Button("Edit") { categoryToEdit = category }
                    Button("Delete", role: .destructive) { requestDelete(category) }
                }
            }
            .onMove(perform: moveCategories)
        }
        .navigationTitle("Tag Categories")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    EditButton()
                    Button {
                        isShowingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingCreateSheet) {
            TagCategoryFormSheet(category: nil)
        }
        .sheet(item: $categoryToEdit) { cat in
            TagCategoryFormSheet(category: cat)
        }
        .confirmationDialog(
            "Delete Category?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let cat = categoryToDelete {
                    deleteCategory(cat)
                    categoryToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                categoryToDelete = nil
            }
        } message: {
            Text("Tags in this category will be moved to \"Uncategorized\".")
        }
        .alert("Cannot Delete", isPresented: $isShowingLastCategoryAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You must have at least one tag category.")
        }
    }

    // MARK: - Helpers

    private func requestDelete(_ category: TagCategory) {
        guard categories.count > 1 else {
            isShowingLastCategoryAlert = true
            return
        }
        categoryToEdit = nil
        categoryToDelete = category
        isShowingDeleteConfirmation = true
    }

    private func deleteCategory(_ category: TagCategory) {
        let uncategorizedName = "Uncategorized"
        let isDeletingUncategorized = category.name == uncategorizedName

        // Ensure "Uncategorized" fallback exists (create if needed, even when deleting "Uncategorized" itself)
        let hasFallback = categories.contains { $0.name == uncategorizedName && $0.uuid != category.uuid }
        if !hasFallback {
            let fallback = TagCategory(
                name: uncategorizedName,
                colorHex: "#78716C",
                iconName: "tag",
                sortOrder: isDeletingUncategorized ? category.sortOrder : categories.count,
                isDefault: false
            )
            modelContext.insert(fallback)
        }

        // Reassign tags to "Uncategorized"
        do {
            let categoryName = category.name
            let predicate = #Predicate<Tag> { $0.categoryName == categoryName }
            let orphanedTags = try modelContext.fetch(FetchDescriptor<Tag>(predicate: predicate))
            for tag in orphanedTags {
                tag.categoryName = uncategorizedName
            }
            modelContext.delete(category)
            syncService.pushCategoriesToCloud()
        } catch {
            logger.error("Failed to reassign tags — category not deleted: \(error)")
        }
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var reordered = categories
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, category) in reordered.enumerated() {
            category.sortOrder = index
        }
        syncService.pushCategoriesToCloud()
    }
}

// MARK: - Row View

private struct CategoryRowView: View {
    let category: TagCategory

    var body: some View {
        HStack(spacing: DictlySpacing.sm) {
            Circle()
                .fill(Color(hexString: category.colorHex))
                .frame(width: 8, height: 8)
            Image(systemName: category.iconName)
                .font(DictlyTypography.body)
                .foregroundStyle(Color(hexString: category.colorHex))
                .frame(width: 24)
            Text(category.name)
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textPrimary)
            Spacer()
            if category.isDefault {
                Text("Default")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Schema(DictlySchema.all), configurations: config)
    try! DefaultTagSeeder.seedIfNeeded(context: container.mainContext)
    return NavigationStack {
        TagCategoryListScreen()
    }
    .modelContainer(container)
    .environment(CategorySyncService())
}
