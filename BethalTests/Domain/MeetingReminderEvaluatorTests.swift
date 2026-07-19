import Foundation
import Testing
@testable import Bethal

@Suite("MeetingReminderEvaluator")
struct MeetingReminderEvaluatorTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test("window includes lead-up and post-start grace")
    func window() {
        let start = now.addingTimeInterval(120)
        #expect(
            MeetingReminderEvaluator.isWithinReminderWindow(
                eventStart: start,
                now: now,
                minutesBefore: 2
            )
        )
        #expect(
            !MeetingReminderEvaluator.isWithinReminderWindow(
                eventStart: start,
                now: now.addingTimeInterval(-1),
                minutesBefore: 2
            )
        )
        let afterStart = start.addingTimeInterval(60)
        #expect(
            MeetingReminderEvaluator.isWithinReminderWindow(
                eventStart: start,
                now: afterStart,
                minutesBefore: 2
            )
        )
        let tooLate = start.addingTimeInterval(MeetingReminderEvaluator.postStartGraceSeconds + 1)
        #expect(
            !MeetingReminderEvaluator.isWithinReminderWindow(
                eventStart: start,
                now: tooLate,
                minutesBefore: 2
            )
        )
    }

    @Test("filters all-day and already reminded")
    func filters() {
        let start = now.addingTimeInterval(60)
        let later = now.addingTimeInterval(90)
        let events = [
            CalendarMeetingEvent(id: "1", title: "A", startDate: later, endDate: later.addingTimeInterval(1800)),
            CalendarMeetingEvent(id: "2", title: "All day", startDate: start, endDate: start.addingTimeInterval(86400), isAllDay: true),
            CalendarMeetingEvent(id: "3", title: "Done", startDate: start, endDate: start.addingTimeInterval(1800)),
            CalendarMeetingEvent(id: "0", title: "Earlier", startDate: start, endDate: start.addingTimeInterval(1800)),
        ]
        let needing = MeetingReminderEvaluator.eventsNeedingReminder(
            events: events,
            now: now,
            minutesBefore: 5,
            alreadyRemindedIDs: ["3"]
        )
        #expect(needing.map(\.id) == ["0", "1"])
    }

    @Test("remindAt and normalize minutes")
    func helpers() {
        let start = Date(timeIntervalSince1970: 1000)
        #expect(MeetingReminderEvaluator.remindAt(eventStart: start, minutesBefore: 2) == Date(timeIntervalSince1970: 880))
        #expect(MeetingReminderEvaluator.normalizedMinutesBefore(-3) == 0)
        #expect(MeetingReminderEvaluator.normalizedMinutesBefore(5) == 5)
        #expect(MeetingReminderEvaluator.normalizedMinutesBefore(500) == 120)
    }

    @Test("recording title fallback")
    func recordingTitle() {
        let empty = CalendarMeetingEvent(id: "x", title: "  ", startDate: now, endDate: now.addingTimeInterval(1))
        #expect(empty.recordingTitle == "Calendar meeting")
        #expect(empty.durationSeconds == 1)
        let named = CalendarMeetingEvent(id: "y", title: " Sync ", startDate: now, endDate: now.addingTimeInterval(10))
        #expect(named.recordingTitle == "Sync")
    }

    @Test("auth status display")
    func auth() {
        for status in CalendarAuthorizationStatus.allCases {
            #expect(!status.displayName.isEmpty)
        }
        #expect(CalendarAuthorizationStatus.authorized.isUsable)
        #expect(!CalendarAuthorizationStatus.denied.isUsable)
    }
}
