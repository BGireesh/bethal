import Foundation

/// App-level preferences stored outside the working directory (UserDefaults).
///
/// Working-directory *content* lives on disk via `WorkingDirectoryStore`.
/// This type only tracks session flags and how to re-open the chosen folder.
public struct AppSessionPreferences: Codable, Equatable, Sendable {
    public var hasCompletedOnboarding: Bool
    public var workingDirectoryPath: String?
    public var workingDirectoryBookmarkData: Data?
    public var completedAt: Date?

    public init(
        hasCompletedOnboarding: Bool = false,
        workingDirectoryPath: String? = nil,
        workingDirectoryBookmarkData: Data? = nil,
        completedAt: Date? = nil
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.workingDirectoryPath = workingDirectoryPath
        self.workingDirectoryBookmarkData = workingDirectoryBookmarkData
        self.completedAt = completedAt
    }

    public static let empty = AppSessionPreferences()

    public var hasUsableWorkingDirectory: Bool {
        hasCompletedOnboarding && workingDirectoryPath != nil
    }
}
