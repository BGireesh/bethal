import Foundation

/// A calendar event that may represent an upcoming meeting.
public struct CalendarMeetingEvent: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var calendarTitle: String?
    public var location: String?
    public var isAllDay: Bool

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        calendarTitle: String? = nil,
        location: String? = nil,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendarTitle = calendarTitle
        self.location = location
        self.isAllDay = isAllDay
    }

    /// Title suitable for a recording session (falls back when empty).
    public var recordingTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Calendar meeting" : trimmed
    }

    public var durationSeconds: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }
}
