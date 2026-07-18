/// Canonical product identity for Bethal.
///
/// Kept free of UI and platform APIs so it can be unit-tested at 100% coverage
/// and reused by storage, settings, and AI provider modules later.
public enum AppIdentity: Sendable {
    public static let displayName = "Bethal"
    public static let bundleIdentifier = "us.gireesh.bethal"
    public static let tagline = "On-device meeting capture and intelligence"

    /// Semantic version string for the app shell (bumped at release; independent of git).
    public static let version = "0.1.0"

    public static let defaultWindowWidth: Double = 960
    public static let defaultWindowHeight: Double = 640

    /// Directory name created under the user-chosen working directory (future PRs).
    public static let workingDirectoryMarker = ".bethal"

    /// Human-readable one-line identity for logs and diagnostics.
    public static var diagnosticLabel: String {
        "\(displayName) \(version) (\(bundleIdentifier))"
    }
}
