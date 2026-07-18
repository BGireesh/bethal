/// Lifecycle phases for a capture session.
public enum RecordingPhase: String, Codable, Sendable, CaseIterable, Equatable {
    case idle
    case checkingPermissions
    case awaitingPermission
    case ready
    case recording
    case stopping
    case finalized
    case failed

    public var isTerminal: Bool {
        self == .finalized || self == .failed
    }

    public var isActiveCapture: Bool {
        self == .recording || self == .stopping
    }
}
