import Foundation

public enum DictlyError: Error, LocalizedError {
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

    public enum RecordingError: Error, LocalizedError {
        case permissionDenied
        case deviceUnavailable
        case interrupted

        public var errorDescription: String? {
            switch self {
            case .permissionDenied: return "Microphone permission denied."
            case .deviceUnavailable: return "Audio device unavailable."
            case .interrupted: return "Recording interrupted."
            }
        }
    }

    public enum TransferError: Error, LocalizedError {
        case networkUnavailable
        case peerNotFound
        case bundleCorrupted

        public var errorDescription: String? {
            switch self {
            case .networkUnavailable: return "Network unavailable for transfer."
            case .peerNotFound: return "Transfer peer not found."
            case .bundleCorrupted: return "Transfer bundle is corrupted."
            }
        }
    }

    public enum TranscriptionError: Error, LocalizedError {
        case modelNotFound
        case processingFailed

        public var errorDescription: String? {
            switch self {
            case .modelNotFound: return "Transcription model not found."
            case .processingFailed: return "Transcription processing failed."
            }
        }
    }

    public enum StorageError: Error, LocalizedError {
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

    public enum ImportError: Error, LocalizedError {
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
