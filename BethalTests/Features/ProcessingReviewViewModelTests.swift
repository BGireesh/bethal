import Foundation
import Testing
@testable import Bethal

@Suite("ProcessingReviewViewModel")
struct ProcessingReviewViewModelTests {
    private let fixedNow = Date(timeIntervalSince1970: 6_200_000_000)

    private func makeVM() throws -> (ProcessingReviewViewModel, String) {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalReviewVM"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fs,
            clock: { fixedNow }
        )
        _ = try store.initialize()
        try store.createMeeting(
            Meeting(
                id: "vm-rev",
                title: "Sync",
                status: .processedPendingReview,
                captureMode: .audioOnly,
                startedAt: fixedNow,
                createdAt: fixedNow,
                updatedAt: fixedNow
            )
        )
        try store.saveSummary("Summary text", meetingID: "vm-rev")
        try store.saveTranscript(
            Transcript(
                meetingID: "vm-rev",
                segments: [TranscriptSegment(id: "s", startSeconds: 0, endSeconds: 1, text: "Body")],
                createdAt: fixedNow
            )
        )
        try store.saveProposedTodos(
            [
                TodoItem(
                    id: "c1",
                    title: "Todo A",
                    meetingID: "vm-rev",
                    meetingTitle: "Sync",
                    lifecycle: .proposed,
                    createdAt: fixedNow
                ),
                TodoItem(
                    id: "c2",
                    title: "Todo B",
                    meetingID: "vm-rev",
                    meetingTitle: "Sync",
                    lifecycle: .proposed,
                    createdAt: fixedNow
                ),
            ],
            meetingID: "vm-rev"
        )
        let coordinator = ProcessingReviewCoordinator(
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        return (ProcessingReviewViewModel(coordinator: coordinator), "vm-rev")
    }

    @Test("load edit remove accept")
    func happyPath() throws {
        let (vm, id) = try makeVM()
        vm.load(meetingID: id)
        #expect(vm.phase == .ready)
        #expect(vm.canAccept)
        #expect(vm.draft?.candidateCount == 2)

        vm.updateCandidate(id: "c1", title: "Todo A edited")
        vm.removeCandidate(id: "c2")
        #expect(vm.draft?.candidateCount == 1)

        vm.accept()
        #expect(vm.phase == .completed)
        #expect(vm.lastAcceptedCount == 1)
        #expect(vm.lastError == nil)
    }

    @Test("discard and reset")
    func discard() throws {
        let (vm, id) = try makeVM()
        vm.load(meetingID: id)
        vm.discard()
        #expect(vm.phase == .completed)
        #expect(vm.draft == nil)
        vm.reset()
        #expect(vm.phase == .idle)
    }

    @Test("remove all candidates then accept")
    func acceptEmpty() throws {
        let (vm, id) = try makeVM()
        vm.load(meetingID: id)
        vm.removeAllCandidates()
        #expect(vm.draft?.isEmpty == true)
        vm.accept()
        #expect(vm.phase == .completed)
        #expect(vm.lastAcceptedCount == 0)
    }

    @Test("load failure")
    func loadFail() {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let vm = ProcessingReviewViewModel(
            coordinator: ProcessingReviewCoordinator(
                sessionStore: session,
                fileSystem: InMemoryFileSystem(),
                clock: { fixedNow }
            )
        )
        #expect(!vm.isBusy)
        vm.load(meetingID: "nope")
        #expect(vm.phase == .failed)
        #expect(vm.lastError != nil)
        #expect(!vm.canAccept)
        vm.accept()
        #expect(vm.lastError != nil)
        vm.discard()
        #expect(vm.lastError != nil)
    }

    @Test("default coordinator initializer")
    func defaultInit() {
        let vm = ProcessingReviewViewModel()
        #expect(vm.phase == .idle)
        #expect(!vm.canAccept)
    }

    @Test("accept failure surfaces error")
    func acceptFail() throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalReviewVMFail"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fs,
            clock: { fixedNow }
        )
        _ = try store.initialize()
        try store.createMeeting(
            Meeting(
                id: "fail-rev",
                title: "Sync",
                status: .processedPendingReview,
                captureMode: .audioOnly,
                startedAt: fixedNow,
                createdAt: fixedNow,
                updatedAt: fixedNow
            )
        )
        try store.saveProposedTodos(
            [
                TodoItem(
                    id: "c1",
                    title: "Todo A",
                    meetingID: "fail-rev",
                    meetingTitle: "Sync",
                    lifecycle: .proposed,
                    createdAt: fixedNow
                ),
            ],
            meetingID: "fail-rev"
        )
        let coordinator = ProcessingReviewCoordinator(
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        let vm = ProcessingReviewViewModel(coordinator: coordinator)
        vm.load(meetingID: "fail-rev")
        fs.failNextWrite = true
        vm.accept()
        #expect(vm.phase == .failed)
        #expect(vm.lastError != nil)

        vm.load(meetingID: "fail-rev")
        fs.failNextWrite = true
        vm.discard()
        #expect(vm.phase == .failed)
    }
}
