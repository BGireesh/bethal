import Foundation
import Testing
@testable import Bethal

@Suite("SettingsViewModel")
struct SettingsViewModelTests {
    private let fixedNow = Date(timeIntervalSince1970: 2_100_000_000)

    private func seededSession(
        path: String,
        fs: InMemoryFileSystem,
        settings: AppSettings = AppSettings(
            defaultCaptureMode: .audioVideo,
            defaultAIProviderID: "claude",
            askEveryTimeForProvider: false,
            calendarAutoDetectEnabled: true,
            calendarRemindMinutesBefore: 5
        )
    ) throws -> AppSessionStore {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(
            AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path)
        )
        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fs,
            clock: { fixedNow }
        )
        _ = try store.initialize()
        try store.saveSettings(settings)
        return session
    }

    @Test("reload loads settings and display names")
    func reload() throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalSettings"
        let session = try seededSession(path: path, fs: fs)
        let workspace = RecordingWorkspaceOpener()
        let vm = SettingsViewModel(sessionStore: session, fileSystem: fs, workspace: workspace)

        #expect(vm.workingDirectoryPath == path)
        #expect(vm.appSettings.defaultAIProviderID == "claude")
        #expect(vm.defaultProviderDisplayName.contains("Claude"))
        #expect(vm.defaultCaptureModeDisplayName == "Audio + video")
        #expect(vm.calendarSummary.contains("5"))
        #expect(vm.loadError == nil)
    }

    @Test("ask every time display name")
    func askEveryTime() throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalAsk"
        let session = try seededSession(
            path: path,
            fs: fs,
            settings: AppSettings(defaultAIProviderID: nil, askEveryTimeForProvider: true)
        )
        let vm = SettingsViewModel(sessionStore: session, fileSystem: fs, workspace: RecordingWorkspaceOpener())
        #expect(vm.defaultProviderDisplayName == "Ask every time")
    }

    @Test("unknown provider falls back to not set when not ask-every-time")
    func unknownProvider() throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalUnknownProvider"
        // Force unknown id with askEveryTime false via direct store write after init
        let session = try seededSession(path: path, fs: fs)
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs)
        try store.saveSettings(AppSettings(defaultAIProviderID: "mystery", askEveryTimeForProvider: false, calendarAutoDetectEnabled: true, calendarRemindMinutesBefore: 2))
        let vm = SettingsViewModel(sessionStore: session, fileSystem: fs, workspace: RecordingWorkspaceOpener())
        #expect(vm.defaultProviderDisplayName == "Not set")
    }

    @Test("calendar off summary")
    func calendarOff() throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalCalOff"
        let session = try seededSession(
            path: path,
            fs: fs,
            settings: AppSettings(calendarAutoDetectEnabled: false)
        )
        let vm = SettingsViewModel(sessionStore: session, fileSystem: fs, workspace: RecordingWorkspaceOpener())
        #expect(vm.calendarSummary == "Off")
    }

    @Test("missing working directory")
    func missingDirectory() {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let vm = SettingsViewModel(sessionStore: session, fileSystem: InMemoryFileSystem(), workspace: RecordingWorkspaceOpener())
        #expect(vm.loadError != nil)
        #expect(!vm.openWorkingDirectoryInFinder())
        #expect(vm.lastOpenSucceeded == false)
    }

    @Test("uninitialized working directory")
    func uninitialized() throws {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/Users/test/EmptyWD"))
        let vm = SettingsViewModel(
            sessionStore: session,
            fileSystem: InMemoryFileSystem(),
            workspace: RecordingWorkspaceOpener()
        )
        #expect(vm.loadError?.contains("not initialized") == true)
    }

    @Test("open working directory uses workspace")
    func openFinder() throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalOpen"
        let session = try seededSession(path: path, fs: fs)
        let workspace = RecordingWorkspaceOpener(result: true)
        let vm = SettingsViewModel(sessionStore: session, fileSystem: fs, workspace: workspace)
        #expect(vm.openWorkingDirectoryInFinder())
        #expect(workspace.openedURLs.first?.path == path)
        #expect(vm.lastOpenSucceeded == true)
    }

    @Test("resolve working directory via completer")
    func resolveURL() throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalResolveSettings"
        let session = try seededSession(path: path, fs: fs)
        let completer = OnboardingCompleter(
            fileSystem: fs,
            bookmarkClient: PathBookmarkClient(),
            sessionStore: session,
            clock: { fixedNow }
        )
        // Ensure bookmark exists on session
        _ = try completer.complete(directoryURL: URL(fileURLWithPath: path, isDirectory: true), providerID: "grok")
        let vm = SettingsViewModel(
            sessionStore: session,
            fileSystem: fs,
            workspace: RecordingWorkspaceOpener(),
            completer: completer
        )
        let url = try vm.resolvedWorkingDirectoryURL()
        #expect(url?.path == path)
    }

    @Test("default initializer path")
    func defaultInit() {
        let vm = SettingsViewModel(
            sessionStore: AppSessionStore(keyValueStore: InMemoryKeyValueStore()),
            fileSystem: InMemoryFileSystem(),
            workspace: RecordingWorkspaceOpener()
        )
        #expect(vm.appSettings == .default || vm.loadError != nil)
    }

    @Test("corrupt settings file surfaces load error")
    func corruptSettings() throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalCorruptSettings"
        let session = try seededSession(path: path, fs: fs)
        let layout = ProjectLayout(root: URL(fileURLWithPath: path, isDirectory: true))
        fs.seedFile(at: layout.settingsFile, data: Data("not-json".utf8))
        let vm = SettingsViewModel(
            sessionStore: session,
            fileSystem: fs,
            workspace: RecordingWorkspaceOpener()
        )
        #expect(vm.loadError != nil)
        #expect(vm.appSettings == .default)
    }

    @Test("audio only capture display name")
    func audioOnlyDisplay() throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalAudioOnly"
        let session = try seededSession(
            path: path,
            fs: fs,
            settings: AppSettings(defaultCaptureMode: .audioOnly)
        )
        let vm = SettingsViewModel(sessionStore: session, fileSystem: fs, workspace: RecordingWorkspaceOpener())
        #expect(vm.defaultCaptureModeDisplayName == "Audio only")
    }

    @Test("update calendar preferences persists")
    func updateCalendar() throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalCalSettings"
        let session = try seededSession(path: path, fs: fs)
        let vm = SettingsViewModel(sessionStore: session, fileSystem: fs, workspace: RecordingWorkspaceOpener())
        vm.updateCalendarPreferences(enabled: false, minutesBefore: 10)
        #expect(vm.appSettings.calendarAutoDetectEnabled == false)
        #expect(vm.appSettings.calendarRemindMinutesBefore == 10)
        #expect(vm.calendarSummary == "Off")

        vm.updateCalendarPreferences(enabled: true, minutesBefore: 3)
        #expect(vm.calendarSummary.contains("3"))

        let reloaded = try WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fs
        ).loadSettings()
        #expect(reloaded.calendarAutoDetectEnabled)
        #expect(reloaded.calendarRemindMinutesBefore == 3)
    }

    @Test("update calendar without working directory fails soft")
    func updateCalendarNoWD() {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let vm = SettingsViewModel(sessionStore: session, fileSystem: InMemoryFileSystem(), workspace: RecordingWorkspaceOpener())
        vm.updateCalendarPreferences(enabled: true, minutesBefore: 5)
        #expect(vm.loadError != nil)
    }

    @Test("update calendar initializes store when missing schema")
    func updateCalendarInitializes() throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalCalInit"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        // No initialize yet — only path in session
        let vm = SettingsViewModel(sessionStore: session, fileSystem: fs, workspace: RecordingWorkspaceOpener())
        vm.updateCalendarPreferences(enabled: true, minutesBefore: 7)
        #expect(vm.loadError == nil)
        let settings = try WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs).loadSettings()
        #expect(settings.calendarRemindMinutesBefore == 7)
    }

    @Test("persist settings surfaces write failures")
    func persistWriteFailure() throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalCalWriteFail"
        let session = try seededSession(path: path, fs: fs)
        let vm = SettingsViewModel(sessionStore: session, fileSystem: fs, workspace: RecordingWorkspaceOpener())
        fs.failNextWrite = true
        vm.updateCalendarPreferences(enabled: true, minutesBefore: 4)
        #expect(vm.loadError != nil)
    }

    @Test("update AI preferences persists")
    func updateAI() throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalAISettings"
        let session = try seededSession(path: path, fs: fs)
        let registry = AIProviderRegistry(
            locator: MapExecutableLocator(map: [
                "claude": URL(fileURLWithPath: "/usr/local/bin/claude"),
            ]),
            runner: MockProcessRunner()
        )
        let vm = SettingsViewModel(
            sessionStore: session,
            fileSystem: fs,
            workspace: RecordingWorkspaceOpener(),
            registry: registry
        )
        vm.updateAIPreferences(defaultProviderID: "codex", askEveryTime: true)
        #expect(vm.appSettings.defaultAIProviderID == "codex")
        #expect(vm.appSettings.askEveryTimeForProvider)
        #expect(vm.defaultProviderDisplayName.contains("Codex") || vm.defaultProviderDisplayName == "Ask every time")

        vm.updateAIPreferences(defaultProviderID: "not-a-provider", askEveryTime: false)
        #expect(vm.appSettings.defaultAIProviderID == nil)

        vm.refreshDiscoveredProviders()
        #expect(vm.discoveredProviders.count == 3)
        #expect(vm.availableProviderOptions.count == 1)
    }
}
