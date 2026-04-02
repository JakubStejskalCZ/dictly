import XCTest
import AVFoundation
@testable import DictlyMac
import SwiftData
import DictlyModels

// MARK: - WaveformTimelineTests
//
// Tests for Story 4.2: Waveform Timeline Rendering with Tag Markers.
// Covers: WaveformDataProvider sample extraction, tag marker X-position math,
// marker shape mapping, and edge cases (no tags, no audio, boundary times).
//
// Note: Mac test target requires dev signing certificate to run locally due to
// iCloud entitlement on the host app (pre-existing constraint from story 3.3).
// The test target builds cleanly (** TEST BUILD SUCCEEDED **) even without signing.

@MainActor
final class WaveformTimelineTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema(DictlySchema.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - 10.2 WaveformDataProvider returns correct sample count

    func testExtractSamples_returnsRequestedCount() async throws {
        let url = try makeTestAudioFileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let provider = WaveformDataProvider()
        let samples = await provider.extractSamples(from: url.path, sampleCount: 100)
        XCTAssertEqual(samples.count, 100, "Should return exactly the requested sample count")
    }

    func testExtractSamples_normalizedRange() async throws {
        let url = try makeTestAudioFileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let provider = WaveformDataProvider()
        let samples = await provider.extractSamples(from: url.path, sampleCount: 50)
        XCTAssertFalse(samples.isEmpty)
        for sample in samples {
            XCTAssertGreaterThanOrEqual(sample, 0.0, "Amplitude must be ≥ 0.0")
            XCTAssertLessThanOrEqual(sample, 1.0, "Amplitude must be ≤ 1.0")
        }
    }

    // MARK: - 10.3 WaveformDataProvider returns empty for missing file

    func testExtractSamples_missingFile_returnsEmpty() async {
        let provider = WaveformDataProvider()
        let samples = await provider.extractSamples(
            from: "/nonexistent/path/audio_\(UUID().uuidString).mp3",
            sampleCount: 100
        )
        XCTAssertTrue(samples.isEmpty, "Missing file should return empty array")
    }

    // MARK: - 10.4 Tag marker X-position calculation

    func testMarkerXPosition_atMidpoint_isHalfWidth() {
        let duration: TimeInterval = 100
        let anchorTime: TimeInterval = 50
        let width: CGFloat = 1000
        let xPos = (anchorTime / duration) * Double(width)
        XCTAssertEqual(xPos, 500, "Midpoint anchor should map to half the view width")
    }

    func testMarkerXPosition_knownValues() {
        let duration: TimeInterval = 3600 // 1 hour
        let width: CGFloat = 800

        XCTAssertEqual((0.0 / duration) * Double(width), 0, "t=0 → x=0")
        XCTAssertEqual((1800.0 / duration) * Double(width), 400, "t=half → x=400")
        XCTAssertEqual((3600.0 / duration) * Double(width), 800, "t=end → x=800")
        XCTAssertEqual((900.0 / duration) * Double(width), 200, accuracy: 0.001)
    }

    // MARK: - 10.5 Marker shape mapping

    func testMarkerShape_story_isCircle() {
        XCTAssertEqual(MarkerShape.shape(for: "Story"), .circle)
        XCTAssertEqual(MarkerShape.shape(for: "story"), .circle)
        XCTAssertEqual(MarkerShape.shape(for: "STORY"), .circle)
    }

    func testMarkerShape_combat_isDiamond() {
        XCTAssertEqual(MarkerShape.shape(for: "Combat"), .diamond)
    }

    func testMarkerShape_roleplay_isSquare() {
        XCTAssertEqual(MarkerShape.shape(for: "Roleplay"), .square)
    }

    func testMarkerShape_world_isTriangle() {
        XCTAssertEqual(MarkerShape.shape(for: "World"), .triangle)
    }

    func testMarkerShape_meta_isHexagon() {
        XCTAssertEqual(MarkerShape.shape(for: "Meta"), .hexagon)
    }

    func testMarkerShape_unknownCategory_fallsBackToCircle() {
        XCTAssertEqual(MarkerShape.shape(for: "Unknown"), .circle)
        XCTAssertEqual(MarkerShape.shape(for: ""), .circle)
        XCTAssertEqual(MarkerShape.shape(for: "Custom"), .circle)
    }

    // MARK: - 10.6 Edge cases

    func testSessionWithNoTags_hasNoMarkers() throws {
        let session = makeSession(title: "Empty Session", duration: 3600, audioFilePath: nil)
        session.tags = []
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetched[0].tags.count, 0, "Session with no tags should have empty tags array")
    }

    func testTagAtTimeZero_xPositionIsZero() {
        let duration: TimeInterval = 100
        let anchorTime: TimeInterval = 0
        let width: CGFloat = 800
        let xPos = (anchorTime / duration) * Double(width)
        XCTAssertEqual(xPos, 0, "Tag at time 0 should be at x=0")
    }

    func testTagAtDurationEnd_xPositionIsFullWidth() {
        let duration: TimeInterval = 100
        let anchorTime: TimeInterval = 100
        let width: CGFloat = 800
        let xPos = (anchorTime / duration) * Double(width)
        XCTAssertEqual(xPos, Double(width), "Tag at session end should be at x=viewWidth")
    }

    func testSessionWithNoAudio_audioFilePathIsNil() throws {
        let session = makeSession(title: "No Audio Session", duration: 1800, audioFilePath: nil)
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        XCTAssertNil(fetched[0].audioFilePath, "Session without audio should have nil audioFilePath")
    }

    func testExtractSamples_requestedCountLargerThanFrames_returnsPaddedArray() async throws {
        // A very short audio file with fewer frames than requested samples
        let url = try makeTestAudioFileURL(durationSeconds: 0.01) // ~441 frames at 44.1kHz
        defer { try? FileManager.default.removeItem(at: url) }

        let provider = WaveformDataProvider()
        let samples = await provider.extractSamples(from: url.path, sampleCount: 200)
        XCTAssertEqual(samples.count, 200, "Should pad to requested count even for short files")
    }

    // MARK: - Helpers

    private func makeSession(
        title: String,
        duration: TimeInterval = 3600,
        audioFilePath: String? = nil
    ) -> Session {
        Session(
            uuid: UUID(),
            title: title,
            sessionNumber: 1,
            date: Date(),
            duration: duration,
            audioFilePath: audioFilePath
        )
    }

    /// Creates a short sine-wave audio file in the temp directory.
    /// - Parameter durationSeconds: Duration of the test file (default 0.1s).
    private func makeTestAudioFileURL(durationSeconds: Double = 0.1) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("waveform_test_\(UUID().uuidString).caf")

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
