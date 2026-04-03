import SwiftUI
import SwiftData
import DictlyModels
import DictlyTheme

struct TagListScreen: View {
    let category: TagCategory

    @Environment(\.modelContext) private var modelContext
    @Query private var tags: [Tag]

    @State private var isShowingCreateSheet = false
    @State private var tagToEdit: Tag?
    @State private var tagToDelete: Tag?
    @State private var isShowingDeleteConfirmation = false

    init(category: TagCategory) {
        self.category = category
        let name = category.name
        _tags = Query(filter: #Predicate<Tag> { $0.categoryName == name })
    }

    var body: some View {
        List {
            if tags.isEmpty {
                Section {
                    Text("No tags yet. Tap + to add one.")
                        .font(DictlyTypography.body)
                        .foregroundStyle(DictlyColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, DictlySpacing.md)
                        .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(tags) { tag in
                        TagRowView(tag: tag)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    requestDelete(tag)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    tagToEdit = tag
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(DictlyColors.textSecondary)
                            }
                            .contextMenu {
                                Button("Rename") { tagToEdit = tag }
                                Button("Delete", role: .destructive) { requestDelete(tag) }
                            }
                    }
                }
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isShowingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingCreateSheet) {
            TagFormSheet(tag: nil, categoryName: category.name)
        }
        .sheet(item: $tagToEdit) { tag in
            TagFormSheet(tag: tag, categoryName: category.name)
        }
        .confirmationDialog(
            "Delete Tag?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let tag = tagToDelete {
                    modelContext.delete(tag)
                    tagToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                tagToDelete = nil
            }
        } message: {
            Text("This will permanently delete the tag.")
        }
    }

    // MARK: - Helpers

    private func requestDelete(_ tag: Tag) {
        tagToEdit = nil
        tagToDelete = tag
        isShowingDeleteConfirmation = true
    }
}

// MARK: - Row View

private struct TagRowView: View {
    let tag: Tag

    var body: some View {
        Text(tag.label)
            .font(DictlyTypography.body)
            .foregroundStyle(DictlyColors.textPrimary)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Schema(DictlySchema.all), configurations: config)
    try! DefaultTagSeeder.seedIfNeeded(context: container.mainContext)
    let category = try! container.mainContext.fetch(FetchDescriptor<TagCategory>()).first!
    return NavigationStack {
        TagListScreen(category: category)
    }
    .modelContainer(container)
}
