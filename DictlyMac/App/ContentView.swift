import SwiftUI
import SwiftData
import DictlyModels
import DictlyTheme

struct ContentView: View {
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @State private var selectedSession: Session?

    var body: some View {
        NavigationSplitView {
            sessionList
                .navigationTitle("Sessions")
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            if let session = selectedSession {
                SessionReviewScreen(session: session)
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
            Text(session.date.formatted(date: .abbreviated, time: .omitted))
                .font(DictlyTypography.caption)
                .foregroundStyle(DictlyColors.textSecondary)
        }
        .padding(.vertical, DictlySpacing.xs)
        .accessibilityLabel("\(session.title), \(session.date.formatted(date: .abbreviated, time: .omitted))")
    }
}

#Preview {
    ContentView()
}
