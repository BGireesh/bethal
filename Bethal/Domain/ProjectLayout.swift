import Foundation

/// Describes the on-disk layout Bethal uses under a user-chosen working directory.
public struct ProjectLayout: Equatable, Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root.standardizedFileURL
    }

    // MARK: - Top-level directories

    public var markerDirectory: URL {
        root.appendingPathComponent(AppIdentity.workingDirectoryMarker, isDirectory: true)
    }

    public var meetingsDirectory: URL {
        root.appendingPathComponent("meetings", isDirectory: true)
    }

    public var indexDirectory: URL {
        root.appendingPathComponent("index", isDirectory: true)
    }

    public var exportsDirectory: URL {
        root.appendingPathComponent("exports", isDirectory: true)
    }

    /// All directories that must exist after `initialize()`.
    public var requiredDirectories: [URL] {
        [markerDirectory, meetingsDirectory, indexDirectory, exportsDirectory]
    }

    // MARK: - Marker / index files

    public var schemaFile: URL {
        markerDirectory.appendingPathComponent("schema.json", isDirectory: false)
    }

    public var settingsFile: URL {
        markerDirectory.appendingPathComponent("settings.json", isDirectory: false)
    }

    public var meetingsIndexFile: URL {
        indexDirectory.appendingPathComponent("meetings.json", isDirectory: false)
    }

    public var todosIndexFile: URL {
        indexDirectory.appendingPathComponent("todos.json", isDirectory: false)
    }

    // MARK: - Per-meeting paths

    public func meetingDirectory(id: String) -> URL {
        meetingsDirectory.appendingPathComponent(id, isDirectory: true)
    }

    public func meetingMetaFile(id: String) -> URL {
        meetingDirectory(id: id).appendingPathComponent("meta.json", isDirectory: false)
    }

    public func meetingTranscriptFile(id: String) -> URL {
        meetingDirectory(id: id).appendingPathComponent("transcript.json", isDirectory: false)
    }

    public func meetingSummaryFile(id: String) -> URL {
        meetingDirectory(id: id).appendingPathComponent("summary.md", isDirectory: false)
    }

    public func meetingTodosFile(id: String) -> URL {
        meetingDirectory(id: id).appendingPathComponent("todos.json", isDirectory: false)
    }

    public func meetingMediaFile(id: String, fileName: String) -> URL {
        meetingDirectory(id: id).appendingPathComponent(fileName, isDirectory: false)
    }

    // MARK: - Path helpers

    /// Relative path components from `root` for a known top-level child.
    public func relativePath(for url: URL) -> String? {
        let standardized = url.standardizedFileURL.path
        let rootPath = root.path
        guard standardized == rootPath || standardized.hasPrefix(rootPath + "/") else {
            return nil
        }
        if standardized == rootPath {
            return ""
        }
        return String(standardized.dropFirst(rootPath.count + 1))
    }

    /// Validates a meeting id is safe as a single path component.
    public static func isValidMeetingID(_ id: String) -> Bool {
        guard !id.isEmpty, id.count <= 128 else { return false }
        if id == "." || id == ".." { return false }
        if id.contains("/") || id.contains("\\") { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return id.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
