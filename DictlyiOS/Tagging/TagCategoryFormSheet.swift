import SwiftUI
import SwiftData
import DictlyModels
import DictlyTheme

struct TagCategoryFormSheet: View {
    let category: TagCategory?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selectedColorHex: String
    @State private var selectedIconName: String

    init(category: TagCategory?) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _selectedColorHex = State(initialValue: category?.colorHex ?? "#D97706")
        _selectedIconName = State(initialValue: category?.iconName ?? "tag")
    }

    private var isEditMode: Bool { category != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category Name", text: $name)
                }

                Section("Color") {
                    ColorPaletteRow(selectedHex: $selectedColorHex)
                }

                Section("Icon") {
                    IconPickerGrid(selectedIconName: $selectedIconName)
                }
            }
            .navigationTitle(isEditMode ? "Edit Category" : "New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Helpers

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existing = category {
            existing.name = trimmedName
            existing.colorHex = selectedColorHex
            existing.iconName = selectedIconName
        } else {
            let newCategory = TagCategory(
                name: trimmedName,
                colorHex: selectedColorHex,
                iconName: selectedIconName,
                isDefault: false
            )
            modelContext.insert(newCategory)
        }
        dismiss()
    }
}

// MARK: - Color Palette

private struct ColorPaletteRow: View {
    @Binding var selectedHex: String

    static let palette: [(hex: String, label: String)] = [
        ("#D97706", "Amber"),
        ("#DC2626", "Crimson"),
        ("#7C3AED", "Violet"),
        ("#059669", "Green"),
        ("#4B7BE5", "Blue"),
        ("#78716C", "Stone"),
        ("#EA580C", "Orange"),
        ("#0891B2", "Cyan"),
        ("#BE185D", "Pink"),
        ("#65A30D", "Lime")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DictlySpacing.sm) {
                ForEach(Self.palette, id: \.hex) { swatch in
                    Button {
                        selectedHex = swatch.hex
                    } label: {
                        Circle()
                            .fill(Color(hexString: swatch.hex))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(DictlyColors.textPrimary, lineWidth: selectedHex == swatch.hex ? 2 : 0)
                                    .padding(2)
                            )
                    }
                    .accessibilityLabel(swatch.label)
                }
            }
            .padding(.vertical, DictlySpacing.sm)
        }
    }
}

// MARK: - Icon Picker

private struct IconPickerGrid: View {
    @Binding var selectedIconName: String

    static let icons: [String] = [
        "book.pages", "shield", "theatermasks", "globe", "info.circle",
        "star", "flag", "bolt", "heart", "map",
        "scroll", "crown", "wand.and.stars", "tag", "pencil",
        "message", "person", "house", "flame", "moon"
    ]

    private let columns = Array(repeating: GridItem(.flexible()), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: DictlySpacing.sm) {
            ForEach(Self.icons, id: \.self) { icon in
                Button {
                    selectedIconName = icon
                } label: {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .background(selectedIconName == icon ? DictlyColors.border : Color.clear)
                        .cornerRadius(8)
                        .foregroundStyle(DictlyColors.textPrimary)
                }
                .accessibilityLabel(icon)
            }
        }
        .padding(.vertical, DictlySpacing.sm)
    }
}

// MARK: - Color Extension

extension Color {
    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

#Preview("Create") {
    TagCategoryFormSheet(category: nil)
        .modelContainer(for: TagCategory.self, inMemory: true)
}
