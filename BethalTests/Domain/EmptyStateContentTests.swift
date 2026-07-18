import Testing
@testable import Bethal

@Suite("EmptyStateContent")
struct EmptyStateContentTests {
    @Test("meetings and todos empty copy")
    func presets() {
        #expect(EmptyStateContent.meetings.title.contains("meetings"))
        #expect(EmptyStateContent.meetings.message.contains("record"))
        #expect(!EmptyStateContent.meetings.systemImage.isEmpty)
        #expect(EmptyStateContent.todos.title.contains("todos"))
        #expect(EmptyStateContent.todos.message.contains("Action"))
        #expect(!EmptyStateContent.todos.systemImage.isEmpty)
    }

    @Test("custom init")
    func custom() {
        let content = EmptyStateContent(title: "T", message: "M", systemImage: "star")
        #expect(content == EmptyStateContent(title: "T", message: "M", systemImage: "star"))
    }
}
