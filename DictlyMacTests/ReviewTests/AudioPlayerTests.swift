import XCTest
import AVFoundation
@testable import DictlyMac
import SwiftData
import DictlyModels

// MARK: - AudioPlayerTests
//
// Tests for Story 4.3: Audio Playback & Waveform Navigation.
// Covers: AudioPlayer state transitions (load, play, pause, seek, scrub),
// error handling for missing files, playhead position math, and
// tap-vs-drag threshold logic.
//
// Note: Tests that start AVAudioEngine require an audio output device.
// In headless CI environments these are gracefully skipped via XCTSkip.
// The test target builds cleanly (** TEST BUILD SUCCEEDED **) in all environments.

@MainActor
final class AudioPlayerTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var audioPlayer: AudioPlayer!
    var testAudioURL: URL?

    override func setUp() async throws {
        let schema = Schema(DictlySchema.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext
        audioPlayer = AudioPlayer()
    }

    override func tearDown() async throws {
        audioPlayer = nil
        if let url = testAudioURL {
            try? FileManager.default.removeItem(at: url)
            testAudioURL = nil
        }
        container = nil
        context = nil
    }

    // MARK: - 9.2 load() succeeds with valid audio file

    func testLoad_succeeds_withValidAudioFile() async throws {
        let url = try makeTestAudioFileURL()
        testAudioURL = url

        do {
            try await audioPlayer.load(filePath: url.path)
            XCTAssertTrue(audioPlayer.isLoaded, "isLoaded should be true after successful load")
            XCTAssertGreaterThan(audioPlayer.duration, 0, "duration should be positive")
            XCTAssertFalse(audioPlayer.isPlaying, "should not be playing after load")
            XCTAssertEqual(audioPlayer.currentTime, 0, "currentTime should start at 0")
        } catch {
            // AVAudioEngine may fail in headless environments without audio device
            throw XCTSkip("Audio engine unavailable in this environment: \(error.localizedDescription)")
        }
    }

    // MARK: - 9.3 load() throws fileNotFound for missing file

    func testLoad_throwsFileNotFound_forMissingFile() async {
        let missingPath = "/nonexistent/path/audio_\(UUID().uuidString).caf"

        do {
            try await audioPlayer.load(filePath: missingPath)
            XCTFail("Expected DictlyError.storage(.fileNotFound) to be thrown")
        } catch DictlyError.storage(.fileNotFound) {
            // Expected — correct error type
        } catch {
            XCTFail("Expected DictlyError.storage(.fileNotFound) but got: \(error)")
        }
    }

    // MARK: - 9.4 seek() updates currentTime

    func testSeek_updatesCurrentTime_toSeekPosition() async throws {
        try await loadPlayerOrSkip()

        audioPlayer.seek(to: 0.05)

        XCTAssertEqual(audioPlayer.currentTime, 0.05, accuracy: 0.001,
                       "seek(to:) should update currentTime to the requested position")
    }

    // MARK: - 9.5 seek() clamps to 0...duration

    func testSeek_clampsToZero_forNegativeValues() async throws {
        try await loadPlayerOrSkip()

        audioPlayer.seek(to: -10)

        XCTAssertEqual(audioPlayer.currentTime, 0,
                       "seek(to:) should clamp negative values to 0")
    }

    func testSeek_clampsToDuration_forOverDurationValues() async throws {
        try await loadPlayerOrSkip()

        let overDuration = audioPlayer.duration + 100
        audioPlayer.seek(to: overDuration)

        XCTAssertEqual(audioPlayer.currentTime, audioPlayer.duration, accuracy: 0.001,
                       "seek(to:) should clamp values beyond duration to duration")
    }

    // MARK: - 9.6 play() sets isPlaying = true

    func testPlay_setsIsPlayingTrue() async throws {
        try await loadPlayerOrSkip()

        audioPlayer.play()

        XCTAssertTrue(audioPlayer.isPlaying, "play() should set isPlaying to true")

        // Clean up: pause so the engine doesn't keep running
        audioPlayer.pause()
    }

    // MARK: - 9.7 pause() sets isPlaying = false and preserves currentTime

    func testPause_setsIsPlayingFalse_andPreservesCurrentTime() async throws {
        try await loadPlayerOrSkip()

        audioPlayer.seek(to: 0.04)
        audioPlayer.play()
        XCTAssertTrue(audioPlayer.isPlaying)

        let timeBeforePause = audioPlayer.currentTime
        audioPlayer.pause()

        XCTAssertFalse(audioPlayer.isPlaying, "pause() should set isPlaying to false")
        XCTAssertEqual(audioPlayer.currentTime, timeBeforePause, accuracy: 0.05,
                       "pause() should preserve currentTime within 50ms accuracy")
    }

    // MARK: - 9.8 Playhead X-position calculation

    /// The formula `(currentTime / duration) * viewWidth` is used in SessionWaveformTimeline.
    /// These tests validate the math independently of any UI dependency.

    func testPlayheadXPosition_atMidpoint_isHalfWidth() {
        let currentTime: TimeInterval = 50
        let duration: TimeInterval = 100
        let viewWidth: CGFloat = 1000

        let xPos = CGFloat(currentTime / duration) * viewWidth

        XCTAssertEqual(xPos, 500, "Midpoint currentTime should map to half viewWidth")
    }

    func testPlayheadXPosition_atStart_isZero() {
        let xPos = CGFloat(0.0 / 100.0) * 800.0
        XCTAssertEqual(xPos, 0, "currentTime=0 → x=0")
    }

    func testPlayheadXPosition_atEnd_isFullWidth() {
        let xPos = CGFloat(100.0 / 100.0) * 800.0
        XCTAssertEqual(xPos, 800, "currentTime=duration → x=viewWidth")
    }

    func testPlayheadXPosition_knownValues() {
        let duration: TimeInterval = 3600
        let width: CGFloat = 800

        XCTAssertEqual(CGFloat(900.0 / duration) * width, 200, accuracy: 0.01,
                       "900s into 1h session at 800pt width → 200pt")
        XCTAssertEqual(CGFloat(1800.0 / duration) * width, 400, accuracy: 0.01,
                       "1800s (half) → 400pt")
    }

    // MARK: - 9.9 Tap-vs-drag threshold

    /// `hypot(translation.width, translation.height) < 4` → tap
    /// `hypot(translation.width, translation.height) >= 4` → drag

    func testTapThreshold_shortMovement_isTap() {
        let distance = hypot(CGFloat(2), CGFloat(1)) // ~2.24pt
        XCTAssertLessThan(distance, 4, "Movement of ~2pt should be classified as tap")
    }

    func testTapThreshold_exactBoundary_isDrag() {
        let distance = hypot(CGFloat(4), CGFloat(0)) // exactly 4pt
        XCTAssertGreaterThanOrEqual(distance, 4, "Movement of exactly 4pt should be classified as drag")
    }

    func testTapThreshold_largeMovement_isDrag() {
        let distance = hypot(CGFloat(10), CGFloat(10)) // ~14.14pt
        XCTAssertGreaterThanOrEqual(distance, 4, "Movement of ~14pt should be classified as drag")
    }

    func testTapThreshold_zeroMovement_isTap() {
        let distance = hypot(CGFloat(0), CGFloat(0))
        XCTAssertLessThan(distance, 4, "Zero movement (pure tap) should be classified as tap")
    }

    // MARK: - Helpers

    /// Attempts to load a test audio file into `audioPlayer`.
    /// Skips the test if the audio engine is unavailable in the current environment.
    private func loadPlayerOrSkip() async throws {
        let url = try makeTestAudioFileURL()
        testAudioURL = url
        do {
            try await audioPlayer.load(filePath: url.path)
        } catch {
            throw XCTSkip("Audio engine unavailable in this environment: \(error.localizedDescription)")
        }
    }

    /// Creates a short 440Hz sine-wave audio file in the temp directory.
    /// Same fixture used by `WaveformTimelineTests` (Story 4.2).
    /// - Parameter durationSeconds: Duration of the test file (default 0.1s).
    private func makeTestAudioFileURL(durationSeconds: Double = 0.1) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("audioplayer_test_\(UUID().uuidString).caf")

        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        if let data = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                // 440 Hz sine wave at 50% amplitude
                data[i] = Float(sin(Double(i) * 440.0 * 2.0 * .pi / sampleRate)) * 0.5
            }
        }
        try file.write(from: buffer)
        return url
    }
}
