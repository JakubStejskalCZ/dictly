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
    @State private var sessionToDelete: Session?
    @State private var isShowingSessionDeleteConfirmation = false
    @State private var sessionToEdit: Session?
    @State private var isShowingManageTags = false
    @State private var activeRecordingSession: Session?
    @State private var sessionToTransfer: Session?

    private var sortedSessions: [Session] {
        campaign.sessions.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if campaign.sessions.isEmpty {
                emptySessionsSection
            } else {
                sessionListSection
            }
        }
        .navigationTitle(campaign.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit Campaign") {
                        isShowingEditForm = true
                    }
                    Button("Manage Tags") {
                        isShowingManageTags = true
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
        .sheet(item: $sessionToEdit) { session in
            SessionFormSheet(session: session)
        }
        .sheet(item: $sessionToTransfer) { session in
            TransferPrompt(session: session, onDismiss: {
                sessionToTransfer = nil
            })
        }
        .fullScreenCover(item: $activeRecordingSession, onDismiss: {
            activeRecordingSession = nil
        }) { session in
            RecordingScreen(session: session)
        }
        .navigationDestination(isPresented: $isShowingManageTags) {
            TagCategoryListScreen()
        }
        .confirmationDialog(
            "Delete Campaign?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                sessionToEdit = nil
                sessionToDelete = nil
                modelContext.delete(campaign)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the campaign and all its sessions.")
        }
        .confirmationDialog(
            "Delete Session?",
            isPresented: $isShowingSessionDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    modelContext.delete(session)
                    sessionToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
        } message: {
            Text("This will permanently delete the session.")
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
                Button("New Session") {
                    createSession()
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DictlySpacing.lg)
            .listRowBackground(Color.clear)
        }
    }

    private var sessionListSection: some View {
        Section {
            ForEach(sortedSessions) { session in
                SessionListRow(session: session)
                    .contextMenu {
                        Button {
                            sessionToTransfer = session
                        } label: {
                            Label("AirDrop to Mac", systemImage: "square.and.arrow.up")
                        }
                        Button("Rename") {
                            sessionToEdit = session
                        }
                        Button("Delete", role: .destructive) {
                            sessionToDelete = session
                            isShowingSessionDeleteConfirmation = true
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            sessionToTransfer = session
                        } label: {
                            Label("AirDrop", systemImage: "square.and.arrow.up")
                        }
                        .tint(.indigo)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            sessionToDelete = session
                            isShowingSessionDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            sessionToEdit = session
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
            }
        } header: {
            HStack {
                Text("Sessions")
                Spacer()
                Button("New Session") {
                    createSession()
                }
                .font(DictlyTypography.caption)
            }
        }
    }

    // MARK: - Helpers

    private func createSession() {
        guard activeRecordingSession == nil else { return }
        let nextNumber = (campaign.sessions.map(\.sessionNumber).max() ?? 0) + 1
        let session = Session(
            title: "Session \(nextNumber)",
            sessionNumber: nextNumber,
            date: Date(),
            duration: 0
        )
        session.campaign = campaign
        modelContext.insert(session)
        activeRecordingSession = session
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
