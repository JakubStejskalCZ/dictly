import Foundation
import AVFoundation
import os

/// Extracts normalized waveform amplitude samples from an audio file.
///
/// Reads audio in chunks to bound memory — even a 4-hour session at 64kbps stays
/// within a few MB of peak memory instead of loading ~1.3GB at once.
struct WaveformDataProvider {

    private static let logger = Logger(subsystem: "com.dictly.mac", category: "waveform")

    /// Extracts normalized amplitude samples on a `.userInitiated` background task.
    ///
    /// - Parameters:
    ///   - audioFilePath: Absolute path to the audio file on disk.
    ///   - sampleCount: Target number of amplitude bars to produce.
    /// - Returns: Array of `sampleCount` normalized amplitudes (0.0–1.0),
    ///            or empty on error or missing file.
    func extractSamples(from audioFilePath: String, sampleCount: Int) async -> [Float] {
        let path = audioFilePath
        let count = max(1, sampleCount)
        return await Task.detached(priority: .userInitiated) {
            Self.extractSync(from: path, sampleCount: count)
        }.value
    }

    // MARK: - Private Extraction

    private static func extractSync(from audioFilePath: String, sampleCount: Int) -> [Float] {
        guard FileManager.default.fileExists(atPath: audioFilePath) else {
            logger.error("Audio file not found at path: \(audioFilePath, privacy: .sensitive)")
            return []
        }
        let url = URL(fileURLWithPath: audioFilePath)
        do {
            let audioFile = try AVAudioFile(forReading: url)
            return extractFromFile(audioFile, sampleCount: sampleCount)
        } catch {
            logger.error("Failed to open audio file: \(error.localizedDescription)")
            return []
        }
    }

    private static func extractFromFile(_ audioFile: AVAudioFile, sampleCount: Int) -> [Float] {
        let format = audioFile.processingFormat
        let totalFrames = Int(audioFile.length)
        guard totalFrames > 0 else { return [] }

        let framesPerSample = max(1, totalFrames / sampleCount)
        // Read in reasonably-sized chunks to avoid a single giant allocation
        let chunkFrames = min(65536, framesPerSample * 32)

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(chunkFrames)
        ) else {
            logger.error("Failed to allocate AVAudioPCMBuffer")
            return []
        }

        var samples = [Float]()
        samples.reserveCapacity(sampleCount)

        var samplesCollected = 0
        var maxInCurrentSample: Float = 0
        var framesInCurrentSample = 0

        audioFile.framePosition = 0

        do {
            while audioFile.framePosition < audioFile.length, samplesCollected < sampleCount {
                let remaining = Int(audioFile.length - audioFile.framePosition)
                let toRead = min(chunkFrames, remaining)
                try audioFile.read(into: buffer, frameCount: AVAudioFrameCount(toRead))

                guard let channelData = buffer.floatChannelData?[0] else { break }
                let framesRead = Int(buffer.frameLength)
                guard framesRead > 0 else { break }

                for i in 0..<framesRead {
                    maxInCurrentSample = max(maxInCurrentSample, abs(channelData[i]))
                    framesInCurrentSample += 1

                    if framesInCurrentSample >= framesPerSample, samplesCollected < sampleCount {
                        samples.append(maxInCurrentSample)
                        samplesCollected += 1
                        maxInCurrentSample = 0
                        framesInCurrentSample = 0
                    }
                }
            }
        } catch {
            logger.error("Error reading audio frames: \(error.localizedDescription)")
        }

        // Capture any remaining frames as the final sample
        if framesInCurrentSample > 0, samplesCollected < sampleCount {
            samples.append(maxInCurrentSample)
        }

        // Pad to exactly sampleCount if we got fewer (short file or read error)
        while samples.count < sampleCount { samples.append(0) }

        // Normalize amplitudes to 0.0–1.0
        let peak = samples.max() ?? 0
        if peak > 0 { samples = samples.map { $0 / peak } }

        return samples
    }
}
