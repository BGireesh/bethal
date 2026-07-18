import Foundation
import Testing
@testable import Bethal

@Suite("ProjectLayout")
struct ProjectLayoutTests {
    private var root: URL {
        URL(fileURLWithPath: "/Users/example/Documents/BethalData", isDirectory: true)
    }

    @Test("standardizes root URL")
    func standardizesRoot() {
        let layout = ProjectLayout(root: URL(fileURLWithPath: "/Users/example/./Documents/BethalData", isDirectory: true))
        #expect(layout.root.path.contains("Documents/BethalData"))
        #expect(!layout.root.path.contains("/./"))
    }

    @Test("exposes marker, meetings, index, and exports directories")
    func childDirectories() {
        let layout = ProjectLayout(root: root)
        #expect(layout.markerDirectory.lastPathComponent == ".bethal")
        #expect(layout.meetingsDirectory.lastPathComponent == "meetings")
        #expect(layout.indexDirectory.lastPathComponent == "index")
        #expect(layout.exportsDirectory.lastPathComponent == "exports")
        #expect(layout.markerDirectory.path.hasPrefix(root.path))
    }

    @Test("meeting directory nests under meetings")
    func meetingDirectory() {
        let layout = ProjectLayout(root: root)
        let meeting = layout.meetingDirectory(id: "abc-123")
        #expect(meeting.lastPathComponent == "abc-123")
        #expect(meeting.deletingLastPathComponent().lastPathComponent == "meetings")
    }

    @Test("relativePath returns path under root")
    func relativePathUnderRoot() {
        let layout = ProjectLayout(root: root)
        let child = root.appendingPathComponent("meetings/foo", isDirectory: true)
        #expect(layout.relativePath(for: child) == "meetings/foo")
        #expect(layout.relativePath(for: root) == "")
    }

    @Test("relativePath returns nil outside root")
    func relativePathOutsideRoot() {
        let layout = ProjectLayout(root: root)
        let other = URL(fileURLWithPath: "/tmp/other", isDirectory: true)
        #expect(layout.relativePath(for: other) == nil)
    }

    @Test("isValidMeetingID accepts UUID-like and slug ids")
    func validMeetingIDs() {
        #expect(ProjectLayout.isValidMeetingID("a1b2c3d4-e5f6-7890-abcd-ef1234567890"))
        #expect(ProjectLayout.isValidMeetingID("meeting_2026-07-18"))
        #expect(ProjectLayout.isValidMeetingID("abc"))
    }

    @Test("isValidMeetingID rejects empty, path traversal, and separators")
    func invalidMeetingIDs() {
        #expect(!ProjectLayout.isValidMeetingID(""))
        #expect(!ProjectLayout.isValidMeetingID("."))
        #expect(!ProjectLayout.isValidMeetingID(".."))
        #expect(!ProjectLayout.isValidMeetingID("a/b"))
        #expect(!ProjectLayout.isValidMeetingID("a\\b"))
        #expect(!ProjectLayout.isValidMeetingID(String(repeating: "x", count: 129)))
        #expect(!ProjectLayout.isValidMeetingID("has space"))
    }

    @Test("equatable compares root")
    func equatable() {
        let a = ProjectLayout(root: root)
        let b = ProjectLayout(root: root)
        let c = ProjectLayout(root: URL(fileURLWithPath: "/tmp", isDirectory: true))
        #expect(a == b)
        #expect(a != c)
    }
}
