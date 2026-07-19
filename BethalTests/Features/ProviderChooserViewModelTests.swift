import Foundation
import Testing
@testable import Bethal

@Suite("ProviderChooserViewModel")
struct ProviderChooserViewModelTests {
    private let fixedNow = Date(timeIntervalSince1970: 5_300_000_000)

    private func makeVM(
        askEveryTime: Bool = true,
        defaultID: String? = "claude",
        available: Bool = true,
        stdout: String = #"{"summaryMarkdown":"S","todos":[]}"#
    ) throws -> (ProviderChooserViewModel, String) {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalChooser"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs, clock: { fixedNow })
        _ = try store.initialize()
        try store.saveSettings(
            AppSettings(defaultAIProviderID: defaultID, askEveryTimeForProvider: askEveryTime)
        )
        try store.createMeeting(
            Meeting(
                id: "c1",
                title: "T",
                status: .transcribed,
                captureMode: .audioOnly,
                startedAt: fixedNow,
                createdAt: fixedNow,
                updatedAt: fixedNow
            )
        )
        try store.saveTranscript(
            Transcript(
                meetingID: "c1",
                segments: [TranscriptSegment(id: "s", startSeconds: 0, endSeconds: 1, text: "Hello")],
                createdAt: fixedNow
            )
        )

        var map: [String: URL] = [:]
        if available {
            map["claude"] = URL(fileURLWithPath: "/usr/local/bin/claude")
        }
        let runner = MockProcessRunner(result: ProcessRunResult(exitCode: 0, standardOutput: stdout))
        let registry = AIProviderRegistry(
            locator: MapExecutableLocator(map: map),
            runner: runner,
            clock: { fixedNow }
        )
        let coordinator = ProcessingCoordinator(
            registry: registry,
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        return (ProviderChooserViewModel(coordinator: coordinator, sessionStore: session, fileSystem: fs), "c1")
    }

    @Test("ask every time enters chooser")
    func chooser() async throws {
        let (vm, id) = try makeVM(askEveryTime: true)
        await vm.begin(meetingID: id)
        #expect(vm.progress.phase == .choosingProvider)
        #expect(vm.preferredProviderID == "claude")
        #expect(!vm.showsEmptyState)
    }

    @Test("use default runs immediately")
    func autoRun() async throws {
        let (vm, id) = try makeVM(askEveryTime: false)
        await vm.begin(meetingID: id)
        #expect(vm.progress.phase == .completed)
        #expect(vm.lastResult != nil)
        #expect(vm.lastError == nil)
        #expect(vm.preferredProviderID == "claude")
    }

    @Test("none available fails with how-to")
    func noneAvailable() async throws {
        let (vm, id) = try makeVM(available: false)
        await vm.begin(meetingID: id)
        #expect(vm.progress.phase == .failed)
        #expect(vm.showsEmptyState)
        #expect(vm.lastError != nil)
        #expect(!vm.emptyStateHowTo.isEmpty)
        #expect(vm.preferredProviderID == nil)
        await vm.retry()
        #expect(vm.progress.phase == .failed)
        vm.showChooserAgain()
        #expect(vm.progress.phase == .failed)
    }

    @Test("select provider from chooser")
    func select() async throws {
        let (vm, id) = try makeVM(askEveryTime: true)
        await vm.begin(meetingID: id)
        await vm.selectProvider(id: "claude")
        #expect(vm.progress.phase == .completed)
        #expect(vm.lastResult?.providerID == "claude")
    }

    @Test("retry and reset")
    func retryReset() async throws {
        let (vm, id) = try makeVM(askEveryTime: false)
        await vm.begin(meetingID: id)
        await vm.retry()
        #expect(vm.progress.phase == .completed)
        vm.showChooserAgain()
        #expect(vm.progress.phase == .choosingProvider)
        vm.reset()
        #expect(vm.progress.phase == .idle)
        #expect(vm.activeMeetingID == nil)
        vm.syncProgress()
    }

    @Test("select without active meeting is no-op")
    func noActive() async throws {
        let (vm, _) = try makeVM()
        await vm.selectProvider(id: "claude")
        #expect(vm.progress.phase == .idle)
        await vm.retry()
        #expect(vm.progress.phase == .idle)
        vm.showChooserAgain()
        #expect(vm.progress.phase == .idle)
    }

    @Test("loadSettings falls back without working directory")
    func noWorkingDirectory() async {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let registry = AIProviderRegistry(
            locator: MapExecutableLocator(map: ["claude": URL(fileURLWithPath: "/bin/claude")]),
            runner: MockProcessRunner(result: ProcessRunResult(exitCode: 0, standardOutput: #"{"summaryMarkdown":"S","todos":[]}"#))
        )
        let coordinator = ProcessingCoordinator(registry: registry, sessionStore: session, fileSystem: InMemoryFileSystem())
        let vm = ProviderChooserViewModel(coordinator: coordinator, sessionStore: session, fileSystem: InMemoryFileSystem())
        await vm.begin(meetingID: "x")
        // ask every time default → chooser; default AppSettings askEveryTime true
        #expect(vm.progress.phase == .choosingProvider)
    }

    @Test("loadSettings falls back when settings corrupt")
    func corruptSettings() async throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalChooserCorrupt"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs, clock: { fixedNow })
        _ = try store.initialize()
        try fs.writeData(Data("not-json".utf8), to: store.layout.settingsFile)
        let registry = AIProviderRegistry(
            locator: MapExecutableLocator(map: ["claude": URL(fileURLWithPath: "/bin/claude")]),
            runner: MockProcessRunner()
        )
        let coordinator = ProcessingCoordinator(registry: registry, sessionStore: session, fileSystem: fs, clock: { fixedNow })
        let vm = ProviderChooserViewModel(coordinator: coordinator, sessionStore: session, fileSystem: fs)
        await vm.begin(meetingID: "any")
        #expect(vm.progress.phase == .choosingProvider)
    }

    @Test("run failure records lastError")
    func runFailure() async throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalChooserFail"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs, clock: { fixedNow })
        _ = try store.initialize()
        try store.saveSettings(AppSettings(defaultAIProviderID: "claude", askEveryTimeForProvider: false))
        try store.createMeeting(
            Meeting(
                id: "fail1",
                title: "T",
                status: .transcribed,
                captureMode: .audioOnly,
                startedAt: fixedNow,
                createdAt: fixedNow,
                updatedAt: fixedNow
            )
        )
        try store.saveTranscript(
            Transcript(
                meetingID: "fail1",
                segments: [TranscriptSegment(id: "s", startSeconds: 0, endSeconds: 1, text: "Hi")],
                createdAt: fixedNow
            )
        )
        let runner = MockProcessRunner(result: ProcessRunResult(exitCode: 9, standardOutput: "", standardError: "boom"))
        let registry = AIProviderRegistry(
            locator: MapExecutableLocator(map: ["claude": URL(fileURLWithPath: "/bin/claude")]),
            runner: runner,
            clock: { fixedNow }
        )
        let coordinator = ProcessingCoordinator(registry: registry, sessionStore: session, fileSystem: fs, clock: { fixedNow })
        let vm = ProviderChooserViewModel(coordinator: coordinator, sessionStore: session, fileSystem: fs)
        await vm.begin(meetingID: "fail1")
        #expect(vm.progress.phase == .failed)
        #expect(vm.lastError != nil)
    }
}
