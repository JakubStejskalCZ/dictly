import SwiftUI
import DictlyTheme

/// Compact real-time audio level visualization shown below the status bar during recording.
/// Renders a horizontal bar chart of audio level samples at ~15 fps.
/// Height: 48pt. Rounded surface container.
struct LiveWaveform: View {
    let isPaused: Bool
    let audioLevel: Float

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Circular buffer of ~60 audio level samples (~4s at 15fps).
    @State private var samples: [Float] = Array(repeating: 0, count: 60)

    var body: some View {
        ZStack {
            TimelineView(
                isPaused
                    ? .animation(minimumInterval: nil, paused: true)
                    : .animation(minimumInterval: 1.0 / 15.0, paused: false)
            ) { context in
                waveformContent
                    .onChange(of: context.date) { _, _ in
                        guard !isPaused else { return }
                        samples.removeFirst()
                        samples.append(audioLevel)
                    }
            }

            if isPaused {
                Text("PAUSED")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
            }
        }
        .frame(height: 48)
        .padding(DictlySpacing.sm)
        .background(DictlyColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel(isPaused ? "Recording is paused." : "Live audio waveform. Recording is active.")
        .accessibilityHidden(false)
    }

    // MARK: - Waveform Bars

    private var waveformContent: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                ForEach(0..<samples.count, id: \.self) { index in
                    let level = samples[index]
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(barColor(for: index))
                        .frame(width: 3)
                        .frame(height: max(2, CGFloat(level) * geometry.size.height))
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.067),
                            value: level
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    // MARK: - Helpers

    private func barColor(for index: Int) -> Color {
        if isPaused {
            return DictlyColors.textSecondary
        }
        let progress = Double(index) / Double(max(1, samples.count - 1))
        return progress > 0.7 ? DictlyColors.recordingActive : DictlyColors.textSecondary
    }
}
