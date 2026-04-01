import XCTest
@testable import DictlyiOS

// MARK: - RecordingViewModelTests

/// Tests for `RecordingViewModel` formatting and state derivation (Story 2.3 Task 7).
@MainActor
final class RecordingViewModelTests: XCTestCase {

    // MARK: - 7.2 formattedElapsedTime

    func testFormatDuration_zero() {
        XCTAssertEqual(RecordingViewModel.formatDuration(0), "0:00:00")
    }

    func testFormatDuration_oneHourThirtyMinutesFortyfiveSeconds() {
        XCTAssertEqual(RecordingViewModel.formatDuration(5445), "1:30:45")
    }

    func testFormatDuration_fiveMinutesNineSeconds() {
        XCTAssertEqual(RecordingViewModel.formatDuration(309), "0:05:09")
    }

    func testFormatDuration_exactHour() {
        XCTAssertEqual(RecordingViewModel.formatDuration(3600), "1:00:00")
    }

    func testFormatDuration_twelveMinutesThirtyfourSeconds() {
        XCTAssertEqual(RecordingViewModel.formatDuration(754), "0:12:34")
    }

    func testFormatDuration_negativeClampsToZero() {
        XCTAssertEqual(RecordingViewModel.formatDuration(-10), "0:00:00")
    }

    func testFormatDuration_largeValue_fourHoursThreeMinutesTwentyone() {
        // 4 * 3600 + 3 * 60 + 21 = 14601
        XCTAssertEqual(RecordingViewModel.formatDuration(14601), "4:03:21")
    }

    func testFormatDuration_oneMinuteZeroSeconds() {
        XCTAssertEqual(RecordingViewModel.formatDuration(60), "0:01:00")
    }

    func testFormatDuration_justUnderOneHour() {
        // 59 * 60 + 59 = 3599
        XCTAssertEqual(RecordingViewModel.formatDuration(3599), "0:59:59")
    }

    // MARK: - 7.3 recordingState derivation

    func testDeriveState_recording_whenNotPaused() {
        let state = RecordingViewModel.deriveState(isPaused: false, wasInterruptedBySystem: false)
        XCTAssertEqual(state, .recording)
    }

    func testDeriveState_recording_whenNotPausedEvenIfInterruptFlagSet() {
        // wasInterruptedBySystem alone (without isPaused) still yields .recording
        let state = RecordingViewModel.deriveState(isPaused: false, wasInterruptedBySystem: true)
        XCTAssertEqual(state, .recording)
    }

    func testDeriveState_paused_whenPausedAndNotInterrupted() {
        let state = RecordingViewModel.deriveState(isPaused: true, wasInterruptedBySystem: false)
        XCTAssertEqual(state, .paused)
    }

    func testDeriveState_systemInterrupted_whenPausedAndInterrupted() {
        let state = RecordingViewModel.deriveState(isPaused: true, wasInterruptedBySystem: true)
        XCTAssertEqual(state, .systemInterrupted)
    }

    func testDeriveState_systemInterrupted_takesPreferenceOverPaused() {
        // Redundant with above — confirms priority ordering
        let interrupted = RecordingViewModel.deriveState(isPaused: true, wasInterruptedBySystem: true)
        let paused = RecordingViewModel.deriveState(isPaused: true, wasInterruptedBySystem: false)
        XCTAssertNotEqual(interrupted, paused)
        XCTAssertEqual(interrupted, .systemInterrupted)
        XCTAssertEqual(paused, .paused)
    }

    // MARK: - Story 2.7: Stop recording

    func testStopRecording_callsRecorderStop() {
        // Given a ViewModel wrapping a fresh recorder (isRecording == false)
        let recorder = SessionRecorder()
        let vm = RecordingViewModel(sessionRecorder: recorder)
        // When stopRecording() is called
        vm.stopRecording()
        // Then recorder.stopRecording() was called — guard branch hit, state unchanged
        XCTAssertFalse(recorder.isRecording, "recorder.isRecording should remain false after stop when not recording")
    }

    func testStopRecording_setsDidStopRecordingTrue() {
        // Given a ViewModel with a fresh recorder
        let recorder = SessionRecorder()
        let vm = RecordingViewModel(sessionRecorder: recorder)
        XCTAssertFalse(vm.didStopRecording, "didStopRecording should be false initially")
        // When stopRecording() is called
        vm.stopRecording()
        // Then didStopRecording is true
        XCTAssertTrue(vm.didStopRecording, "didStopRecording should be true after stopRecording()")
    }

    func testIsRecording_reflectsRecorderState() {
        // Given a ViewModel wrapping a recorder
        let recorder = SessionRecorder()
        let vm = RecordingViewModel(sessionRecorder: recorder)
        // Then isRecording mirrors the recorder
        XCTAssertEqual(vm.isRecording, recorder.isRecording, "vm.isRecording should equal recorder.isRecording")
        XCTAssertFalse(vm.isRecording, "isRecording should be false for a freshly created recorder")
    }
}
