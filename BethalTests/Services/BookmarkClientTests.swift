import Foundation
import Testing
@testable import Bethal

@Suite("BookmarkClient")
struct BookmarkClientTests {
    @Test("path bookmark round-trip")
    func pathBookmark() throws {
        let client = PathBookmarkClient()
        let url = URL(fileURLWithPath: "/Users/test/BethalData", isDirectory: true)
        let data = try client.bookmark(for: url)
        let resolved = try client.resolveBookmark(data)
        #expect(resolved.url.standardizedFileURL.path == url.standardizedFileURL.path)
        #expect(!resolved.isStale)
    }

    @Test("path bookmark rejects empty payload")
    func pathEmpty() {
        let client = PathBookmarkClient()
        #expect(throws: BookmarkError.self) {
            _ = try client.resolveBookmark(Data())
        }
    }

    @Test("security-scoped bookmark on temp directory")
    func securityScopedTemp() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bethal-bookmark-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let client = SecurityScopedBookmarkClient()
        let data = try client.bookmark(for: root)
        let resolved = try client.resolveBookmark(data)
        #expect(resolved.url.standardizedFileURL.path == root.standardizedFileURL.path)
    }

    @Test("bookmark error descriptions")
    func errorDescriptions() {
        #expect(BookmarkError.creationFailed("x").errorDescription?.contains("x") == true)
        #expect(BookmarkError.resolutionFailed("y").errorDescription?.contains("y") == true)
    }

    @Test("security-scoped resolve rejects garbage data")
    func securityScopedGarbage() {
        let client = SecurityScopedBookmarkClient()
        #expect(throws: BookmarkError.self) {
            _ = try client.resolveBookmark(Data([0x00, 0x01, 0x02]))
        }
    }

    @Test("security-scoped bookmark creation failure path")
    func securityScopedCreateFailure() {
        // Relative file URLs without a resolvable base can fail bookmark creation.
        let client = SecurityScopedBookmarkClient()
        let bad = URL(string: "file://")!
        #expect(throws: BookmarkError.self) {
            _ = try client.bookmark(for: bad)
        }
    }
}
