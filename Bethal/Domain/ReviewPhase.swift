/// Lifecycle of the post-processing review UI for one meeting.
public enum ReviewPhase: String, Codable, Sendable, CaseIterable, Equatable {
    case idle
    case loading
    case ready
    case saving
    case completed
    case failed

    public var isBusy: Bool {
        self == .loading || self == .saving
    }

    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .loading: return "Loading"
        case .ready: return "Ready"
        case .saving: return "Saving"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}
