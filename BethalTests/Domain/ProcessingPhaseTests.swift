import Testing
@testable import Bethal

@Suite("ProcessingPhase and Progress")
struct ProcessingPhaseTests {
    @Test("phase helpers")
    func phases() {
        #expect(ProcessingPhase.running.isInProgress)
        #expect(ProcessingPhase.choosingProvider.isInProgress)
        #expect(!ProcessingPhase.completed.isInProgress)
        for phase in ProcessingPhase.allCases {
            #expect(!phase.displayName.isEmpty)
        }
    }

    @Test("progress factories")
    func progress() {
        #expect(ProcessingProgress.choosing(meetingID: "m").phase == .choosingProvider)
        #expect(ProcessingProgress.preparing(meetingID: "m", providerID: "claude").fractionCompleted == 0.1)
        #expect(ProcessingProgress.running(meetingID: "m", providerID: "claude").selectedProviderID == "claude")
        #expect(ProcessingProgress.saving(meetingID: "m", providerID: "x").phase == .saving)
        #expect(ProcessingProgress.completed(meetingID: "m", providerID: "x").fractionCompleted == 1)
        #expect(ProcessingProgress.failed(meetingID: "m", message: "e").message == "e")
        let clamped = ProcessingProgress(phase: .running, fractionCompleted: 2)
        #expect(clamped.fractionCompleted == 1)
    }

    @Test("request and result models")
    func models() {
        let request = MeetingProcessRequest(
            meetingID: "m",
            meetingTitle: "T",
            transcriptText: "hello",
            languageCode: "en-US"
        )
        #expect(request.languageCode == "en-US")
        let result = MeetingProcessResult(summaryMarkdown: "# S", providerID: "claude")
        #expect(result.proposedTodos.isEmpty)
        let candidate = AITodoCandidate(title: "Do", notes: "n")
        #expect(candidate.notes == "n")
        let payload = AIProcessJSONPayload(summaryMarkdown: "s", todos: [candidate])
        #expect(payload.todos.count == 1)
    }
}
