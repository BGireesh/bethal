/// Authorization state for EventKit calendar access.
public enum CalendarAuthorizationStatus: String, Codable, Sendable, CaseIterable, Equatable {
    case notDetermined
    case restricted
    case denied
    case authorized

    public var isUsable: Bool { self == .authorized }

    public var displayName: String {
        switch self {
        case .notDetermined: return "Not determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        }
    }
}
