import SwiftUI
import DictlyModels
import DictlyTheme

// MARK: - SessionWaveformTimeline

/// Renders the full session audio as a waveform bar chart with color-coded tag markers.
///
/// Two-layer composition:
/// - `Canvas`: waveform bars extracted via `WaveformDataProvider`; animated skeleton while loading
/// - SwiftUI overlay: interactive tag marker shapes (hover tooltip, tap/keyboard select, VoiceOver)
///
/// Replaces `waveformPlaceholder` in `SessionReviewScreen` (Story 4.2).
struct SessionWaveformTimeline: View {

    let session: Session
    @Binding var selectedTag: Tag?

    // MARK: Private State

    @State private var waveformSamples: [Float] = []
    @State private var isLoading: Bool = true
    @State private var viewWidth: CGFloat = 0
    @State private var scrubPosition: CGFloat? = nil
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

                // Layer 3: scrub cursor (always on top)
                if let pos = scrubPosition {
                    scrubCursorView(at: pos, size: geo.size)
                }
            }
            .onAppear { viewWidth = geo.size.width }
            .onChange(of: geo.size.width) { _, new in viewWidth = new }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 120)
        .background(DictlyColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .gesture(scrubGesture)
        .task(id: sampleCount) { await loadWaveform() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session waveform timeline with \(session.tags.count) tag markers")
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
        .opacity(skeletonPulse ? 0.5 : 0.2)
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
                let xPos = (tag.anchorTime / duration) * width
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

    // MARK: - Scrub Cursor

    @ViewBuilder
    private func scrubCursorView(at pos: CGFloat, size: CGSize) -> some View {
        let time = size.width > 0 && session.duration > 0
            ? (pos / size.width) * session.duration
            : 0

        ZStack(alignment: .topLeading) {
            // Vertical line
            Rectangle()
                .fill(DictlyColors.textPrimary.opacity(0.6))
                .frame(width: 2, height: size.height)

            // Floating timestamp above cursor
            Text(formatTimestamp(time))
                .font(DictlyTypography.caption)
                .foregroundStyle(DictlyColors.textPrimary)
                .monospacedDigit()
                .padding(.horizontal, DictlySpacing.xs)
                .padding(.vertical, 2)
                .background(DictlyColors.surface.opacity(0.9))
                .cornerRadius(4)
                .offset(x: 6, y: -20)
        }
        .offset(x: pos - 1)
        .accessibilityLabel("Timeline position: \(formatTimestamp(time))")
    }

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                scrubPosition = min(max(0, value.location.x), viewWidth)
            }
            .onEnded { _ in
                scrubPosition = nil
            }
    }

    // MARK: - Waveform Loading

    private func loadWaveform() async {
        isLoading = true
        waveformSamples = []
        skeletonPulse = false

        guard let path = session.audioFilePath else {
            isLoading = false
            return
        }

        let samples = await WaveformDataProvider().extractSamples(
            from: path,
            sampleCount: sampleCount
        )

        guard !Task.isCancelled else { return }

        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
            waveformSamples = samples
            isLoading = false
        }
    }
}

// MARK: - TagMarkerColumn

/// A single tag marker column: a thin vertical line with a category shape at the top.
///
/// Interactive: hover shows tooltip popover, tap/Enter/Space toggles selection, focusable via Tab.
private struct TagMarkerColumn: View {

    let tag: Tag
    let height: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

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
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
        .popover(
            isPresented: $isHovered,
            attachmentAnchor: .point(.top),
            arrowEdge: .bottom
        ) {
            TagMarkerTooltip(tag: tag, label: label)
        }
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

/// Popover tooltip shown on hover over a tag marker.
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
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(DictlyColors.border, lineWidth: 1)
        }
        .cornerRadius(8)
    }
}
