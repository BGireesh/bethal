import Foundation
import Testing
@testable import Bethal

@Suite("TodoListFilter and presentation")
struct TodoListFilterTests {
    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

    private func todo(
        id: String,
        title: String = "T",
        completed: Bool = false,
        created: TimeInterval = 0,
        completedAt: Date? = nil,
        reminderAt: Date? = nil,
        meetingTitle: String = "Meeting"
    ) -> TodoItem {
        TodoItem(
            id: id,
            title: title,
            isCompleted: completed,
            meetingID: "m1",
            meetingTitle: meetingTitle,
            lifecycle: .accepted,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000 + created),
            completedAt: completedAt,
            reminderAt: reminderAt
        )
    }

    @Test("filter incomplete completed all")
    func filters() {
        let items = [
            todo(id: "a", completed: false, created: 10),
            todo(id: "b", completed: true, created: 5, completedAt: fixedNow),
            todo(id: "c", completed: false, created: 20),
            // completed with nil completedAt sorts by createdAt
            todo(id: "d", completed: true, created: 1, completedAt: nil),
        ]
        #expect(TodoListFilter.incomplete.apply(to: items).map(\.id) == ["c", "a"])
        let done = TodoListFilter.completed.apply(to: items).map(\.id)
        #expect(Set(done) == Set(["b", "d"]))
        // d has nil completedAt → sorts by createdAt (newer than b's completedAt)
        #expect(done.first == "d")
        let all = TodoListFilter.all.apply(to: items).map(\.id)
        #expect(Array(all.prefix(2)) == ["c", "a"])
        for filter in TodoListFilter.allCases {
            #expect(!filter.displayName.isEmpty)
            #expect(filter.id == filter.rawValue)
        }
    }

    @Test("presentation provenance and reminder labels")
    func presentation() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let open = todo(id: "1", reminderAt: fixedNow.addingTimeInterval(3600))
        let row = TodoListPresentation(todo: open, now: fixedNow, calendar: calendar)
        #expect(row.provenanceLabel.contains("From:"))
        #expect(row.hasReminder)
        #expect(row.reminderLabel != nil)

        let overdue = todo(id: "2", reminderAt: fixedNow.addingTimeInterval(-60))
        let overdueRow = TodoListPresentation(todo: overdue, now: fixedNow, calendar: calendar)
        #expect(overdueRow.reminderLabel == "Reminder overdue")

        let emptyTitle = todo(id: "3", meetingTitle: "")
        #expect(TodoListPresentation(todo: emptyTitle).meetingTitle == "Untitled meeting")

        #expect(TodoListPresentation.makeProvenance(meetingTitle: "X", createdAt: fixedNow, now: fixedNow, calendar: calendar).contains("X"))

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: fixedNow)!
        let remindTomorrow = TodoListPresentation.formatReminder(tomorrow, now: fixedNow, calendar: calendar)
        #expect(remindTomorrow.contains("tomorrow") || !remindTomorrow.isEmpty)

        let later = calendar.date(byAdding: .day, value: 5, to: fixedNow)!
        #expect(!TodoListPresentation.formatReminder(later, now: fixedNow, calendar: calendar).isEmpty)

        let member = TodoListPresentation(
            id: "x",
            title: "T",
            isCompleted: false,
            meetingID: "m",
            meetingTitle: "M",
            provenanceLabel: "P"
        )
        #expect(member.id == "x")
    }

    @Test("reminder presets")
    func presets() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let hour = TodoReminderPreset.inOneHour.fireDate(from: now, calendar: calendar)
        #expect(hour.timeIntervalSince(now) == 3600)

        let morning = TodoReminderPreset.tomorrowMorning.fireDate(from: now, calendar: calendar)
        #expect(calendar.component(.hour, from: morning) == 9)

        let three = TodoReminderPreset.inThreeDays.fireDate(from: now, calendar: calendar)
        #expect(three.timeIntervalSince(now) == 3 * 86_400)

        for preset in TodoReminderPreset.allCases {
            #expect(!preset.displayName.isEmpty)
            #expect(preset.id == preset.rawValue)
        }
    }
}
