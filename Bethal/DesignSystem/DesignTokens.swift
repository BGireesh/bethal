import CoreGraphics

/// Baseline spacing scale for consistent layout.
public enum DesignSpacing: Sendable {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32

    public static let sidebarMinWidth: CGFloat = 200
    public static let contentMinWidth: CGFloat = 480
}

/// Semantic font roles (mapped to SwiftUI styles in views).
public enum DesignTypographyRole: String, CaseIterable, Sendable {
    case largeTitle
    case title
    case headline
    case body
    case callout
    case caption
    case mono

    public var accessibilityName: String { rawValue }
}
