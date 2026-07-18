import Foundation

/// Creates and resolves directory bookmarks for the working directory.
public protocol BookmarkClient: Sendable {
    func bookmark(for url: URL) throws -> Data
    func resolveBookmark(_ data: Data) throws -> ResolvedBookmark
}

public struct ResolvedBookmark: Equatable, Sendable {
    public var url: URL
    public var isStale: Bool

    public init(url: URL, isStale: Bool) {
        self.url = url
        self.isStale = isStale
    }
}

public enum BookmarkError: Error, Equatable, Sendable, LocalizedError {
    case creationFailed(String)
    case resolutionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .creationFailed(let message):
            return "Could not create bookmark: \(message)"
        case .resolutionFailed(let message):
            return "Could not resolve bookmark: \(message)"
        }
    }
}

/// Security-scoped bookmarks (works with or without App Sandbox).
public struct SecurityScopedBookmarkClient: BookmarkClient, Sendable {
    public init() {}

    public func bookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw BookmarkError.creationFailed(error.localizedDescription)
        }
    }

    public func resolveBookmark(_ data: Data) throws -> ResolvedBookmark {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return ResolvedBookmark(url: url, isStale: isStale)
        } catch {
            throw BookmarkError.resolutionFailed(error.localizedDescription)
        }
    }
}

/// Path-encoded bookmarks for unit tests (no security scope).
public struct PathBookmarkClient: BookmarkClient, Sendable {
    public init() {}

    public func bookmark(for url: URL) throws -> Data {
        Data(url.standardizedFileURL.path.utf8)
    }

    public func resolveBookmark(_ data: Data) throws -> ResolvedBookmark {
        guard let path = String(data: data, encoding: .utf8), !path.isEmpty else {
            throw BookmarkError.resolutionFailed("Empty path bookmark.")
        }
        return ResolvedBookmark(url: URL(fileURLWithPath: path, isDirectory: true), isStale: false)
    }
}
