import Foundation

public enum ProcessingReviewError: Error, Equatable, Sendable, LocalizedError {
    case workingDirectoryMissing
    case meetingNotEligible(String)
    case notLoaded
    case saveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .workingDirectoryMissing:
            return "Working directory is not configured."
        case .meetingNotEligible(let detail):
            return detail
        case .notLoaded:
            return "Review is not loaded."
        case .saveFailed(let detail):
            return detail
        }
    }
}

/// Loads AI output for review and commits accepted todos into the global list.
public final class ProcessingReviewCoordinator: @unchecked Sendable {
    public private(set) var phase: ReviewPhase
    public private(set) var draft: ReviewDraft?
    public private(set) var lastError: String?

    private let sessionStore: AppSessionStore
    private let fileSystem: FileSystemClient
    private let clock: () -> Date

    public init(
        sessionStore: AppSessionStore = AppSessionStore(),
        fileSystem: FileSystemClient = FoundationFileSystem(),
        clock: (() -> Date)? = nil
    ) {
        self.sessionStore = sessionStore
        self.fileSystem = fileSystem
        self.clock = clock ?? Date.init
        self.phase = .idle
        self.draft = nil
        self.lastError = nil
    }

    public static func validateEligible(_ meeting: Meeting) throws {
        switch meeting.status {
        case .processedPendingReview, .completed:
            return
        case .transcribed:
            throw ProcessingReviewError.meetingNotEligible("Run AI processing before review.")
        case .capturing:
            throw ProcessingReviewError.meetingNotEligible("Meeting is still being recorded.")
        case .captured:
            throw ProcessingReviewError.meetingNotEligible("Transcribe and process this meeting first.")
        case .failed:
            throw ProcessingReviewError.meetingNotEligible("Meeting failed processing. Re-process before review.")
        }
    }

    /// Loads summary, transcript peek, and proposed todos for the meeting.
    public func load(meetingID: String) throws -> ReviewDraft {
        phase = .loading
        lastError = nil
        do {
            let store = try makeStore()
            let meeting = try store.loadMeeting(id: meetingID)
            try Self.validateEligible(meeting)

            let summary = (try store.loadSummary(meetingID: meetingID)) ?? ""
            let transcript = try store.loadTranscript(meetingID: meetingID)
            let preview = Self.transcriptPreview(from: transcript)
            let proposed = try store.loadProposedTodos(meetingID: meetingID)

            let draft = ReviewDraft(
                meetingID: meeting.id,
                meetingTitle: meeting.title,
                summaryMarkdown: summary,
                transcriptPreview: preview,
                candidates: proposed
            )
            self.draft = draft
            phase = .ready
            return draft
        } catch {
            phase = .failed
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Persists in-memory candidate edits back to the meeting folder (still proposed).
    public func saveDraftEdits(_ draft: ReviewDraft) throws {
        lastError = nil
        do {
            let store = try makeStore()
            try store.saveProposedTodos(draft.candidates, meetingID: draft.meetingID)
            self.draft = draft
            phase = .ready
        } catch {
            lastError = error.localizedDescription
            throw ProcessingReviewError.saveFailed(error.localizedDescription)
        }
    }

    /// Accepts remaining draft candidates into the global todo list and marks meeting completed.
    @discardableResult
    public func accept(_ draft: ReviewDraft) throws -> [TodoItem] {
        phase = .saving
        lastError = nil
        do {
            let store = try makeStore()
            _ = try store.loadMeeting(id: draft.meetingID)

            // Persist latest edits as proposed, then accept all remaining ids.
            try store.saveProposedTodos(draft.candidates, meetingID: draft.meetingID)
            let accepted = try store.acceptProposedTodos(ids: draft.acceptIDs, meetingID: draft.meetingID)

            // Clear proposed list after accept (candidates are now global).
            try store.saveProposedTodos([], meetingID: draft.meetingID)

            var meeting = try store.loadMeeting(id: draft.meetingID)
            meeting.status = .completed
            meeting.failureReason = nil
            meeting.updatedAt = clock()
            try store.updateMeeting(meeting)

            self.draft = draft
            self.draft?.candidates = []
            phase = .completed
            return accepted
        } catch {
            phase = .failed
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Discards proposed todos and returns the meeting to `transcribed` for re-processing.
    public func discard(meetingID: String) throws {
        phase = .saving
        lastError = nil
        do {
            let store = try makeStore()
            try store.saveProposedTodos([], meetingID: meetingID)
            var meeting = try store.loadMeeting(id: meetingID)
            meeting.status = .transcribed
            meeting.failureReason = nil
            meeting.updatedAt = clock()
            try store.updateMeeting(meeting)
            draft = nil
            phase = .completed
        } catch {
            phase = .failed
            lastError = error.localizedDescription
            throw error
        }
    }

    public func reset() {
        phase = .idle
        draft = nil
        lastError = nil
    }

    public static func transcriptPreview(from transcript: Transcript?, maxCharacters: Int = 500) -> String {
        guard let transcript else { return "" }
        let text = transcript.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > maxCharacters else { return text }
        let end = text.index(text.startIndex, offsetBy: maxCharacters)
        return String(text[..<end]) + "…"
    }

    private func makeStore() throws -> WorkingDirectoryStore {
        let session = sessionStore.load()
        guard let path = session.workingDirectoryPath, !path.isEmpty else {
            throw ProcessingReviewError.workingDirectoryMissing
        }
        let root = URL(fileURLWithPath: path, isDirectory: true)
        let store = WorkingDirectoryStore(root: root, fileSystem: fileSystem, clock: clock)
        if !store.isInitialized {
            _ = try store.initialize()
        }
        return store
    }
}
