import Testing
@testable import Bethal

@Suite("HomeNavigationState")
struct HomeNavigationStateTests {
    @Test("defaults to meetings")
    func defaults() {
        let state = HomeNavigationState()
        #expect(state.selectedSection == .meetings)
        #expect(state.selectedTitle == "Meetings")
    }

    @Test("select updates section")
    func select() {
        var state = HomeNavigationState()
        state.select(.todos)
        #expect(state.selectedSection == .todos)
        #expect(state.selectedTitle == "Todos")
        state.select(.settings)
        #expect(state.selectedSection == .settings)
    }
}
