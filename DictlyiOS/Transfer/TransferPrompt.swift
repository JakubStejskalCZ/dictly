import SwiftUI
import Network
import DictlyModels
import DictlyTheme

/// Post-session transfer UI.
///
/// Displays a session summary card, a prominent AirDrop button, a secondary
/// "Send via Wi-Fi" option, and a "Transfer Later" option. Driven by
/// `TransferService` (AirDrop) and `LocalNetworkSender` (Wi-Fi) state machines.
struct TransferPrompt: View {

    let session: Session
    let onDismiss: () -> Void

    @State private var transferService = TransferService()
    @State private var localNetworkSender = LocalNetworkSender()
    @State private var autoDismissTask: Task<Void, Never>?
    @State private var noPeersTimerTask: Task<Void, Never>?
    @State private var showNoPeersMessage = false

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
                    if isShowingCancelButton {
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
        // AirDrop auto-dismiss
        .onChange(of: transferService.transferState) { _, newState in
            if case .completed = newState {
                scheduleAutoDismiss()
            }
        }
        // Wi-Fi auto-dismiss
        .onChange(of: localNetworkSender.senderState) { _, newState in
            if case .completed = newState {
                scheduleAutoDismiss()
            }
        }
        .onDisappear {
            autoDismissTask?.cancel()
            noPeersTimerTask?.cancel()
            transferService.reset()
            localNetworkSender.stopBrowsing()
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
        // Wi-Fi flow takes precedence when active
        if localNetworkSender.senderState != .idle {
            wifiActionArea
        } else {
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
    }

    // MARK: - Idle Actions (AirDrop + Wi-Fi + Later)

    private var idleActions: some View {
        VStack(spacing: DictlySpacing.md) {
            Button {
                Task { await transferService.shareViaAirDrop(session: session) }
            } label: {
                Label("AirDrop to Mac", systemImage: "square.and.arrow.up")
                    .font(DictlyTypography.h3)
                    .frame(maxWidth: .infinity)
                    .frame(height: DictlySpacing.minTapTarget)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("AirDrop to Mac — send session bundle via AirDrop")
            .accessibilityHint("Opens share sheet to send .dictly bundle to your Mac")

            Button {
                startWiFiTransfer()
            } label: {
                Label("Send via Wi-Fi", systemImage: "wifi")
                    .font(DictlyTypography.body)
                    .frame(maxWidth: .infinity)
                    .frame(height: DictlySpacing.minTapTarget)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Send via Wi-Fi — transfer session over local network")
            .accessibilityHint("Discovers your Mac on the same Wi-Fi network and sends directly")

            Button("Transfer Later") {
                onDismiss()
            }
            .font(DictlyTypography.body)
            .foregroundStyle(DictlyColors.textSecondary)
            .accessibilityLabel("Transfer Later — dismiss and transfer later from session list")
        }
    }

    // MARK: - AirDrop Views

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

    // MARK: - Wi-Fi Action Area

    @ViewBuilder
    private var wifiActionArea: some View {
        switch localNetworkSender.senderState {
        case .idle:
            EmptyView() // Handled by outer actionArea check

        case .browsing:
            wifiBrowsingView

        case .connecting:
            wifiConnectingView

        case .sending(let progress):
            wifiSendingView(progress: progress)

        case .completed:
            completedView

        case .failed(let error):
            wifiFailedView(error: error)
        }
    }

    private var wifiBrowsingView: some View {
        VStack(spacing: DictlySpacing.md) {
            if showNoPeersMessage {
                // No Mac found after timeout
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 40))
                    .foregroundStyle(DictlyColors.textSecondary)
                    .accessibilityHidden(true)

                Text("No Mac Found")
                    .font(DictlyTypography.h3)
                    .foregroundStyle(DictlyColors.textPrimary)

                Text("Make sure Dictly is open on your Mac and both devices are on the same Wi-Fi network.")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    retryWiFiDiscovery()
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(DictlyTypography.body)
                        .frame(maxWidth: .infinity)
                        .frame(height: DictlySpacing.minTapTarget)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Retry Wi-Fi discovery")

                Button("Transfer Later") {
                    onDismiss()
                }
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textSecondary)
                .accessibilityLabel("Transfer Later — dismiss and transfer later from session list")
            } else if localNetworkSender.discoveredPeers.isEmpty {
                // Scanning in progress
                ProgressView()
                    .scaleEffect(1.5)
                    .accessibilityLabel("Searching for Mac on Wi-Fi")
                Text("Looking for your Mac...")
                    .font(DictlyTypography.body)
                    .foregroundStyle(DictlyColors.textSecondary)

                Button("Cancel") {
                    cancelWiFiTransfer()
                }
                .font(DictlyTypography.caption)
                .foregroundStyle(DictlyColors.textSecondary)
                .accessibilityLabel("Cancel Wi-Fi discovery")
            } else {
                // Peers found — show picker
                Text("Select Your Mac")
                    .font(DictlyTypography.h3)
                    .foregroundStyle(DictlyColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                ForEach(localNetworkSender.discoveredPeers, id: \.hashValue) { peer in
                    Button {
                        localNetworkSender.send(session: session, to: peer)
                    } label: {
                        HStack {
                            Image(systemName: "laptopcomputer")
                                .foregroundStyle(DictlyColors.textSecondary)
                                .accessibilityHidden(true)
                            Text(peerDisplayName(peer))
                                .font(DictlyTypography.body)
                                .foregroundStyle(DictlyColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(DictlyColors.textSecondary)
                                .accessibilityHidden(true)
                        }
                        .padding(DictlySpacing.sm)
                        .frame(maxWidth: .infinity)
                        .frame(height: DictlySpacing.minTapTarget)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Send to \(peerDisplayName(peer))")
                    .accessibilityHint("Transfers session bundle to this Mac over Wi-Fi")
                }

                Button("Cancel") {
                    cancelWiFiTransfer()
                }
                .font(DictlyTypography.caption)
                .foregroundStyle(DictlyColors.textSecondary)
                .accessibilityLabel("Cancel Wi-Fi transfer")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DictlySpacing.sm)
        .accessibilityElement(children: .contain)
    }

    private var wifiConnectingView: some View {
        VStack(spacing: DictlySpacing.md) {
            ProgressView()
                .scaleEffect(1.5)
                .accessibilityLabel("Connecting to Mac")
            Text("Connecting...")
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DictlySpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connecting to Mac over Wi-Fi")
    }

    private func wifiSendingView(progress: Double) -> some View {
        VStack(spacing: DictlySpacing.md) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(DictlyColors.success)
                .accessibilityLabel("Sending session via Wi-Fi, \(Int(progress * 100)) percent complete")
            Text("Sending via Wi-Fi...")
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textSecondary)
            Text("\(Int(progress * 100))%")
                .font(DictlyTypography.monospacedDigits)
                .foregroundStyle(DictlyColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DictlySpacing.lg)
        .accessibilityElement(children: .combine)
    }

    private func wifiFailedView(error: Error) -> some View {
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
                retryWiFiTransfer()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(DictlyTypography.body)
                    .frame(maxWidth: .infinity)
                    .frame(height: DictlySpacing.minTapTarget)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Retry Wi-Fi transfer")

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
            set: { newValue in
                if !newValue, case .sharing = transferService.transferState {
                    // Sheet dismissed without completion callback (e.g. swipe-down)
                    transferService.handleShareCompletion(completed: false, error: nil)
                }
            }
        )
    }

    // MARK: - Wi-Fi Helpers

    private func startWiFiTransfer() {
        showNoPeersMessage = false
        localNetworkSender.startBrowsing()
        startNoPeersTimer()
    }

    private func cancelWiFiTransfer() {
        noPeersTimerTask?.cancel()
        noPeersTimerTask = nil
        showNoPeersMessage = false
        localNetworkSender.stopBrowsing()
    }

    private func retryWiFiTransfer() {
        localNetworkSender.reset()
        startWiFiTransfer()
    }

    private func retryWiFiDiscovery() {
        showNoPeersMessage = false
        localNetworkSender.stopBrowsing()
        localNetworkSender.startBrowsing()
        startNoPeersTimer()
    }

    private func startNoPeersTimer() {
        noPeersTimerTask?.cancel()
        noPeersTimerTask = Task {
            do {
                try await Task.sleep(for: .seconds(5))
                if localNetworkSender.discoveredPeers.isEmpty,
                   case .browsing = localNetworkSender.senderState {
                    showNoPeersMessage = true
                }
            } catch {
                // Cancelled
            }
        }
    }

    private func peerDisplayName(_ peer: NWBrowser.Result) -> String {
        switch peer.endpoint {
        case .service(let name, _, _, _):
            return name
        default:
            return "Mac"
        }
    }

    // MARK: - Auto-Dismiss

    private func scheduleAutoDismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = Task {
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return // Cancelled
            }
            onDismiss()
        }
    }

    // MARK: - Toolbar Visibility

    /// Show the "Transfer Later" toolbar button only when in idle or browsing (no active transfer).
    private var isShowingCancelButton: Bool {
        if case .idle = transferService.transferState,
           case .idle = localNetworkSender.senderState {
            return true
        }
        return false
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
