/// Authorization state for capture-related TCC permissions.
public enum PermissionStatus: String, Codable, Sendable, CaseIterable, Equatable {
    case notDetermined
    case denied
    case authorized
    case restricted

    public var isUsable: Bool { self == .authorized }

    public var displayName: String {
        switch self {
        case .notDetermined: return "Not determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .restricted: return "Restricted"
        }
    }
}
