import Foundation

/// Orchestrates discovery, selection policy, and AI processing for a meeting.
public final class ProviderChooserViewModel: @unchecked Sendable {
    public private(set) var providers: [AIProviderDescriptor]
    public private(set) var availableProviders: [AIProviderDescriptor]
    public private(set) var progress: ProcessingProgress
    public private(set) var lastResult: MeetingProcessResult?
    public private(set) var lastError: String?
    public private(set) var decision: ProviderSelectionDecision
    public private(set) var activeMeetingID: String?

    private let coordinator: ProcessingCoordinator
    private let sessionStore: AppSessionStore
    private let fileSystem: FileSystemClient

    public init(
        coordinator: ProcessingCoordinator,
        sessionStore: AppSessionStore = AppSessionStore(),
        fileSystem: FileSystemClient = FoundationFileSystem()
    ) {
        self.coordinator = coordinator
        self.sessionStore = sessionStore
        self.fileSystem = fileSystem
        self.providers = []
        self.availableProviders = []
        self.progress = ProcessingProgress()
        self.lastResult = nil
        self.lastError = nil
        self.decision = .noneAvailable
        self.activeMeetingID = nil
        refreshDiscovery()
    }

    public var showsEmptyState: Bool { availableProviders.isEmpty }
    public var emptyStateHowTo: String {
        providers.map(\.howToInstall).joined(separator: "\n")
    }

    public func refreshDiscovery() {
        providers = coordinator.discoverProviders()
        availableProviders = providers.filter(\.isAvailable)
        decision = coordinator.selectionDecision(settings: loadSettings())
    }

    /// Start processing flow for a meeting: auto-run default or enter chooser phase.
    public func begin(meetingID: String) async {
        activeMeetingID = meetingID
        lastError = nil
        lastResult = nil
        refreshDiscovery()

        switch decision {
        case .noneAvailable:
            progress = .failed(
                meetingID: meetingID,
                message: "No local AI tools found. Install Claude, Codex, or Grok CLI and ensure it is on your PATH."
            )
            lastError = progress.message
        case .useDefault(let providerID):
            await run(meetingID: meetingID, providerID: providerID)
        case .askUser:
            progress = .choosing(meetingID: meetingID)
        }
    }

    public func selectProvider(id: String) async {
        guard let meetingID = activeMeetingID else { return }
        await run(meetingID: meetingID, providerID: id)
    }

    public func retry() async {
        guard let meetingID = activeMeetingID else { return }
        if let providerID = progress.selectedProviderID {
            await run(meetingID: meetingID, providerID: providerID)
        } else {
            await begin(meetingID: meetingID)
        }
    }

    /// Re-open the tool list after a failure (or when user wants another provider).
    public func showChooserAgain() {
        guard let meetingID = activeMeetingID else { return }
        lastError = nil
        refreshDiscovery()
        if availableProviders.isEmpty {
            progress = .failed(
                meetingID: meetingID,
                message: "No local AI tools found. Install Claude, Codex, or Grok CLI and ensure it is on your PATH."
            )
            lastError = progress.message
        } else {
            progress = .choosing(meetingID: meetingID)
        }
    }

    public var preferredProviderID: String? {
        switch decision {
        case .askUser(let preferredID):
            return preferredID
        case .useDefault(let providerID):
            return providerID
        case .noneAvailable:
            return nil
        }
    }

    public func reset() {
        coordinator.resetProgress()
        progress = coordinator.progress
        lastResult = nil
        lastError = nil
        activeMeetingID = nil
    }

    public func syncProgress() {
        progress = coordinator.progress
    }

    private func run(meetingID: String, providerID: String) async {
        lastError = nil
        lastResult = nil
        do {
            let result = try await coordinator.processMeeting(id: meetingID, providerID: providerID)
            lastResult = result
            progress = coordinator.progress
        } catch {
            lastError = error.localizedDescription
            progress = coordinator.progress
        }
    }

    private func loadSettings() -> AppSettings {
        let session = sessionStore.load()
        guard let path = session.workingDirectoryPath, !path.isEmpty else {
            return .default
        }
        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fileSystem
        )
        guard store.isInitialized, let settings = try? store.loadSettings() else {
            return .default
        }
        return settings
    }
}
