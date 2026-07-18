import Testing
@testable import Bethal

@Suite("KnownAIProviderOption")
struct KnownAIProviderOptionTests {
    @Test("catalog includes claude codex grok")
    func catalog() {
        let ids = KnownAIProviderOption.catalog.map(\.id)
        #expect(ids == ["claude", "codex", "grok"])
        #expect(KnownAIProviderOption.catalog.allSatisfy { !$0.displayName.isEmpty && !$0.detail.isEmpty })
    }

    @Test("lookup helpers")
    func lookup() {
        #expect(KnownAIProviderOption.option(id: "claude")?.displayName.contains("Claude") == true)
        #expect(KnownAIProviderOption.option(id: "nope") == nil)
        #expect(KnownAIProviderOption.isKnownProviderID("codex"))
        #expect(!KnownAIProviderOption.isKnownProviderID("unknown"))
    }
}
