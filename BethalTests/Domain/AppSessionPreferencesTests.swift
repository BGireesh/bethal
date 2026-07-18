import Foundation
import Testing
@testable import Bethal

@Suite("AppSessionPreferences")
struct AppSessionPreferencesTests {
    @Test("empty defaults")
    func empty() {
        let prefs = AppSessionPreferences.empty
        #expect(!prefs.hasCompletedOnboarding)
        #expect(!prefs.hasUsableWorkingDirectory)
    }

    @Test("usable when completed with path")
    func usable() {
        let prefs = AppSessionPreferences(
            hasCompletedOnboarding: true,
            workingDirectoryPath: "/tmp/bethal",
            workingDirectoryBookmarkData: Data([1, 2, 3]),
            completedAt: Date(timeIntervalSince1970: 10)
        )
        #expect(prefs.hasUsableWorkingDirectory)
    }

    @Test("JSON round-trip")
    func jsonRoundTrip() throws {
        let prefs = AppSessionPreferences(
            hasCompletedOnboarding: true,
            workingDirectoryPath: "/Users/me/Bethal",
            workingDirectoryBookmarkData: Data("bookmark".utf8),
            completedAt: Date(timeIntervalSince1970: 50)
        )
        let data = try JSONCoding.encode(prefs)
        let decoded = try JSONCoding.decode(AppSessionPreferences.self, from: data)
        #expect(decoded == prefs)
    }
}
