import Foundation
import Testing
@testable import Bethal

@Suite("OnboardingFlowState")
struct OnboardingFlowStateTests {
    @Test("privacy can always advance")
    func privacyAdvance() {
        var flow = OnboardingFlowState()
        #expect(flow.step == .privacy)
        #expect(flow.canAdvance)
        #expect(flow.primaryActionTitle == "Continue")
        let moved = flow.advance()
        #expect(moved)
        #expect(flow.step == .workingDirectory)
    }

    @Test("working directory requires path")
    func directoryGate() {
        var flow = OnboardingFlowState(step: .workingDirectory)
        #expect(!flow.canAdvance)
        let blocked = flow.advance()
        #expect(!blocked)
        flow.setDirectoryPath(" /tmp/x ")
        #expect(flow.hasDirectory)
        flow.setDirectoryPath("/tmp/bethal")
        #expect(flow.canAdvance)
        let moved = flow.advance()
        #expect(moved)
        #expect(flow.step == .defaultProvider)
    }

    @Test("empty directory path is not usable")
    func emptyDirectory() {
        var flow = OnboardingFlowState(step: .workingDirectory)
        flow.setDirectoryPath("")
        #expect(!flow.hasDirectory)
        #expect(!flow.canAdvance)
        flow.setDirectoryPath(nil)
        #expect(!flow.hasDirectory)
    }

    @Test("provider step always advances and finish title")
    func providerStep() {
        var flow = OnboardingFlowState(step: .defaultProvider, directoryPath: "/tmp")
        #expect(flow.canAdvance)
        #expect(flow.primaryActionTitle == "Finish setup")
        flow.setProviderID("claude")
        #expect(flow.providerID == "claude")
        let moved = flow.advance()
        #expect(moved)
        #expect(flow.step == .finished)
        #expect(flow.isComplete)
        #expect(!flow.canAdvance)
        let blocked = flow.advance()
        #expect(!blocked)
        #expect(flow.primaryActionTitle == "Done")
    }

    @Test("retreat from each step")
    func retreat() {
        var flow = OnboardingFlowState(step: .defaultProvider, directoryPath: "/tmp")
        let back1 = flow.retreat()
        #expect(back1)
        #expect(flow.step == .workingDirectory)
        let back2 = flow.retreat()
        #expect(back2)
        #expect(flow.step == .privacy)
        let blocked = flow.retreat()
        #expect(!blocked)
    }

    @Test("errors clear on mutation and markFinished")
    func errorsAndFinish() {
        var flow = OnboardingFlowState(step: .workingDirectory)
        flow.setError("pick a folder")
        #expect(flow.errorMessage == "pick a folder")
        flow.setDirectoryPath("/data")
        #expect(flow.errorMessage == nil)
        flow.setError("x")
        flow.setProviderID("grok")
        #expect(flow.errorMessage == nil)
        flow.setError("y")
        let toProvider = flow.advance()
        #expect(toProvider)
        flow.setError("z")
        let toFinished = flow.advance()
        #expect(toFinished)
        flow.markFinished()
        #expect(flow.step == .finished)
        #expect(flow.errorMessage == nil)
    }

    @Test("steps are ordered")
    func ordering() {
        #expect(OnboardingStep.privacy < OnboardingStep.workingDirectory)
        #expect(OnboardingStep.workingDirectory < OnboardingStep.defaultProvider)
        #expect(OnboardingStep.allCases.count == 4)
        #expect(OnboardingStep.privacy.title.contains("Privacy"))
        #expect(OnboardingStep.workingDirectory.title.contains("directory"))
        #expect(OnboardingStep.defaultProvider.title.contains("AI"))
        #expect(OnboardingStep.finished.isTerminal)
        #expect(!OnboardingStep.privacy.isTerminal)
    }
}
