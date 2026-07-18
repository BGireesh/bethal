import Testing
@testable import Bethal

@Suite("DesignTokens")
struct DesignTokensTests {
    @Test("spacing scale is positive and ordered")
    func spacing() {
        #expect(DesignSpacing.xxs > 0)
        #expect(DesignSpacing.xs > DesignSpacing.xxs)
        #expect(DesignSpacing.sm > DesignSpacing.xs)
        #expect(DesignSpacing.md > DesignSpacing.sm)
        #expect(DesignSpacing.lg > DesignSpacing.md)
        #expect(DesignSpacing.xl > DesignSpacing.lg)
        #expect(DesignSpacing.xxl > DesignSpacing.xl)
        #expect(DesignSpacing.sidebarMinWidth > 0)
        #expect(DesignSpacing.contentMinWidth > DesignSpacing.sidebarMinWidth)
    }

    @Test("typography roles have accessibility names")
    func typography() {
        #expect(DesignTypographyRole.allCases.count == 7)
        for role in DesignTypographyRole.allCases {
            #expect(role.accessibilityName == role.rawValue)
        }
    }
}
