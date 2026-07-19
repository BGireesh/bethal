import Foundation

/// Loads a meeting transcript, runs a selected AI provider, and persists summary + proposed todos.
public final class ProcessingCoordinator: @unchecked Sendable {
    public private(set) var progress: ProcessingProgress

    private let registry: AIProviderRegistry
    private let sessionStore: AppSessionStore
    private let fileSystem: FileSystemClient
    private let clock: () -> Date

    public init(
        registry: AIProviderRegistry,
        sessionStore: AppSessionStore = AppSessionStore(),
        fileSystem: FileSystemClient = FoundationFileSystem(),
        clock: (() -> Date)? = nil
    ) {
        self.registry = registry
        self.sessionStore = sessionStore
        self.fileSystem = fileSystem
        self.clock = clock ?? Date.init
        self.progress = ProcessingProgress()
    }

    public func discoverProviders() -> [AIProviderDescriptor] {
        registry.discover()
    }

    public func selectionDecision(settings: AppSettings) -> ProviderSelectionDecision {
        let ids = registry.availableDescriptors().map(\.id)
        return ProviderSelectionPolicy.decide(settings: settings, availableProviderIDs: ids)
    }

    /// Runs AI processing for a meeting that already has a transcript.
    public func processMeeting(id: String, providerID: String) async throws -> MeetingProcessResult {
        progress = .preparing(meetingID: id, providerID: providerID)

        let session = sessionStore.load()
        guard let path = session.workingDirectoryPath, !path.isEmpty else {
            let error = AIProviderError.processFailed("Working directory is not configured.")
            progress = .failed(meetingID: id, message: error.localizedDescription)
            throw error
        }

        let root = URL(fileURLWithPath: path, isDirectory: true)
        let store = WorkingDirectoryStore(root: root, fileSystem: fileSystem, clock: clock)

        do {
            if !store.isInitialized {
                _ = try store.initialize()
            }
            let meeting = try store.loadMeeting(id: id)
            try Self.validateEligible(meeting)

            guard let transcript = try store.loadTranscript(meetingID: id) else {
                throw AIProviderError.processFailed("No transcript found. Transcribe this meeting first.")
            }
            let text = transcript.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw AIProviderError.processFailed("Transcript is empty.")
            }

            let request = MeetingProcessRequest(
                meetingID: meeting.id,
                meetingTitle: meeting.title,
                transcriptText: text,
                languageCode: transcript.languageCode
            )

            progress = .running(meetingID: id, providerID: providerID)
            let provider = try registry.makeProvider(id: providerID)
            let result = try await provider.process(request)

            progress = .saving(meetingID: id, providerID: providerID)
            try store.saveSummary(result.summaryMarkdown, meetingID: id)
            try store.saveProposedTodos(result.proposedTodos, meetingID: id)

            var updated = meeting
            updated.status = .processedPendingReview
            updated.failureReason = nil
            updated.updatedAt = clock()
            try store.updateMeeting(updated)

            progress = .completed(meetingID: id, providerID: providerID)
            return result
        } catch {
            let message = error.localizedDescription
            progress = .failed(meetingID: id, message: message)
            if let path = session.workingDirectoryPath {
                let errorStore = WorkingDirectoryStore(
                    root: URL(fileURLWithPath: path, isDirectory: true),
                    fileSystem: fileSystem,
                    clock: clock
                )
                if let meeting = try? errorStore.loadMeeting(id: id),
                   meeting.status == .transcribed || meeting.status == .failed || meeting.status == .processedPendingReview {
                    var failed = meeting
                    failed.status = .failed
                    failed.failureReason = message
                    failed.updatedAt = clock()
                    try? errorStore.updateMeeting(failed)
                }
            }
            throw error
        }
    }

    public static func validateEligible(_ meeting: Meeting) throws {
        switch meeting.status {
        case .transcribed, .processedPendingReview, .completed, .failed:
            return
        case .capturing:
            throw AIProviderError.processFailed("Meeting is still being recorded.")
        case .captured:
            throw AIProviderError.processFailed("Transcribe this meeting before AI processing.")
        }
    }

    public func resetProgress() {
        progress = ProcessingProgress()
    }
}
