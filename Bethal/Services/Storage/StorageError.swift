import Foundation

/// Errors raised by working-directory storage.
public enum StorageError: Error, Equatable, Sendable, LocalizedError {
    case notInitialized
    case invalidMeetingID(String)
    case meetingNotFound(String)
    case todoNotFound(String)
    case corruptFile(path: String, reason: String)
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case ioFailure(String)

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Working directory is not initialized."
        case .invalidMeetingID(let id):
            return "Invalid meeting id: \(id)"
        case .meetingNotFound(let id):
            return "Meeting not found: \(id)"
        case .todoNotFound(let id):
            return "Todo not found: \(id)"
        case .corruptFile(let path, let reason):
            return "Corrupt file at \(path): \(reason)"
        case .unsupportedSchemaVersion(let found, let supported):
            return "Unsupported schema version \(found) (supported max \(supported))."
        case .ioFailure(let message):
            return message
        }
    }
}
