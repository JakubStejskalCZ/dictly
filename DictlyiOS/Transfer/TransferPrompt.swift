import SwiftUI
import DictlyModels
import DictlyTheme

/// Post-session AirDrop transfer UI.
///
/// Displays a session summary card, a prominent AirDrop button, and a
/// secondary "Transfer Later" option. Driven entirely by `TransferService`
/// state; transitions through: idle → preparing → sharing → completed/failed.
struct TransferPrompt: View {

    let session: Session
    let onDismiss: () -> Void

    @State private var transferService = TransferService()
    @State private var autoDismissTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: DictlySpacing.lg) {
                summaryCard
                Spacer()
                actionArea
            }
            .padding(DictlySpacing.md)
            .navigationTitle("Transfer Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if case .idle = transferService.transferState {
                        Button("Transfer Later") {
                            onDismiss()
                        }
                        .accessibilityLabel("Transfer Later — save session locally and transfer later")
                    }
                }
            }
        }
        .sheet(isPresented: isShowingShareSheet) {
            if let bundleURL = transferService.temporaryBundleURL {
                ActivityViewControllerRepresentable(
                    activityItems: [bundleURL],
                    completion: { completed, error in
                        transferService.handleShareCompletion(completed: completed, error: error)
                    }
                )
                .ignoresSafeArea()
            }
        }
        .onChange(of: transferService.transferState) { _, newState in
            if case .completed = newState {
                autoDismissTask?.cancel()
                autoDismissTask = Task {
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    onDismiss()
                }
            }
        }
        .onDisappear {
            autoDismissTask?.cancel()
            transferService.cleanupTemporaryBundle()
        }
        .presentationDetents([.large])
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: DictlySpacing.md) {
            VStack(alignment: .leading, spacing: DictlySpacing.xs) {
                Text(session.title)
                    .font(DictlyTypography.h2)
                    .foregroundStyle(DictlyColors.textPrimary)
                Text(session.date, format: .dateTime.month(.wide).day().year())
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
            }

            Divider()

            HStack(spacing: DictlySpacing.md) {
                summaryStatCell(value: formattedDuration(session.duration), label: "Duration")
                Divider().frame(height: 36)
                summaryStatCell(value: "\(session.tags.count)", label: session.tags.count == 1 ? "tag" : "tags")
            }

            if !categoryBreakdown.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: DictlySpacing.xs) {
                    Text("Categories")
                        .font(DictlyTypography.caption)
                        .foregroundStyle(DictlyColors.textSecondary)
                    ForEach(categoryBreakdown, id: \.category) { item in
                        HStack {
                            Text(item.category)
                                .font(DictlyTypography.body)
                                .foregroundStyle(DictlyColors.textPrimary)
                            Spacer()
                            Text("\(item.count)")
                                .font(DictlyTypography.monospacedDigits)
                                .foregroundStyle(DictlyColors.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(DictlySpacing.md)
        .background(DictlyColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(summaryAccessibilityLabel)
    }

    // MARK: - Action Area

    @ViewBuilder
    private var actionArea: some View {
        switch transferService.transferState {
        case .idle:
            idleActions

        case .preparing:
            preparingView

        case .sharing:
            sharingView

        case .completed:
            completedView

        case .failed(let error):
            failedView(error: error)
        }
    }

    private var idleActions: some View {
        VStack(spacing: DictlySpacing.md) {
            Button {
                Task { await transferService.shareViaAirDrop(session: session) }
            } label: {
                Label("AirDrop to Mac", systemImage: "airplayaudio")
                    .font(DictlyTypography.h3)
                    .frame(maxWidth: .infinity)
                    .frame(height: DictlySpacing.minTapTarget)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("AirDrop to Mac — send session bundle via AirDrop")
            .accessibilityHint("Opens share sheet to send .dictly bundle to your Mac")

            Button("Transfer Later") {
                onDismiss()
            }
            .font(DictlyTypography.body)
            .foregroundStyle(DictlyColors.textSecondary)
            .accessibilityLabel("Transfer Later — dismiss and transfer later from session list")
        }
    }

    private var preparingView: some View {
        VStack(spacing: DictlySpacing.md) {
            ProgressView()
                .scaleEffect(1.5)
                .accessibilityLabel("Preparing bundle")
            Text("Preparing...")
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DictlySpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preparing session bundle for transfer")
    }

    private var sharingView: some View {
        VStack(spacing: DictlySpacing.md) {
            ProgressView()
                .scaleEffect(1.5)
                .accessibilityLabel("Sharing via AirDrop")
            Text("Sharing via AirDrop...")
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DictlySpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sharing session via AirDrop")
    }

    private var completedView: some View {
        VStack(spacing: DictlySpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(DictlyColors.success)
                .accessibilityLabel("Transfer complete")
            Text("Transferred!")
                .font(DictlyTypography.h2)
                .foregroundStyle(DictlyColors.success)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DictlySpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Transfer complete. Dismissing automatically.")
    }

    private func failedView(error: Error) -> some View {
        VStack(spacing: DictlySpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(DictlyColors.destructive)
                .accessibilityHidden(true)

            Text("Transfer Failed")
                .font(DictlyTypography.h3)
                .foregroundStyle(DictlyColors.destructive)

            Text(error.localizedDescription)
                .font(DictlyTypography.caption)
                .foregroundStyle(DictlyColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                transferService.reset()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(DictlyTypography.body)
                    .frame(maxWidth: .infinity)
                    .frame(height: DictlySpacing.minTapTarget)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Retry AirDrop transfer")

            Button("Transfer Later") {
                onDismiss()
            }
            .font(DictlyTypography.body)
            .foregroundStyle(DictlyColors.textSecondary)
            .accessibilityLabel("Transfer Later — dismiss and transfer later from session list")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DictlySpacing.sm)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Share Sheet Binding

    private var isShowingShareSheet: Binding<Bool> {
        Binding(
            get: {
                if case .sharing = transferService.transferState { return true }
                return false
            },
            set: { _ in }
        )
    }

    // MARK: - Helpers

    private struct CategoryCount {
        let category: String
        let count: Int
    }

    private var categoryBreakdown: [CategoryCount] {
        let grouped = Dictionary(grouping: session.tags, by: \.categoryName)
        return grouped.map { CategoryCount(category: $0.key, count: $0.value.count) }
            .sorted { $0.category < $1.category }
    }

    private func summaryStatCell(value: String, label: String) -> some View {
        VStack(spacing: DictlySpacing.xs) {
            Text(value)
                .font(DictlyTypography.h2)
                .foregroundStyle(DictlyColors.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(DictlyTypography.caption)
                .foregroundStyle(DictlyColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    private var summaryAccessibilityLabel: String {
        let duration = formattedDuration(session.duration)
        let tagCount = session.tags.count
        return "\(session.title). Duration \(duration). \(tagCount) \(tagCount == 1 ? "tag" : "tags")."
    }
}
