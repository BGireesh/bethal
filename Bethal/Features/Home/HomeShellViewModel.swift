import Foundation

/// Coordinates home shell navigation and list data from the working directory.
public final class HomeShellViewModel: @unchecked Sendable {
    public private(set) var navigation: HomeNavigationState
    public private(set) var meetings: [MeetingIndexEntry]
    public private(set) var todos: [TodoItem]
    public private(set) var refreshError: String?
    public let settings: SettingsViewModel

    private let sessionStore: AppSessionStore
    private let fileSystem: FileSystemClient

    public init(
        sessionStore: AppSessionStore = AppSessionStore(),
        fileSystem: FileSystemClient = FoundationFileSystem(),
        settings: SettingsViewModel? = nil,
        navigation: HomeNavigationState = HomeNavigationState()
    ) {
        self.sessionStore = sessionStore
        self.fileSystem = fileSystem
        self.navigation = navigation
        self.meetings = []
        self.todos = []
        if let settings {
            self.settings = settings
        } else {
            self.settings = SettingsViewModel(sessionStore: sessionStore, fileSystem: fileSystem)
        }
        refresh()
    }

    public var meetingsEmptyState: EmptyStateContent { .meetings }
    public var todosEmptyState: EmptyStateContent { .todos }

    public var showsMeetingsEmpty: Bool { meetings.isEmpty }
    public var showsTodosEmpty: Bool { todos.isEmpty }

    public func selectSection(_ section: AppSection) {
        navigation.select(section)
    }

    public func refresh() {
        refreshError = nil
        settings.reload()

        let session = sessionStore.load()
        guard let path = session.workingDirectoryPath, !path.isEmpty else {
            meetings = []
            todos = []
            refreshError = "Working directory is not configured."
            return
        }

        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fileSystem
        )
        guard store.isInitialized else {
            meetings = []
            todos = []
            refreshError = "Working directory is not initialized."
            return
        }

        do {
            meetings = try store.listMeetings()
            todos = try store.loadGlobalTodos()
        } catch {
            meetings = []
            todos = []
            refreshError = error.localizedDescription
        }
    }
}
