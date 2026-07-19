import Foundation

/// Runs transcription for a stored meeting and persists `transcript.json` + status.
public final class TranscriptionCoordinator: @unchecked Sendable {
    public private(set) var progress: TranscriptionProgress

    private let engine: TranscriptionEngine
    private let sessionStore: AppSessionStore
    private let fileSystem: FileSystemClient
    private let clock: () -> Date
    private let languageCode: String?

    public init(
        engine: TranscriptionEngine,
        sessionStore: AppSessionStore = AppSessionStore(),
        fileSystem: FileSystemClient = FoundationFileSystem(),
        clock: @escaping () -> Date = Date.init,
        languageCode: String? = nil
    ) {
        self.engine = engine
        self.sessionStore = sessionStore
        self.fileSystem = fileSystem
        self.clock = clock
        self.languageCode = languageCode
        self.progress = TranscriptionProgress()
    }

    /// Transcribes a meeting that is at least `captured` (or `failed` retry after capture).
    public func transcribeMeeting(id: String) async throws -> Transcript {
        progress = .preparing(meetingID: id)

        let session = sessionStore.load()
        guard let path = session.workingDirectoryPath, !path.isEmpty else {
            let error = TranscriptionError.meetingNotEligible("Working directory is not configured.")
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

            let audioURL = try MeetingAudioResolver.resolveAudioURL(
                for: meeting,
                layout: store.layout,
                fileSystem: fileSystem
            )

            progress = .transcribing(meetingID: id, fraction: 0.1)
            let transcript = try await engine.transcribe(
                audioURL: audioURL,
                meetingID: id,
                languageCode: languageCode
            ) { [weak self] fraction in
                self?.progress = .transcribing(meetingID: id, fraction: fraction)
            }

            progress = .saving(meetingID: id)
            try store.saveTranscript(transcript)

            var updated = meeting
            updated.status = .transcribed
            updated.failureReason = nil
            updated.updatedAt = clock()
            try store.updateMeeting(updated)

            progress = .completed(meetingID: id)
            return transcript
        } catch {
            let message = error.localizedDescription
            progress = .failed(meetingID: id, message: message)
            // Best-effort: mark meeting failed if it was captured
            if let path = session.workingDirectoryPath {
                let errorStore = WorkingDirectoryStore(
                    root: URL(fileURLWithPath: path, isDirectory: true),
                    fileSystem: fileSystem,
                    clock: clock
                )
                if let meeting = try? errorStore.loadMeeting(id: id),
                   meeting.status == .captured || meeting.status == .failed {
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
        case .captured, .failed, .transcribed, .processedPendingReview, .completed:
            return
        case .capturing:
            throw TranscriptionError.meetingNotEligible("Meeting is still being recorded.")
        }
    }

    public func resetProgress() {
        progress = TranscriptionProgress()
    }
}
