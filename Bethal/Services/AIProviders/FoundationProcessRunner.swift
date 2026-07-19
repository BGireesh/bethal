import Foundation

/// Real `Foundation.Process` adapter. Prefer mocks in unit tests.
public final class FoundationProcessRunner: ProcessRunner, @unchecked Sendable {
    public init() {}

    public func run(
        executable: URL,
        arguments: [String],
        standardInput: String?
    ) async throws -> ProcessRunResult {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = executable
                    process.arguments = arguments

                    let out = Pipe()
                    let err = Pipe()
                    process.standardOutput = out
                    process.standardError = err

                    if let standardInput {
                        let input = Pipe()
                        process.standardInput = input
                        if let data = standardInput.data(using: .utf8) {
                            input.fileHandleForWriting.write(data)
                        }
                        try? input.fileHandleForWriting.close()
                    } else {
                        process.standardInput = FileHandle.nullDevice
                    }

                    try process.run()
                    process.waitUntilExit()

                    let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    cont.resume(
                        returning: ProcessRunResult(
                            exitCode: process.terminationStatus,
                            standardOutput: stdout,
                            standardError: stderr
                        )
                    )
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}
