import Foundation
import Testing
@testable import Bethal

@Suite("HomeShellViewModel")
struct HomeShellViewModelTests {
    private let fixedNow = Date(timeIntervalSince1970: 2_200_000_000)

    private func makeEnv(
        path: String = "/Users/test/BethalHome",
        withData: Bool
    ) throws -> (AppSessionStore, InMemoryFileSystem) {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        if withData {
            let store = WorkingDirectoryStore(
                root: URL(fileURLWithPath: path, isDirectory: true),
                fileSystem: fs,
                clock: { fixedNow }
            )
            _ = try store.initialize()
            try store.createMeeting(
                Meeting(
                    id: "m1",
                    title: "Vendor call",
                    status: .captured,
                    captureMode: .audioOnly,
                    startedAt: fixedNow,
                    createdAt: fixedNow,
                    updatedAt: fixedNow
                )
            )
            try store.upsertGlobalTodo(
                TodoItem(
                    id: "t1",
                    title: "Send deck",
                    meetingID: "m1",
                    meetingTitle: "Vendor call",
                    lifecycle: .accepted,
                    createdAt: fixedNow
                )
            )
        }
        return (session, fs)
    }

    @Test("loads meetings and todos from store")
    func loadsData() throws {
        let (session, fs) = try makeEnv(withData: true)
        let settings = SettingsViewModel(sessionStore: session, fileSystem: fs, workspace: RecordingWorkspaceOpener())
        let vm = HomeShellViewModel(sessionStore: session, fileSystem: fs, settings: settings)
        #expect(vm.meetings.count == 1)
        #expect(vm.meetings[0].title == "Vendor call")
        #expect(vm.todos.count == 1)
        #expect(vm.todos[0].title == "Send deck")
        #expect(!vm.showsMeetingsEmpty)
        #expect(!vm.showsTodosEmpty)
        #expect(vm.refreshError == nil)
    }

    @Test("empty states when no data")
    func emptyStates() throws {
        let (session, fs) = try makeEnv(withData: true)
        // Re-init empty store by using fresh fs without meetings... use path with only initialize
        let emptyFS = InMemoryFileSystem()
        let path = "/Users/test/BethalEmptyHome"
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        _ = try WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: emptyFS).initialize()
        let vm = HomeShellViewModel(
            sessionStore: session,
            fileSystem: emptyFS,
            settings: SettingsViewModel(sessionStore: session, fileSystem: emptyFS, workspace: RecordingWorkspaceOpener())
        )
        #expect(vm.showsMeetingsEmpty)
        #expect(vm.showsTodosEmpty)
        #expect(vm.meetingsEmptyState == .meetings)
        #expect(vm.todosEmptyState == .todos)
    }

    @Test("select section updates navigation")
    func selectSection() throws {
        let (session, fs) = try makeEnv(withData: false)
        let vm = HomeShellViewModel(
            sessionStore: session,
            fileSystem: fs,
            settings: SettingsViewModel(sessionStore: session, fileSystem: fs, workspace: RecordingWorkspaceOpener())
        )
        vm.selectSection(.settings)
        #expect(vm.navigation.selectedSection == .settings)
        vm.selectSection(.todos)
        #expect(vm.navigation.selectedSection == .todos)
    }

    @Test("missing working directory surfaces error")
    func missingWD() {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let fs = InMemoryFileSystem()
        let vm = HomeShellViewModel(
            sessionStore: session,
            fileSystem: fs,
            settings: SettingsViewModel(sessionStore: session, fileSystem: fs, workspace: RecordingWorkspaceOpener())
        )
        #expect(vm.refreshError?.contains("not configured") == true)
        #expect(vm.meetings.isEmpty)
    }

    @Test("uninitialized directory surfaces error")
    func uninitialized() throws {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/Users/test/NoInit"))
        let fs = InMemoryFileSystem()
        let vm = HomeShellViewModel(
            sessionStore: session,
            fileSystem: fs,
            settings: SettingsViewModel(sessionStore: session, fileSystem: fs, workspace: RecordingWorkspaceOpener())
        )
        #expect(vm.refreshError?.contains("not initialized") == true)
    }

    @Test("corrupt index surfaces refresh error")
    func corruptIndex() throws {
        let (session, fs) = try makeEnv(withData: true)
        let path = session.load().workingDirectoryPath!
        let layout = ProjectLayout(root: URL(fileURLWithPath: path, isDirectory: true))
        fs.seedFile(at: layout.meetingsIndexFile, data: Data("bad".utf8))
        let vm = HomeShellViewModel(
            sessionStore: session,
            fileSystem: fs,
            settings: SettingsViewModel(sessionStore: session, fileSystem: fs, workspace: RecordingWorkspaceOpener())
        )
        vm.refresh()
        #expect(vm.refreshError != nil)
        #expect(vm.meetings.isEmpty)
    }

    @Test("default settings factory path")
    func defaultSettingsFactory() throws {
        let (session, fs) = try makeEnv(withData: false)
        // Force initialize so settings load cleanly
        let path = session.load().workingDirectoryPath!
        _ = try WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs).initialize()
        let vm = HomeShellViewModel(sessionStore: session, fileSystem: fs)
        #expect(vm.navigation.selectedSection == .meetings)
        #expect(vm.settings.workingDirectoryPath == path)
    }
}
