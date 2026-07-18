import Testing
@testable import Bethal

@Suite("AppSection")
struct AppSectionTests {
    @Test("all cases have titles and symbols")
    func cases() {
        #expect(AppSection.allCases.map(\.rawValue) == ["meetings", "record", "todos", "settings"])
        for section in AppSection.allCases {
            #expect(!section.title.isEmpty)
            #expect(!section.systemImage.isEmpty)
            #expect(section.id == section.rawValue)
            #expect(section.accessibilityLabel == section.title)
        }
    }
}
