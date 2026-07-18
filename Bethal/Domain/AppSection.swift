/// Primary sidebar destinations in the home shell.
public enum AppSection: String, CaseIterable, Identifiable, Codable, Sendable, Equatable {
    case meetings
    case todos
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .meetings: return "Meetings"
        case .todos: return "Todos"
        case .settings: return "Settings"
        }
    }

    public var systemImage: String {
        switch self {
        case .meetings: return "waveform"
        case .todos: return "checklist"
        case .settings: return "gearshape"
        }
    }

    public var accessibilityLabel: String { title }
}
