import Foundation

/// Loads settings from the working directory and supports Finder reveal.
public final class SettingsViewModel: @unchecked Sendable {
    public private(set) var workingDirectoryPath: String?
    public private(set) var appSettings: AppSettings
    public private(set) var loadError: String?
    public private(set) var lastOpenSucceeded: Bool?

    private let sessionStore: AppSessionStore
    private let fileSystem: FileSystemClient
    private let workspace: WorkspaceOpener
    private let completer: OnboardingCompleter

    public init(
        sessionStore: AppSessionStore = AppSessionStore(),
        fileSystem: FileSystemClient = FoundationFileSystem(),
        workspace: WorkspaceOpener = FinderWorkspaceOpener(),
        completer: OnboardingCompleter? = nil
    ) {
        self.sessionStore = sessionStore
        self.fileSystem = fileSystem
        self.workspace = workspace
        if let completer {
            self.completer = completer
        } else {
            self.completer = OnboardingCompleter(
                fileSystem: fileSystem,
                sessionStore: sessionStore
            )
        }
        self.workingDirectoryPath = sessionStore.load().workingDirectoryPath
        self.appSettings = .default
        reload()
    }

    public var defaultProviderDisplayName: String {
        if let id = appSettings.defaultAIProviderID,
           let option = KnownAIProviderOption.option(id: id) {
            return option.displayName
        }
        if appSettings.askEveryTimeForProvider {
            return "Ask every time"
        }
        return "Not set"
    }

    public var defaultCaptureModeDisplayName: String {
        switch appSettings.defaultCaptureMode {
        case .audioOnly: return "Audio only"
        case .audioVideo: return "Audio + video"
        }
    }

    public var calendarSummary: String {
        if appSettings.calendarAutoDetectEnabled {
            return "On · remind \(appSettings.calendarRemindMinutesBefore) min before"
        }
        return "Off"
    }

    /// Updates calendar auto-detect preferences and persists to the working directory.
    public func updateCalendarPreferences(enabled: Bool, minutesBefore: Int) {
        let minutes = MeetingReminderEvaluator.normalizedMinutesBefore(minutesBefore)
        appSettings.calendarAutoDetectEnabled = enabled
        appSettings.calendarRemindMinutesBefore = minutes
        persistSettings()
    }

    public func reload() {
        loadError = nil
        let session = sessionStore.load()
        workingDirectoryPath = session.workingDirectoryPath

        guard let path = session.workingDirectoryPath, !path.isEmpty else {
            appSettings = .default
            loadError = "Working directory is not configured."
            return
        }

        let root = URL(fileURLWithPath: path, isDirectory: true)
        let store = WorkingDirectoryStore(root: root, fileSystem: fileSystem)
        do {
            if store.isInitialized {
                appSettings = try store.loadSettings()
            } else {
                appSettings = .default
                loadError = "Working directory is not initialized yet."
            }
        } catch {
            appSettings = .default
            loadError = error.localizedDescription
        }
    }

    @discardableResult
    public func openWorkingDirectoryInFinder() -> Bool {
        guard let path = workingDirectoryPath, !path.isEmpty else {
            lastOpenSucceeded = false
            return false
        }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let ok = workspace.open(url)
        lastOpenSucceeded = ok
        return ok
    }

    /// Resolves bookmark when present; falls back to path.
    public func resolvedWorkingDirectoryURL() throws -> URL? {
        try completer.resolveWorkingDirectory(from: sessionStore.load())
    }

    private func persistSettings() {
        loadError = nil
        guard let path = workingDirectoryPath, !path.isEmpty else {
            loadError = "Working directory is not configured."
            return
        }
        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fileSystem
        )
        do {
            if !store.isInitialized {
                _ = try store.initialize()
            }
            try store.saveSettings(appSettings)
        } catch {
            loadError = error.localizedDescription
        }
    }
}
