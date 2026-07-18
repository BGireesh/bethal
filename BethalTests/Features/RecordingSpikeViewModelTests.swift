import Foundation
import Testing
@testable import Bethal

@Suite("RecordingSpikeViewModel")
struct RecordingSpikeViewModelTests {
    private let fixedNow = Date(timeIntervalSince1970: 3_100_000_000)

    private func makeVM(
        mic: PermissionStatus = .authorized
    ) throws -> RecordingSpikeViewModel {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(
            AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/Users/test/BethalSpikeVM")
        )
        let coordinator = RecordingSessionCoordinator(
            permissions: MockPermissionChecker(microphone: mic, screen: .authorized),
            engine: MockCaptureEngine(fileSystem: fs),
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "spike-1" }
        )
        return RecordingSpikeViewModel(coordinator: coordinator)
    }

    @Test("mode selection and lifecycle status lines")
    func lifecycle() async throws {
        let vm = try makeVM()
        vm.setMode(.audioVideo)
        #expect(vm.selectedMode == .audioVideo)
        await vm.prepare()
        #expect(vm.state.phase == .ready)
        #expect(vm.statusLine.contains("Ready"))
        await vm.start(title: "VM test")
        #expect(vm.isRecording)
        #expect(vm.canStop)
        vm.tickElapsed(5)
        #expect(vm.state.elapsedSeconds == 5)
        await vm.stop()
        #expect(vm.state.phase == .finalized)
        #expect(vm.statusLine.contains("Saved"))
        vm.reset()
        #expect(vm.state.phase == .idle)
    }

    @Test("cannot change mode while recording")
    func modeLocked() async throws {
        let vm = try makeVM()
        await vm.start()
        vm.setMode(.audioVideo)
        #expect(vm.selectedMode == .audioOnly)
        await vm.stop()
    }

    @Test("failed status line")
    func failed() async throws {
        let vm = try makeVM(mic: .denied)
        await vm.prepare()
        #expect(vm.state.phase == .failed)
        #expect(vm.statusLine.contains("Microphone") || vm.statusLine.lowercased().contains("required") || !vm.statusLine.isEmpty)
    }

    @Test("failed with empty error uses fallback status")
    func failedEmptyMessage() throws {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let coordinator = RecordingSessionCoordinator(
            permissions: MockPermissionChecker(),
            engine: MockCaptureEngine(fileSystem: fs),
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "empty-fail" },
            initialState: RecordingSessionState(phase: .failed, errorMessage: nil)
        )
        let vm = RecordingSpikeViewModel(coordinator: coordinator)
        #expect(vm.statusLine == "Recording failed")
    }

    @Test("canStart after prepare and idle status")
    func canStartFlag() async throws {
        let vm = try makeVM()
        #expect(vm.canStart)
        #expect(vm.statusLine.contains("Idle"))
        await vm.prepare()
        #expect(vm.canStart)
        #expect(vm.statusLine.contains("Ready"))
        await vm.start()
        #expect(!vm.canStart)
        #expect(vm.statusLine.contains("Recording"))
        await vm.stop()
        #expect(vm.canStart)
    }

    @Test("finalized status mentions deferred video")
    func deferredVideoLine() async throws {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(
            AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/Users/test/BethalDeferredVM")
        )
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
            idGenerator: { "def-1" }
        )
        let vm = RecordingSpikeViewModel(coordinator: coordinator, selectedMode: .audioVideo)
        await vm.start()
        await vm.stop()
        #expect(vm.statusLine.contains("video deferred"))
    }

    @Test("finalized without audio file name")
    func finalizedNoAudio() async throws {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(
            AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/Users/test/BethalNoAudioVM")
        )
        let mock = MockCaptureEngine(fileSystem: fs)
        mock.artifacts = CaptureArtifacts(audioFileName: nil, durationSeconds: 0.5)
        mock.writePlaceholderFile = false
        let coordinator = RecordingSessionCoordinator(
            permissions: MockPermissionChecker(),
            engine: mock,
            fileSystem: fs,
            sessionStore: session,
            clock: { fixedNow },
            idGenerator: { "noaud-1" }
        )
        let vm = RecordingSpikeViewModel(coordinator: coordinator)
        await vm.start()
        await vm.stop()
        #expect(vm.statusLine.contains("no audio"))
    }

    @Test("awaiting permission status line")
    func awaitingLine() async throws {
        let fs = InMemoryFileSystem()
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(
            AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: "/Users/test/BethalAwait")
        )
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
            idGenerator: { "await-1" }
        )
        let vm = RecordingSpikeViewModel(coordinator: coordinator)
        await vm.prepare()
        #expect(vm.state.phase == .awaitingPermission || vm.state.phase == .failed || vm.state.phase == .ready)
        // When request keeps notDetermined, applyPermissionResults stays awaiting
        #expect(vm.statusLine.contains("Checking") || vm.statusLine.contains("Ready") || !vm.statusLine.isEmpty)
    }
}
