/// Placeholder local AI tools shown during onboarding (full discovery in sub-task 09).
public struct KnownAIProviderOption: Equatable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let detail: String

    public init(id: String, displayName: String, detail: String) {
        self.id = id
        self.displayName = displayName
        self.detail = detail
    }

    public static let catalog: [KnownAIProviderOption] = [
        KnownAIProviderOption(
            id: "claude",
            displayName: "Claude CLI",
            detail: "Use your Anthropic Max / Claude subscription via the local CLI."
        ),
        KnownAIProviderOption(
            id: "codex",
            displayName: "ChatGPT / Codex CLI",
            detail: "Use your OpenAI subscription via the local Codex CLI."
        ),
        KnownAIProviderOption(
            id: "grok",
            displayName: "Grok CLI",
            detail: "Use your xAI Grok access via the local CLI."
        ),
    ]

    public static func option(id: String) -> KnownAIProviderOption? {
        catalog.first { $0.id == id }
    }

    public static func isKnownProviderID(_ id: String) -> Bool {
        catalog.contains { $0.id == id }
    }
}
