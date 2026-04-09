import SwiftUI
import SwiftData
import DictlyModels
import DictlyTheme

/// Compact sheet form for creating a retroactive tag at a specific waveform position.
///
/// Presented from `SessionReviewScreen` when the DM right-clicks the waveform
/// or presses Cmd+T at the current playhead position.
///
/// Shows template tags grouped by category for quick selection.
/// A "Custom" option allows typing a free-form label.
///
/// On Create: calls `onCreate(label, categoryName)` — parent handles SwiftData insertion.
/// On Cancel or Escape: calls `onCancel()` — no state changes.
struct NewTagForm: View {
    let anchorTime: TimeInterval
    let onCreate: (String, String, TimeInterval) -> Void
    let onCancel: () -> Void

    @State private var label: String = ""
    @State private var selectedCategoryName: String = ""
    @State private var isCustomMode: Bool = false

    @FocusState private var labelFocused: Bool

    @Query(sort: \TagCategory.sortOrder) private var categories: [TagCategory]
    @Query(sort: \Tag.label) private var allTags: [Tag]

    /// Template tags are those not attached to any session.
    private var templateTags: [Tag] {
        allTags.filter { $0.session == nil }
    }

    /// Unique categories derived from the query (deduplicated by name).
    private var uniqueCategories: [TagCategory] {
        var seen = Set<String>()
        return categories.filter { seen.insert($0.name).inserted }
    }

    /// Template tags for the selected category.
    private var filteredTags: [Tag] {
        guard !selectedCategoryName.isEmpty else { return templateTags }
        return templateTags.filter { $0.categoryName == selectedCategoryName }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DictlySpacing.md) {

            // MARK: Title
            Text("New Tag")
                .font(DictlyTypography.h3)
                .foregroundStyle(DictlyColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            // MARK: Category tabs
            if !uniqueCategories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DictlySpacing.xs) {
                        ForEach(uniqueCategories) { category in
                            Button {
                                selectedCategoryName = category.name
                                isCustomMode = false
                            } label: {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(categoryColor(for: category.name))
                                        .frame(width: 6, height: 6)
                                    Text(category.name)
                                        .font(DictlyTypography.caption)
                                }
                                .padding(.horizontal, DictlySpacing.sm)
                                .padding(.vertical, DictlySpacing.xs)
                                .background(
                                    category.name == selectedCategoryName && !isCustomMode
                                        ? DictlyColors.surface
                                        : Color.clear
                                )
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(
                                category.name == selectedCategoryName && !isCustomMode
                                    ? DictlyColors.textPrimary
                                    : DictlyColors.textSecondary
                            )
                        }
                    }
                }
            }

            // MARK: Tag list or custom input
            if isCustomMode {
                // Custom tag entry
                TextField("Tag name", text: $label)
                    .font(DictlyTypography.body)
                    .textFieldStyle(.roundedBorder)
                    .focused($labelFocused)
                    .onSubmit { submitIfValid() }
                    .accessibilityLabel("Tag label")

                // Category picker for custom tag
                VStack(alignment: .leading, spacing: DictlySpacing.xs) {
                    Text("Category")
                        .font(DictlyTypography.caption)
                        .foregroundStyle(DictlyColors.textSecondary)
                    ForEach(uniqueCategories) { category in
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
                                    .fontWeight(category.name == selectedCategoryName ? .semibold : .regular)
                                Spacer()
                                if category.name == selectedCategoryName {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(DictlyColors.textSecondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, DictlySpacing.xs)
                    }
                }
            } else {
                // Template tag grid
                ScrollView(.vertical) {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: DictlySpacing.xs
                    ) {
                        ForEach(filteredTags) { tag in
                            Button {
                                onCreate(tag.label, tag.categoryName, anchorTime)
                            } label: {
                                HStack(spacing: DictlySpacing.xs) {
                                    Circle()
                                        .fill(categoryColor(for: tag.categoryName))
                                        .frame(width: 6, height: 6)
                                    Text(tag.label)
                                        .font(DictlyTypography.caption)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, DictlySpacing.sm)
                                .padding(.vertical, DictlySpacing.sm)
                                .background(DictlyColors.surface)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(DictlyColors.textPrimary)
                        }

                        // Custom tag button
                        Button {
                            isCustomMode = true
                            labelFocused = true
                        } label: {
                            HStack(spacing: DictlySpacing.xs) {
                                Image(systemName: "plus")
                                    .font(.caption2)
                                Text("Custom")
                                    .font(DictlyTypography.caption)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DictlySpacing.sm)
                            .padding(.vertical, DictlySpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .foregroundStyle(DictlyColors.textSecondary)
                            )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DictlyColors.textSecondary)
                    }
                }
                .frame(maxHeight: 200)
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
                Button(isCustomMode ? "Back" : "Cancel") {
                    if isCustomMode {
                        isCustomMode = false
                        label = ""
                    } else {
                        onCancel()
                    }
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if isCustomMode {
                    Button("Create") { submitIfValid() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty || selectedCategoryName.isEmpty)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(DictlySpacing.md)
        .frame(width: 320)
        .onAppear {
            if let first = uniqueCategories.first {
                selectedCategoryName = first.name
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Create new tag at \(formatTimestamp(anchorTime))")
    }

    // MARK: - Helpers

    private func submitIfValid() {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !selectedCategoryName.isEmpty else { return }
        onCreate(trimmed, selectedCategoryName, anchorTime)
    }
}
