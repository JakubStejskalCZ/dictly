import SwiftUI
import SwiftData
import DictlyModels
import DictlyStorage
import DictlyTheme

struct TagFormSheet: View {
    let tag: Tag?
    let categoryName: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CategorySyncService.self) private var syncService

    @State private var label: String

    init(tag: Tag?, categoryName: String) {
        self.tag = tag
        self.categoryName = categoryName
        _label = State(initialValue: tag?.label ?? "")
    }

    private var isEditMode: Bool { tag != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tag Name", text: $label)
                }
            }
            .navigationTitle(isEditMode ? "Edit Tag" : "New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Helpers

    private func save() {
        let trimmedLabel = label.trimmingCharacters(in: .whitespaces)
        guard !trimmedLabel.isEmpty else { return }

        if let existing = tag {
            existing.label = trimmedLabel
            syncService.markTagModified(existing)
        } else {
            let newTag = Tag(
                label: trimmedLabel,
                categoryName: categoryName,
                anchorTime: 0,
                rewindDuration: 0
            )
            modelContext.insert(newTag)
            syncService.markTagModified(newTag)
        }
        syncService.pushTagsToCloud()
        dismiss()
    }
}

#Preview("Create") {
    TagFormSheet(tag: nil, categoryName: "Story")
        .modelContainer(for: Tag.self, inMemory: true)
        .environment(CategorySyncService())
}
