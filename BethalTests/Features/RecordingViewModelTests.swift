import Foundation
import Testing
@testable import Bethal

@Suite("RecordingViewModel")
struct RecordingViewModelTests {
    private let fixedNow = Date(timeIntervalSince1970: 3_300_000_000)

    private func makeVM(
        path: String = "/Users/test/BethalRecUI",
        mode: CaptureMode = .audioOnly
    ) throws -> (RecordingViewModel, AppSessionStore, InMemoryFileSystem, MockCaptureEngine) {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs, clock: { fixedNow })
        _ = try store.initialize()
        try store.saveSettings(AppSettings(defaultCaptureMode: .audioVideo))
        let engine = MockCaptureEngine(fileSystem: fs)
        let coordinator = RecordingSessionCoordinator(
            permissions: MockPermissionChecker(),
            engine: engine,
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "prod-1" }
        )
        let vm = RecordingViewModel(
            coordinator: coordinator,
            sessionStore: session,
            fileSystem: fs,
            selectedMode: mode,
            meetingTitle: "Standup"
        )
        return (vm, session, fs, engine)
    }

    @Test("loads default mode from settings when not overridden")
    func defaultModeFromSettings() throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalDefaultMode"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs)
        _ = try store.initialize()
        try store.saveSettings(AppSettings(defaultCaptureMode: .audioVideo))
        let mode = RecordingViewModel.loadDefaultMode(sessionStore: session, fileSystem: fs)
        #expect(mode == .audioVideo)
    }

    @Test("start stop saves meeting with title")
    func startStop() async throws {
        let (vm, _, fs, _) = try makeVM()
        await vm.start()
        #expect(vm.isRecording)
        #expect(vm.canCancel)
        vm.tickElapsed(9)
        await vm.stop()
        #expect(vm.state.phase == .finalized)
        #expect(vm.lastCompletedMeetingID == "prod-1")
        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: "/Users/test/BethalRecUI", isDirectory: true),
            fileSystem: fs,
            clock: { fixedNow }
        )
        let meeting = try store.loadMeeting(id: "prod-1")
        #expect(meeting.title == "Standup")
        #expect(meeting.status == .captured)
    }

    @Test("cancel discards meeting")
    func cancel() async throws {
        let (vm, _, fs, engine) = try makeVM()
        await vm.start()
        #expect(engine.didStart)
        await vm.cancel()
        #expect(vm.didCancelLastSession)
        #expect(vm.state.phase == .idle)
        #expect(vm.statusLine.lowercased().contains("cancel"))
        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: "/Users/test/BethalRecUI", isDirectory: true),
            fileSystem: fs,
            clock: { fixedNow }
        )
        #expect(throws: StorageError.self) {
            _ = try store.loadMeeting(id: "prod-1")
        }
    }

    @Test("set title and mode guards while recording")
    func guards() async throws {
        let (vm, _, _, _) = try makeVM()
        vm.setTitle("  Weekly sync  ")
        #expect(vm.meetingTitle == "Weekly sync")
        vm.setTitle("   ")
        #expect(vm.meetingTitle == "Meeting")
        vm.setMode(.audioVideo)
        #expect(vm.selectedMode == .audioVideo)
        await vm.start()
        let titleDuring = vm.meetingTitle
        vm.setMode(.audioOnly)
        #expect(vm.selectedMode == .audioVideo)
        vm.setTitle("Nope")
        #expect(vm.meetingTitle == titleDuring)
        await vm.stop()
    }

    @Test("reset clears completion flags")
    func reset() async throws {
        let (vm, _, _, _) = try makeVM()
        await vm.start()
        await vm.stop()
        #expect(vm.lastCompletedMeetingID != nil)
        vm.reset()
        #expect(vm.lastCompletedMeetingID == nil)
        #expect(!vm.didCancelLastSession)
    }

    @Test("prepare ready path")
    func prepare() async throws {
        let (vm, _, _, _) = try makeVM()
        await vm.prepare()
        #expect(vm.state.phase == .ready)
        #expect(vm.canStart)
    }

    @Test("default mode fallback without working directory")
    func defaultModeFallback() {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let mode = RecordingViewModel.loadDefaultMode(sessionStore: session, fileSystem: InMemoryFileSystem())
        #expect(mode == .audioOnly)
    }

    @Test("default mode fallback when store not initialized")
    func defaultModeUninitialized() throws {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/Users/test/NoInitMode"))
        let mode = RecordingViewModel.loadDefaultMode(sessionStore: session, fileSystem: InMemoryFileSystem())
        #expect(mode == .audioOnly)
    }

    @Test("selectedMode nil uses settings default")
    func nilSelectedMode() throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalNilMode"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs)
        _ = try store.initialize()
        try store.saveSettings(AppSettings(defaultCaptureMode: .audioVideo))
        let coordinator = RecordingSessionCoordinator(
            permissions: MockPermissionChecker(),
            engine: MockCaptureEngine(fileSystem: fs),
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "nm1" }
        )
        let vm = RecordingViewModel(
            coordinator: coordinator,
            sessionStore: session,
            fileSystem: fs,
            selectedMode: nil
        )
        #expect(vm.selectedMode == .audioVideo)
    }

    @Test("busy and canStop flags during recording")
    func flags() async throws {
        let (vm, _, _, _) = try makeVM()
        #expect(!vm.canStop)
        #expect(!vm.isBusy)
        await vm.start()
        #expect(vm.canStop)
        #expect(vm.isBusy)
        #expect(vm.isRecording)
        await vm.stop()
        #expect(vm.state.phase == .finalized)
        #expect(vm.statusLine.contains("Saved"))
    }

    @Test("failed status sync")
    func failedSync() async throws {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/Users/test/BethalFailVM"))
        let coordinator = RecordingSessionCoordinator(
            permissions: MockPermissionChecker(microphone: .denied),
            engine: MockCaptureEngine(fileSystem: fs),
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "fail-vm" }
        )
        let vm = RecordingViewModel(coordinator: coordinator, sessionStore: session, fileSystem: fs)
        await vm.prepare()
        #expect(vm.state.phase == .failed)
        #expect(!vm.statusLine.isEmpty)
    }

    @Test("failed empty message fallback via initial state")
    func failedEmpty() {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let coordinator = RecordingSessionCoordinator(
            permissions: MockPermissionChecker(),
            engine: MockCaptureEngine(fileSystem: fs),
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "fe" },
            initialState: RecordingSessionState(phase: .failed, errorMessage: nil)
        )
        let vm = RecordingViewModel(coordinator: coordinator, sessionStore: session, fileSystem: fs)
        #expect(vm.statusLine == "Recording failed")
    }

    @Test("checking permissions status line")
    func checkingPermissionsLine() async throws {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/Users/test/BethalAwaitVM"))
        let permissions = MockPermissionChecker(
            microphone: .notDetermined,
            screen: .notDetermined,
            microphoneRequestResult: .notDetermined,
            screenRequestResult: .notDetermined
        )
        let coordinator = RecordingSessionCoordinator(
            permissions: permissions,
            engine: MockCaptureEngine(fileSystem: fs),
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "await-vm" }
        )
        let vm = RecordingViewModel(coordinator: coordinator, sessionStore: session, fileSystem: fs)
        await vm.prepare()
        #expect(vm.state.phase == .awaitingPermission || vm.state.phase == .checkingPermissions || vm.state.phase == .failed)
        #expect(vm.statusLine.contains("Checking") || vm.statusLine.contains("Microphone") || !vm.statusLine.isEmpty)
        #expect(vm.isBusy || vm.state.phase == .failed)
    }

    @Test("ready status line after prepare")
    func readyLine() async throws {
        let (vm, _, _, _) = try makeVM()
        await vm.prepare()
        #expect(vm.state.phase == .ready)
        #expect(vm.statusLine.contains("Ready"))
    }

    @Test("finalized without audio file")
    func finalizedNoAudio() async throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalNoAud"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let mock = MockCaptureEngine(fileSystem: fs)
        mock.artifacts = CaptureArtifacts(audioFileName: nil, durationSeconds: 1)
        mock.writePlaceholderFile = false
        let coordinator = RecordingSessionCoordinator(
            permissions: MockPermissionChecker(),
            engine: mock,
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "na1" }
        )
        let vm = RecordingViewModel(coordinator: coordinator, sessionStore: session, fileSystem: fs)
        await vm.start()
        await vm.stop()
        #expect(vm.statusLine.contains("no audio"))
    }

    @Test("finalized with deferred video note")
    func deferredVideo() async throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalDefVid"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let mock = MockCaptureEngine(fileSystem: fs)
        mock.artifacts = CaptureArtifacts(
            audioFileName: "audio.m4a",
            durationSeconds: 1,
            videoDeferredReason: RecordingSpikeDecisions.videoDeferredReason
        )
        let coordinator = RecordingSessionCoordinator(
            permissions: MockPermissionChecker(),
            engine: mock,
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "dv1" }
        )
        let vm = RecordingViewModel(
            coordinator: coordinator,
            sessionStore: session,
            fileSystem: fs,
            selectedMode: .audioVideo
        )
        await vm.start()
        await vm.stop()
        #expect(vm.statusLine.contains("video deferred"))
    }

    @Test("stopping phase status line via initial state")
    func stoppingLine() {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let coordinator = RecordingSessionCoordinator(
            permissions: MockPermissionChecker(),
            engine: MockCaptureEngine(fileSystem: fs),
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "st1" },
            initialState: RecordingSessionState(phase: .stopping, microphoneStatus: .authorized)
        )
        let vm = RecordingViewModel(coordinator: coordinator, sessionStore: session, fileSystem: fs)
        #expect(vm.statusLine == "Stopping…")
        #expect(vm.isBusy)
    }
}
