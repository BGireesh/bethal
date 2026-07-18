import Foundation

/// Testable onboarding coordinator (no SwiftUI dependency).
public final class OnboardingViewModel: @unchecked Sendable {
    public private(set) var flow: OnboardingFlowState
    public private(set) var sessionPreferences: AppSessionPreferences

    private let completer: OnboardingCompleter
    private let sessionStore: AppSessionStore

    public init(
        sessionStore: AppSessionStore = AppSessionStore(),
        completer: OnboardingCompleter? = nil,
        initialFlow: OnboardingFlowState = OnboardingFlowState()
    ) {
        self.sessionStore = sessionStore
        self.sessionPreferences = sessionStore.load()
        if let completer {
            self.completer = completer
        } else {
            self.completer = OnboardingCompleter(sessionStore: sessionStore)
        }
        if sessionPreferences.hasCompletedOnboarding {
            var finished = initialFlow
            finished.directoryPath = sessionPreferences.workingDirectoryPath
            finished.markFinished()
            self.flow = finished
        } else {
            self.flow = initialFlow
        }
    }

    public var needsOnboarding: Bool {
        !sessionPreferences.hasCompletedOnboarding
    }

    public func selectDirectory(url: URL) {
        flow.setDirectoryPath(url.standardizedFileURL.path)
    }

    public func clearDirectory() {
        flow.setDirectoryPath(nil)
    }

    public func selectProvider(id: String?) {
        if let id, !KnownAIProviderOption.isKnownProviderID(id) {
            flow.setProviderID(nil)
            return
        }
        flow.setProviderID(id)
    }

    @discardableResult
    public func goBack() -> Bool {
        flow.retreat()
    }

    /// Advances wizard steps. On the provider step, persists completion instead of only advancing.
    @discardableResult
    public func continueOrFinish() -> Bool {
        switch flow.step {
        case .privacy:
            return flow.advance()
        case .workingDirectory:
            guard flow.canAdvance else {
                flow.setError("Choose a folder where Bethal will store meetings and todos.")
                return false
            }
            return flow.advance()
        case .defaultProvider:
            return finish()
        case .finished:
            return false
        }
    }

    @discardableResult
    public func finish() -> Bool {
        guard let path = flow.directoryPath, !path.isEmpty else {
            flow.setError("Choose a working directory before finishing.")
            flow.step = .workingDirectory
            return false
        }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        do {
            let preferences = try completer.complete(
                directoryURL: url,
                providerID: flow.providerID
            )
            sessionPreferences = preferences
            flow.markFinished()
            return true
        } catch {
            flow.setError(error.localizedDescription)
            return false
        }
    }

    public func reloadSession() {
        sessionPreferences = sessionStore.load()
        if sessionPreferences.hasCompletedOnboarding {
            flow.markFinished()
            flow.directoryPath = sessionPreferences.workingDirectoryPath
        }
    }
}
