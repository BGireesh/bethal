/// Lifecycle of a transcription job for one meeting.
public enum TranscriptionPhase: String, Codable, Sendable, CaseIterable, Equatable {
    case idle
    case preparing
    case transcribing
    case saving
    case completed
    case failed

    public var isInProgress: Bool {
        self == .preparing || self == .transcribing || self == .saving
    }

    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .preparing: return "Preparing"
        case .transcribing: return "Transcribing"
        case .saving: return "Saving"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}
