import Foundation
import Testing
@testable import Bethal

@Suite("ReviewDraft and TodoAcceptMerge")
struct ReviewDraftTests {
    private let fixedNow = Date(timeIntervalSince1970: 6_000_000_000)

    private func todo(_ id: String, title: String = "T") -> TodoItem {
        TodoItem(
            id: id,
            title: title,
            meetingID: "m1",
            meetingTitle: "Call",
            lifecycle: .proposed,
            createdAt: fixedNow
        )
    }

    @Test("update and remove candidates")
    func edit() {
        var draft = ReviewDraft(
            meetingID: "m1",
            meetingTitle: "Call",
            summaryMarkdown: "# S",
            transcriptPreview: "hello",
            candidates: [todo("a", title: "One"), todo("b", title: "Two")]
        )
        #expect(draft.candidateCount == 2)
        let updated = draft.updateCandidate(id: "a", title: "  Updated  ", notes: " n ")
        #expect(updated)
        #expect(draft.candidates[0].title == "Updated")
        #expect(draft.candidates[0].notes == "n")
        let emptyTitle = draft.updateCandidate(id: "a", title: "   ")
        #expect(!emptyTitle)
        let missing = draft.updateCandidate(id: "missing", title: "X")
        #expect(!missing)
        let removed = draft.removeCandidate(id: "b")
        #expect(removed)
        #expect(draft.candidateCount == 1)
        let removedAgain = draft.removeCandidate(id: "b")
        #expect(!removedAgain)
        draft.removeAllCandidates()
        #expect(draft.isEmpty)
    }

    @Test("accept ids and accepted todos")
    func acceptHelpers() {
        let draft = ReviewDraft(
            meetingID: "m1",
            meetingTitle: "Call",
            candidates: [todo("a"), todo("b")]
        )
        #expect(draft.acceptIDs == Set(["a", "b"]))
        let accepted = draft.acceptedTodos()
        #expect(accepted.allSatisfy { $0.lifecycle == .accepted })
    }

    @Test("merge into global list")
    func merge() {
        let existing = [
            todo("old", title: "Keep").acceptedCopy(),
            todo("a", title: "Stale").acceptedCopy(),
        ]
        let accepting = [todo("a", title: "Fresh"), todo("new", title: "New")]
        let merged = TodoAcceptMerge.merge(existing: existing, accepting: accepting)
        #expect(merged.count == 3)
        #expect(merged.first { $0.id == "a" }?.title == "Fresh")
        #expect(merged.first { $0.id == "new" }?.title == "New")
        #expect(merged.first { $0.id == "old" }?.title == "Keep")
    }

    @Test("review phase helpers")
    func phases() {
        #expect(ReviewPhase.loading.isBusy)
        #expect(ReviewPhase.saving.isBusy)
        #expect(!ReviewPhase.ready.isBusy)
        for phase in ReviewPhase.allCases {
            #expect(!phase.displayName.isEmpty)
        }
    }

    @Test("transcript preview truncates")
    func preview() {
        let short = Transcript(
            meetingID: "m",
            segments: [TranscriptSegment(id: "s", startSeconds: 0, endSeconds: 1, text: "hi")],
            createdAt: fixedNow
        )
        #expect(ProcessingReviewCoordinator.transcriptPreview(from: short) == "hi")
        #expect(ProcessingReviewCoordinator.transcriptPreview(from: nil).isEmpty)

        let longText = String(repeating: "a", count: 600)
        let long = Transcript(
            meetingID: "m",
            segments: [TranscriptSegment(id: "s", startSeconds: 0, endSeconds: 1, text: longText)],
            createdAt: fixedNow
        )
        let preview = ProcessingReviewCoordinator.transcriptPreview(from: long, maxCharacters: 50)
        #expect(preview.hasSuffix("…"))
        #expect(preview.count == 51)
    }
}
