import Foundation
import SwiftUI

/// SwiftUI-facing home shell state.
@MainActor
final class HomeShellController: ObservableObject {
    @Published private(set) var navigation: HomeNavigationState
    @Published private(set) var meetings: [MeetingIndexEntry]
    @Published private(set) var todos: [TodoItem]
    @Published private(set) var refreshError: String?
    @Published private(set) var settingsPath: String?
    @Published private(set) var settingsProvider: String
    @Published private(set) var settingsCaptureMode: String
    @Published private(set) var settingsCalendar: String
    @Published private(set) var settingsLoadError: String?
    @Published private(set) var lastOpenSucceeded: Bool?
    @Published private(set) var activeReminder: CalendarMeetingEvent?
    @Published private(set) var calendarMinutesBefore: Int
    @Published private(set) var calendarAuthLabel: String
    @Published private(set) var calendarError: String?
    @Published var pendingRecordingTitle: String?

    private let viewModel: HomeShellViewModel
    private let calendarReminders: CalendarReminderViewModel

    init(
        viewModel: HomeShellViewModel = HomeShellViewModel(),
        calendarReminders: CalendarReminderViewModel = CalendarReminderViewModel()
    ) {
        self.viewModel = viewModel
        self.calendarReminders = calendarReminders
        self.navigation = viewModel.navigation
        self.meetings = viewModel.meetings
        self.todos = viewModel.todos
        self.refreshError = viewModel.refreshError
        self.settingsPath = viewModel.settings.workingDirectoryPath
        self.settingsProvider = viewModel.settings.defaultProviderDisplayName
        self.settingsCaptureMode = viewModel.settings.defaultCaptureModeDisplayName
        self.settingsCalendar = viewModel.settings.calendarSummary
        self.settingsLoadError = viewModel.settings.loadError
        self.lastOpenSucceeded = viewModel.settings.lastOpenSucceeded
        self.activeReminder = calendarReminders.activeReminder
        self.calendarMinutesBefore = calendarReminders.minutesBefore
        self.calendarAuthLabel = calendarReminders.authorizationStatus.displayName
        self.calendarError = calendarReminders.lastError
        self.pendingRecordingTitle = nil
    }

    var showsMeetingsEmpty: Bool { viewModel.showsMeetingsEmpty }
    var showsTodosEmpty: Bool { viewModel.showsTodosEmpty }
    var meetingsEmptyState: EmptyStateContent { viewModel.meetingsEmptyState }
    var todosEmptyState: EmptyStateContent { viewModel.todosEmptyState }
    var meetingPresentations: [MeetingListPresentation] { viewModel.meetingPresentations }
    var calendarEnabled: Bool { viewModel.settings.appSettings.calendarAutoDetectEnabled }
    var calendarMinutes: Int { viewModel.settings.appSettings.calendarRemindMinutesBefore }

    func select(_ section: AppSection) {
        viewModel.selectSection(section)
        sync()
    }

    func refresh() {
        viewModel.refresh()
        sync()
    }

    func openWorkingDirectory() {
        _ = viewModel.settings.openWorkingDirectoryInFinder()
        sync()
    }

    func updateCalendarPreferences(enabled: Bool, minutesBefore: Int) {
        viewModel.settings.updateCalendarPreferences(enabled: enabled, minutesBefore: minutesBefore)
        calendarReminders.reloadSettings()
        Task { await refreshCalendar() }
        sync()
    }

    func requestCalendarAccess() {
        Task {
            await calendarReminders.requestCalendarAccess()
            sync()
        }
    }

    func refreshCalendar() async {
        await calendarReminders.refresh()
        sync()
    }

    func dismissReminder() {
        calendarReminders.dismissActiveReminder()
        sync()
    }

    func startRecordingFromReminder() {
        pendingRecordingTitle = calendarReminders.consumeRecordingTitle()
        viewModel.selectSection(.record)
        sync()
    }

    func clearPendingRecordingTitle() {
        pendingRecordingTitle = nil
    }

    private func sync() {
        navigation = viewModel.navigation
        meetings = viewModel.meetings
        todos = viewModel.todos
        refreshError = viewModel.refreshError
        settingsPath = viewModel.settings.workingDirectoryPath
        settingsProvider = viewModel.settings.defaultProviderDisplayName
        settingsCaptureMode = viewModel.settings.defaultCaptureModeDisplayName
        settingsCalendar = viewModel.settings.calendarSummary
        settingsLoadError = viewModel.settings.loadError
        lastOpenSucceeded = viewModel.settings.lastOpenSucceeded
        activeReminder = calendarReminders.activeReminder
        calendarMinutesBefore = calendarReminders.minutesBefore
        calendarAuthLabel = calendarReminders.authorizationStatus.displayName
        calendarError = calendarReminders.lastError
    }
}
