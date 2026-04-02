import SwiftUI
import DictlyModels
import DictlyTheme

// MARK: - SessionWaveformTimeline

/// Renders the full session audio as a waveform bar chart with color-coded tag markers,
/// a draggable playhead, and audio playback interaction (tap-to-play, drag-to-scrub).
///
/// Four-layer composition:
/// - `Canvas`: waveform bars extracted via `WaveformDataProvider`; animated skeleton while loading
/// - SwiftUI overlay: interactive tag marker shapes (hover tooltip, tap/keyboard select, VoiceOver)
/// - SwiftUI overlay: persistent playhead (white line + diamond cap) driven by `audioPlayer.currentTime`
///
/// Replaces `waveformPlaceholder` in `SessionReviewScreen` (Story 4.2).
/// Audio playback integration added in Story 4.3.
struct SessionWaveformTimeline: View {

    let session: Session
    @Binding var selectedTag: Tag?

    /// View-scoped audio player passed from `SessionReviewScreen`.
    /// Not injected via `@Environment` — `AudioPlayer` is session-scoped, not app-wide.
    let audioPlayer: AudioPlayer

    // MARK: Private State

    @State private var waveformSamples: [Float] = []
    @State private var isLoading: Bool = true
    @State private var viewWidth: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var dragPosition: CGFloat? = nil
    @State private var lastScrubDate: Date = .distantPast
    @State private var skeletonPulse: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Derived

    /// Target number of bars: ~2pt bar + 1pt gap = 3pt per bar.
    private var sampleCount: Int { max(100, Int(viewWidth / 3)) }

    private var sortedTags: [Tag] { session.tags.sorted { $0.anchorTime < $1.anchorTime } }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Layer 0: background
                Color.clear

                // Layer 1: waveform / skeleton / no-audio
                if session.audioFilePath == nil {
                    noAudioView
                } else if isLoading {
                    skeletonCanvas
                        .transition(.opacity)
                } else if waveformSamples.isEmpty {
                    noAudioView  // file exists but couldn't be read
                } else {
                    waveformCanvas
                        .transition(.opacity)
                }

                // Layer 2: tag markers (only once waveform is loaded)
                if !isLoading, !waveformSamples.isEmpty, session.duration > 0 {
                    tagMarkersLayer(in: geo.size)
                }

                // Layer 3: persistent playhead (Task 4 — replaces scrub cursor)
                if let xPos = playheadX(in: geo.size) {
                    playheadView(at: xPos, in: geo.size)
                }
            }
            .onAppear { viewWidth = geo.size.width }
            .onChange(of: geo.size.width) { _, new in viewWidth = new }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 120)
        .background(DictlyColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .gesture(waveformGesture)
        // Task 7: Keyboard shortcuts — only fires when waveform has focus
        .focusable()
        .onKeyPress(.space) {
            if audioPlayer.isPlaying {
                audioPlayer.pause()
            } else {
                audioPlayer.play()
            }
            return .handled
        }
        .onKeyPress(.leftArrow) {
            let newTime = max(0, audioPlayer.currentTime - 5)
            audioPlayer.seek(to: newTime)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            let newTime = min(audioPlayer.duration, audioPlayer.currentTime + 5)
            audioPlayer.seek(to: newTime)
            return .handled
        }
        .task(id: sampleCount) { await loadWaveform() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session waveform timeline with \(session.tags.count) tag markers")
        // Task 8.3: VoiceOver custom action for play/pause
        .accessibilityAction(named: "Play/Pause") {
            audioPlayer.isPlaying ? audioPlayer.pause() : audioPlayer.play()
        }
    }

    // MARK: - Playhead Position (Tasks 4.3, 6.1)

    /// Computes the X position (in points) where the playhead should be rendered.
    /// During drag: uses `dragPosition`. Otherwise: derived from `audioPlayer.currentTime`.
    private func playheadX(in size: CGSize) -> CGFloat? {
        if isDragging, let pos = dragPosition {
            return min(max(0, pos), size.width)
        }
        guard audioPlayer.isLoaded, session.duration > 0, size.width > 0 else { return nil }
        return CGFloat(audioPlayer.currentTime / session.duration) * size.width
    }

    // MARK: - Playhead View (Tasks 4.2, 4.5, 8.2, 8.5)

    /// Returns the display time for the playhead label: drag position during drag, currentTime otherwise.
    private func playheadDisplayTime(in size: CGSize) -> TimeInterval {
        if isDragging, let pos = dragPosition, session.duration > 0, size.width > 0 {
            return (Double(pos) / Double(size.width)) * session.duration
        }
        return audioPlayer.currentTime
    }

    @ViewBuilder
    private func playheadView(at xPos: CGFloat, in size: CGSize) -> some View {
        let time = playheadDisplayTime(in: size)
        let labelXOffset: CGFloat = xPos > size.width - 60 ? -56 : 6

        ZStack(alignment: .topLeading) {
            // Task 4.2: Vertical white line (2pt, textPrimary)
            Rectangle()
                .fill(DictlyColors.textPrimary)
                .frame(width: 2, height: size.height)

            // Task 4.2: Diamond cap (8pt, filled white) at top of line
            // Centered on the 2pt line: offset x by -(8-2)/2 = -3, y by -4 (centers diamond on top edge)
            PlayheadDiamond()
                .fill(DictlyColors.textPrimary)
                .frame(width: 8, height: 8)
                .offset(x: -3, y: -4)

            // Task 4.5: Floating timestamp label above playhead
            Text(formatTimestamp(time))
                .font(DictlyTypography.caption)
                .foregroundStyle(DictlyColors.textPrimary)
                .monospacedDigit()
                .padding(.horizontal, DictlySpacing.xs)
                .padding(.vertical, 2)
                .background(DictlyColors.surface.opacity(0.9))
                .cornerRadius(4)
                .offset(x: labelXOffset, y: -20)
        }
        .offset(x: xPos - 1) // Center the 2pt line at xPos
        // Task 8.2: Accessibility value for playhead position
        .accessibilityValue("Playback position: \(formatTimestamp(time))")
        .accessibilityLabel("Playhead")
        .accessibilityHidden(false)
    }

    // MARK: - Waveform Gesture (Tasks 5, 6)

    /// Unified gesture that distinguishes taps (< 4pt movement) from drags (≥ 4pt).
    ///
    /// - Tap: seek to tapped time + play (Task 5.1, 5.2)
    /// - Drag: update playhead visually + throttled scrub preview (Task 6.1, 6.2)
    /// - Drag end: seek to final position, no auto-play (Task 6.3)
    private var waveformGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let distance = hypot(value.translation.width, value.translation.height)
                // Task 5.4: distance < 4pt = tap; >= 4pt = drag
                if distance >= 4 {
                    isDragging = true
                    let pos = min(max(0, value.location.x), viewWidth)
                    dragPosition = pos
                    // Task 6.2: Throttle scrub calls to ~10Hz
                    let dragTime = (Double(pos) / Double(max(1, viewWidth))) * session.duration
                    throttledScrub(to: dragTime)
                }
            }
            .onEnded { value in
                let distance = hypot(value.translation.width, value.translation.height)
                if distance < 4 {
                    // Task 5.1, 5.2: TAP — seek + play
                    let tappedTime = (Double(value.location.x) / Double(max(1, viewWidth))) * session.duration
                    audioPlayer.seek(to: tappedTime)
                    audioPlayer.play()
                } else {
                    // Task 6.3: DRAG END — seek only, no auto-play
                    let finalTime = (Double(value.location.x) / Double(max(1, viewWidth))) * session.duration
                    audioPlayer.seek(to: finalTime)
                }
                isDragging = false
                dragPosition = nil
            }
    }

    /// Throttles `audioPlayer.scrub(to:)` to ~10 calls/sec to avoid audio glitching.
    private func throttledScrub(to time: TimeInterval) {
        let now = Date()
        guard now.timeIntervalSince(lastScrubDate) > 0.1 else { return }
        lastScrubDate = now
        audioPlayer.scrub(to: time)
    }

    // MARK: - No Audio

    private var noAudioView: some View {
        Text("No audio file available")
            .font(DictlyTypography.body)
            .foregroundStyle(DictlyColors.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Skeleton Canvas (loading state)

    private var skeletonCanvas: some View {
        Canvas { context, size in
            let count = max(50, sampleCount)
            let barWidth = max(1, size.width / CGFloat(count) - 1)

            for i in 0..<count {
                let amplitude = skeletonBarAmplitude(index: i, count: count)
                let barHeight = max(2, amplitude * size.height)
                let x = CGFloat(i) * (barWidth + 1)
                let y = (size.height - barHeight) / 2
                context.fill(
                    Path(roundedRect: CGRect(x: x, y: y, width: barWidth, height: barHeight),
                         cornerRadius: 1),
                    with: .color(DictlyColors.textSecondary)
                )
            }
        }
        .opacity(skeletonPulse ? 0.4 : 0.2)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
            value: skeletonPulse
        )
        .onAppear { skeletonPulse = !reduceMotion }
        .accessibilityHidden(true)
    }

    /// Deterministic pseudo-random amplitude for skeleton bars — same heights on every render.
    private func skeletonBarAmplitude(index: Int, count: Int) -> CGFloat {
        let t = Double(index) / Double(max(1, count))
        return CGFloat(0.1 + 0.7 * abs(sin(t * 47.3 + 1.7)) * abs(cos(t * 17.8 + 0.5)))
    }

    // MARK: - Waveform Canvas

    private var waveformCanvas: some View {
        Canvas { context, size in
            let samples = waveformSamples
            guard !samples.isEmpty else { return }
            let barWidth = max(1, size.width / CGFloat(samples.count) - 1)

            for (i, amplitude) in samples.enumerated() {
                let barHeight = max(2, CGFloat(amplitude) * size.height)
                let x = CGFloat(i) * (barWidth + 1)
                let y = (size.height - barHeight) / 2
                context.fill(
                    Path(roundedRect: CGRect(x: x, y: y, width: barWidth, height: barHeight),
                         cornerRadius: 1),
                    with: .color(DictlyColors.textSecondary.opacity(0.4))
                )
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Tag Markers Layer

    @ViewBuilder
    private func tagMarkersLayer(in size: CGSize) -> some View {
        let tags = sortedTags
        let duration = session.duration
        let width = size.width

        ZStack(alignment: .topLeading) {
            ForEach(tags, id: \.uuid) { tag in
                let xPos = min(max(0, (tag.anchorTime / duration) * width), width)
                TagMarkerColumn(
                    tag: tag,
                    height: size.height,
                    isSelected: selectedTag?.uuid == tag.uuid,
                    onSelect: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedTag?.uuid == tag.uuid {
                                selectedTag = nil
                            } else {
                                selectedTag = tag
                            }
                        }
                    }
                )
                .frame(width: 20, alignment: .center)
                .offset(x: xPos - 10)
            }
        }
        .frame(width: width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(true)
    }

    // MARK: - Waveform Loading

    private func loadWaveform() async {
        isLoading = true
        waveformSamples = []
        skeletonPulse = !reduceMotion

        guard let path = session.audioFilePath else {
            isLoading = false
            return
        }

        let samples = await WaveformDataProvider().extractSamples(
            from: path,
            sampleCount: sampleCount
        )

        guard !Task.isCancelled else {
            isLoading = false
            return
        }

        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
            waveformSamples = samples
            isLoading = false
        }
    }
}

// MARK: - PlayheadDiamond

/// Diamond shape used as the playhead cap marker (8pt). Per UX-DR7.
private struct PlayheadDiamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

// MARK: - TagMarkerColumn

/// A single tag marker column: a thin vertical line with a category shape at the top.
///
/// Interactive: hover shows tooltip overlay, tap/Enter/Space toggles selection, focusable via Tab.
private struct TagMarkerColumn: View {

    let tag: Tag
    let height: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false
    @State private var showTooltip = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        let color = categoryColor(for: tag.categoryName)
        let shape = MarkerShape.shape(for: tag.categoryName)
        let label = tag.label.isEmpty ? "Untitled Tag" : tag.label

        ZStack(alignment: .top) {
            // Vertical indicator line — full column height, 30% opacity
            Rectangle()
                .fill(color.opacity(0.3))
                .frame(width: 1, height: height)

            // Category shape with optional selection ring
            ZStack {
                TagMarkerShapeView(shape: shape, color: color, size: 8)
                    .opacity(isSelected ? 1.0 : 0.75)

                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 12, height: 12)
                    Circle()
                        .stroke(color, lineWidth: 1)
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.top, 4)
        }
        .frame(width: 20, height: height)
        .contentShape(Rectangle())
        .overlay(alignment: .top) {
            if showTooltip {
                TagMarkerTooltip(tag: tag, label: label)
                    .fixedSize()
                    .offset(y: -60)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .onHover { hovering in
            isHovered = hovering
            hoverTask?.cancel()
            if hovering {
                hoverTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.15)) { showTooltip = true }
                }
            } else {
                withAnimation(.easeInOut(duration: 0.15)) { showTooltip = false }
            }
        }
        .onTapGesture { onSelect() }
        .focusable()
        .onKeyPress(.space) { onSelect(); return .handled }
        .onKeyPress(.return) { onSelect(); return .handled }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(tag.categoryName): \(label) at \(formatTimestamp(tag.anchorTime))"
        )
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - TagMarkerTooltip

/// Overlay tooltip shown on hover over a tag marker.
private struct TagMarkerTooltip: View {

    let tag: Tag
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: DictlySpacing.xs) {
            Text(label)
                .font(DictlyTypography.tagLabel)
                .bold()
                .foregroundStyle(DictlyColors.textPrimary)
            Text(tag.categoryName)
                .font(DictlyTypography.caption)
                .foregroundStyle(DictlyColors.textSecondary)
            Text(formatTimestamp(tag.anchorTime))
                .font(DictlyTypography.caption)
                .foregroundStyle(DictlyColors.textSecondary)
                .monospacedDigit()
        }
        .padding(DictlySpacing.sm)
        .background(DictlyColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(DictlyColors.border, lineWidth: 1)
        }
    }
}
