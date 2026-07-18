import Testing
@testable import Bethal

@Suite("AppIdentity")
struct AppIdentityTests {
    @Test("display name is Bethal")
    func displayName() {
        #expect(AppIdentity.displayName == "Bethal")
    }

    @Test("bundle identifier matches package id")
    func bundleIdentifier() {
        #expect(AppIdentity.bundleIdentifier == "us.gireesh.bethal")
    }

    @Test("tagline describes on-device product")
    func tagline() {
        #expect(AppIdentity.tagline.contains("On-device"))
        #expect(AppIdentity.tagline.lowercased().contains("meeting"))
    }

    @Test("version is semver-shaped")
    func version() {
        let parts = AppIdentity.version.split(separator: ".")
        #expect(parts.count == 3)
        #expect(parts.allSatisfy { Int($0) != nil })
    }

    @Test("default window size is positive")
    func defaultWindowSize() {
        #expect(AppIdentity.defaultWindowWidth > 0)
        #expect(AppIdentity.defaultWindowHeight > 0)
    }

    @Test("working directory marker is hidden folder name")
    func workingDirectoryMarker() {
        #expect(AppIdentity.workingDirectoryMarker == ".bethal")
        #expect(AppIdentity.workingDirectoryMarker.hasPrefix("."))
    }

    @Test("diagnostic label includes name, version, and bundle id")
    func diagnosticLabel() {
        let label = AppIdentity.diagnosticLabel
        #expect(label.contains(AppIdentity.displayName))
        #expect(label.contains(AppIdentity.version))
        #expect(label.contains(AppIdentity.bundleIdentifier))
    }
}
