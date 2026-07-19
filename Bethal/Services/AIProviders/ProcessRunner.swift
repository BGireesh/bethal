import Foundation

/// Outcome of a local process invocation.
public struct ProcessRunResult: Equatable, Sendable {
    public var exitCode: Int32
    public var standardOutput: String
    public var standardError: String

    public init(exitCode: Int32, standardOutput: String, standardError: String = "") {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }

    public var succeeded: Bool { exitCode == 0 }
}

public enum ProcessRunnerError: Error, Equatable, Sendable, LocalizedError {
    case executableNotFound(String)
    case failed(exitCode: Int32, stderr: String)
    case emptyOutput

    public var errorDescription: String? {
        switch self {
        case .executableNotFound(let path):
            return "Executable not found: \(path)"
        case .failed(let code, let stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                return "Process failed with exit code \(code)."
            }
            return "Process failed (\(code)): \(detail)"
        case .emptyOutput:
            return "Process produced no output."
        }
    }
}

/// Abstraction over launching local CLIs (testable without real processes).
public protocol ProcessRunner: Sendable {
    func run(
        executable: URL,
        arguments: [String],
        standardInput: String?
    ) async throws -> ProcessRunResult
}

/// In-memory runner for unit tests.
public final class MockProcessRunner: ProcessRunner, @unchecked Sendable {
    public var results: [ProcessRunResult]
    public var error: Error?
    public private(set) var callCount = 0
    public private(set) var lastExecutable: URL?
    public private(set) var lastArguments: [String]?
    public private(set) var lastStdin: String?

    public init(results: [ProcessRunResult] = [], error: Error? = nil) {
        self.results = results
        self.error = error
    }

    public convenience init(result: ProcessRunResult) {
        self.init(results: [result])
    }

    public func run(
        executable: URL,
        arguments: [String],
        standardInput: String?
    ) async throws -> ProcessRunResult {
        callCount += 1
        lastExecutable = executable
        lastArguments = arguments
        lastStdin = standardInput
        if let error { throw error }
        if results.isEmpty {
            return ProcessRunResult(exitCode: 0, standardOutput: "", standardError: "")
        }
        if results.count == 1 {
            return results[0]
        }
        let index = min(callCount - 1, results.count - 1)
        return results[index]
    }
}

