import Foundation
import Observation
import os.log
import DictlyModels

private let logger = Logger(subsystem: "com.dictly.mac", category: "transcription")

// MARK: - WhisperModel

struct WhisperModel: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let fileName: String
    let size: Int64
    let quality: String
    let isBundled: Bool

    var downloadURL: URL {
        let encoded = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
        guard let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(encoded)") else {
            preconditionFailure("ModelManager: invalid download URL for model '\(id)' — fileName: \(fileName)")
        }
        return url
    }
}

// MARK: - ModelManager

@Observable
@MainActor
final class ModelManager {

    // MARK: - Constants

    static let defaultModelId = "base.en"
    private static let userDefaultsKey = "activeWhisperModel"

    // MARK: - Model Registry

    static let registry: [WhisperModel] = [
        WhisperModel(
            id: "base.en",
            name: "base.en",
            fileName: "ggml-base.en.bin",
            size: 147_964_211,
            quality: "Good quality",
            isBundled: false
        ),
        WhisperModel(
            id: "small.en",
            name: "small.en",
            fileName: "ggml-small.en.bin",
            size: 487_601_520,
            quality: "Better quality",
            isBundled: false
        ),
        WhisperModel(
            id: "medium.en",
            name: "medium.en",
            fileName: "ggml-medium.en.bin",
            size: 1_528_088_332,
            quality: "Best quality",
            isBundled: false
        )
    ]

    // MARK: - Observable State

    private(set) var activeModel: String = ModelManager.defaultModelId
    var downloadProgress: Double = 0.0
    var isDownloading: Bool = false
    var downloadingModelId: String? = nil

    // MARK: - Private

    private var activeDownloadSession: URLSession?

    // MARK: - Directory

    let modelsDirectory: URL

    // MARK: - Init

    /// Production init — uses the standard `~/Library/Application Support/Dictly/Models/` directory.
    convenience init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Dictly/Models", isDirectory: true)
        self.init(modelsDirectory: dir)
    }

    /// Designated init — accepts any directory URL, useful for testing.
    init(modelsDirectory: URL) {
        self.modelsDirectory = modelsDirectory
        if !FileManager.default.fileExists(atPath: modelsDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
                logger.info("ModelManager: created Models directory at \(modelsDirectory.path)")
            } catch {
                logger.error("ModelManager: failed to create Models directory — \(error.localizedDescription)")
            }
        }

        let stored = UserDefaults.standard.string(forKey: Self.userDefaultsKey) ?? Self.defaultModelId
        if let model = Self.registry.first(where: { $0.id == stored }) {
            let filePath = modelsDirectory.appendingPathComponent(model.fileName).path
            let exists = model.isBundled || FileManager.default.fileExists(atPath: filePath)
            if exists {
                activeModel = stored
            } else {
                activeModel = Self.defaultModelId
                UserDefaults.standard.set(Self.defaultModelId, forKey: Self.userDefaultsKey)
                logger.info("ModelManager: persisted model '\(stored)' not on disk — fell back to \(Self.defaultModelId)")
            }
        } else {
            activeModel = Self.defaultModelId
            UserDefaults.standard.set(Self.defaultModelId, forKey: Self.userDefaultsKey)
        }
        copyBundledModelIfNeeded()
    }

    // MARK: - Model URL Helpers

    func modelURL(for model: WhisperModel) -> URL {
        modelsDirectory.appendingPathComponent(model.fileName)
    }

    var activeModelURL: URL {
        let model = Self.registry.first(where: { $0.id == activeModel }) ?? Self.registry[0]
        return modelURL(for: model)
    }

    var bundledModelURL: URL? {
        Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin")
    }

    // MARK: - Status

    func isDownloaded(_ model: WhisperModel) -> Bool {
        FileManager.default.fileExists(atPath: modelURL(for: model).path)
    }

    // MARK: - Selection

    func selectModel(_ model: WhisperModel) {
        guard model.isBundled || isDownloaded(model) else {
            logger.info("ModelManager: cannot select '\(model.id)' — not downloaded")
            return
        }
        activeModel = model.id
        UserDefaults.standard.set(model.id, forKey: Self.userDefaultsKey)
        logger.info("ModelManager: selected model '\(model.id)'")
    }

    // MARK: - Download

    func downloadModel(_ model: WhisperModel) async throws {
        guard !model.isBundled else { return }
        guard !isDownloading else { return }

        logger.info("ModelManager: starting download for '\(model.id)'")
        isDownloading = true
        downloadingModelId = model.id
        downloadProgress = 0.0

        let progressHandler: @Sendable (Double) -> Void = { [weak self] progress in
            Task { @MainActor [weak self] in
                self?.downloadProgress = progress
                logger.debug("ModelManager: download progress \(String(format: "%.1f", progress * 100))%")
            }
        }

        let delegate = ModelDownloadDelegate(progressHandler: progressHandler)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        activeDownloadSession = session

        defer {
            activeDownloadSession = nil
            isDownloading = false
            downloadingModelId = nil
            downloadProgress = 0.0
        }

        do {
            let (tempURL, response) = try await session.download(from: model.downloadURL)

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                logger.error("ModelManager: download failed — HTTP \(httpResponse.statusCode)")
                try? FileManager.default.removeItem(at: tempURL)
                throw DictlyError.transcription(.downloadFailed)
            }

            let destination = modelURL(for: model)
            if FileManager.default.fileExists(atPath: destination.path) {
                do {
                    try FileManager.default.removeItem(at: destination)
                } catch {
                    logger.warning("ModelManager: failed to remove existing model before move — \(error.localizedDescription)")
                }
            }
            do {
                try FileManager.default.moveItem(at: tempURL, to: destination)
            } catch {
                logger.error("ModelManager: failed to move downloaded model to destination — \(error.localizedDescription)")
                try? FileManager.default.removeItem(at: tempURL)
                throw DictlyError.transcription(.downloadFailed)
            }
            logger.info("ModelManager: download complete for '\(model.id)'")

        } catch let urlError as NSError where urlError.code == NSURLErrorCancelled {
            logger.info("ModelManager: download cancelled for '\(model.id)'")
            // Normal cancellation — not an error, return silently
        } catch let error as DictlyError {
            logger.error("ModelManager: download error for '\(model.id)' — \(error.localizedDescription ?? "unknown")")
            throw error
        } catch {
            logger.error("ModelManager: download error for '\(model.id)' — \(error.localizedDescription)")
            throw DictlyError.transcription(.downloadFailed)
        }
    }

    func cancelDownload() {
        activeDownloadSession?.invalidateAndCancel()
        activeDownloadSession = nil
        isDownloading = false
        downloadingModelId = nil
        downloadProgress = 0.0
        logger.info("ModelManager: download cancelled by user")
    }

    // MARK: - Deletion

    func deleteModel(_ model: WhisperModel) throws {
        guard !model.isBundled else {
            logger.info("ModelManager: cannot delete bundled model '\(model.id)'")
            return
        }

        // Cancel any in-progress download for this model before deleting
        if downloadingModelId == model.id {
            cancelDownload()
        }

        let url = modelURL(for: model)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        try FileManager.default.removeItem(at: url)
        logger.info("ModelManager: deleted model '\(model.id)'")

        if activeModel == model.id {
            activeModel = Self.defaultModelId
            UserDefaults.standard.set(Self.defaultModelId, forKey: Self.userDefaultsKey)
            logger.info("ModelManager: active model deleted — fell back to \(Self.defaultModelId)")
        }
    }

    // MARK: - Bundle Copy

    private func copyBundledModelIfNeeded() {
        guard let bundled = bundledModelURL else {
            logger.debug("ModelManager: ggml-base.en.bin not found in Bundle.main")
            return
        }
        let baseModel = Self.registry[0]
        let destination = modelURL(for: baseModel)
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }
        do {
            try FileManager.default.copyItem(at: bundled, to: destination)
            logger.info("ModelManager: copied bundled base.en to \(destination.path)")
        } catch {
            logger.error("ModelManager: failed to copy bundled model — \(error.localizedDescription)")
        }
    }
}

// MARK: - Download Delegate

private final class ModelDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

    private let progressHandler: @Sendable (Double) -> Void

    init(progressHandler: @escaping @Sendable (Double) -> Void) {
        self.progressHandler = progressHandler
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressHandler(progress)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // File move is handled in the async download call
    }
}
