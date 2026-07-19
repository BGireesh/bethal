import Foundation
import Testing
@testable import Bethal

@Suite("RecordingSessionCoordinator")
struct RecordingCoordinatorTests {
    private let fixedNow = Date(timeIntervalSince1970: 3_000_000_000)

    private func makeCoordinator(
        path: String = "/Users/test/BethalRec",
        mic: PermissionStatus = .authorized,
        screen: PermissionStatus = .authorized,
        engine: MockCaptureEngine? = nil,
        fs: InMemoryFileSystem = InMemoryFileSystem()
    ) throws -> (RecordingSessionCoordinator, AppSessionStore, MockCaptureEngine, InMemoryFileSystem) {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let mock = engine ?? MockCaptureEngine(fileSystem: fs)
        let permissions = MockPermissionChecker(microphone: mic, screen: screen)
        let coordinator = RecordingSessionCoordinator(
            permissions: permissions,
            engine: mock,
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "rec-meeting-1" }
        )
        return (coordinator, session, mock, fs)
    }

    @Test("prepare authorizes and becomes ready")
    func prepareReady() async throws {
        let (coordinator, _, _, _) = try makeCoordinator()
        await coordinator.prepare(mode: .audioOnly)
        #expect(coordinator.state.phase == .ready)
        #expect(coordinator.state.microphoneStatus == .authorized)
    }

    @Test("prepare requests mic when not determined")
    func prepareRequestMic() async throws {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/Users/test/BethalRec2"))
        let permissions = MockPermissionChecker(
            microphone: .notDetermined,
            screen: .notDetermined,
            microphoneRequestResult: .authorized,
            screenRequestResult: .authorized
        )
        let coordinator = RecordingSessionCoordinator(
            permissions: permissions,
            engine: MockCaptureEngine(fileSystem: fs),
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "id-2" }
        )
        await coordinator.prepare(mode: .audioVideo)
        #expect(permissions.microphoneRequestCount == 1)
        #expect(permissions.screenRequestCount == 1)
        #expect(coordinator.state.phase == .ready)
    }

    @Test("start and stop persist meeting")
    func startStop() async throws {
        let (coordinator, _, mock, fs) = try makeCoordinator()
        await coordinator.prepare(mode: .audioOnly)
        await coordinator.start(title: "Spike call")
        #expect(coordinator.state.phase == .recording)
        #expect(mock.didStart)
        #expect(coordinator.state.meetingID == "rec-meeting-1")

        await coordinator.stop()
        #expect(coordinator.state.phase == .finalized)
        #expect(mock.didStop)

        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: "/Users/test/BethalRec", isDirectory: true),
            fileSystem: fs,
            clock: { fixedNow }
        )
        let meeting = try store.loadMeeting(id: "rec-meeting-1")
        #expect(meeting.status == .captured)
        #expect(meeting.title == "Spike call")
        #expect(meeting.audioFileName == "audio.m4a")
        #expect(fs.fileExists(atPath: store.layout.meetingMediaFile(id: "rec-meeting-1", fileName: "audio.m4a").path))
    }

    @Test("av mode carries deferred video reason")
    func avDeferred() async throws {
        let fs = InMemoryFileSystem()
        let mock = MockCaptureEngine(fileSystem: fs)
        mock.artifacts = CaptureArtifacts(
            audioFileName: "audio.m4a",
            durationSeconds: 2,
            videoDeferredReason: RecordingSpikeDecisions.videoDeferredReason
        )
        let (coordinator, _, _, _) = try makeCoordinator(engine: mock, fs: fs)
        await coordinator.prepare(mode: .audioVideo)
        await coordinator.start()
        await coordinator.stop()
        #expect(coordinator.state.videoDeferredReason != nil)
    }

    @Test("missing working directory fails start")
    func missingWD() async {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let fs = InMemoryFileSystem()
        let coordinator = RecordingSessionCoordinator(
            permissions: MockPermissionChecker(),
            engine: MockCaptureEngine(fileSystem: fs),
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow }
        )
        await coordinator.prepare(mode: .audioOnly)
        await coordinator.start()
        #expect(coordinator.state.phase == .failed)
        #expect(coordinator.state.errorMessage?.contains("Working directory") == true)
    }

    @Test("engine prepare failure fails session")
    func engineFail() async throws {
        let mock = MockCaptureEngine()
        mock.prepareError = CaptureEngineError.ioFailure("disk full")
        let (coordinator, _, _, _) = try makeCoordinator(engine: mock)
        await coordinator.prepare(mode: .audioOnly)
        await coordinator.start()
        #expect(coordinator.state.phase == .failed)
    }

    @Test("mic denied prepare fails")
    func micDenied() async throws {
        let (coordinator, _, _, _) = try makeCoordinator(mic: .denied)
        await coordinator.prepare(mode: .audioOnly)
        #expect(coordinator.state.phase == .failed)
    }

    @Test("reset returns idle")
    func reset() async throws {
        let (coordinator, _, _, _) = try makeCoordinator()
        await coordinator.prepare(mode: .audioOnly)
        coordinator.reset()
        #expect(coordinator.state.phase == .idle)
    }

    @Test("update elapsed while recording")
    func elapsed() async throws {
        let (coordinator, _, _, _) = try makeCoordinator()
        await coordinator.prepare(mode: .audioOnly)
        await coordinator.start()
        coordinator.updateElapsed(to: 42)
        #expect(coordinator.state.elapsedSeconds == 42)
    }

    @Test("sanitize invalid generated id")
    func sanitizeID() async throws {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/Users/test/BethalBadID"))
        let coordinator = RecordingSessionCoordinator(
            permissions: MockPermissionChecker(),
            engine: MockCaptureEngine(fileSystem: fs),
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "has space" }
        )
        await coordinator.prepare(mode: .audioOnly)
        await coordinator.start()
        #expect(coordinator.state.phase == .recording)
        #expect(ProjectLayout.isValidMeetingID(coordinator.state.meetingID ?? ""))
    }

    @Test("sanitize replaces backslash and keeps valid cleaned id")
    func sanitizeBackslash() async throws {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/Users/test/BethalSlashID"))
        let coordinator = RecordingSessionCoordinator(
            permissions: MockPermissionChecker(),
            engine: MockCaptureEngine(fileSystem: fs),
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "a\\b" }
        )
        await coordinator.prepare(mode: .audioOnly)
        await coordinator.start()
        #expect(coordinator.state.meetingID == "a-b")
    }

    @Test("stop while not recording is no-op")
    func stopNoop() async throws {
        let (coordinator, _, _, _) = try makeCoordinator()
        await coordinator.stop()
        #expect(coordinator.state.phase == .idle)
    }

    @Test("stop engine failure fails session")
    func stopEngineFail() async throws {
        let fs = InMemoryFileSystem()
        let mock = MockCaptureEngine(fileSystem: fs)
        mock.stopError = CaptureEngineError.ioFailure("flush failed")
        let (coordinator, _, _, _) = try makeCoordinator(engine: mock, fs: fs)
        await coordinator.prepare(mode: .audioOnly)
        await coordinator.start()
        #expect(coordinator.state.phase == .recording)
        await coordinator.stop()
        #expect(coordinator.state.phase == .failed)
        #expect(coordinator.state.errorMessage != nil)
    }

    @Test("start fails when meeting already exists")
    func duplicateMeeting() async throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalDup"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs, clock: { fixedNow })
        _ = try store.initialize()
        try store.createMeeting(
            Meeting(
                id: "dup-1",
                title: "Existing",
                status: .captured,
                captureMode: .audioOnly,
                startedAt: fixedNow,
                createdAt: fixedNow,
                updatedAt: fixedNow
            )
        )
        let coordinator = RecordingSessionCoordinator(
            permissions: MockPermissionChecker(),
            engine: MockCaptureEngine(fileSystem: fs),
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "dup-1" }
        )
        await coordinator.prepare(mode: .audioOnly)
        await coordinator.start()
        #expect(coordinator.state.phase == .failed)
    }

    @Test("default clock and id generators")
    func defaultGenerators() async throws {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/Users/test/BethalDefGen"))
        let coordinator = RecordingSessionCoordinator(
            permissions: MockPermissionChecker(),
            engine: MockCaptureEngine(fileSystem: fs),
            fileSystem: fs,
            sessionStore: session
        )
        await coordinator.prepare(mode: .audioOnly)
        await coordinator.start()
        #expect(coordinator.state.phase == .recording)
        await coordinator.stop()
        #expect(coordinator.state.phase == .finalized)
    }

    @Test("start fails when ready but mic unusable")
    func startRecordingTransitionFail() async throws {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/Users/test/BethalBadReady"))
        let coordinator = RecordingSessionCoordinator(
            permissions: MockPermissionChecker(microphone: .denied),
            engine: MockCaptureEngine(fileSystem: fs),
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "x1" },
            initialState: RecordingSessionState(phase: .ready, mode: .audioOnly, microphoneStatus: .denied)
        )
        await coordinator.start()
        #expect(coordinator.state.phase == .failed)
        #expect(coordinator.state.errorMessage == "Could not transition into recording.")
    }

    @Test("cancel discards in-progress meeting")
    func cancelSession() async throws {
        let (coordinator, _, mock, fs) = try makeCoordinator(path: "/Users/test/BethalCancel")
        await coordinator.prepare(mode: .audioOnly)
        await coordinator.start(title: "Temp")
        #expect(coordinator.state.phase == .recording)
        #expect(mock.didStart)
        await coordinator.cancel()
        #expect(coordinator.state.phase == .idle)
        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: "/Users/test/BethalCancel", isDirectory: true),
            fileSystem: fs,
            clock: { fixedNow }
        )
        #expect(throws: StorageError.self) {
            _ = try store.loadMeeting(id: "rec-meeting-1")
        }
    }

    @Test("cancel from ready clears session")
    func cancelReady() async throws {
        let (coordinator, _, _, _) = try makeCoordinator(path: "/Users/test/BethalCancelReady")
        await coordinator.prepare(mode: .audioOnly)
        #expect(coordinator.state.phase == .ready)
        await coordinator.cancel()
        #expect(coordinator.state.phase == .idle)
    }

    @Test("cancel from idle is safe")
    func cancelIdle() async throws {
        let (coordinator, _, _, _) = try makeCoordinator(path: "/Users/test/BethalCancelIdle")
        await coordinator.cancel()
        #expect(coordinator.state.phase == .idle)
    }

    @Test("start returns early when permissions leave phase not ready")
    func startNotReady() async throws {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/Users/test/BethalNotReady"))
        let coordinator = RecordingSessionCoordinator(
            permissions: MockPermissionChecker(microphone: .denied),
            engine: MockCaptureEngine(fileSystem: fs),
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "nr1" },
            initialState: RecordingSessionState(phase: .idle, mode: .audioOnly)
        )
        await coordinator.start()
        #expect(coordinator.state.phase == .failed)
    }
}
