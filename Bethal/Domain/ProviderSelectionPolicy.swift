/// Pure rules for whether to show the post-call provider chooser.
public enum ProviderSelectionDecision: Equatable, Sendable {
    /// Use this provider id without asking.
    case useDefault(providerID: String)
    /// Show chooser (optionally preselecting a default).
    case askUser(preferredID: String?)
    /// No discovered tools; show empty state.
    case noneAvailable
}

public enum ProviderSelectionPolicy: Sendable {
    /// Decide how to pick a provider given settings and currently available tool ids.
    public static func decide(
        settings: AppSettings,
        availableProviderIDs: [String]
    ) -> ProviderSelectionDecision {
        let available = availableProviderIDs
        guard !available.isEmpty else {
            return .noneAvailable
        }

        let preferred = settings.defaultAIProviderID.flatMap { id in
            available.contains(id) ? id : nil
        }

        if settings.askEveryTimeForProvider {
            return .askUser(preferredID: preferred)
        }

        if let preferred {
            return .useDefault(providerID: preferred)
        }

        // Default configured but unavailable, or no default → ask.
        return .askUser(preferredID: nil)
    }
}
