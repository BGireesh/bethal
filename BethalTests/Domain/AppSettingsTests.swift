import Foundation
import Testing
@testable import Bethal

@Suite("AppSettings")
struct AppSettingsTests {
    @Test("defaults match product expectations")
    func defaults() {
        let settings = AppSettings.default
        #expect(settings.defaultCaptureMode == .audioOnly)
        #expect(settings.defaultAIProviderID == nil)
        #expect(settings.askEveryTimeForProvider)
        #expect(settings.calendarAutoDetectEnabled)
        #expect(settings.calendarRemindMinutesBefore == 2)
    }

    @Test("JSON round-trip preserves custom values")
    func jsonRoundTrip() throws {
        let settings = AppSettings(
            defaultCaptureMode: .audioVideo,
            defaultAIProviderID: "grok",
            askEveryTimeForProvider: false,
            calendarAutoDetectEnabled: false,
            calendarRemindMinutesBefore: 5
        )
        let data = try JSONCoding.encode(settings)
        let decoded = try JSONCoding.decode(AppSettings.self, from: data)
        #expect(decoded == settings)
    }
}
