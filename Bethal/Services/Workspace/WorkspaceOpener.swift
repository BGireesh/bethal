import AppKit
import Foundation

/// Opens files/folders in the system workspace (Finder).
public protocol WorkspaceOpener: Sendable {
    /// Returns whether the open request was accepted by the workspace.
    func open(_ url: URL) -> Bool
}

/// Production opener backed by `NSWorkspace`.
public struct FinderWorkspaceOpener: WorkspaceOpener, Sendable {
    public init() {}

    public func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}

/// Records open requests for unit tests.
public final class RecordingWorkspaceOpener: WorkspaceOpener, @unchecked Sendable {
    public private(set) var openedURLs: [URL] = []
    public var result: Bool = true

    public init(result: Bool = true) {
        self.result = result
    }

    public func open(_ url: URL) -> Bool {
        openedURLs.append(url.standardizedFileURL)
        return result
    }
}
