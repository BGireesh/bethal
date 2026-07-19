import Foundation

/// Resolves a command name to an absolute executable path.
public protocol ExecutableLocating: Sendable {
    func resolve(command: String) -> URL?
}

/// PATH-based locator with injectable environment and filesystem checks.
public struct PATHExecutableLocator: ExecutableLocating, Sendable {
    public var pathEnvironment: String
    public var fileExists: @Sendable (String) -> Bool

    public init(
        pathEnvironment: String,
        fileExists: (@Sendable (String) -> Bool)? = nil
    ) {
        self.pathEnvironment = pathEnvironment
        self.fileExists = fileExists ?? Self.systemIsExecutable
    }

    /// Reads `PATH` from an environment dictionary (defaults to the process environment).
    public static func pathString(from environment: [String: String]) -> String {
        environment["PATH"] ?? ""
    }

    /// Builds a locator from the current process `PATH` environment variable.
    public static func fromProcessEnvironment(
        fileExists: (@Sendable (String) -> Bool)? = nil
    ) -> PATHExecutableLocator {
        let path = pathString(from: ProcessInfo.processInfo.environment)
        return PATHExecutableLocator(pathEnvironment: path, fileExists: fileExists)
    }

    /// Default executable check used when no custom predicate is supplied.
    public static func systemIsExecutable(_ path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }

    public func resolve(command: String) -> URL? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Absolute or relative path already provided.
        if trimmed.contains("/") {
            return fileExists(trimmed) ? URL(fileURLWithPath: trimmed) : nil
        }

        let dirs = pathEnvironment.split(separator: ":").map(String.init)
        for dir in dirs {
            guard !dir.isEmpty else { continue }
            let candidate = (dir as NSString).appendingPathComponent(trimmed)
            if fileExists(candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        return nil
    }
}

/// Fixed map for unit tests.
public struct MapExecutableLocator: ExecutableLocating, Sendable {
    public var map: [String: URL]

    public init(map: [String: URL] = [:]) {
        self.map = map
    }

    public func resolve(command: String) -> URL? {
        map[command]
    }
}
