import Foundation

/// A discovered (or known) local AI tool entry for UI and settings.
public struct AIProviderDescriptor: Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var detail: String
    public var executableName: String
    public var executablePath: String?
    public var howToInstall: String

    public init(
        id: String,
        displayName: String,
        detail: String,
        executableName: String,
        executablePath: String? = nil,
        howToInstall: String
    ) {
        self.id = id
        self.displayName = displayName
        self.detail = detail
        self.executableName = executableName
        self.executablePath = executablePath
        self.howToInstall = howToInstall
    }

    public var isAvailable: Bool {
        guard let path = executablePath else { return false }
        return !path.isEmpty
    }
}

/// Runs meeting post-processing via a local tool.
public protocol AIProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    func process(_ request: MeetingProcessRequest) async throws -> MeetingProcessResult
}

public enum AIProviderError: Error, Equatable, Sendable, LocalizedError {
    case notAvailable(String)
    case processFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAvailable(let id):
            return "AI provider “\(id)” is not available on this Mac."
        case .processFailed(let detail):
            return detail
        }
    }
}

/// Known catalog entries (ids align with `KnownAIProviderOption` / onboarding).
public enum AIProviderBlueprint: String, CaseIterable, Sendable {
    case claude
    case codex
    case grok

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claude: return "Claude CLI"
        case .codex: return "ChatGPT / Codex CLI"
        case .grok: return "Grok CLI"
        }
    }

    public var detail: String {
        switch self {
        case .claude: return "Anthropic Claude via the local `claude` CLI."
        case .codex: return "OpenAI Codex via the local `codex` CLI."
        case .grok: return "xAI Grok via the local `grok` CLI."
        }
    }

    public var executableName: String {
        switch self {
        case .claude: return "claude"
        case .codex: return "codex"
        case .grok: return "grok"
        }
    }

    public var howToInstall: String {
        switch self {
        case .claude:
            return "Install Claude Code (`claude`) via Homebrew or Anthropic’s installer. Bethal also checks /opt/homebrew/bin and your login shell PATH."
        case .codex:
            return "Install the OpenAI Codex CLI (`codex`) and ensure the binary is on your PATH (not only the Codex desktop app)."
        case .grok:
            return "Install the Grok CLI (`grok`), typically under ~/.grok/bin or ~/.local/bin."
        }
    }

    /// Non-interactive args: prompt is passed as the final argument.
    public func arguments(forPrompt prompt: String) -> [String] {
        switch self {
        case .claude:
            // Print response to stdout without interactive TUI.
            return ["-p", prompt]
        case .codex:
            return ["exec", "--skip-git-repo-check", prompt]
        case .grok:
            return ["-p", prompt]
        }
    }

    public func makeDescriptor(path: String?) -> AIProviderDescriptor {
        AIProviderDescriptor(
            id: id,
            displayName: displayName,
            detail: detail,
            executableName: executableName,
            executablePath: path,
            howToInstall: howToInstall
        )
    }
}
