import Foundation
import AVFoundation
import Observation
import os.log
import DictlyModels

private let logger = Logger(subsystem: "com.dictly.mac", category: "transcription")

@Observable
final class WhisperBridge {

    private var context: OpaquePointer?
    private var loadedModelURL: URL?
    private let modelLock = NSLock()

    init() {
        logger.debug("WhisperBridge initialized")
    }

    deinit {
        if let ctx = context {
            whisper_free(ctx)
            logger.debug("WhisperBridge: freed whisper context")
        }
    }

    // MARK: - Model Loading

    func loadModel(at modelURL: URL) throws {
        _ = try loadContext(for: modelURL)
    }

    func unloadModel() {
        modelLock.lock()
        defer { modelLock.unlock() }
        if let ctx = context {
            whisper_free(ctx)
            context = nil
            loadedModelURL = nil
            logger.info("WhisperBridge: model unloaded")
        }
    }

    // MARK: - Transcription

    func transcribe(audioURL: URL, modelURL: URL) async throws -> String {
        assert(!Thread.isMainThread, "WhisperBridge.transcribe must not run on the main thread")

        logger.info("WhisperBridge: starting transcription of \(audioURL.lastPathComponent)")

        // Load model if needed, returns the context pointer under lock
        let ctx = try loadContext(for: modelURL)

        // Convert audio to 16kHz mono PCM Float32
        let samples = try convertToPCM(audioURL: audioURL)
        logger.debug("WhisperBridge: converted audio — \(samples.count) samples at 16kHz")

        // Guard against empty audio (e.g. zero-length file)
        guard !samples.isEmpty else {
            logger.info("WhisperBridge: audio produced no samples — returning empty transcription")
            return ""
        }

        // Configure transcription params
        // Note: whisper_full_default_params already sets language = "en"; no withCString needed.
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = Int32(min(ProcessInfo.processInfo.activeProcessorCount, 8))
        params.translate = false
        params.print_timestamps = false
        params.print_progress = false
        params.print_special = false
        params.no_timestamps = true

        logger.debug("WhisperBridge: running whisper_full with \(params.n_threads) threads")

        // Run transcription (blocking — caller is already on background thread via async context)
        let result = samples.withUnsafeBufferPointer { buffer -> Int32 in
            whisper_full(ctx, params, buffer.baseAddress, Int32(buffer.count))
        }

        guard result == 0 else {
            logger.error("WhisperBridge: whisper_full returned error code \(result)")
            throw DictlyError.transcription(.processingFailed)
        }

        // Collect segments
        let segmentCount = whisper_full_n_segments(ctx)
        var transcription = ""
        for i in 0..<segmentCount {
            if let text = whisper_full_get_segment_text(ctx, i) {
                transcription += String(cString: text)
            }
        }

        logger.info("WhisperBridge: transcription complete — \(transcription.count) characters, \(segmentCount) segments")
        return transcription.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Private: Locked Model Access

    /// Loads (or returns already-loaded) whisper context under `modelLock`.
    /// Serializes concurrent calls so only one context is initialized at a time.
    private func loadContext(for modelURL: URL) throws -> OpaquePointer {
        try modelLock.withLock {
            guard FileManager.default.fileExists(atPath: modelURL.path) else {
                logger.error("WhisperBridge: model not found at \(modelURL.path)")
                throw DictlyError.transcription(.modelNotFound)
            }

            // Free existing context if model URL changed
            if let existing = context, loadedModelURL != modelURL {
                whisper_free(existing)
                context = nil
                loadedModelURL = nil
            }

            // Already loaded with the correct model
            if let ctx = context, loadedModelURL == modelURL {
                return ctx
            }

            logger.info("WhisperBridge: loading model from \(modelURL.lastPathComponent)")

            var cparams = whisper_context_default_params()
            cparams.use_gpu = true

            guard let ctx = modelURL.withUnsafeFileSystemRepresentation({ path -> OpaquePointer? in
                guard let path else { return nil }
                return whisper_init_from_file_with_params(path, cparams)
            }) else {
                logger.error("WhisperBridge: model loaded but whisper_init returned nil — file may be corrupted")
                throw DictlyError.transcription(.modelCorrupted)
            }

            context = ctx
            loadedModelURL = modelURL
            logger.info("WhisperBridge: model loaded successfully")
            return ctx
        }
    }

    // MARK: - Audio Conversion

    private func convertToPCM(audioURL: URL) throws -> [Float] {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            logger.error("WhisperBridge: audio file not found at \(audioURL.path)")
            throw DictlyError.transcription(.audioFileNotFound)
        }

        do {
            let audioFile = try AVAudioFile(forReading: audioURL)

            guard let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16000,
                channels: 1,
                interleaved: false
            ) else {
                logger.error("WhisperBridge: failed to create 16kHz mono PCM format")
                throw DictlyError.transcription(.audioConversionFailed)
            }

            guard let converter = AVAudioConverter(from: audioFile.processingFormat, to: targetFormat) else {
                logger.error("WhisperBridge: failed to create AVAudioConverter from \(audioFile.processingFormat) to 16kHz PCM")
                throw DictlyError.transcription(.audioConversionFailed)
            }

            // Calculate output frame count
            let inputSampleRate = audioFile.processingFormat.sampleRate
            let inputFrameCount = audioFile.length
            let outputFrameCount = AVAudioFrameCount(
                Double(inputFrameCount) * targetFormat.sampleRate / inputSampleRate
            )

            guard let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: outputFrameCount + 1
            ) else {
                logger.error("WhisperBridge: failed to allocate PCM output buffer")
                throw DictlyError.transcription(.audioConversionFailed)
            }

            var conversionError: NSError?
            var inputExhausted = false

            let status = converter.convert(to: outputBuffer, error: &conversionError) { inNumPackets, outStatus in
                if inputExhausted {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                guard let inputBuffer = AVAudioPCMBuffer(
                    pcmFormat: audioFile.processingFormat,
                    frameCapacity: inNumPackets
                ) else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                do {
                    try audioFile.read(into: inputBuffer)
                    outStatus.pointee = .haveData
                    if inputBuffer.frameLength < inNumPackets {
                        inputExhausted = true
                    }
                    return inputBuffer
                } catch {
                    outStatus.pointee = .endOfStream
                    return nil
                }
            }

            if status == .error || conversionError != nil {
                let detail = conversionError?.localizedDescription ?? "unknown"
                logger.error("WhisperBridge: audio conversion failed — \(detail)")
                throw DictlyError.transcription(.audioConversionFailed)
            }

            guard let floatData = outputBuffer.floatChannelData else {
                logger.error("WhisperBridge: no float channel data after conversion")
                throw DictlyError.transcription(.audioConversionFailed)
            }

            let frameLength = Int(outputBuffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: floatData[0], count: frameLength))

            logger.debug("WhisperBridge: PCM conversion — \(frameLength) frames, sampleRate=\(targetFormat.sampleRate), channels=\(targetFormat.channelCount)")
            return samples

        } catch let error as DictlyError {
            throw error
        } catch {
            logger.error("WhisperBridge: unexpected audio error — \(error.localizedDescription)")
            throw DictlyError.transcription(.audioConversionFailed)
        }
    }
}
