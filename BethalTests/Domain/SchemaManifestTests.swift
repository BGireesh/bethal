import Foundation
import Testing
@testable import Bethal

@Suite("SchemaManifest")
struct SchemaManifestTests {
    @Test("current version is positive")
    func currentVersion() {
        #expect(SchemaManifest.currentVersion >= 1)
    }

    @Test("JSON round-trip")
    func jsonRoundTrip() throws {
        let manifest = SchemaManifest(
            schemaVersion: 1,
            createdAt: Date(timeIntervalSince1970: 10),
            lastMigratedAt: Date(timeIntervalSince1970: 20)
        )
        let data = try JSONCoding.encode(manifest)
        let decoded = try JSONCoding.decode(SchemaManifest.self, from: data)
        #expect(decoded == manifest)
    }
}
