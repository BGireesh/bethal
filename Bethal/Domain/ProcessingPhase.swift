/// Lifecycle of an AI processing job for one meeting.
public enum ProcessingPhase: String, Codable, Sendable, CaseIterable, Equatable {
    case idle
    case choosingProvider
    case preparing
    case running
    case saving
    case completed
    case failed

    public var isInProgress: Bool {
        self == .choosingProvider || self == .preparing || self == .running || self == .saving
    }

    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .choosingProvider: return "Choose tool"
        case .preparing: return "Preparing"
        case .running: return "Running AI"
        case .saving: return "Saving"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}
