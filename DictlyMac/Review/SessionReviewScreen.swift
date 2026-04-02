import SwiftUI
import DictlyModels
import DictlyTheme
import os

/// Main three-panel review layout for a session on Mac.
///
/// Uses `HSplitView` for the tag sidebar + main content split to avoid
/// nested `NavigationSplitView` issues when embedded in `ContentView`.
///
/// Layout: [TagSidebar 260pt] | [Toolbar + WaveformTimeline + TagDetailPanel]
struct SessionReviewScreen: View {
    let session: Session

    @State private var selectedTag: Tag?
    @State private var isSidebarVisible: Bool = true
    @State private var audioPlayer = AudioPlayer()

    private let logger = Logger(subsystem: "com.dictly.mac", category: "playback")

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
        // Task 2.2: Load audio when session appears
        .task {
            guard let path = session.audioFilePath else { return }
            do {
                try await audioPlayer.load(filePath: path)
            } catch {
                logger.error("Failed to load audio: \(error.localizedDescription)")
            }
        }
        // Task 2.4: Seek + play when selectedTag changes to non-nil
        .onChange(of: selectedTag) { _, newTag in
            guard let tag = newTag else { return }
            audioPlayer.seek(to: tag.anchorTime)
            audioPlayer.play()
        }
    }

    // MARK: - Main Content Area

    private var mainContent: some View {
        VStack(spacing: 0) {
            sessionToolbar
                .padding(DictlySpacing.md)
                .background(DictlyColors.surface)
                .overlay(alignment: .bottom) { Divider() }

            // Task 2.3: Pass audioPlayer to waveform (view-scoped, not @Environment)
            SessionWaveformTimeline(session: session, selectedTag: $selectedTag, audioPlayer: audioPlayer)
                .padding(DictlySpacing.md)

            Divider()

            TagDetailPanel(tag: selectedTag)
                .frame(minHeight: 200)
        }
    }

    // MARK: - Session Toolbar (Tasks 2, 3)

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

            // Task 3: Playback transport controls
            playbackControls

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

    // MARK: - Playback Controls (Task 3)

    private var playbackControls: some View {
        HStack(spacing: DictlySpacing.sm) {
            // Task 3.1: Play/pause toggle button
            Button {
                // Task 8.4: Announce state change for VoiceOver
                if audioPlayer.isPlaying {
                    audioPlayer.pause()
                    AccessibilityNotification.Announcement("Paused").post()
                } else {
                    audioPlayer.play()
                    AccessibilityNotification.Announcement("Playing").post()
                }
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
            }
            // Task 3.5: Disable when not loaded or no audio file
            .disabled(!audioPlayer.isLoaded || session.audioFilePath == nil)
            // Task 8.1: Accessibility label reflects current state
            .accessibilityLabel(audioPlayer.isPlaying ? "Pause" : "Play")
            .help(audioPlayer.isPlaying ? "Pause playback" : "Play session audio")

            // Task 3.2: Current position / total duration timestamp
            Text("\(formatTimestamp(audioPlayer.currentTime)) / \(formatTimestamp(audioPlayer.duration))")
                .font(DictlyTypography.caption)
                .foregroundStyle(DictlyColors.textSecondary)
                .monospacedDigit()
        }
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
