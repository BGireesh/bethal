import Foundation
import Testing
@testable import Bethal

@Suite("OnboardingCompleter")
struct OnboardingCompleterTests {
    private let fixedNow = Date(timeIntervalSince1970: 1_900_000_000)

    private func makeCompleter(
        fs: InMemoryFileSystem = InMemoryFileSystem(),
        session: AppSessionStore? = nil
    ) -> (OnboardingCompleter, AppSessionStore, InMemoryFileSystem) {
        let sessionStore = session ?? AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let completer = OnboardingCompleter(
            fileSystem: fs,
            bookmarkClient: PathBookmarkClient(),
            sessionStore: sessionStore,
            clock: { fixedNow }
        )
        return (completer, sessionStore, fs)
    }

    @Test("complete initializes store and saves session with provider")
    func completeWithProvider() throws {
        let (completer, sessionStore, fs) = makeCompleter()
        let root = URL(fileURLWithPath: "/Users/test/BethalOnboard", isDirectory: true)
        let prefs = try completer.complete(directoryURL: root, providerID: "claude")

        #expect(prefs.hasCompletedOnboarding)
        #expect(prefs.workingDirectoryPath == root.standardizedFileURL.path)
        #expect(prefs.workingDirectoryBookmarkData != nil)
        #expect(prefs.completedAt == fixedNow)
        #expect(sessionStore.load() == prefs)
        #expect(fs.fileExists(atPath: ProjectLayout(root: root).schemaFile.path))

        let store = WorkingDirectoryStore(root: root, fileSystem: fs, clock: { fixedNow })
        let settings = try store.loadSettings()
        #expect(settings.defaultAIProviderID == "claude")
        #expect(settings.askEveryTimeForProvider == false)
    }

    @Test("complete without provider asks every time")
    func completeWithoutProvider() throws {
        let (completer, _, fs) = makeCompleter()
        let root = URL(fileURLWithPath: "/Users/test/BethalAsk", isDirectory: true)
        _ = try completer.complete(directoryURL: root, providerID: nil)
        let settings = try WorkingDirectoryStore(root: root, fileSystem: fs, clock: { fixedNow }).loadSettings()
        #expect(settings.defaultAIProviderID == nil)
        #expect(settings.askEveryTimeForProvider)
    }

    @Test("unknown provider id treated as ask every time")
    func unknownProvider() throws {
        let (completer, _, fs) = makeCompleter()
        let root = URL(fileURLWithPath: "/Users/test/BethalUnknown", isDirectory: true)
        _ = try completer.complete(directoryURL: root, providerID: "not-a-tool")
        let settings = try WorkingDirectoryStore(root: root, fileSystem: fs, clock: { fixedNow }).loadSettings()
        #expect(settings.defaultAIProviderID == nil)
        #expect(settings.askEveryTimeForProvider)
    }

    @Test("resolve working directory prefers bookmark")
    func resolveDirectory() throws {
        let (completer, _, _) = makeCompleter()
        let root = URL(fileURLWithPath: "/Users/test/BethalResolve", isDirectory: true)
        let prefs = try completer.complete(directoryURL: root, providerID: "grok")
        let resolved = try completer.resolveWorkingDirectory(from: prefs)
        #expect(resolved?.path == root.standardizedFileURL.path)
    }

    @Test("resolve falls back to path when bookmark missing")
    func resolvePathFallback() throws {
        let (completer, _, _) = makeCompleter()
        let prefs = AppSessionPreferences(
            hasCompletedOnboarding: true,
            workingDirectoryPath: "/fallback/path",
            workingDirectoryBookmarkData: nil
        )
        let resolved = try completer.resolveWorkingDirectory(from: prefs)
        #expect(resolved?.path == "/fallback/path")
    }

    @Test("resolve returns nil when nothing stored")
    func resolveNil() throws {
        let (completer, _, _) = makeCompleter()
        let resolved = try completer.resolveWorkingDirectory(from: .empty)
        #expect(resolved == nil)
    }

    @Test("default clock initializer is usable")
    func defaultClock() throws {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let completer = OnboardingCompleter(
            fileSystem: fs,
            bookmarkClient: PathBookmarkClient(),
            sessionStore: session
        )
        let root = URL(fileURLWithPath: "/Users/test/BethalDefaultClock", isDirectory: true)
        let prefs = try completer.complete(directoryURL: root, providerID: nil)
        #expect(prefs.hasCompletedOnboarding)
        #expect(prefs.completedAt != nil)
    }
}
