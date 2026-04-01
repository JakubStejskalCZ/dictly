import SwiftUI
import SwiftData
import DictlyModels
import DictlyTheme

struct CampaignFormSheet: View {
    let campaign: Campaign?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var descriptionText: String

    init(campaign: Campaign?) {
        self.campaign = campaign
        _name = State(initialValue: campaign?.name ?? "")
        _descriptionText = State(initialValue: campaign?.descriptionText ?? "")
    }

    private var isEditMode: Bool { campaign != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Campaign Name", text: $name)
                    TextField("Description (optional)", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditMode ? "Edit Campaign" : "New Campaign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Helpers

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = campaign {
            existing.name = trimmedName
            existing.descriptionText = trimmedDescription
        } else {
            let newCampaign = Campaign(name: trimmedName, descriptionText: trimmedDescription)
            modelContext.insert(newCampaign)
        }
        dismiss()
    }
}

#Preview("Create") {
    CampaignFormSheet(campaign: nil)
        .modelContainer(for: Campaign.self, inMemory: true)
}
