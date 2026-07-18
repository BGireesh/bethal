import Foundation
import Testing
@testable import Bethal

@Suite("TodoItem")
struct TodoItemTests {
    @Test("setCompleted stamps and clears completedAt")
    func setCompleted() {
        var todo = TodoItem(
            id: "t1",
            title: "Send deck",
            meetingID: "m1",
            meetingTitle: "Call"
        )
        let when = Date(timeIntervalSince1970: 999)
        todo.setCompleted(true, at: when)
        #expect(todo.isCompleted)
        #expect(todo.completedAt == when)
        todo.setCompleted(false, at: when)
        #expect(!todo.isCompleted)
        #expect(todo.completedAt == nil)
    }

    @Test("acceptedCopy flips lifecycle")
    func acceptedCopy() {
        let proposed = TodoItem(
            id: "t1",
            title: "Follow up",
            meetingID: "m1",
            meetingTitle: "Sync",
            lifecycle: .proposed
        )
        let accepted = proposed.acceptedCopy()
        #expect(accepted.lifecycle == .accepted)
        #expect(accepted.id == proposed.id)
        #expect(proposed.lifecycle == .proposed)
    }

    @Test("TodosDocument and JSON round-trip")
    func documentRoundTrip() throws {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let doc = TodosDocument(todos: [
            TodoItem(
                id: "t1",
                title: "A",
                meetingID: "m",
                meetingTitle: "M",
                lifecycle: .accepted,
                createdAt: created
            ),
        ])
        let data = try JSONCoding.encode(doc)
        let decoded = try JSONCoding.decode(TodosDocument.self, from: data)
        #expect(decoded == doc)
        #expect(TodosDocument().todos.isEmpty)
    }
}
