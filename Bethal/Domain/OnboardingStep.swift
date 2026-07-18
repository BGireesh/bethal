/// Ordered steps in first-launch onboarding.
public enum OnboardingStep: Int, Codable, Sendable, CaseIterable, Equatable, Comparable {
    case privacy = 0
    case workingDirectory = 1
    case defaultProvider = 2
    case finished = 3

    public static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var title: String {
        switch self {
        case .privacy: return "Privacy first"
        case .workingDirectory: return "Working directory"
        case .defaultProvider: return "Default AI tool"
        case .finished: return "Ready"
        }
    }

    public var isTerminal: Bool { self == .finished }
}
