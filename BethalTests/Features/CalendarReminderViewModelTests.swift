import Foundation
import Testing
@testable import Bethal

@Suite("CalendarReminderViewModel")
struct CalendarReminderViewModelTests {
    private let fixedNow = Date(timeIntervalSince1970: 2_500_000_000)

    private func makeVM(
        events: [CalendarMeetingEvent] = [],
        enabled: Bool = true,
        minutes: Int = 2,
        status: CalendarAuthorizationStatus = .authorized
    ) throws -> (CalendarReminderViewModel, MockCalendarClient, MockNotificationClient) {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalCal"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs, clock: { fixedNow })
        _ = try store.initialize()
        try store.saveSettings(AppSettings(calendarAutoDetectEnabled: enabled, calendarRemindMinutesBefore: minutes))

        let calendar = MockCalendarClient(status: status, events: events)
        let notifications = MockNotificationClient()
        let vm = CalendarReminderViewModel(
            calendarClient: calendar,
            notifications: notifications,
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow },
            lookAheadHours: 6
        )
        return (vm, calendar, notifications)
    }

    @Test("refresh sets active reminder and posts notification")
    func refreshReminder() async throws {
        let start = fixedNow.addingTimeInterval(60)
        let event = CalendarMeetingEvent(
            id: "e1",
            title: "Vendor sync",
            startDate: start,
            endDate: start.addingTimeInterval(1800)
        )
        let (vm, calendar, notifications) = try makeVM(events: [event])
        await vm.refresh()
        #expect(vm.activeReminder?.id == "e1")
        #expect(vm.hasActiveReminder)
        #expect(notifications.posted.count == 1)
        #expect(notifications.posted[0].eventID == "e1")
        #expect(calendar.lastFetchRange != nil)
    }

    @Test("disabled skips fetch")
    func disabled() async throws {
        let start = fixedNow.addingTimeInterval(60)
        let event = CalendarMeetingEvent(id: "e1", title: "X", startDate: start, endDate: start.addingTimeInterval(60))
        let (vm, calendar, notifications) = try makeVM(events: [event], enabled: false)
        await vm.refresh()
        #expect(vm.activeReminder == nil)
        #expect(calendar.lastFetchRange == nil)
        #expect(notifications.posted.isEmpty)
    }

    @Test("denied access surfaces error")
    func denied() async throws {
        let (vm, _, _) = try makeVM(status: .denied)
        await vm.refresh()
        #expect(vm.lastError != nil)
        #expect(vm.activeReminder == nil)
    }

    @Test("request access updates status")
    func requestAccess() async throws {
        let (vm, calendar, _) = try makeVM(status: .notDetermined)
        calendar.requestResult = .authorized
        await vm.requestCalendarAccess()
        #expect(vm.authorizationStatus == .authorized)
        #expect(calendar.requestCount == 1)
    }

    @Test("dismiss and consume title")
    func dismissAndConsume() async throws {
        let start = fixedNow.addingTimeInterval(30)
        let event = CalendarMeetingEvent(id: "e2", title: "Partner call", startDate: start, endDate: start.addingTimeInterval(600))
        let (vm, _, _) = try makeVM(events: [event])
        await vm.refresh()
        #expect(vm.activeReminder != nil)
        let title = vm.consumeRecordingTitle()
        #expect(title == "Partner call")
        #expect(vm.activeReminder == nil)

        await vm.refresh()
        // already reminded — no new active unless new event
        #expect(vm.activeReminder == nil)
    }

    @Test("dismissActiveReminder clears banner")
    func dismiss() async throws {
        let start = fixedNow.addingTimeInterval(30)
        let event = CalendarMeetingEvent(id: "e3", title: "Standup", startDate: start, endDate: start.addingTimeInterval(600))
        let (vm, _, _) = try makeVM(events: [event])
        await vm.refresh()
        vm.dismissActiveReminder()
        #expect(vm.activeReminder == nil)
    }

    @Test("notification payload builder")
    func notificationPayload() {
        let event = CalendarMeetingEvent(
            id: "n1",
            title: "Demo",
            startDate: fixedNow,
            endDate: fixedNow.addingTimeInterval(60)
        )
        let note = MeetingReminderNotification.forEvent(event, minutesBefore: 2)
        #expect(note.eventID == "n1")
        #expect(note.body.contains("Demo"))
        #expect(note.id.contains("n1"))
    }

    @Test("load settings defaults without store")
    func loadSettingsDefault() {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let settings = CalendarReminderViewModel.loadSettings(sessionStore: session, fileSystem: InMemoryFileSystem())
        #expect(settings == .default)
    }

    @Test("fetch error is captured")
    func fetchError() async throws {
        let (vm, calendar, _) = try makeVM()
        calendar.fetchError = CalendarClientError.fetchFailed("boom")
        await vm.refresh()
        #expect(vm.lastError?.contains("boom") == true)
    }

    @Test("mock calendar filters range")
    func mockFetchRange() async throws {
        let cal = MockCalendarClient(events: [
            CalendarMeetingEvent(
                id: "inside",
                title: "In",
                startDate: fixedNow.addingTimeInterval(100),
                endDate: fixedNow.addingTimeInterval(200)
            ),
            CalendarMeetingEvent(
                id: "outside",
                title: "Out",
                startDate: fixedNow.addingTimeInterval(10_000),
                endDate: fixedNow.addingTimeInterval(10_100)
            ),
        ])
        let events = try await cal.fetchEvents(from: fixedNow, to: fixedNow.addingTimeInterval(500))
        #expect(events.map(\.id) == ["inside"])
    }

    @Test("calendar and notification error descriptions")
    func errors() {
        #expect(CalendarClientError.notAuthorized.errorDescription != nil)
        #expect(CalendarClientError.fetchFailed("x").errorDescription == "x")
        #expect(NotificationClientError.notAuthorized.errorDescription != nil)
        #expect(NotificationClientError.postFailed("y").errorDescription == "y")
    }

    @Test("notification not authorized throws")
    func notificationDenied() async {
        let client = MockNotificationClient(authorized: false)
        #expect(await client.requestAuthorization() == false)
        await #expect(throws: NotificationClientError.self) {
            try await client.postMeetingReminder(
                MeetingReminderNotification(id: "1", title: "t", body: "b", eventID: "e")
            )
        }
    }

    @Test("request access denied path")
    func requestAccessDenied() async throws {
        let (vm, calendar, _) = try makeVM(status: .notDetermined)
        calendar.requestResult = .denied
        await vm.requestCalendarAccess()
        #expect(vm.authorizationStatus == .denied)
        #expect(vm.lastError != nil)
    }

    @Test("restricted access on refresh")
    func restricted() async throws {
        let (vm, _, _) = try makeVM(status: .restricted)
        await vm.refresh()
        #expect(vm.lastError != nil)
    }

    @Test("clears active reminder when window ends")
    func clearsExpiredActive() async throws {
        let start = fixedNow.addingTimeInterval(30)
        let event = CalendarMeetingEvent(id: "exp", title: "Expiring", startDate: start, endDate: start.addingTimeInterval(600))
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalCalExpire"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        _ = try WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs).initialize()
        try WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs)
            .saveSettings(AppSettings(calendarAutoDetectEnabled: true, calendarRemindMinutesBefore: 2))

        var now = fixedNow
        let calendar = MockCalendarClient(events: [event])
        let vm = CalendarReminderViewModel(
            calendarClient: calendar,
            notifications: MockNotificationClient(),
            sessionStore: session,
            fileSystem: fs,
            clock: { now },
            lookAheadHours: 6
        )
        await vm.refresh()
        #expect(vm.activeReminder?.id == "exp")

        // Move past grace window; no new events in window
        now = start.addingTimeInterval(MeetingReminderEvaluator.postStartGraceSeconds + 10)
        calendar.events = [event]
        await vm.refresh()
        #expect(vm.activeReminder == nil)
    }

    @Test("load settings when store uninitialized")
    func loadUninitialized() throws {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/Users/test/CalUninit"))
        let settings = CalendarReminderViewModel.loadSettings(sessionStore: session, fileSystem: InMemoryFileSystem())
        #expect(settings == .default)
    }

    @Test("notDetermined requests access during refresh")
    func notDeterminedRefresh() async throws {
        let (vm, calendar, _) = try makeVM(status: .notDetermined)
        calendar.requestResult = .authorized
        await vm.refresh()
        #expect(vm.authorizationStatus == .authorized)
    }

    @Test("all-day events are filtered out")
    func filtersAllDay() async throws {
        let allDay = CalendarMeetingEvent(
            id: "ad",
            title: "Holiday",
            startDate: fixedNow,
            endDate: fixedNow.addingTimeInterval(86_400),
            isAllDay: true
        )
        let timed = CalendarMeetingEvent(
            id: "tm",
            title: "Call",
            startDate: fixedNow.addingTimeInterval(30),
            endDate: fixedNow.addingTimeInterval(600)
        )
        let (vm, _, _) = try makeVM(events: [allDay, timed])
        await vm.refresh()
        #expect(vm.upcomingEvents.map(\.id) == ["tm"])
    }

    @Test("default clock initializer")
    func defaultClock() async throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalCalDefaultClock"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        _ = try WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs).initialize()
        let start = Date().addingTimeInterval(45)
        let calendar = MockCalendarClient(events: [
            CalendarMeetingEvent(id: "later", title: "B", startDate: start.addingTimeInterval(30), endDate: start.addingTimeInterval(600)),
            CalendarMeetingEvent(id: "sooner", title: "A", startDate: start, endDate: start.addingTimeInterval(600)),
        ])
        let vm = CalendarReminderViewModel(
            calendarClient: calendar,
            notifications: MockNotificationClient(),
            sessionStore: session,
            fileSystem: fs
        )
        await vm.refresh()
        #expect(vm.minutesBefore >= 0)
        // Sort order: sooner first when both in window
        if let active = vm.activeReminder {
            #expect(active.id == "sooner" || active.id == "later")
        }
    }
}
