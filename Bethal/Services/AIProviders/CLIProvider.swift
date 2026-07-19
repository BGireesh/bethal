import Foundation

/// Generic local CLI provider (Claude / Codex / Grok) using `ProcessRunner`.
public final class CLIProvider: AIProvider, @unchecked Sendable {
    public let id: String
    public let displayName: String
    public let blueprint: AIProviderBlueprint
    public let executableURL: URL

    private let runner: ProcessRunner
    private let clock: () -> Date

    public init(
        blueprint: AIProviderBlueprint,
        executableURL: URL,
        runner: ProcessRunner,
        clock: (() -> Date)? = nil
    ) {
        self.blueprint = blueprint
        self.id = blueprint.id
        self.displayName = blueprint.displayName
        self.executableURL = executableURL
        self.runner = runner
        self.clock = clock ?? Date.init
    }

    public func process(_ request: MeetingProcessRequest) async throws -> MeetingProcessResult {
        let prompt = PromptTemplates.summaryAndTodosPrompt(for: request)
        let args = blueprint.arguments(forPrompt: prompt)
        let run = try await runner.run(
            executable: executableURL,
            arguments: args,
            standardInput: nil
        )
        guard run.succeeded else {
            throw ProcessRunnerError.failed(exitCode: run.exitCode, stderr: run.standardError)
        }
        let output = run.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else {
            throw ProcessRunnerError.emptyOutput
        }
        let payload = try AIProcessResponseParser.parse(output)
        return AIProcessResponseParser.makeResult(
            from: payload,
            request: request,
            providerID: id,
            rawOutput: output,
            clock: clock
        )
    }
}
