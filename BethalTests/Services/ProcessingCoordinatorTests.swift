import Foundation
import Testing
@testable import Bethal

@Suite("ProcessingCoordinator")
struct ProcessingCoordinatorTests {
    private let fixedNow = Date(timeIntervalSince1970: 5_200_000_000)

    private func seeded(
        status: MeetingStatus = .transcribed,
        withTranscript: Bool = true,
        transcriptText: String = "Hello world from the call."
    ) throws -> (AppSessionStore, InMemoryFileSystem, String) {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalAI"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs, clock: { fixedNow })
        _ = try store.initialize()
        try store.createMeeting(
            Meeting(
                id: "m-ai-1",
                title: "Vendor sync",
                status: status,
                captureMode: .audioOnly,
                startedAt: fixedNow,
                audioFileName: "audio.m4a",
                createdAt: fixedNow,
                updatedAt: fixedNow
            )
        )
        if withTranscript {
            try store.saveTranscript(
                Transcript(
                    meetingID: "m-ai-1",
                    languageCode: "en-US",
                    segments: [
                        TranscriptSegment(id: "s1", startSeconds: 0, endSeconds: 1, text: transcriptText),
                    ],
                    createdAt: fixedNow
                )
            )
        }
        return (session, fs, path)
    }

    private func makeCoordinator(
        session: AppSessionStore,
        fs: InMemoryFileSystem,
        stdout: String = #"{"summaryMarkdown":"Summary","todos":[{"title":"Send notes"}]}"#,
        exitCode: Int32 = 0
    ) -> ProcessingCoordinator {
        let runner = MockProcessRunner(
            result: ProcessRunResult(exitCode: exitCode, standardOutput: stdout, standardError: exitCode == 0 ? "" : "err")
        )
        let locator = MapExecutableLocator(map: [
            "claude": URL(fileURLWithPath: "/usr/local/bin/claude"),
            "codex": URL(fileURLWithPath: "/usr/local/bin/codex"),
            "grok": URL(fileURLWithPath: "/usr/local/bin/grok"),
        ])
        let registry = AIProviderRegistry(locator: locator, runner: runner, clock: { fixedNow })
        return ProcessingCoordinator(
            registry: registry,
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
    }

    @Test("process saves summary todos and status")
    func success() async throws {
        let (session, fs, path) = try seeded()
        let coordinator = makeCoordinator(session: session, fs: fs)
        let result = try await coordinator.processMeeting(id: "m-ai-1", providerID: "claude")
        #expect(result.summaryMarkdown == "Summary")
        #expect(result.proposedTodos.count == 1)
        #expect(coordinator.progress.phase == .completed)

        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs)
        let meeting = try store.loadMeeting(id: "m-ai-1")
        #expect(meeting.status == .processedPendingReview)
        #expect(try store.loadSummary(meetingID: "m-ai-1") == "Summary")
        let todos = try store.loadProposedTodos(meetingID: "m-ai-1")
        #expect(todos.count == 1)
    }

    @Test("missing working directory")
    func noWD() async {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let coordinator = makeCoordinator(session: session, fs: InMemoryFileSystem())
        await #expect(throws: AIProviderError.self) {
            _ = try await coordinator.processMeeting(id: "x", providerID: "claude")
        }
        #expect(coordinator.progress.phase == .failed)
    }

    @Test("missing transcript fails")
    func noTranscript() async throws {
        let (session, fs, path) = try seeded(withTranscript: false)
        let coordinator = makeCoordinator(session: session, fs: fs)
        await #expect(throws: AIProviderError.self) {
            _ = try await coordinator.processMeeting(id: "m-ai-1", providerID: "claude")
        }
        let meeting = try WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fs
        ).loadMeeting(id: "m-ai-1")
        #expect(meeting.status == .failed)
    }

    @Test("empty transcript fails")
    func emptyTranscript() async throws {
        let (session, fs, _) = try seeded(transcriptText: "   ")
        let coordinator = makeCoordinator(session: session, fs: fs)
        await #expect(throws: AIProviderError.self) {
            _ = try await coordinator.processMeeting(id: "m-ai-1", providerID: "claude")
        }
    }

    @Test("captured is not eligible")
    func captured() async throws {
        let (session, fs, _) = try seeded(status: .captured)
        let coordinator = makeCoordinator(session: session, fs: fs)
        await #expect(throws: AIProviderError.self) {
            _ = try await coordinator.processMeeting(id: "m-ai-1", providerID: "claude")
        }
    }

    @Test("capturing not eligible")
    func capturing() throws {
        let meeting = Meeting(
            id: "a",
            title: "t",
            status: .capturing,
            captureMode: .audioOnly,
            startedAt: fixedNow
        )
        #expect(throws: AIProviderError.self) {
            try ProcessingCoordinator.validateEligible(meeting)
        }
        var transcribed = meeting
        transcribed.status = .transcribed
        try ProcessingCoordinator.validateEligible(transcribed)
    }

    @Test("engine failure marks failed")
    func engineFail() async throws {
        let (session, fs, path) = try seeded()
        let coordinator = makeCoordinator(session: session, fs: fs, stdout: "", exitCode: 7)
        await #expect(throws: Error.self) {
            _ = try await coordinator.processMeeting(id: "m-ai-1", providerID: "claude")
        }
        let meeting = try WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fs
        ).loadMeeting(id: "m-ai-1")
        #expect(meeting.status == .failed)
        #expect(meeting.failureReason != nil)
    }

    @Test("selection decision and discover")
    func selection() throws {
        let (session, fs, path) = try seeded()
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs)
        try store.saveSettings(AppSettings(defaultAIProviderID: "claude", askEveryTimeForProvider: false))
        let coordinator = makeCoordinator(session: session, fs: fs)
        let decision = coordinator.selectionDecision(settings: try store.loadSettings())
        #expect(decision == .useDefault(providerID: "claude"))
        #expect(coordinator.discoverProviders().count == 3)
        coordinator.resetProgress()
        #expect(coordinator.progress.phase == .idle)
    }

    @Test("initialize if needed then missing meeting")
    func initIfNeeded() async {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalAIInit"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try? session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let coordinator = makeCoordinator(session: session, fs: fs)
        await #expect(throws: Error.self) {
            _ = try await coordinator.processMeeting(id: "missing", providerID: "claude")
        }
        #expect(WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs).isInitialized)
    }

    @Test("default clock initializer")
    func defaultClock() throws {
        let locator = MapExecutableLocator(map: ["claude": URL(fileURLWithPath: "/usr/local/bin/claude")])
        let registry = AIProviderRegistry(locator: locator, runner: MockProcessRunner())
        _ = ProcessingCoordinator(registry: registry)
    }
}
