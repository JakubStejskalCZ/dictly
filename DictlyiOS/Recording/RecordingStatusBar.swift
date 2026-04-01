import SwiftUI
import DictlyTheme

/// Persistent header displayed during recording.
/// Shows animated/static dot, state label ("REC"/"PAUSED"), elapsed timer, and tag count badge.
struct RecordingStatusBar: View {
    let recordingState: RecordingState
    let formattedElapsedTime: String
    let tagCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dotPulse = false

    var body: some View {
        HStack(spacing: DictlySpacing.sm) {
            recordingDot
                .onAppear { updateDotAnimation(for: recordingState) }
                .onChange(of: recordingState) { _, newState in
                    updateDotAnimation(for: newState)
                }

            Text(stateLabel)
                .font(DictlyTypography.caption)
                .foregroundStyle(stateColor)

            Spacer()

            Text(formattedElapsedTime)
                .font(.system(size: 28, weight: .bold).monospacedDigit())
                .foregroundStyle(DictlyColors.textPrimary)

            tagCountBadge
        }
        .padding(.horizontal, DictlySpacing.md)
        .padding(.vertical, DictlySpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Subviews

    private var recordingDot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 10, height: 10)
            .scaleEffect(dotPulse ? 1.3 : 1.0)
            .opacity(dotPulse ? 0.6 : 1.0)
            .animation(
                dotPulse ? DictlyAnimation.recordingBreath(reduceMotion: reduceMotion) : .default,
                value: dotPulse
            )
    }

    private var tagCountBadge: some View {
        Text("\(tagCount) tags")
            .font(DictlyTypography.caption)
            .foregroundStyle(DictlyColors.textPrimary)
            .padding(.horizontal, DictlySpacing.sm)
            .padding(.vertical, DictlySpacing.xs)
            .background(DictlyColors.surface)
            .clipShape(Capsule())
    }

    // MARK: - Animation

    private func updateDotAnimation(for state: RecordingState) {
        if state == .recording {
            withAnimation(DictlyAnimation.recordingBreath(reduceMotion: reduceMotion)) {
                dotPulse = true
            }
        } else {
            withAnimation(.default) {
                dotPulse = false
            }
        }
    }

    // MARK: - Helpers

    private var stateLabel: String {
        switch recordingState {
        case .recording: return "REC"
        case .paused, .systemInterrupted: return "PAUSED"
        }
    }

    private var dotColor: Color {
        switch recordingState {
        case .recording: return DictlyColors.recordingActive
        case .paused, .systemInterrupted: return DictlyColors.warning
        }
    }

    private var stateColor: Color {
        switch recordingState {
        case .recording: return DictlyColors.recordingActive
        case .paused, .systemInterrupted: return DictlyColors.warning
        }
    }

    private var accessibilityLabel: String {
        switch recordingState {
        case .recording:
            return "Recording. \(formattedElapsedTime). \(tagCount) tags placed."
        case .paused, .systemInterrupted:
            return "Paused. \(formattedElapsedTime). \(tagCount) tags placed."
        }
    }
}
