import SwiftUI
import DictlyModels

/// Partial-height sheet for creating a custom tag during recording.
/// The caller captures the rewind-anchor timestamp on "+" tap (timestamp-first);
/// this sheet only collects the label and category, then calls `onSave` to delegate placement.
struct CustomTagSheet: View {
    let selectedCategoryName: String
    let categories: [TagCategory]
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var categoryName: String
    @FocusState private var isLabelFocused: Bool

    init(selectedCategoryName: String, categories: [TagCategory], onSave: @escaping (String, String) -> Void) {
        self.selectedCategoryName = selectedCategoryName
        self.categories = categories
        self.onSave = onSave
        _categoryName = State(initialValue: selectedCategoryName)
    }

    private var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tag Name", text: $label)
                        .focused($isLabelFocused)
                        .accessibilityLabel("Tag name. Enter a short label for this moment.")
                }
                Section {
                    Picker("Category", selection: $categoryName) {
                        ForEach(categories, id: \.name) { category in
                            Text(category.name).tag(category.name)
                        }
                        if categories.isEmpty {
                            Text("Uncategorized").tag("Uncategorized")
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Category, \(categoryName)")
                }
            }
            .navigationTitle("Custom Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(trimmedLabel, categoryName)
                        dismiss()
                    }
                    .disabled(trimmedLabel.isEmpty)
                }
            }
            .onAppear {
                isLabelFocused = true
            }
        }
        .presentationDetents([.medium])
    }
}
