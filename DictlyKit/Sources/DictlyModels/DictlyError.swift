import Foundation

public enum DictlyError: Error, LocalizedError, Equatable {
    case recording(RecordingError)
    case transfer(TransferError)
    case transcription(TranscriptionError)
    case storage(StorageError)
    case `import`(ImportError)

    public var errorDescription: String? {
        switch self {
        case .recording(let error): return error.errorDescription
        case .transfer(let error): return error.errorDescription
        case .transcription(let error): return error.errorDescription
        case .storage(let error): return error.errorDescription
        case .import(let error): return error.errorDescription
        }
    }

    public enum RecordingError: Error, LocalizedError, Equatable {
        case permissionDenied
        case deviceUnavailable
        case interrupted
        case audioSessionSetupFailed(String)
        case engineStartFailed(String)
        case fileCreationFailed(String)
        case diskFull

        public var errorDescription: String? {
            switch self {
            case .permissionDenied: return "Microphone permission denied."
            case .deviceUnavailable: return "Audio device unavailable."
            case .interrupted: return "Recording interrupted."
            case .audioSessionSetupFailed(let detail): return "Audio session setup failed: \(detail)"
            case .engineStartFailed(let detail): return "Failed to start recording engine: \(detail)"
            case .fileCreationFailed(let detail): return "Failed to create recording file: \(detail)"
            case .diskFull: return "Not enough disk space to continue recording."
            }
        }
    }

    public enum TransferError: Error, LocalizedError, Equatable {
        case networkUnavailable
        case peerNotFound
        case bundleCorrupted
        case connectionFailed
        case transferInterrupted
        case timeout

        public var errorDescription: String? {
            switch self {
            case .networkUnavailable: return "Network unavailable for transfer."
            case .peerNotFound: return "Transfer peer not found."
            case .bundleCorrupted: return "Transfer bundle is corrupted."
            case .connectionFailed: return "Could not connect to Mac. Check that Dictly is running."
            case .transferInterrupted: return "Transfer interrupted. Check your Wi-Fi connection and try again."
            case .timeout: return "Transfer timed out."
            }
        }
    }

    public enum TranscriptionError: Error, LocalizedError, Equatable {
        case modelNotFound
        case modelCorrupted
        case processingFailed
        case audioConversionFailed
        case audioFileNotFound

        public var errorDescription: String? {
            switch self {
            case .modelNotFound: return "Transcription model not found."
            case .modelCorrupted: return "Transcription model file exists but could not be loaded."
            case .processingFailed: return "Transcription processing failed."
            case .audioConversionFailed: return "Failed to convert audio to PCM format for transcription."
            case .audioFileNotFound: return "Audio file not found for transcription."
            }
        }
    }

    public enum StorageError: Error, LocalizedError, Equatable {
        case diskFull
        case permissionDenied
        case fileNotFound
        case syncFailed(String)

        public var errorDescription: String? {
            switch self {
            case .diskFull: return "Not enough disk space."
            case .permissionDenied: return "Storage permission denied."
            case .fileNotFound: return "File not found."
            case .syncFailed(let detail): return "Sync failed: \(detail)"
            }
        }
    }

    public enum ImportError: Error, LocalizedError, Equatable {
        case invalidFormat
        case duplicateDetected
        case missingData

        public var errorDescription: String? {
            switch self {
            case .invalidFormat: return "Invalid import format."
            case .duplicateDetected: return "Duplicate session detected."
            case .missingData: return "Required data missing from import."
            }
        }
    }
}
