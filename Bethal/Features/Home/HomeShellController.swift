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

    private let viewModel: HomeShellViewModel

    init(viewModel: HomeShellViewModel = HomeShellViewModel()) {
        self.viewModel = viewModel
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
    }

    var showsMeetingsEmpty: Bool { viewModel.showsMeetingsEmpty }
    var showsTodosEmpty: Bool { viewModel.showsTodosEmpty }
    var meetingsEmptyState: EmptyStateContent { viewModel.meetingsEmptyState }
    var todosEmptyState: EmptyStateContent { viewModel.todosEmptyState }

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
    }
}
