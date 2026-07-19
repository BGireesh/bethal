import Foundation

/// Discovers local AI CLIs and constructs providers for available tools.
public final class AIProviderRegistry: @unchecked Sendable {
    private let locator: ExecutableLocating
    private let runner: ProcessRunner
    private let clock: () -> Date

    public init(
        locator: ExecutableLocating? = nil,
        runner: ProcessRunner? = nil,
        clock: (() -> Date)? = nil
    ) {
        // Augmented PATH covers Homebrew / ~/.local/bin / ~/.grok/bin for GUI launches.
        // (Login-shell fallback is available on PATHExecutableLocator but not used by
        // default — spawning zsh -lc can hang under XCTest.)
        self.locator = locator ?? PATHExecutableLocator.fromProcessEnvironment()
        self.runner = runner ?? FoundationProcessRunner()
        self.clock = clock ?? Date.init
    }

    /// All known tools with availability filled from PATH.
    public func discover() -> [AIProviderDescriptor] {
        AIProviderBlueprint.allCases.map { blueprint in
            let url = locator.resolve(command: blueprint.executableName)
            return blueprint.makeDescriptor(path: url?.path)
        }
    }

    public func availableDescriptors() -> [AIProviderDescriptor] {
        discover().filter(\.isAvailable)
    }

    public func descriptor(id: String) -> AIProviderDescriptor? {
        discover().first { $0.id == id }
    }

    public func makeProvider(id: String) throws -> AIProvider {
        guard let blueprint = AIProviderBlueprint(rawValue: id) else {
            throw AIProviderError.notAvailable(id)
        }
        guard let url = locator.resolve(command: blueprint.executableName) else {
            throw AIProviderError.notAvailable(id)
        }
        return CLIProvider(
            blueprint: blueprint,
            executableURL: url,
            runner: runner,
            clock: clock
        )
    }
}
