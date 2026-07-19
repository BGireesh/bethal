import Foundation

/// Local notification payload for an upcoming meeting.
public struct MeetingReminderNotification: Equatable, Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var eventID: String

    public init(id: String, title: String, body: String, eventID: String) {
        self.id = id
        self.title = title
        self.body = body
        self.eventID = eventID
    }

    public static func forEvent(_ event: CalendarMeetingEvent, minutesBefore: Int) -> MeetingReminderNotification {
        MeetingReminderNotification(
            id: "bethal.meeting.\(event.id)",
            title: "Meeting starting soon",
            body: "\(event.recordingTitle) · start recording in Bethal (1-click). Reminder \(minutesBefore) min before.",
            eventID: event.id
        )
    }
}

public protocol NotificationClient: Sendable {
    func requestAuthorization() async -> Bool
    func postMeetingReminder(_ notification: MeetingReminderNotification) async throws
}

public enum NotificationClientError: Error, Equatable, Sendable, LocalizedError {
    case notAuthorized
    case postFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Notification permission denied."
        case .postFailed(let detail): return detail
        }
    }
}

/// Records notification posts for unit tests.
public final class MockNotificationClient: NotificationClient, @unchecked Sendable {
    public var authorized = true
    public private(set) var posted: [MeetingReminderNotification] = []
    public var postError: Error?
    public private(set) var authRequestCount = 0

    public init(authorized: Bool = true) {
        self.authorized = authorized
    }

    public func requestAuthorization() async -> Bool {
        authRequestCount += 1
        return authorized
    }

    public func postMeetingReminder(_ notification: MeetingReminderNotification) async throws {
        if let postError { throw postError }
        guard authorized else { throw NotificationClientError.notAuthorized }
        posted.append(notification)
    }
}
