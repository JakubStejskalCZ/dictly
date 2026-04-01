import Observation
import OSLog

private let logger = Logger(subsystem: "com.dictly.ios", category: "recording")

// MARK: - RecordingState

/// Represents the current recording UI state derived from SessionRecorder properties.
enum RecordingState: Equatable {
    /// Audio is actively being recorded — dot pulses, timer increments.
    case recording
    /// Recording paused by user — dot is static yellow, timer frozen.
    case paused
    /// Recording paused by system (phone call, alarm) — shows interruption banner.
    case systemInterrupted
}

// MARK: - RecordingViewModel

/// `@Observable @MainActor` class that bridges `SessionRecorder` state to
/// UI-specific formatting and logic for `RecordingScreen`.
@Observable @MainActor
final class RecordingViewModel {

    // MARK: - Properties

    private let sessionRecorder: SessionRecorder

    init(sessionRecorder: SessionRecorder) {
        self.sessionRecorder = sessionRecorder
    }

    // MARK: - Computed Properties

    /// Elapsed time formatted as "H:MM:SS".
    var formattedElapsedTime: String {
        RecordingViewModel.formatDuration(sessionRecorder.elapsedTime)
    }

    /// Derived recording state from `SessionRecorder` properties.
    var recordingState: RecordingState {
        RecordingViewModel.deriveState(
            isPaused: sessionRecorder.isPaused,
            wasInterruptedBySystem: sessionRecorder.wasInterruptedBySystem
        )
    }

    /// Whether the recorder is actively recording (not stopped).
    var isRecording: Bool { sessionRecorder.isRecording }

    /// Set to `true` once `stopRecording()` completes. RecordingScreen observes this to present the summary sheet.
    var didStopRecording = false

    /// Pure state derivation — exposed for unit testing.
    static func deriveState(isPaused: Bool, wasInterruptedBySystem: Bool) -> RecordingState {
        if isPaused && wasInterruptedBySystem { return .systemInterrupted }
        if isPaused { return .paused }
        return .recording
    }

    // MARK: - Methods

    /// Toggles between pause and resume based on current recording state.
    func togglePause() {
        switch recordingState {
        case .recording:
            sessionRecorder.pauseRecording()
        case .paused:
            sessionRecorder.resumeRecording()
        case .systemInterrupted:
            break
        }
    }

    /// Resumes recording after a system interruption (phone call).
    func resumeFromInterruption() {
        sessionRecorder.resumeRecording()
    }

    /// Stops the active recording and signals the UI to show the session summary.
    func stopRecording() {
        sessionRecorder.stopRecording()
        didStopRecording = true
    }

    // MARK: - Formatting

    /// Formats a `TimeInterval` as `"H:MM:SS"`.
    static func formatDuration(_ timeInterval: TimeInterval) -> String {
        guard timeInterval.isFinite else { return "0:00:00" }
        let total = max(0, Int(timeInterval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
    }
}
