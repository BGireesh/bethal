import Testing
@testable import Bethal

@Suite("OnboardingCopy")
struct OnboardingCopyTests {
    @Test("copy is non-empty and mentions privacy themes")
    func content() {
        #expect(OnboardingCopy.privacyBody.contains("on this device"))
        #expect(OnboardingCopy.privacyBody.contains("Conductor"))
        #expect(OnboardingCopy.directoryBody.contains("Settings"))
        #expect(OnboardingCopy.providerBody.contains("Ask") || OnboardingCopy.providerBody.contains("every time") || OnboardingCopy.providerBody.contains("default"))
        #expect(OnboardingCopy.privacyShield.contains("cloud"))
    }
}
