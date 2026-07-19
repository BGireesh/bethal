import Foundation
import UserNotifications

/// Production local notifications via `UserNotifications`.
public final class UserNotificationClient: NotificationClient, @unchecked Sendable {
    public static let startRecordingActionID = "START_RECORDING"
    public static let categoryID = "MEETING_REMINDER"

    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        Self.registerCategories(center: center)
    }

    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    public func postMeetingReminder(_ notification: MeetingReminderNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        content.userInfo = ["eventID": notification.eventID, "recordingTitle": notification.body]

        let request = UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: nil
        )
        try await center.add(request)
    }

    public func scheduleTodoReminder(_ notification: TodoReminderNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.userInfo = ["todoID": notification.todoID]

        let interval = max(1, notification.fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    public func cancelTodoReminder(id: String) async throws {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    private static func registerCategories(center: UNUserNotificationCenter) {
        let start = UNNotificationAction(
            identifier: startRecordingActionID,
            title: "Start recording",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [start],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }
}
