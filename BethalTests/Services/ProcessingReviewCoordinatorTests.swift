import Foundation
import Testing
@testable import Bethal

@Suite("ProcessingReviewCoordinator")
struct ProcessingReviewCoordinatorTests {
    private let fixedNow = Date(timeIntervalSince1970: 6_100_000_000)

    private func seeded(
        status: MeetingStatus = .processedPendingReview,
        withSummary: Bool = true,
        todos: [TodoItem]? = nil
    ) throws -> (AppSessionStore, InMemoryFileSystem, String) {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalReview"
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
                id: "rev-1",
                title: "Vendor call",
                status: status,
                captureMode: .audioOnly,
                startedAt: fixedNow,
                createdAt: fixedNow,
                updatedAt: fixedNow
            )
        )
        try store.saveTranscript(
            Transcript(
                meetingID: "rev-1",
                segments: [
                    TranscriptSegment(id: "s1", startSeconds: 0, endSeconds: 2, text: "We should follow up next week."),
                ],
                createdAt: fixedNow
            )
        )
        if withSummary {
            try store.saveSummary("## Summary\n- Points", meetingID: "rev-1")
        }
        let proposed = todos ?? [
            TodoItem(
                id: "t1",
                title: "Send notes",
                meetingID: "rev-1",
                meetingTitle: "Vendor call",
                lifecycle: .proposed,
                createdAt: fixedNow
            ),
            TodoItem(
                id: "t2",
                title: "Schedule demo",
                meetingID: "rev-1",
                meetingTitle: "Vendor call",
                lifecycle: .proposed,
                createdAt: fixedNow
            ),
        ]
        try store.saveProposedTodos(proposed, meetingID: "rev-1")
        return (session, fs, path)
    }

    @Test("load builds draft")
    func load() throws {
        let (session, fs, _) = try seeded()
        let coordinator = ProcessingReviewCoordinator(
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        let draft = try coordinator.load(meetingID: "rev-1")
        #expect(draft.meetingTitle == "Vendor call")
        #expect(draft.summaryMarkdown.contains("Summary"))
        #expect(draft.transcriptPreview.contains("follow up"))
        #expect(draft.candidateCount == 2)
        #expect(coordinator.phase == .ready)
    }

    @Test("accept merges todos and completes meeting")
    func accept() throws {
        let (session, fs, path) = try seeded()
        let coordinator = ProcessingReviewCoordinator(
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        var draft = try coordinator.load(meetingID: "rev-1")
        let removed = draft.removeCandidate(id: "t2")
        let updated = draft.updateCandidate(id: "t1", title: "Send notes ASAP")
        #expect(removed)
        #expect(updated)
        let accepted = try coordinator.accept(draft)
        #expect(accepted.count == 1)
        #expect(accepted[0].title == "Send notes ASAP")
        #expect(accepted[0].lifecycle == .accepted)
        #expect(coordinator.phase == .completed)

        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs)
        let meeting = try store.loadMeeting(id: "rev-1")
        #expect(meeting.status == .completed)
        let global = try store.loadGlobalTodos()
        #expect(global.count == 1)
        #expect(global[0].id == "t1")
        #expect(try store.loadProposedTodos(meetingID: "rev-1").isEmpty)
    }

    @Test("discard clears proposed and returns to transcribed")
    func discard() throws {
        let (session, fs, path) = try seeded()
        let coordinator = ProcessingReviewCoordinator(
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        _ = try coordinator.load(meetingID: "rev-1")
        try coordinator.discard(meetingID: "rev-1")
        #expect(coordinator.phase == .completed)
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs)
        #expect(try store.loadMeeting(id: "rev-1").status == .transcribed)
        #expect(try store.loadProposedTodos(meetingID: "rev-1").isEmpty)
    }

    @Test("missing working directory")
    func noWD() {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let coordinator = ProcessingReviewCoordinator(
            sessionStore: session,
            fileSystem: InMemoryFileSystem(),
            clock: { fixedNow }
        )
        #expect(throws: ProcessingReviewError.self) {
            _ = try coordinator.load(meetingID: "x")
        }
        #expect(coordinator.phase == .failed)
    }

    @Test("ineligible statuses")
    func ineligible() throws {
        let base = Meeting(
            id: "a",
            title: "t",
            status: .captured,
            captureMode: .audioOnly,
            startedAt: fixedNow
        )
        for status in [MeetingStatus.capturing, .captured, .transcribed, .failed] {
            var m = base
            m.status = status
            #expect(throws: ProcessingReviewError.self) {
                try ProcessingReviewCoordinator.validateEligible(m)
            }
        }
        for status in [MeetingStatus.processedPendingReview, .completed] {
            var m = base
            m.status = status
            try ProcessingReviewCoordinator.validateEligible(m)
        }

        let (session, fs, _) = try seeded(status: .transcribed)
        let coordinator = ProcessingReviewCoordinator(
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        #expect(throws: ProcessingReviewError.self) {
            _ = try coordinator.load(meetingID: "rev-1")
        }
    }

    @Test("save draft edits write failure")
    func saveEditsFails() throws {
        let (session, fs, _) = try seeded()
        let coordinator = ProcessingReviewCoordinator(
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        let draft = try coordinator.load(meetingID: "rev-1")
        fs.failNextWrite = true
        #expect(throws: ProcessingReviewError.self) {
            try coordinator.saveDraftEdits(draft)
        }
        #expect(coordinator.lastError != nil)
    }

    @Test("accept write failure")
    func acceptFails() throws {
        let (session, fs, _) = try seeded()
        let coordinator = ProcessingReviewCoordinator(
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        let draft = try coordinator.load(meetingID: "rev-1")
        fs.failNextWrite = true
        #expect(throws: Error.self) {
            _ = try coordinator.accept(draft)
        }
        #expect(coordinator.phase == .failed)
    }

    @Test("discard write failure")
    func discardFails() throws {
        let (session, fs, _) = try seeded()
        let coordinator = ProcessingReviewCoordinator(
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        _ = try coordinator.load(meetingID: "rev-1")
        fs.failNextWrite = true
        #expect(throws: Error.self) {
            try coordinator.discard(meetingID: "rev-1")
        }
        #expect(coordinator.phase == .failed)
    }

    @Test("load initializes store when needed")
    func initStore() throws {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalReviewInit"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let coordinator = ProcessingReviewCoordinator(
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        #expect(throws: Error.self) {
            _ = try coordinator.load(meetingID: "missing")
        }
        #expect(
            WorkingDirectoryStore(
                root: URL(fileURLWithPath: path, isDirectory: true),
                fileSystem: fs
            ).isInitialized
        )
    }

    @Test("load without summary still works")
    func noSummary() throws {
        let (session, fs, _) = try seeded(withSummary: false)
        let coordinator = ProcessingReviewCoordinator(
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        let draft = try coordinator.load(meetingID: "rev-1")
        #expect(draft.summaryMarkdown.isEmpty)
    }

    @Test("save draft edits and reset")
    func saveEdits() throws {
        let (session, fs, path) = try seeded()
        let coordinator = ProcessingReviewCoordinator(
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        var draft = try coordinator.load(meetingID: "rev-1")
        let didUpdate = draft.updateCandidate(id: "t1", title: "Edited")
        #expect(didUpdate)
        try coordinator.saveDraftEdits(draft)
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs)
        let proposed = try store.loadProposedTodos(meetingID: "rev-1")
        #expect(proposed.first { $0.id == "t1" }?.title == "Edited")
        coordinator.reset()
        #expect(coordinator.phase == .idle)
        #expect(coordinator.draft == nil)
    }

    @Test("error descriptions")
    func errors() {
        #expect(ProcessingReviewError.workingDirectoryMissing.errorDescription != nil)
        #expect(ProcessingReviewError.meetingNotEligible("x").errorDescription == "x")
        #expect(ProcessingReviewError.notLoaded.errorDescription != nil)
        #expect(ProcessingReviewError.saveFailed("y").errorDescription?.contains("y") == true)
    }

    @Test("default clock initializer")
    func defaultClock() {
        _ = ProcessingReviewCoordinator(
            sessionStore: AppSessionStore(keyValueStore: InMemoryKeyValueStore()),
            fileSystem: InMemoryFileSystem()
        )
    }
}
