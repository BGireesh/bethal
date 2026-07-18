import Foundation
import Testing
@testable import Bethal

@Suite("OnboardingViewModel")
struct OnboardingViewModelTests {
    private let fixedNow = Date(timeIntervalSince1970: 2_000_000_000)

    private func makeViewModel(
        session: AppSessionStore = AppSessionStore(keyValueStore: InMemoryKeyValueStore()),
        fs: InMemoryFileSystem = InMemoryFileSystem()
    ) -> OnboardingViewModel {
        let completer = OnboardingCompleter(
            fileSystem: fs,
            bookmarkClient: PathBookmarkClient(),
            sessionStore: session,
            clock: { fixedNow }
        )
        return OnboardingViewModel(sessionStore: session, completer: completer)
    }

    @Test("fresh install needs onboarding")
    func needsOnboarding() {
        let vm = makeViewModel()
        #expect(vm.needsOnboarding)
        #expect(vm.flow.step == .privacy)
    }

    @Test("completed session starts finished")
    func alreadyCompleted() throws {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(
            AppSessionPreferences(
                hasCompletedOnboarding: true,
                workingDirectoryPath: "/done",
                completedAt: fixedNow
            )
        )
        let vm = makeViewModel(session: session)
        #expect(!vm.needsOnboarding)
        #expect(vm.flow.isComplete)
        #expect(vm.flow.directoryPath == "/done")
    }

    @Test("directory and provider selection")
    func selection() {
        let vm = makeViewModel()
        vm.selectDirectory(url: URL(fileURLWithPath: "/Users/me/Bethal", isDirectory: true))
        #expect(vm.flow.directoryPath?.hasSuffix("/Users/me/Bethal") == true)
        vm.selectProvider(id: "claude")
        #expect(vm.flow.providerID == "claude")
        vm.selectProvider(id: "nope")
        #expect(vm.flow.providerID == nil)
        vm.clearDirectory()
        #expect(vm.flow.directoryPath == nil)
    }

    @Test("wizard navigation and finish")
    func wizardFinish() throws {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let vm = makeViewModel(session: session, fs: fs)

        #expect(vm.continueOrFinish()) // privacy -> directory
        #expect(vm.flow.step == .workingDirectory)

        #expect(!vm.continueOrFinish()) // missing directory
        #expect(vm.flow.errorMessage != nil)

        vm.selectDirectory(url: URL(fileURLWithPath: "/Users/me/BethalData", isDirectory: true))
        #expect(vm.continueOrFinish()) // directory -> provider
        #expect(vm.flow.step == .defaultProvider)

        vm.selectProvider(id: "codex")
        #expect(vm.continueOrFinish()) // finish
        #expect(vm.flow.isComplete)
        #expect(!vm.needsOnboarding)
        #expect(session.load().hasCompletedOnboarding)
        #expect(session.load().workingDirectoryPath?.contains("BethalData") == true)

        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: "/Users/me/BethalData", isDirectory: true),
            fileSystem: fs,
            clock: { fixedNow }
        )
        #expect(store.isInitialized)
        let settings = try store.loadSettings()
        #expect(settings.defaultAIProviderID == "codex")
    }

    @Test("go back works")
    func goBack() {
        let vm = makeViewModel()
        _ = vm.continueOrFinish()
        #expect(vm.flow.step == .workingDirectory)
        #expect(vm.goBack())
        #expect(vm.flow.step == .privacy)
        #expect(!vm.goBack())
    }

    @Test("finish fails without directory via finish()")
    func finishMethodWithoutDirectory() {
        let vm = makeViewModel()
        _ = vm.continueOrFinish() // to directory
        #expect(!vm.finish())
        #expect(vm.flow.step == .workingDirectory)
        #expect(vm.flow.errorMessage != nil)
    }

    @Test("finish surfaces storage errors")
    func finishStorageError() {
        let fs = InMemoryFileSystem()
        let vm = makeViewModel(fs: fs)
        _ = vm.continueOrFinish()
        vm.selectDirectory(url: URL(fileURLWithPath: "/Users/me/BethalFail", isDirectory: true))
        _ = vm.continueOrFinish()
        fs.failNextCreateDirectory = true
        #expect(!vm.finish())
        #expect(vm.flow.errorMessage != nil)
        #expect(!vm.flow.isComplete)
    }

    @Test("continueOrFinish on finished is false")
    func finishedNoop() throws {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/x"))
        let vm = makeViewModel(session: session)
        #expect(!vm.continueOrFinish())
    }

    @Test("reloadSession refreshes from store")
    func reloadSession() throws {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let vm = makeViewModel(session: session)
        #expect(vm.needsOnboarding)
        try session.save(
            AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/reloaded")
        )
        vm.reloadSession()
        #expect(!vm.needsOnboarding)
        #expect(vm.flow.directoryPath == "/reloaded")
    }

    @Test("default completer initializer path")
    func defaultCompleterInit() {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let vm = OnboardingViewModel(sessionStore: session)
        #expect(vm.needsOnboarding)
        #expect(vm.flow.step == .privacy)
    }
}
