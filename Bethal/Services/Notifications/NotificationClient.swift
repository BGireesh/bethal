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

/// Local notification payload for a todo reminder.
public struct TodoReminderNotification: Equatable, Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var todoID: String
    public var fireDate: Date

    public init(id: String, title: String, body: String, todoID: String, fireDate: Date) {
        self.id = id
        self.title = title
        self.body = body
        self.todoID = todoID
        self.fireDate = fireDate
    }

    public static func forTodo(_ todo: TodoItem, fireDate: Date) -> TodoReminderNotification {
        TodoReminderNotification(
            id: "bethal.todo.\(todo.id)",
            title: "Todo reminder",
            body: "\(todo.title) · from \(todo.meetingTitle.isEmpty ? "a meeting" : todo.meetingTitle)",
            todoID: todo.id,
            fireDate: fireDate
        )
    }
}

public protocol NotificationClient: Sendable {
    func requestAuthorization() async -> Bool
    func postMeetingReminder(_ notification: MeetingReminderNotification) async throws
    func scheduleTodoReminder(_ notification: TodoReminderNotification) async throws
    func cancelTodoReminder(id: String) async throws
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
    public private(set) var scheduledTodos: [TodoReminderNotification] = []
    public private(set) var cancelledTodoIDs: [String] = []
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

    public func scheduleTodoReminder(_ notification: TodoReminderNotification) async throws {
        if let postError { throw postError }
        guard authorized else { throw NotificationClientError.notAuthorized }
        scheduledTodos.removeAll { $0.id == notification.id }
        scheduledTodos.append(notification)
    }

    public func cancelTodoReminder(id: String) async throws {
        if let postError { throw postError }
        cancelledTodoIDs.append(id)
        scheduledTodos.removeAll { $0.id == id }
    }
}
