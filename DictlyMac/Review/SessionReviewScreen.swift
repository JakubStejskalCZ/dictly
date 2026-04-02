import SwiftUI
import DictlyModels
import DictlyTheme

/// Main three-panel review layout for a session on Mac.
///
/// Uses `HSplitView` for the tag sidebar + main content split to avoid
/// nested `NavigationSplitView` issues when embedded in `ContentView`.
///
/// Layout: [TagSidebar 260pt] | [Toolbar + WaveformPlaceholder + TagDetailPanel]
struct SessionReviewScreen: View {
    let session: Session

    @State private var selectedTag: Tag?
    @State private var isSidebarVisible: Bool = true

    var body: some View {
        HSplitView {
            if isSidebarVisible {
                TagSidebar(session: session, selectedTag: $selectedTag)
                    .frame(minWidth: 200, idealWidth: 260, maxWidth: 320)
                    .accessibilityLabel("Tag sidebar")
            }

            mainContent
                .frame(minWidth: 500, maxWidth: .infinity)
        }
        .background(DictlyColors.background)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSidebarVisible.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(isSidebarVisible ? "Hide sidebar" : "Show sidebar")
                .accessibilityLabel(isSidebarVisible ? "Hide sidebar" : "Show sidebar")
            }
        }
    }

    // MARK: - Main Content Area

    private var mainContent: some View {
        VStack(spacing: 0) {
            sessionToolbar
                .padding(DictlySpacing.md)
                .background(DictlyColors.surface)
                .overlay(alignment: .bottom) { Divider() }

            waveformPlaceholder
                .padding(DictlySpacing.md)

            Divider()

            TagDetailPanel(tag: selectedTag)
                .frame(minHeight: 200)
        }
    }

    // MARK: - Session Toolbar (Task 2)

    private var sessionToolbar: some View {
        HStack(alignment: .center, spacing: DictlySpacing.md) {
            // Leading: session metadata
            VStack(alignment: .leading, spacing: DictlySpacing.xs) {
                Text(session.title)
                    .font(DictlyTypography.h3)
                    .foregroundStyle(DictlyColors.textPrimary)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: DictlySpacing.sm) {
                    if let campaignName = session.campaign?.name {
                        Text(campaignName)
                            .font(DictlyTypography.caption)
                            .foregroundStyle(DictlyColors.textSecondary)
                    }
                    Text(formatDuration(session.duration))
                        .font(DictlyTypography.caption)
                        .foregroundStyle(DictlyColors.textSecondary)
                        .monospacedDigit()
                    Text("\(session.tags.count) tags")
                        .font(DictlyTypography.caption)
                        .foregroundStyle(DictlyColors.textSecondary)
                }
            }

            Spacer()

            // Trailing: action buttons (disabled stubs — wired in later stories)
            HStack(spacing: DictlySpacing.sm) {
                Button("Transcribe All") { }
                    .disabled(true)
                    .accessibilityLabel("Transcribe all tags")
                    .help("Transcription available after Whisper integration (Epic 5)")

                Button("Export MD") { }
                    .disabled(true)
                    .accessibilityLabel("Export as Markdown")
                    .help("Markdown export available after export feature (Epic 6)")

                Button("Session Notes") { }
                    .disabled(true)
                    .accessibilityLabel("Session notes")
                    .help("Session notes editing available in story 4.7")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Waveform Placeholder (Task 3)

    private var waveformPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(DictlyColors.surface)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 120)
            .overlay(
                Text("Waveform Timeline")
                    .font(DictlyTypography.body)
                    .foregroundStyle(DictlyColors.textSecondary)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "Waveform timeline placeholder. Available after waveform rendering is implemented."
            )
    }

}

// MARK: - Duration Formatting

/// Formats a `TimeInterval` (seconds) as a human-readable duration string: `Xh Ym` or `Xm`.
func formatDuration(_ seconds: TimeInterval) -> String {
    let totalSeconds = max(0, Int(seconds))
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    return "\(minutes)m"
}
