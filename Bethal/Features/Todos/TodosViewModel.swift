import Foundation

/// Global todo list: filter, complete, reminders, open source meeting.
public final class TodosViewModel: @unchecked Sendable {
    public private(set) var todos: [TodoItem]
    public private(set) var filter: TodoListFilter
    public private(set) var loadError: String?
    public private(set) var lastActionError: String?
    public private(set) var pendingMeetingID: String?

    private let sessionStore: AppSessionStore
    private let fileSystem: FileSystemClient
    private let notifications: NotificationClient
    private let clock: () -> Date
    private let calendar: Calendar

    public init(
        sessionStore: AppSessionStore = AppSessionStore(),
        fileSystem: FileSystemClient = FoundationFileSystem(),
        notifications: NotificationClient = UserNotificationClient(),
        clock: (() -> Date)? = nil,
        calendar: Calendar = .current,
        filter: TodoListFilter = .incomplete
    ) {
        self.sessionStore = sessionStore
        self.fileSystem = fileSystem
        self.notifications = notifications
        self.clock = clock ?? Date.init
        self.calendar = calendar
        self.filter = filter
        self.todos = []
        self.loadError = nil
        self.lastActionError = nil
        self.pendingMeetingID = nil
        reload()
    }

    public var presentations: [TodoListPresentation] {
        filter.apply(to: todos).map {
            TodoListPresentation(todo: $0, now: clock(), calendar: calendar)
        }
    }

    public var showsEmpty: Bool { presentations.isEmpty }
    public var emptyState: EmptyStateContent {
        switch filter {
        case .incomplete:
            return EmptyStateContent(
                title: "No open todos",
                message: "Accepted action items from meetings show up here. Switch to All or Done to see completed work.",
                systemImage: "checklist"
            )
        case .completed:
            return EmptyStateContent(
                title: "No completed todos",
                message: "Mark todos complete from the Open list.",
                systemImage: "checkmark.circle"
            )
        case .all:
            return .todos
        }
    }

    public var incompleteCount: Int { todos.filter { !$0.isCompleted }.count }
    public var completedCount: Int { todos.filter(\.isCompleted).count }

    public func setFilter(_ filter: TodoListFilter) {
        self.filter = filter
    }

    public func reload() {
        loadError = nil
        let session = sessionStore.load()
        guard let path = session.workingDirectoryPath, !path.isEmpty else {
            todos = []
            loadError = "Working directory is not configured."
            return
        }
        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fileSystem,
            clock: clock
        )
        guard store.isInitialized else {
            todos = []
            loadError = "Working directory is not initialized."
            return
        }
        do {
            todos = try store.loadGlobalTodos()
        } catch {
            todos = []
            loadError = error.localizedDescription
        }
    }

    public func setCompleted(id: String, completed: Bool) {
        lastActionError = nil
        guard var todo = todos.first(where: { $0.id == id }) else {
            lastActionError = "Todo not found."
            return
        }
        todo.setCompleted(completed, at: clock())
        if completed {
            // Clear reminder when done.
            todo.reminderAt = nil
            Task { try? await notifications.cancelTodoReminder(id: "bethal.todo.\(id)") }
        }
        persist(todo)
    }

    public func scheduleReminder(id: String, preset: TodoReminderPreset) async {
        lastActionError = nil
        guard var todo = todos.first(where: { $0.id == id }) else {
            lastActionError = "Todo not found."
            return
        }
        let fireDate = preset.fireDate(from: clock(), calendar: calendar)
        let authorized = await notifications.requestAuthorization()
        guard authorized else {
            lastActionError = NotificationClientError.notAuthorized.localizedDescription
            return
        }
        do {
            let payload = TodoReminderNotification.forTodo(todo, fireDate: fireDate)
            try await notifications.scheduleTodoReminder(payload)
            todo.reminderAt = fireDate
            persist(todo)
        } catch {
            lastActionError = error.localizedDescription
        }
    }

    public func clearReminder(id: String) async {
        lastActionError = nil
        guard var todo = todos.first(where: { $0.id == id }) else {
            lastActionError = "Todo not found."
            return
        }
        do {
            try await notifications.cancelTodoReminder(id: "bethal.todo.\(id)")
            todo.reminderAt = nil
            persist(todo)
        } catch {
            lastActionError = error.localizedDescription
        }
    }

    /// Records intent to open the source meeting (Home shell navigates / opens review).
    public func openSourceMeeting(id todoID: String) {
        lastActionError = nil
        guard let todo = todos.first(where: { $0.id == todoID }) else {
            lastActionError = "Todo not found."
            return
        }
        pendingMeetingID = todo.meetingID
    }

    public func consumePendingMeetingID() -> String? {
        let id = pendingMeetingID
        pendingMeetingID = nil
        return id
    }

    private func persist(_ todo: TodoItem) {
        do {
            let store = try makeStore()
            try store.upsertGlobalTodo(todo)
            todos = try store.loadGlobalTodos()
        } catch {
            lastActionError = error.localizedDescription
            reload()
        }
    }

    private func makeStore() throws -> WorkingDirectoryStore {
        let session = sessionStore.load()
        guard let path = session.workingDirectoryPath, !path.isEmpty else {
            throw StorageError.notInitialized
        }
        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fileSystem,
            clock: clock
        )
        if !store.isInitialized {
            _ = try store.initialize()
        }
        return store
    }
}
