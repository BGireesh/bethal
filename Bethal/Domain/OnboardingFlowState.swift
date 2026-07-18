import Foundation

/// Pure onboarding wizard state (no I/O). Fully unit-tested.
public struct OnboardingFlowState: Equatable, Sendable {
    public var step: OnboardingStep
    /// Absolute path string for the chosen working directory.
    public var directoryPath: String?
    /// Optional default provider id (`claude`, `codex`, `grok`). `nil` means ask every time.
    public var providerID: String?
    public var errorMessage: String?

    public init(
        step: OnboardingStep = .privacy,
        directoryPath: String? = nil,
        providerID: String? = nil,
        errorMessage: String? = nil
    ) {
        self.step = step
        self.directoryPath = directoryPath
        self.providerID = providerID
        self.errorMessage = errorMessage
    }

    public var hasDirectory: Bool {
        guard let directoryPath, !directoryPath.isEmpty else { return false }
        return true
    }

    /// Whether the primary Continue / Finish control should be enabled.
    public var canAdvance: Bool {
        switch step {
        case .privacy:
            return true
        case .workingDirectory:
            return hasDirectory
        case .defaultProvider:
            return true
        case .finished:
            return false
        }
    }

    public var isComplete: Bool { step == .finished }

    /// Primary button label for the current step.
    public var primaryActionTitle: String {
        switch step {
        case .privacy: return "Continue"
        case .workingDirectory: return "Continue"
        case .defaultProvider: return "Finish setup"
        case .finished: return "Done"
        }
    }

    public mutating func setDirectoryPath(_ path: String?) {
        directoryPath = path
        errorMessage = nil
    }

    public mutating func setProviderID(_ id: String?) {
        providerID = id
        errorMessage = nil
    }

    public mutating func setError(_ message: String?) {
        errorMessage = message
    }

    /// Moves forward one step when allowed. Returns whether the step changed.
    @discardableResult
    public mutating func advance() -> Bool {
        guard canAdvance, !step.isTerminal else { return false }
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return false }
        step = next
        errorMessage = nil
        return true
    }

    /// Moves back one step when possible. Returns whether the step changed.
    @discardableResult
    public mutating func retreat() -> Bool {
        guard step > .privacy else { return false }
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return false }
        step = previous
        errorMessage = nil
        return true
    }

    /// Marks the flow finished after successful persistence.
    public mutating func markFinished() {
        step = .finished
        errorMessage = nil
    }
}
