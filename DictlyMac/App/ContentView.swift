import SwiftUI
import SwiftData
import DictlyModels
import DictlyTheme
import os

struct ContentView: View {
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSession: Session?
    @State private var searchService = SearchService()
    @State private var pendingTagID: UUID?
    private let logger = Logger(subsystem: "com.dictly.mac", category: "search")

    var body: some View {
        NavigationSplitView {
            sessionList
                .navigationTitle("Sessions")
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
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
        List(sessions, id: \.uuid, selection: $selectedSession) { session in
            sessionRow(session)
                .tag(session)
        }
        .listStyle(.sidebar)
        .overlay {
            if sessions.isEmpty {
                Text("No sessions yet.\nImport a session from iOS to get started.")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(DictlySpacing.md)
            }
        }
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
