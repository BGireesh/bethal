import Foundation

/// Resolves a command name to an absolute executable path.
public protocol ExecutableLocating: Sendable {
    func resolve(command: String) -> URL?
}

/// PATH-based locator with injectable environment and filesystem checks.
///
/// GUI-launched macOS apps often see a minimal PATH (`/usr/bin:/bin:…`) that
/// omits Homebrew and user bin dirs. This locator **augments** the process PATH
/// with common install locations and can optionally fall back to a login shell
/// `command -v` lookup (same PATH your Terminal sees).
public struct PATHExecutableLocator: ExecutableLocating, Sendable {
    public var pathEnvironment: String
    public var fileExists: @Sendable (String) -> Bool
    /// When PATH search fails, run `zsh -lc 'command -v <name>'`.
    public var enableShellFallback: Bool
    /// Injectable shell resolver for tests (`nil` uses real `/bin/zsh`).
    public var shellResolver: (@Sendable (String) -> URL?)?

    public init(
        pathEnvironment: String,
        fileExists: (@Sendable (String) -> Bool)? = nil,
        enableShellFallback: Bool = false,
        shellResolver: (@Sendable (String) -> URL?)? = nil
    ) {
        self.pathEnvironment = pathEnvironment
        self.fileExists = fileExists ?? Self.systemIsExecutable
        self.enableShellFallback = enableShellFallback
        self.shellResolver = shellResolver
    }

    /// Reads `PATH` from an environment dictionary (defaults to the process environment).
    public static func pathString(from environment: [String: String]) -> String {
        environment["PATH"] ?? ""
    }

    /// Well-known directories where local AI CLIs are typically installed on macOS.
    public static func commonSearchDirectories(home: String) -> [String] {
        [
            "\(home)/.local/bin",
            "\(home)/.grok/bin",
            "\(home)/.bun/bin",
            "\(home)/.cargo/bin",
            "\(home)/.npm-global/bin",
            "\(home)/.nvm/current/bin",
            "\(home)/.volta/bin",
            "\(home)/.asdf/shims",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
        ]
    }

    /// Prepends common install dirs so GUI apps find Homebrew / user tools.
    public static func augmentedPATH(
        processPATH: String,
        home: String = NSHomeDirectory()
    ) -> String {
        var seen = Set<String>()
        var ordered: [String] = []

        func append(_ dir: String) {
            let trimmed = dir.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { return }
            seen.insert(trimmed)
            ordered.append(trimmed)
        }

        for dir in commonSearchDirectories(home: home) {
            append(dir)
        }
        for dir in processPATH.split(separator: ":").map(String.init) {
            append(dir)
        }
        for dir in ["/usr/bin", "/bin", "/usr/sbin", "/sbin"] {
            append(dir)
        }
        return ordered.joined(separator: ":")
    }

    /// Builds a production locator with **augmented** PATH (Homebrew, `~/.local/bin`, …).
    ///
    /// Shell fallback is **off** by default (spawning login shells is slow and can
    /// hang under XCTest). Enable it when constructing the app’s live registry if needed.
    public static func fromProcessEnvironment(
        fileExists: (@Sendable (String) -> Bool)? = nil,
        home: String = NSHomeDirectory(),
        enableShellFallback: Bool = false,
        shellResolver: (@Sendable (String) -> URL?)? = nil
    ) -> PATHExecutableLocator {
        let processPATH = pathString(from: ProcessInfo.processInfo.environment)
        let path = augmentedPATH(processPATH: processPATH, home: home)
        return PATHExecutableLocator(
            pathEnvironment: path,
            fileExists: fileExists,
            enableShellFallback: enableShellFallback,
            shellResolver: shellResolver
        )
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

        if let fromPath = resolveOnPATH(command: trimmed) {
            return fromPath
        }

        guard enableShellFallback, let shellResolver else { return nil }
        return shellResolver(trimmed)
    }

    private func resolveOnPATH(command: String) -> URL? {
        let dirs = pathEnvironment.split(separator: ":").map(String.init)
        for dir in dirs {
            guard !dir.isEmpty else { continue }
            let candidate = (dir as NSString).appendingPathComponent(command)
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
