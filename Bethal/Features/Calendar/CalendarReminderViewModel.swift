import Foundation

/// Orchestrates calendar polling, reminder eligibility, notifications, and in-app banner state.
public final class CalendarReminderViewModel: @unchecked Sendable {
    public private(set) var authorizationStatus: CalendarAuthorizationStatus
    public private(set) var activeReminder: CalendarMeetingEvent?
    public private(set) var upcomingEvents: [CalendarMeetingEvent]
    public private(set) var lastError: String?
    public private(set) var isEnabled: Bool
    public private(set) var minutesBefore: Int
    public private(set) var alreadyRemindedIDs: Set<String>

    private let calendarClient: CalendarClient
    private let notifications: NotificationClient
    private let sessionStore: AppSessionStore
    private let fileSystem: FileSystemClient
    private let clock: () -> Date
    private let lookAheadHours: Int

    public init(
        calendarClient: CalendarClient = EventKitCalendarClient(),
        notifications: NotificationClient = UserNotificationClient(),
        sessionStore: AppSessionStore = AppSessionStore(),
        fileSystem: FileSystemClient = FoundationFileSystem(),
        clock: @escaping () -> Date = Date.init,
        lookAheadHours: Int = 12
    ) {
        self.calendarClient = calendarClient
        self.notifications = notifications
        self.sessionStore = sessionStore
        self.fileSystem = fileSystem
        self.clock = clock
        self.lookAheadHours = max(1, lookAheadHours)
        self.authorizationStatus = calendarClient.authorizationStatus()
        self.activeReminder = nil
        self.upcomingEvents = []
        self.lastError = nil
        self.alreadyRemindedIDs = []
        let settings = Self.loadSettings(sessionStore: sessionStore, fileSystem: fileSystem)
        self.isEnabled = settings.calendarAutoDetectEnabled
        self.minutesBefore = MeetingReminderEvaluator.normalizedMinutesBefore(settings.calendarRemindMinutesBefore)
    }

    public var hasActiveReminder: Bool { activeReminder != nil }

    public func reloadSettings() {
        let settings = Self.loadSettings(sessionStore: sessionStore, fileSystem: fileSystem)
        isEnabled = settings.calendarAutoDetectEnabled
        minutesBefore = MeetingReminderEvaluator.normalizedMinutesBefore(settings.calendarRemindMinutesBefore)
    }

    public func requestCalendarAccess() async {
        authorizationStatus = await calendarClient.requestAccess()
        if authorizationStatus.isUsable {
            lastError = nil
            await refresh()
        } else {
            lastError = "Calendar access denied. Enable it in System Settings → Privacy → Calendars."
        }
    }

    /// Fetches upcoming events and updates the active in-app reminder (never auto-starts recording).
    public func refresh() async {
        reloadSettings()
        lastError = nil
        guard isEnabled else {
            upcomingEvents = []
            return
        }

        authorizationStatus = calendarClient.authorizationStatus()
        if authorizationStatus == .notDetermined {
            authorizationStatus = await calendarClient.requestAccess()
        }
        guard authorizationStatus.isUsable else {
            upcomingEvents = []
            if authorizationStatus == .denied || authorizationStatus == .restricted {
                lastError = "Calendar access is not available."
            }
            return
        }

        let now = clock()
        let end = now.addingTimeInterval(TimeInterval(lookAheadHours * 3600))
        do {
            let events = try await calendarClient.fetchEvents(from: now.addingTimeInterval(-30 * 60), to: end)
            upcomingEvents = events
                .filter { !$0.isAllDay }
                .sorted { $0.startDate < $1.startDate }

            let needing = MeetingReminderEvaluator.eventsNeedingReminder(
                events: upcomingEvents,
                now: now,
                minutesBefore: minutesBefore,
                alreadyRemindedIDs: alreadyRemindedIDs
            )

            if let next = needing.first {
                activeReminder = next
                alreadyRemindedIDs.insert(next.id)
                _ = await notifications.requestAuthorization()
                let payload = MeetingReminderNotification.forEvent(next, minutesBefore: minutesBefore)
                try? await notifications.postMeetingReminder(payload)
            } else if let active = activeReminder,
                      !MeetingReminderEvaluator.isWithinReminderWindow(
                        eventStart: active.startDate,
                        now: now,
                        minutesBefore: minutesBefore
                      ) {
                activeReminder = nil
            }
        } catch {
            lastError = error.localizedDescription
            upcomingEvents = []
        }
    }

    public func dismissActiveReminder() {
        if let id = activeReminder?.id {
            alreadyRemindedIDs.insert(id)
        }
        activeReminder = nil
    }

    /// Title to prefill when the user taps 1-click start.
    public func consumeRecordingTitle() -> String? {
        guard let event = activeReminder else { return nil }
        alreadyRemindedIDs.insert(event.id)
        let title = event.recordingTitle
        activeReminder = nil
        return title
    }

    public static func loadSettings(
        sessionStore: AppSessionStore,
        fileSystem: FileSystemClient
    ) -> AppSettings {
        let session = sessionStore.load()
        guard let path = session.workingDirectoryPath, !path.isEmpty else {
            return .default
        }
        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fileSystem
        )
        guard store.isInitialized, let settings = try? store.loadSettings() else {
            return .default
        }
        return settings
    }
}
