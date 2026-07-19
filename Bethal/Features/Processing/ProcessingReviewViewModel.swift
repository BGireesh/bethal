import Foundation

/// UI façade for reviewing AI summary/todos and accepting into the global list.
public final class ProcessingReviewViewModel: @unchecked Sendable {
    public private(set) var phase: ReviewPhase
    public private(set) var draft: ReviewDraft?
    public private(set) var lastError: String?
    public private(set) var lastAcceptedCount: Int

    private let coordinator: ProcessingReviewCoordinator

    public init(coordinator: ProcessingReviewCoordinator = ProcessingReviewCoordinator()) {
        self.coordinator = coordinator
        self.phase = coordinator.phase
        self.draft = coordinator.draft
        self.lastError = coordinator.lastError
        self.lastAcceptedCount = 0
    }

    public var isBusy: Bool { phase.isBusy }
    public var canAccept: Bool {
        phase == .ready && draft != nil
    }

    public func load(meetingID: String) {
        lastError = nil
        lastAcceptedCount = 0
        do {
            draft = try coordinator.load(meetingID: meetingID)
            phase = coordinator.phase
        } catch {
            lastError = error.localizedDescription
            phase = coordinator.phase
            draft = nil
        }
    }

    public func updateCandidate(id: String, title: String, notes: String? = nil) {
        guard var draft else { return }
        guard draft.updateCandidate(id: id, title: title, notes: notes) else { return }
        self.draft = draft
        try? coordinator.saveDraftEdits(draft)
        phase = coordinator.phase
        lastError = coordinator.lastError
    }

    public func removeCandidate(id: String) {
        guard var draft else { return }
        guard draft.removeCandidate(id: id) else { return }
        self.draft = draft
        try? coordinator.saveDraftEdits(draft)
        phase = coordinator.phase
    }

    public func removeAllCandidates() {
        guard var draft else { return }
        draft.removeAllCandidates()
        self.draft = draft
        try? coordinator.saveDraftEdits(draft)
        phase = coordinator.phase
    }

    public func accept() {
        guard let draft else {
            lastError = ProcessingReviewError.notLoaded.localizedDescription
            return
        }
        do {
            let accepted = try coordinator.accept(draft)
            lastAcceptedCount = accepted.count
            self.draft = coordinator.draft
            phase = coordinator.phase
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            phase = coordinator.phase
        }
    }

    public func discard() {
        guard let meetingID = draft?.meetingID else {
            lastError = ProcessingReviewError.notLoaded.localizedDescription
            return
        }
        do {
            try coordinator.discard(meetingID: meetingID)
            draft = nil
            phase = coordinator.phase
            lastError = nil
            lastAcceptedCount = 0
        } catch {
            lastError = error.localizedDescription
            phase = coordinator.phase
        }
    }

    public func reset() {
        coordinator.reset()
        phase = .idle
        draft = nil
        lastError = nil
        lastAcceptedCount = 0
    }
}
