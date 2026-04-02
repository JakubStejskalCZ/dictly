import SwiftUI
import SwiftData
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

    @Environment(\.modelContext) private var modelContext

    @State private var selectedTag: Tag?
    @State private var isSidebarVisible: Bool = true
    @State private var audioPlayer = AudioPlayer()
    @State private var activeCategories: Set<String> = []

    // MARK: Retroactive tag creation state (Story 4.6)
    @State private var isCreatingTag: Bool = false
    @State private var newTagAnchorTime: TimeInterval = 0

    // MARK: Session notes state (Story 4.7)
    @State private var isShowingSessionNotes: Bool = false

    private let logger = Logger(subsystem: "com.dictly.mac", category: "playback")
    private let taggingLogger = Logger(subsystem: "com.dictly.mac", category: "tagging")

    var body: some View {
        HSplitView {
            if isSidebarVisible {
                TagSidebar(session: session, sessionID: session.uuid, selectedTag: $selectedTag, activeCategories: $activeCategories)
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
        // Task 2.2: Load audio when session appears (or re-fires when audioFilePath changes).
        // Binding id to audioFilePath ensures the task re-fires if a different session is shown
        // via view recycling (e.g. NavigationStack identity reuse).
        .task(id: session.audioFilePath) {
            guard let path = session.audioFilePath else { return }
            do {
                try await audioPlayer.load(filePath: path)
            } catch {
                logger.error("Failed to load audio: \(error.localizedDescription)")
            }
        }
        // Task 4.1: Reset active category filters and selection when session changes
        .onChange(of: session.uuid) { _, _ in
            activeCategories = []
            selectedTag = nil
        }
        // Task 2.4: Seek + play when selectedTag changes to non-nil
        .onChange(of: selectedTag) { _, newTag in
            guard let tag = newTag else { return }
            audioPlayer.seek(to: tag.anchorTime)
            audioPlayer.play()
        }
        // Story 4.6: NewTagForm sheet for retroactive tag creation
        .sheet(isPresented: $isCreatingTag) {
            NewTagForm(
                anchorTime: newTagAnchorTime,
                onCreate: { label, categoryName, anchorTime in
                    createTag(label: label, categoryName: categoryName, anchorTime: anchorTime)
                },
                onCancel: {
                    isCreatingTag = false
                }
            )
        }
        // Story 4.7: Session notes sheet
        .sheet(isPresented: $isShowingSessionNotes) {
            SessionNotesView(session: session)
        }
    }

    // MARK: - Retroactive Tag Creation (Story 4.6)

    /// Creates a Tag at `anchorTime`, inserts it into SwiftData, appends to session,
    /// and auto-selects it so `TagDetailPanel` populates immediately.
    private func createTag(label: String, categoryName: String, anchorTime: TimeInterval) {
        let tag = Tag(
            label: label,
            categoryName: categoryName,
            anchorTime: anchorTime,
            rewindDuration: 0
        )
        modelContext.insert(tag)
        session.tags.append(tag)
        selectedTag = tag
        isCreatingTag = false
        taggingLogger.info("Retroactive tag created: \(tag.label, privacy: .public) at \(tag.anchorTime, privacy: .public)")
        AccessibilityNotification.Announcement("Tag created: \(tag.label)").post()
    }

    // MARK: - Main Content Area

    private var mainContent: some View {
        VStack(spacing: 0) {
            sessionToolbar
                .padding(DictlySpacing.md)
                .background(DictlyColors.surface)
                .overlay(alignment: .bottom) { Divider() }

            // Task 2.3: Pass audioPlayer to waveform (view-scoped, not @Environment)
            // Story 4.6: Pass onRequestNewTag so right-click opens NewTagForm
            SessionWaveformTimeline(
                session: session,
                selectedTag: $selectedTag,
                audioPlayer: audioPlayer,
                activeCategories: activeCategories,
                onRequestNewTag: { time in
                    guard !isCreatingTag else { return }
                    newTagAnchorTime = time
                    isCreatingTag = true
                }
            )
            .padding(DictlySpacing.md)

            Divider()

            TagDetailPanel(selectedTag: $selectedTag)
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

            // Trailing: action buttons
            HStack(spacing: DictlySpacing.sm) {
                // Story 4.6: Add Tag at Playhead (Cmd+T)
                Button {
                    guard audioPlayer.isLoaded, session.duration > 0, !isCreatingTag else { return }
                    newTagAnchorTime = audioPlayer.currentTime
                    isCreatingTag = true
                } label: {
                    Label("Add Tag", systemImage: "tag")
                }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(!audioPlayer.isLoaded || session.duration == 0)
                .accessibilityLabel("Add tag at current playhead position")
                .help("Add tag at current playhead position (⌘T)")

                Button("Transcribe All") { }
                    .disabled(true)
                    .accessibilityLabel("Transcribe all tags")
                    .help("Transcription available after Whisper integration (Epic 5)")

                Button("Export MD") { }
                    .disabled(true)
                    .accessibilityLabel("Export as Markdown")
                    .help("Markdown export available after export feature (Epic 6)")

                Button("Session Notes") {
                    isShowingSessionNotes = true
                }
                .accessibilityLabel("Edit session notes")
                .help("Add or edit session summary notes")
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
