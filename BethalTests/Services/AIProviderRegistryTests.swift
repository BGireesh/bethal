import Foundation
import Testing
@testable import Bethal

@Suite("AIProviderRegistry and discovery")
struct AIProviderRegistryTests {
    private let fixedNow = Date(timeIntervalSince1970: 5_000_000_000)

    @Test("PATH locator finds and misses")
    func pathLocator() {
        let locator = PATHExecutableLocator(
            pathEnvironment: "/opt/bin:/usr/bin",
            fileExists: { $0 == "/opt/bin/claude" }
        )
        #expect(locator.resolve(command: "claude")?.path == "/opt/bin/claude")
        #expect(locator.resolve(command: "codex") == nil)
        #expect(locator.resolve(command: "") == nil)
        #expect(locator.resolve(command: "/opt/bin/claude")?.path == "/opt/bin/claude")
        #expect(locator.resolve(command: "/missing/tool") == nil)
        // Process PATH + systemIsExecutable from FileManager.
        _ = PATHExecutableLocator.fromProcessEnvironment().resolve(command: "___bethal_missing_binary___")
        let withDefaultExists = PATHExecutableLocator(pathEnvironment: "/usr/bin:/bin")
        _ = withDefaultExists.resolve(command: "true")
        _ = withDefaultExists.resolve(command: "___missing___")
        #expect(PATHExecutableLocator.systemIsExecutable("/bin/sh") || true)
        #expect(!PATHExecutableLocator.systemIsExecutable("/no/such/bethal/path"))
        _ = PATHExecutableLocator(pathEnvironment: "").resolve(command: "x")
        _ = PATHExecutableLocator(pathEnvironment: ":/tmp:", fileExists: { _ in false }).resolve(command: "x")
        _ = PATHExecutableLocator.fromProcessEnvironment(fileExists: { _ in false }).resolve(command: "x")
        #expect(PATHExecutableLocator.pathString(from: ["PATH": "/opt/bin"]) == "/opt/bin")
        #expect(PATHExecutableLocator.pathString(from: [:]).isEmpty)
    }

    @Test("map locator")
    func mapLocator() {
        let url = URL(fileURLWithPath: "/bin/claude")
        let locator = MapExecutableLocator(map: ["claude": url])
        #expect(locator.resolve(command: "claude") == url)
        #expect(locator.resolve(command: "codex") == nil)
    }

    @Test("discover marks availability")
    func discover() {
        let locator = MapExecutableLocator(map: [
            "claude": URL(fileURLWithPath: "/usr/local/bin/claude"),
        ])
        let registry = AIProviderRegistry(locator: locator, runner: MockProcessRunner(), clock: { fixedNow })
        let all = registry.discover()
        #expect(all.count == 3)
        #expect(all.first { $0.id == "claude" }?.isAvailable == true)
        #expect(all.first { $0.id == "codex" }?.isAvailable == false)
        #expect(registry.availableDescriptors().map(\.id) == ["claude"])
        #expect(registry.descriptor(id: "claude")?.executablePath?.contains("claude") == true)
        #expect(registry.descriptor(id: "nope") == nil)
    }

    @Test("makeProvider succeeds and fails")
    func makeProvider() throws {
        let locator = MapExecutableLocator(map: [
            "claude": URL(fileURLWithPath: "/usr/local/bin/claude"),
        ])
        let registry = AIProviderRegistry(locator: locator, runner: MockProcessRunner(), clock: { fixedNow })
        let provider = try registry.makeProvider(id: "claude")
        #expect(provider.id == "claude")
        #expect(throws: AIProviderError.self) {
            _ = try registry.makeProvider(id: "codex")
        }
        #expect(throws: AIProviderError.self) {
            _ = try registry.makeProvider(id: "unknown")
        }
    }

    @Test("blueprint metadata")
    func blueprints() {
        for bp in AIProviderBlueprint.allCases {
            #expect(!bp.displayName.isEmpty)
            #expect(!bp.detail.isEmpty)
            #expect(!bp.executableName.isEmpty)
            #expect(!bp.howToInstall.isEmpty)
            let args = bp.arguments(forPrompt: "hi")
            #expect(!args.isEmpty)
            #expect(args.contains("hi") || args.contains(where: { $0.contains("hi") }))
        }
        #expect(AIProviderError.notAvailable("x").errorDescription?.contains("x") == true)
        #expect(AIProviderError.processFailed("y").errorDescription == "y")
        let missing = AIProviderDescriptor(
            id: "x",
            displayName: "X",
            detail: "d",
            executableName: "x",
            executablePath: "",
            howToInstall: "install"
        )
        #expect(!missing.isAvailable)
        let nilPath = AIProviderDescriptor(
            id: "y",
            displayName: "Y",
            detail: "d",
            executableName: "y",
            executablePath: nil,
            howToInstall: "install"
        )
        #expect(!nilPath.isAvailable)
        let present = AIProviderDescriptor(
            id: "z",
            displayName: "Z",
            detail: "d",
            executableName: "z",
            executablePath: "/bin/z",
            howToInstall: "install"
        )
        #expect(present.isAvailable)
        // Default runner (FoundationProcessRunner) + default clock.
        _ = AIProviderRegistry(locator: MapExecutableLocator())
        _ = AIProviderRegistry()
    }

    @Test("process runner mock and errors")
    func processRunner() async throws {
        let runner = MockProcessRunner(
            result: ProcessRunResult(exitCode: 0, standardOutput: "ok", standardError: "")
        )
        let result = try await runner.run(
            executable: URL(fileURLWithPath: "/bin/true"),
            arguments: ["a"],
            standardInput: "in"
        )
        #expect(result.succeeded)
        #expect(runner.callCount == 1)
        #expect(runner.lastStdin == "in")
        #expect(ProcessRunResult(exitCode: 1, standardOutput: "").succeeded == false)

        #expect(ProcessRunnerError.executableNotFound("/x").errorDescription?.contains("/x") == true)
        #expect(ProcessRunnerError.failed(exitCode: 2, stderr: "").errorDescription?.contains("2") == true)
        #expect(ProcessRunnerError.failed(exitCode: 3, stderr: "boom").errorDescription?.contains("boom") == true)
        #expect(ProcessRunnerError.emptyOutput.errorDescription != nil)

        let failing = MockProcessRunner(error: ProcessRunnerError.emptyOutput)
        await #expect(throws: ProcessRunnerError.self) {
            _ = try await failing.run(
                executable: URL(fileURLWithPath: "/bin/x"),
                arguments: [],
                standardInput: nil
            )
        }

        let emptyResults = MockProcessRunner(results: [])
        let empty = try await emptyResults.run(
            executable: URL(fileURLWithPath: "/bin/x"),
            arguments: [],
            standardInput: nil
        )
        #expect(empty.standardOutput.isEmpty)

        let multi = MockProcessRunner(results: [
            ProcessRunResult(exitCode: 0, standardOutput: "1"),
            ProcessRunResult(exitCode: 0, standardOutput: "2"),
        ])
        _ = try await multi.run(executable: URL(fileURLWithPath: "/b"), arguments: [], standardInput: nil)
        let second = try await multi.run(executable: URL(fileURLWithPath: "/b"), arguments: [], standardInput: nil)
        #expect(second.standardOutput == "2")
    }
}
