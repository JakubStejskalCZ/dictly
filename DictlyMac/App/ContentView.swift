import SwiftUI
import SwiftData
import DictlyModels
import DictlyTheme
import os

struct ContentView: View {
    @Query(sort: \Campaign.createdAt, order: .forward) private var campaigns: [Campaign]
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    private let uncampaignedGroupID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSession: Session?
    @State private var searchService = SearchService()
    @State private var pendingTagID: UUID?
    private let logger = Logger(subsystem: "com.dictly.mac", category: "search")

    var body: some View {
        NavigationSplitView {
            sessionList
                .navigationTitle("Sessions")
                .navigationSplitViewColumnWidth(min: 200, ideal: 260)
        } detail: {
            if let session = selectedSession {
                SessionReviewScreen(
                    session: session,
                    pendingTagID: $pendingTagID,
                    onResultSelected: { result in
                        handleSearchResultSelected(result)
                    },
                    onRelatedTagSelected: { result in
                        handleSearchResultSelected(result)
                    }
                )
            } else {
                Text("Select a session to review")
                    .font(DictlyTypography.body)
                    .foregroundStyle(DictlyColors.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 900, minHeight: 500)
        .overlay(alignment: .top) {
            ImportProgressView()
        }
        .environment(searchService)
        .onAppear {
            searchService.setModelContext(modelContext)
        }
    }

    // MARK: - Grouped Sessions

    private var groupedSessions: [(id: UUID, title: String, sessions: [Session])] {
        var groups: [(id: UUID, title: String, sessions: [Session])] = campaigns
            .filter { !$0.sessions.isEmpty }
            .map { ($0.uuid, $0.name, $0.sessions.sorted { $0.date > $1.date }) }
        let uncampaigned = sessions.filter { $0.campaign == nil }
        if !uncampaigned.isEmpty {
            groups.append((uncampaignedGroupID, "Uncampaigned", uncampaigned.sorted { $0.date > $1.date }))
        }
        return groups
    }

    // MARK: - Search Navigation

    private func handleSearchResultSelected(_ result: SearchResult) {
        // Fetch the session from SwiftData by UUID
        let sessionID = result.sessionID
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.uuid == sessionID })
        guard let session = try? modelContext.fetch(descriptor).first else {
            logger.warning("Search nav: session \(sessionID, privacy: .public) not found in store")
            return
        }

        selectedSession = session
        searchService.clearSearch()
        // Defer pendingTagID by one run-loop tick so SessionReviewScreen receives
        // the new session identity before the onChange fires.
        let tagID = result.tagID
        Task { @MainActor in
            pendingTagID = tagID
        }
    }

    // MARK: - Session List

    private var sessionList: some View {
        let groups = groupedSessions
        return List(selection: $selectedSession) {
            ForEach(groups, id: \.id) { group in
                Section {
                    ForEach(group.sessions, id: \.uuid) { session in
                        sessionRow(session)
                            .tag(session)
                    }
                } header: {
                    campaignSectionHeader(group.title, sessionCount: group.sessions.count)
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if groups.isEmpty {
                Text("No sessions yet.\nImport a session from iOS to get started.")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(DictlySpacing.md)
            }
        }
    }

    private func campaignSectionHeader(_ campaignName: String, sessionCount: Int) -> some View {
        Text(campaignName)
            .font(DictlyTypography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(DictlyColors.textPrimary)
            .accessibilityLabel("\(campaignName) campaign, \(sessionCount) session\(sessionCount == 1 ? "" : "s")")
    }

    @ViewBuilder
    private func sessionRow(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: DictlySpacing.xs) {
            Text(session.title)
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textPrimary)
                .lineLimit(1)
            HStack(spacing: DictlySpacing.xs) {
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                Text("·")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                Text(formatDuration(session.duration))
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                    .monospacedDigit()
                Text("·")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                Text("\(session.tags.count) tag\(session.tags.count == 1 ? "" : "s")")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
            }
        }
        .padding(.vertical, DictlySpacing.xs)
        .accessibilityLabel("\(session.title), \(session.date.formatted(date: .abbreviated, time: .omitted)), \(formatDuration(session.duration)), \(session.tags.count) tags")
    }
}

#Preview {
    ContentView()
}
