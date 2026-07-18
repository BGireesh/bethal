import Foundation
import Testing
@testable import Bethal

@Suite("FoundationFileSystem")
struct FoundationFileSystemTests {
    @Test("create, write, read, list, remove on temp disk")
    func tempDiskRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bethal-fs-\(UUID().uuidString)", isDirectory: true)
        let fs = FoundationFileSystem()
        defer { try? fs.removeItem(at: root) }

        try fs.createDirectory(at: root, withIntermediateDirectories: true)
        #expect(fs.fileExists(atPath: root.path))

        let file = root.appendingPathComponent("note.txt")
        try fs.writeData(Data("hello".utf8), to: file)
        #expect(try fs.readData(from: file) == Data("hello".utf8))

        let children = try fs.contentsOfDirectory(at: root)
        #expect(children.map(\.lastPathComponent).contains("note.txt"))

        try fs.removeItem(at: file)
        #expect(!fs.fileExists(atPath: file.path))
    }
}
