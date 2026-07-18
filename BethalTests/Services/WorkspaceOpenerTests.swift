import Foundation
import Testing
@testable import Bethal

@Suite("WorkspaceOpener")
struct WorkspaceOpenerTests {
    @Test("recording opener tracks URLs and result")
    func recording() {
        let opener = RecordingWorkspaceOpener(result: true)
        let url = URL(fileURLWithPath: "/tmp/bethal-open", isDirectory: true)
        #expect(opener.open(url))
        #expect(opener.openedURLs.map(\.path) == [url.standardizedFileURL.path])

        let fail = RecordingWorkspaceOpener(result: false)
        #expect(!fail.open(url))
    }

    @Test("finder opener returns bool for existing temp dir")
    func finder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bethal-finder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let opened = FinderWorkspaceOpener().open(root)
        #expect(opened)
    }
}
