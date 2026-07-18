import Foundation
@testable import Bethal

/// Dictionary-backed filesystem for deterministic storage tests.
final class InMemoryFileSystem: FileSystemClient, @unchecked Sendable {
    private var files: [String: Data] = [:]
    private var directories: Set<String> = []
    var failNextWrite: Bool = false
    var failNextRead: Bool = false
    var failNextCreateDirectory: Bool = false
    var failNextRemove: Bool = false

    func fileExists(atPath path: String) -> Bool {
        let normalized = normalize(path)
        return files[normalized] != nil || directories.contains(normalized)
    }

    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        if failNextCreateDirectory {
            failNextCreateDirectory = false
            throw TestFileError.forced("createDirectory")
        }
        let path = normalize(url.path)
        guard withIntermediateDirectories else {
            directories.insert(path)
            return
        }
        let parts = path.split(separator: "/").map(String.init)
        var built = path.hasPrefix("/") ? "" : nil as String?
        if path.hasPrefix("/") {
            var current = ""
            for part in parts {
                current += "/" + part
                directories.insert(current)
            }
        } else {
            var current = ""
            for part in parts {
                current = current.isEmpty ? part : current + "/" + part
                directories.insert(current)
            }
            _ = built
        }
    }

    func removeItem(at url: URL) throws {
        if failNextRemove {
            failNextRemove = false
            throw TestFileError.forced("remove")
        }
        let path = normalize(url.path)
        files = files.filter { key, _ in
            key != path && !key.hasPrefix(path + "/")
        }
        directories = Set(directories.filter { dir in
            dir != path && !dir.hasPrefix(path + "/")
        })
    }

    func contentsOfDirectory(at url: URL) throws -> [URL] {
        let path = normalize(url.path)
        let prefix = path.hasSuffix("/") ? path : path + "/"
        var children: Set<String> = []

        for dir in directories where dir.hasPrefix(prefix) {
            let rest = String(dir.dropFirst(prefix.count))
            if let first = rest.split(separator: "/").first.map(String.init), !first.isEmpty {
                children.insert(prefix + first)
            }
        }
        for file in files.keys where file.hasPrefix(prefix) {
            let rest = String(file.dropFirst(prefix.count))
            if !rest.contains("/"), !rest.isEmpty {
                children.insert(prefix + rest)
            }
        }
        return children.sorted().map { URL(fileURLWithPath: $0) }
    }

    func readData(from url: URL) throws -> Data {
        if failNextRead {
            failNextRead = false
            throw TestFileError.forced("read")
        }
        let path = normalize(url.path)
        guard let data = files[path] else {
            throw TestFileError.forced("not found: \(path)")
        }
        return data
    }

    func writeData(_ data: Data, to url: URL) throws {
        if failNextWrite {
            failNextWrite = false
            throw TestFileError.forced("write")
        }
        let path = normalize(url.path)
        let parent = normalize(URL(fileURLWithPath: path).deletingLastPathComponent().path)
        directories.insert(parent)
        files[path] = data
    }

    /// Seeds raw bytes at a path (for corrupt-file tests).
    func seedFile(at url: URL, data: Data) {
        let path = normalize(url.path)
        let parent = normalize(URL(fileURLWithPath: path).deletingLastPathComponent().path)
        directories.insert(parent)
        files[path] = data
    }

    private func normalize(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}

private enum TestFileError: Error, LocalizedError {
    case forced(String)
    var errorDescription: String? {
        switch self {
        case .forced(let message): return message
        }
    }
}
