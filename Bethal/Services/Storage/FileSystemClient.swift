import Foundation

/// Minimal filesystem surface for storage so unit tests can inject failures.
public protocol FileSystemClient: Sendable {
    func fileExists(atPath path: String) -> Bool
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws
    func removeItem(at url: URL) throws
    func contentsOfDirectory(at url: URL) throws -> [URL]
    func readData(from url: URL) throws -> Data
    func writeData(_ data: Data, to url: URL) throws
}

/// Production filesystem backed by `FileManager`.
public struct FoundationFileSystem: FileSystemClient, @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func fileExists(atPath path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }

    public func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: withIntermediateDirectories,
            attributes: nil
        )
    }

    public func removeItem(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    public func contentsOfDirectory(at url: URL) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
    }

    public func readData(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func writeData(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic])
    }
}
