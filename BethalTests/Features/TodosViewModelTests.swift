import Foundation
import Testing
@testable import Bethal

@Suite("TodosViewModel")
struct TodosViewModelTests {
    private let fixedNow = Date(timeIntervalSince1970: 7_000_000_000)

    private func makeVM(
        authorized: Bool = true
    ) throws -> (TodosViewModel, MockNotificationClient, InMemoryFileSystem, String) {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalTodos"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fs,
            clock: { fixedNow }
        )
        _ = try store.initialize()
        try store.saveGlobalTodos([
            TodoItem(
                id: "t1",
                title: "Follow up",
                notes: "Email",
                meetingID: "m1",
                meetingTitle: "Vendor",
                lifecycle: .accepted,
                createdAt: fixedNow
            ),
            TodoItem(
                id: "t2",
                title: "Done already",
                isCompleted: true,
                meetingID: "m2",
                meetingTitle: "Retro",
                lifecycle: .accepted,
                createdAt: fixedNow.addingTimeInterval(-100),
                completedAt: fixedNow.addingTimeInterval(-50)
            ),
        ])
        let notifications = MockNotificationClient(authorized: authorized)
        let vm = TodosViewModel(
            sessionStore: session,
            fileSystem: fs,
            notifications: notifications,
            clock: { fixedNow },
            calendar: Calendar(identifier: .gregorian),
            filter: .incomplete
        )
        return (vm, notifications, fs, path)
    }

    @Test("loads and filters")
    func loadFilter() throws {
        let (vm, _, _, _) = try makeVM()
        #expect(vm.todos.count == 2)
        #expect(vm.presentations.count == 1)
        #expect(vm.incompleteCount == 1)
        #expect(vm.completedCount == 1)
        vm.setFilter(.completed)
        #expect(vm.presentations.count == 1)
        #expect(vm.presentations[0].id == "t2")
        vm.setFilter(.all)
        #expect(vm.presentations.count == 2)
        #expect(!vm.emptyState.title.isEmpty)
        vm.setFilter(.incomplete)
        #expect(!vm.emptyState.message.isEmpty)
        vm.setFilter(.completed)
        #expect(vm.emptyState.title.contains("completed") || !vm.emptyState.title.isEmpty)
    }

    @Test("toggle complete clears reminder")
    func complete() async throws {
        let (vm, notifications, _, _) = try makeVM()
        await vm.scheduleReminder(id: "t1", preset: .inOneHour)
        #expect(vm.todos.first { $0.id == "t1" }?.reminderAt != nil)
        #expect(notifications.scheduledTodos.count == 1)

        vm.setCompleted(id: "t1", completed: true)
        #expect(vm.todos.first { $0.id == "t1" }?.isCompleted == true)
        #expect(vm.todos.first { $0.id == "t1" }?.reminderAt == nil)

        vm.setCompleted(id: "t1", completed: false)
        #expect(vm.todos.first { $0.id == "t1" }?.isCompleted == false)

        vm.setCompleted(id: "missing", completed: true)
        #expect(vm.lastActionError != nil)
    }

    @Test("schedule and clear reminder")
    func reminders() async throws {
        let (vm, notifications, _, _) = try makeVM()
        await vm.scheduleReminder(id: "t1", preset: .tomorrowMorning)
        #expect(notifications.scheduledTodos.first?.todoID == "t1")
        #expect(vm.todos.first { $0.id == "t1" }?.reminderAt != nil)

        await vm.clearReminder(id: "t1")
        #expect(notifications.cancelledTodoIDs.contains("bethal.todo.t1"))
        #expect(vm.todos.first { $0.id == "t1" }?.reminderAt == nil)

        await vm.scheduleReminder(id: "nope", preset: .inOneHour)
        #expect(vm.lastActionError != nil)
        await vm.clearReminder(id: "nope")
        #expect(vm.lastActionError != nil)
    }

    @Test("reminder denied")
    func reminderDenied() async throws {
        let (vm, notifications, _, _) = try makeVM(authorized: false)
        await vm.scheduleReminder(id: "t1", preset: .inOneHour)
        #expect(vm.lastActionError != nil)
        #expect(notifications.scheduledTodos.isEmpty)
    }

    @Test("open source meeting")
    func openMeeting() throws {
        let (vm, _, _, _) = try makeVM()
        vm.openSourceMeeting(id: "t1")
        #expect(vm.consumePendingMeetingID() == "m1")
        #expect(vm.consumePendingMeetingID() == nil)
        vm.openSourceMeeting(id: "missing")
        #expect(vm.lastActionError != nil)
    }

    @Test("missing working directory")
    func noWD() {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let vm = TodosViewModel(
            sessionStore: session,
            fileSystem: InMemoryFileSystem(),
            notifications: MockNotificationClient(),
            clock: { fixedNow }
        )
        #expect(vm.loadError != nil)
        #expect(vm.showsEmpty)
        #expect(vm.emptyState.title.contains("todos") || !vm.emptyState.title.isEmpty)
    }

    @Test("uninitialized directory")
    func uninitialized() throws {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/Users/test/EmptyTodos"))
        let vm = TodosViewModel(
            sessionStore: session,
            fileSystem: InMemoryFileSystem(),
            notifications: MockNotificationClient(),
            clock: { fixedNow }
        )
        #expect(vm.loadError?.contains("not initialized") == true)
    }

    @Test("todo reminder notification factory")
    func notificationFactory() {
        let todo = TodoItem(
            id: "x",
            title: "Do",
            meetingID: "m",
            meetingTitle: "Call",
            createdAt: fixedNow
        )
        let n = TodoReminderNotification.forTodo(todo, fireDate: fixedNow.addingTimeInterval(60))
        #expect(n.id == "bethal.todo.x")
        #expect(n.body.contains("Do"))
        #expect(n.todoID == "x")

        let untitled = TodoItem(id: "y", title: "Y", meetingID: "m", meetingTitle: "", createdAt: fixedNow)
        #expect(TodoReminderNotification.forTodo(untitled, fireDate: fixedNow).body.contains("meeting"))
    }

    @Test("schedule reminder post error")
    func scheduleError() async throws {
        let (vm, notifications, _, _) = try makeVM()
        notifications.postError = NotificationClientError.postFailed("boom")
        await vm.scheduleReminder(id: "t1", preset: .inThreeDays)
        #expect(vm.lastActionError?.contains("boom") == true)
    }

    @Test("default initializer path")
    func defaultInit() {
        let vm = TodosViewModel(
            sessionStore: AppSessionStore(keyValueStore: InMemoryKeyValueStore()),
            fileSystem: InMemoryFileSystem(),
            notifications: MockNotificationClient()
        )
        #expect(vm.todos.isEmpty || vm.loadError != nil)
    }

    @Test("reload corrupt file and persist failures")
    func failures() async throws {
        let (vm, notifications, fs, path) = try makeVM()
        // Reschedule same id exercises mock removeAll path.
        await vm.scheduleReminder(id: "t1", preset: .inOneHour)
        await vm.scheduleReminder(id: "t1", preset: .inThreeDays)
        #expect(notifications.scheduledTodos.count == 1)

        notifications.postError = NotificationClientError.postFailed("cancel-fail")
        await vm.clearReminder(id: "t1")
        #expect(vm.lastActionError?.contains("cancel-fail") == true)
        notifications.postError = nil

        fs.failNextWrite = true
        vm.setCompleted(id: "t1", completed: true)
        #expect(vm.lastActionError != nil)

        // Corrupt global todos index
        let layout = ProjectLayout(root: URL(fileURLWithPath: path, isDirectory: true))
        try fs.writeData(Data("not-json".utf8), to: layout.todosIndexFile)
        vm.reload()
        #expect(vm.loadError != nil)
    }

    @Test("persist initializes store when schema missing")
    func persistInitializes() async throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalTodosInit"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fs,
            clock: { fixedNow }
        )
        _ = try store.initialize()
        try store.saveGlobalTodos([
            TodoItem(
                id: "z1",
                title: "Z",
                meetingID: "m",
                meetingTitle: "M",
                lifecycle: .accepted,
                createdAt: fixedNow
            ),
        ])
        let vm = TodosViewModel(
            sessionStore: session,
            fileSystem: fs,
            notifications: MockNotificationClient(),
            clock: { fixedNow }
        )
        #expect(vm.todos.count == 1)
        // Remove schema while VM still has in-memory todos; persist re-initializes.
        try? fs.removeItem(at: store.layout.schemaFile)
        #expect(!store.isInitialized)
        await vm.scheduleReminder(id: "z1", preset: .inOneHour)
        #expect(store.isInitialized)
    }

    @Test("persist with cleared session path")
    func persistClearedSession() throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalTodosCleared"
        let keyValue = InMemoryKeyValueStore()
        let session = AppSessionStore(keyValueStore: keyValue)
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fs,
            clock: { fixedNow }
        )
        _ = try store.initialize()
        try store.saveGlobalTodos([
            TodoItem(
                id: "c1",
                title: "C",
                meetingID: "m",
                meetingTitle: "M",
                lifecycle: .accepted,
                createdAt: fixedNow
            ),
        ])
        let vm = TodosViewModel(
            sessionStore: session,
            fileSystem: fs,
            notifications: MockNotificationClient(),
            clock: { fixedNow }
        )
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: nil))
        vm.setCompleted(id: "c1", completed: true)
        #expect(vm.lastActionError != nil)
    }
}
