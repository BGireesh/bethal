import Testing
@testable import Bethal

@Suite("ProviderSelectionPolicy")
struct ProviderSelectionPolicyTests {
    @Test("none available")
    func none() {
        let decision = ProviderSelectionPolicy.decide(
            settings: AppSettings(defaultAIProviderID: "claude", askEveryTimeForProvider: false),
            availableProviderIDs: []
        )
        #expect(decision == .noneAvailable)
    }

    @Test("ask every time shows chooser with preferred")
    func askEveryTime() {
        let decision = ProviderSelectionPolicy.decide(
            settings: AppSettings(defaultAIProviderID: "claude", askEveryTimeForProvider: true),
            availableProviderIDs: ["claude", "codex"]
        )
        #expect(decision == .askUser(preferredID: "claude"))
    }

    @Test("use default when available and not asking")
    func useDefault() {
        let decision = ProviderSelectionPolicy.decide(
            settings: AppSettings(defaultAIProviderID: "codex", askEveryTimeForProvider: false),
            availableProviderIDs: ["claude", "codex"]
        )
        #expect(decision == .useDefault(providerID: "codex"))
    }

    @Test("default missing falls back to ask")
    func defaultMissing() {
        let decision = ProviderSelectionPolicy.decide(
            settings: AppSettings(defaultAIProviderID: "grok", askEveryTimeForProvider: false),
            availableProviderIDs: ["claude"]
        )
        #expect(decision == .askUser(preferredID: nil))
    }

    @Test("no default asks")
    func noDefault() {
        let decision = ProviderSelectionPolicy.decide(
            settings: AppSettings(defaultAIProviderID: nil, askEveryTimeForProvider: false),
            availableProviderIDs: ["claude"]
        )
        #expect(decision == .askUser(preferredID: nil))
    }
}
