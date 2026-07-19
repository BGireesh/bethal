import Foundation
import Testing
@testable import Bethal

@Suite("TranscriptionViewModel")
struct TranscriptionViewModelTests {
    private let fixedNow = Date(timeIntervalSince1970: 4_100_000_000)

    private func makeVM(succeed: Bool = true) throws -> (TranscriptionViewModel, String) {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalTxVM"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs, clock: { fixedNow })
        _ = try store.initialize()
        try store.createMeeting(
            Meeting(
                id: "vm1",
                title: "T",
                status: .captured,
                captureMode: .audioOnly,
                startedAt: fixedNow,
                audioFileName: "audio.m4a",
                createdAt: fixedNow,
                updatedAt: fixedNow
            )
        )
        try fs.writeData(Data("a".utf8), to: store.layout.meetingMediaFile(id: "vm1", fileName: "audio.m4a"))

        let engine: MockTranscriptionEngine
        if succeed {
            engine = MockTranscriptionEngine()
        } else {
            engine = MockTranscriptionEngine(error: TranscriptionError.emptyResult)
        }
        let coordinator = TranscriptionCoordinator(
            engine: engine,
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        return (TranscriptionViewModel(coordinator: coordinator), "vm1")
    }

    @Test("successful transcription updates state")
    func success() async throws {
        let (vm, id) = try makeVM(succeed: true)
        #expect(!vm.isInProgress)
        #expect(vm.canRetry)
        await vm.transcribe(meetingID: id)
        #expect(vm.progress.phase == .completed)
        #expect(vm.lastTranscript != nil)
        #expect(vm.lastError == nil)
        #expect(vm.canRetry)
        #expect(!vm.isInProgress)
    }

    @Test("failure records error and allows retry")
    func failureAndRetry() async throws {
        let (vm, id) = try makeVM(succeed: false)
        await vm.transcribe(meetingID: id)
        #expect(vm.progress.phase == .failed)
        #expect(vm.lastError != nil)
        await vm.retry(meetingID: id)
        #expect(vm.progress.phase == .failed)
    }

    @Test("reset clears state")
    func reset() async throws {
        let (vm, id) = try makeVM()
        await vm.transcribe(meetingID: id)
        vm.reset()
        #expect(vm.progress.phase == .idle)
        #expect(vm.lastTranscript == nil)
        #expect(vm.lastError == nil)
        vm.syncProgress()
        #expect(vm.progress.phase == .idle)
    }
}
