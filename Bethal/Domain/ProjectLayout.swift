import Foundation

/// Describes the on-disk layout Bethal will use under a user-chosen working directory.
///
/// Sub-task 02 owns the real storage layer; this type documents and validates
/// path conventions early so UI and tests share one source of truth.
public struct ProjectLayout: Equatable, Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root.standardizedFileURL
    }

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

    public func meetingDirectory(id: String) -> URL {
        meetingsDirectory.appendingPathComponent(id, isDirectory: true)
    }

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
        // Reject path separators and null; allow UUID-like and slug characters.
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return id.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
