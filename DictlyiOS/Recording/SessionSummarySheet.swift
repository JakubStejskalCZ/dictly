import SwiftUI
import DictlyModels
import DictlyTheme

/// Full-height sheet displayed after stopping a recording.
/// Shows session duration, tag count, pause count, and a tag list grouped by category.
struct SessionSummarySheet: View {
    let session: Session
    let onDismiss: () -> Void

    @State private var isShowingTransferPrompt = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DictlySpacing.lg) {
                    headerSection
                    statsSection
                    tagListSection
                    airDropButton
                }
                .padding(DictlySpacing.md)
            }
            .navigationTitle("Session Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingTransferPrompt) {
            TransferPrompt(session: session, onDismiss: {
                isShowingTransferPrompt = false
                onDismiss()
            })
        }
        .presentationDetents([.large])
    }

    // MARK: - AirDrop

    private var airDropButton: some View {
        Button {
            isShowingTransferPrompt = true
        } label: {
            Label("AirDrop to Mac", systemImage: "airplayaudio")
                .font(DictlyTypography.h3)
                .frame(maxWidth: .infinity)
                .frame(height: DictlySpacing.minTapTarget)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("AirDrop to Mac — send session bundle via AirDrop")
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DictlySpacing.xs) {
            Text(session.title)
                .font(DictlyTypography.h2)
                .foregroundStyle(DictlyColors.textPrimary)
            Text(session.date, format: .dateTime.month(.wide).day().year())
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textSecondary)
            if let campaignName = session.campaign?.name {
                Text(campaignName)
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
            }
        }
    }

    private var statsSection: some View {
        HStack(spacing: DictlySpacing.md) {
            statCell(value: formattedDuration(session.duration), label: "Duration")
            Divider().frame(height: 40)
            statCell(value: "\(session.tags.count)", label: session.tags.count == 1 ? "tag" : "tags")
            let pauseCount = session.pauseIntervals.count
            if pauseCount > 0 {
                Divider().frame(height: 40)
                statCell(value: "\(pauseCount)", label: pauseCount == 1 ? "pause" : "pauses")
            }
        }
        .padding(DictlySpacing.md)
        .background(DictlyColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statsAccessibilityLabel)
    }

    private var tagListSection: some View {
        VStack(alignment: .leading, spacing: DictlySpacing.md) {
            Text("Tags")
                .font(DictlyTypography.h3)
                .foregroundStyle(DictlyColors.textPrimary)

            if session.tags.isEmpty {
                Text("No tags placed")
                    .font(DictlyTypography.body)
                    .foregroundStyle(DictlyColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DictlySpacing.lg)
            } else {
                let grouped = Dictionary(grouping: session.tags, by: \.categoryName)
                    .sorted { $0.key < $1.key }
                ForEach(grouped, id: \.key) { categoryName, tags in
                    categoryGroup(name: categoryName, tags: tags)
                }
            }
        }
    }

    private func categoryGroup(name: String, tags: [Tag]) -> some View {
        VStack(alignment: .leading, spacing: DictlySpacing.sm) {
            HStack {
                Text(name)
                    .font(DictlyTypography.h3)
                    .foregroundStyle(DictlyColors.textPrimary)
                Spacer()
                Text("\(tags.count)")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
            }
            .padding(.bottom, DictlySpacing.xs)

            ForEach(tags.sorted { $0.anchorTime < $1.anchorTime }, id: \.uuid) { tag in
                HStack {
                    Text(tag.label)
                        .font(DictlyTypography.body)
                        .foregroundStyle(DictlyColors.textPrimary)
                    Spacer()
                    Text(formattedAnchorTime(tag.anchorTime))
                        .font(DictlyTypography.monospacedDigits)
                        .foregroundStyle(DictlyColors.textSecondary)
                }
                .padding(.vertical, DictlySpacing.xs)
                .accessibilityLabel("\(tag.label), \(name), at \(formattedAnchorTime(tag.anchorTime))")
            }

            Divider()
        }
    }

    // MARK: - Formatting

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

    private func formattedAnchorTime(_ anchorTime: TimeInterval) -> String {
        let total = max(0, Int(anchorTime))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
        } else {
            return "\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
        }
    }

    private var statsAccessibilityLabel: String {
        let duration = formattedDuration(session.duration)
        let tagCount = session.tags.count
        let pauseCount = session.pauseIntervals.count
        var label = "Duration \(duration). \(tagCount) \(tagCount == 1 ? "tag" : "tags")."
        if pauseCount > 0 {
            label += " \(pauseCount) \(pauseCount == 1 ? "pause" : "pauses")."
        }
        return label
    }

    // MARK: - Helpers

    private func statCell(value: String, label: String) -> some View {
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
}
