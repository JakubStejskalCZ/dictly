import SwiftUI
import SwiftData
import DictlyModels
import DictlyTheme

struct CampaignDetailScreen: View {
    let campaign: Campaign

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingEditForm = false
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        List {
            emptySessionsSection
        }
        .navigationTitle(campaign.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit Campaign") {
                        isShowingEditForm = true
                    }
                    Button("Delete Campaign", role: .destructive) {
                        isShowingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isShowingEditForm) {
            CampaignFormSheet(campaign: campaign)
        }
        .confirmationDialog(
            "Delete Campaign?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(campaign)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the campaign and all its sessions.")
        }
    }

    // MARK: - Subviews

    private var emptySessionsSection: some View {
        Section {
            VStack(spacing: DictlySpacing.md) {
                Text("Start your first session — place your phone on the table and hit record")
                    .font(DictlyTypography.body)
                    .foregroundStyle(DictlyColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DictlySpacing.md)
                Button("New Session") {}
                    .buttonStyle(.bordered)
                    .disabled(true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DictlySpacing.lg)
            .listRowBackground(Color.clear)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Campaign.self, configurations: config)
    let campaign = Campaign(name: "The Lost Mines", descriptionText: "A classic D&D adventure")
    container.mainContext.insert(campaign)
    return NavigationStack {
        CampaignDetailScreen(campaign: campaign)
    }
    .modelContainer(container)
}
