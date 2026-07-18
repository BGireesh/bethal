import Foundation

/// Persists onboarding choices: working directory layout + session preferences.
public struct OnboardingCompleter: Sendable {
    private let fileSystem: FileSystemClient
    private let bookmarkClient: BookmarkClient
    private let sessionStore: AppSessionStore
    private let clock: @Sendable () -> Date

    public init(
        fileSystem: FileSystemClient = FoundationFileSystem(),
        bookmarkClient: BookmarkClient = SecurityScopedBookmarkClient(),
        sessionStore: AppSessionStore = AppSessionStore(),
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fileSystem = fileSystem
        self.bookmarkClient = bookmarkClient
        self.sessionStore = sessionStore
        self.clock = clock
    }

    public func complete(
        directoryURL: URL,
        providerID: String?
    ) throws -> AppSessionPreferences {
        let root = directoryURL.standardizedFileURL
        let store = WorkingDirectoryStore(root: root, fileSystem: fileSystem, clock: clock)
        try store.initialize()

        var settings = try store.loadSettings()
        if let providerID, KnownAIProviderOption.isKnownProviderID(providerID) {
            settings.defaultAIProviderID = providerID
            settings.askEveryTimeForProvider = false
        } else {
            settings.defaultAIProviderID = nil
            settings.askEveryTimeForProvider = true
        }
        try store.saveSettings(settings)

        let bookmark = try bookmarkClient.bookmark(for: root)
        let preferences = AppSessionPreferences(
            hasCompletedOnboarding: true,
            workingDirectoryPath: root.path,
            workingDirectoryBookmarkData: bookmark,
            completedAt: clock()
        )
        try sessionStore.save(preferences)
        return preferences
    }

    /// Resolves the stored working directory URL from session preferences when possible.
    public func resolveWorkingDirectory(from preferences: AppSessionPreferences) throws -> URL? {
        if let data = preferences.workingDirectoryBookmarkData {
            let resolved = try bookmarkClient.resolveBookmark(data)
            return resolved.url.standardizedFileURL
        }
        if let path = preferences.workingDirectoryPath {
            return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        }
        return nil
    }
}
