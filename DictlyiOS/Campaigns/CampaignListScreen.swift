import SwiftUI
import SwiftData
import DictlyModels
import DictlyTheme

struct CampaignListScreen: View {
    @Query(sort: \Campaign.createdAt, order: .reverse) private var campaigns: [Campaign]
    @Environment(\.modelContext) private var modelContext
    @State private var isShowingCreateForm = false
    @State private var campaignToDelete: Campaign?
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        Group {
            if campaigns.isEmpty {
                emptyCampaignsView
            } else {
                campaignListView
            }
        }
        .navigationTitle("Campaigns")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isShowingCreateForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingCreateForm) {
            CampaignFormSheet(campaign: nil)
        }
        .confirmationDialog(
            "Delete Campaign?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let campaign = campaignToDelete {
                    modelContext.delete(campaign)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the campaign and all its sessions.")
        }
    }

    // MARK: - Subviews

    private var emptyCampaignsView: some View {
        VStack(spacing: DictlySpacing.md) {
            Text("Create your first campaign to start recording sessions")
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DictlySpacing.lg)
            Button("Create Campaign") {
                isShowingCreateForm = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var campaignListView: some View {
        List {
            ForEach(campaigns) { campaign in
                NavigationLink(destination: CampaignDetailScreen(campaign: campaign)) {
                    CampaignRowView(campaign: campaign)
                }
            }
            .onDelete(perform: confirmDelete)
        }
    }

    // MARK: - Helpers

    private func confirmDelete(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        campaignToDelete = campaigns[index]
        isShowingDeleteConfirmation = true
    }
}

// MARK: - Campaign Row

private struct CampaignRowView: View {
    let campaign: Campaign

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: DictlySpacing.xs) {
            Text(campaign.name)
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textPrimary)
            if !campaign.descriptionText.isEmpty {
                Text(campaign.descriptionText)
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                    .lineLimit(2)
            }
            HStack(spacing: DictlySpacing.sm) {
                Text("\(campaign.sessions.count) session\(campaign.sessions.count == 1 ? "" : "s")")
                Text("·")
                Text(Self.dateFormatter.string(from: campaign.createdAt))
            }
            .font(DictlyTypography.caption)
            .foregroundStyle(DictlyColors.textSecondary)
        }
        .padding(.vertical, DictlySpacing.xs)
    }
}

#Preview {
    NavigationStack {
        CampaignListScreen()
    }
    .modelContainer(for: Campaign.self, inMemory: true)
}
