import Foundation
import Testing
@testable import Bethal

@Suite("SchemaMigrator")
struct SchemaMigratorTests {
    private let layout = ProjectLayout(root: URL(fileURLWithPath: "/tmp/bethal-migrate", isDirectory: true))
    private let fs = InMemoryFileSystem()
    private let migrator = SchemaMigrator()

    @Test("current version is a no-op")
    func currentNoOp() throws {
        let manifest = SchemaManifest(schemaVersion: SchemaManifest.currentVersion, createdAt: Date(timeIntervalSince1970: 1))
        let result = try migrator.migrate(manifest: manifest, layout: layout, fileSystem: fs, now: Date(timeIntervalSince1970: 2))
        #expect(result == manifest)
    }

    @Test("migrates from version 0 to current")
    func migrateFromZero() throws {
        let old = SchemaManifest(schemaVersion: 0, createdAt: Date(timeIntervalSince1970: 1))
        let now = Date(timeIntervalSince1970: 99)
        let result = try migrator.migrate(manifest: old, layout: layout, fileSystem: fs, now: now)
        #expect(result.schemaVersion == SchemaManifest.currentVersion)
        #expect(result.createdAt == old.createdAt)
        #expect(result.lastMigratedAt == now)
    }

    @Test("future version is rejected")
    func futureRejected() {
        let future = SchemaManifest(schemaVersion: SchemaManifest.currentVersion + 5, createdAt: Date())
        #expect(throws: StorageError.self) {
            try migrator.migrate(manifest: future, layout: layout, fileSystem: fs)
        }
    }

    @Test("unknown step is rejected")
    func unknownStepRejected() {
        let base = SchemaManifest(schemaVersion: 0, createdAt: Date(timeIntervalSince1970: 1))
        #expect(throws: StorageError.self) {
            try migrator.performStep(to: 99, from: base, now: Date())
        }
    }
}
