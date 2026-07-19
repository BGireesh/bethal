import Foundation

/// Pure scheduling rules for pre-meeting 1-click record reminders.
public enum MeetingReminderEvaluator: Sendable {
    /// Grace period after start during which we still offer 1-click record (late join).
    public static let postStartGraceSeconds: TimeInterval = 15 * 60

    /// Whether `now` falls in the reminder window for an event starting at `start`.
    ///
    /// Window is `[start - minutesBefore, start + postStartGrace]`.
    public static func isWithinReminderWindow(
        eventStart start: Date,
        now: Date,
        minutesBefore: Int,
        postStartGraceSeconds: TimeInterval = postStartGraceSeconds
    ) -> Bool {
        let lead = TimeInterval(max(0, minutesBefore) * 60)
        let windowStart = start.addingTimeInterval(-lead)
        let windowEnd = start.addingTimeInterval(postStartGraceSeconds)
        return now >= windowStart && now <= windowEnd
    }

    /// Filters timed (non-all-day) events that need a reminder and have not been shown yet.
    public static func eventsNeedingReminder(
        events: [CalendarMeetingEvent],
        now: Date,
        minutesBefore: Int,
        alreadyRemindedIDs: Set<String>,
        postStartGraceSeconds: TimeInterval = postStartGraceSeconds
    ) -> [CalendarMeetingEvent] {
        events
            .filter { !$0.isAllDay }
            .filter { !alreadyRemindedIDs.contains($0.id) }
            .filter {
                isWithinReminderWindow(
                    eventStart: $0.startDate,
                    now: now,
                    minutesBefore: minutesBefore,
                    postStartGraceSeconds: postStartGraceSeconds
                )
            }
            .sorted { $0.startDate < $1.startDate }
    }

    /// Absolute time when a reminder should first become eligible.
    public static func remindAt(eventStart: Date, minutesBefore: Int) -> Date {
        eventStart.addingTimeInterval(-TimeInterval(max(0, minutesBefore) * 60))
    }

    /// Normalizes user-facing minutes-before (clamped 0...120).
    public static func normalizedMinutesBefore(_ value: Int) -> Int {
        min(120, max(0, value))
    }
}
