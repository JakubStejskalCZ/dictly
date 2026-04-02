import SwiftUI
import SwiftData
import DictlyModels
import DictlyTheme

/// Compact sheet form for creating a retroactive tag at a specific waveform position.
///
/// Presented from `SessionReviewScreen` when the DM right-clicks the waveform
/// or presses Cmd+T at the current playhead position.
///
/// On Create: calls `onCreate(label, categoryName)` — parent handles SwiftData insertion.
/// On Cancel or Escape: calls `onCancel()` — no state changes.
struct NewTagForm: View {
    let anchorTime: TimeInterval
    let onCreate: (String, String) -> Void
    let onCancel: () -> Void

    @State private var label: String = "New Tag"
    @State private var selectedCategoryName: String = ""

    @FocusState private var labelFocused: Bool

    @Query(sort: \TagCategory.sortOrder) private var categories: [TagCategory]

    var body: some View {
        VStack(alignment: .leading, spacing: DictlySpacing.md) {

            // MARK: Title
            Text("New Tag")
                .font(DictlyTypography.h3)
                .foregroundStyle(DictlyColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            // MARK: Label field
            TextField("Tag label", text: $label)
                .font(DictlyTypography.body)
                .textFieldStyle(.roundedBorder)
                .focused($labelFocused)
                .onSubmit { submitIfValid() }
                .accessibilityLabel("Tag label")
                .accessibilityHint("Enter a name for this tag")

            // MARK: Category picker
            VStack(alignment: .leading, spacing: DictlySpacing.xs) {
                Text("Category")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)

                ForEach(categories) { category in
                    Button {
                        selectedCategoryName = category.name
                    } label: {
                        HStack(spacing: DictlySpacing.sm) {
                            Circle()
                                .fill(categoryColor(for: category.name))
                                .frame(width: 8, height: 8)
                            Text(category.name)
                                .font(DictlyTypography.body)
                                .foregroundStyle(DictlyColors.textPrimary)
                                .fontWeight(category.name == effectiveCategory ? .semibold : .regular)
                            Spacer()
                            if category.name == effectiveCategory {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(DictlyColors.textSecondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, DictlySpacing.xs)
                    .accessibilityLabel("\(category.name). Double-tap to select.")
                }
            }

            // MARK: Timestamp display (read-only)
            HStack(spacing: DictlySpacing.xs) {
                Text("Position:")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                Text(formatTimestamp(anchorTime))
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textPrimary)
                    .monospacedDigit()
            }

            // MARK: Buttons
            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") { submitIfValid() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(DictlySpacing.md)
        .frame(width: 280)
        .onAppear {
            if let first = categories.first {
                selectedCategoryName = first.name
            }
            // Auto-focus label field for immediate typing
            labelFocused = true
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Create new tag at \(formatTimestamp(anchorTime))")
    }

    // MARK: - Helpers

    /// Returns the currently selected category name, falling back to the first available category.
    private var effectiveCategory: String {
        if !selectedCategoryName.isEmpty { return selectedCategoryName }
        return categories.first?.name ?? ""
    }

    private func submitIfValid() {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onCreate(trimmed, effectiveCategory)
    }
}
