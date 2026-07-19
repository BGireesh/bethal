import Foundation

/// UI façade for running and retrying local transcription on a meeting.
public final class TranscriptionViewModel: @unchecked Sendable {
    public private(set) var progress: TranscriptionProgress
    public private(set) var lastTranscript: Transcript?
    public private(set) var lastError: String?

    private let coordinator: TranscriptionCoordinator

    public init(coordinator: TranscriptionCoordinator) {
        self.coordinator = coordinator
        self.progress = coordinator.progress
        self.lastTranscript = nil
        self.lastError = nil
    }

    public var isInProgress: Bool { progress.phase.isInProgress }
    public var canRetry: Bool { progress.phase == .failed || progress.phase == .completed || progress.phase == .idle }

    public func transcribe(meetingID: String) async {
        lastError = nil
        lastTranscript = nil
        do {
            let transcript = try await coordinator.transcribeMeeting(id: meetingID)
            lastTranscript = transcript
            progress = coordinator.progress
        } catch {
            lastError = error.localizedDescription
            progress = coordinator.progress
        }
    }

    public func retry(meetingID: String) async {
        await transcribe(meetingID: meetingID)
    }

    public func reset() {
        coordinator.resetProgress()
        progress = coordinator.progress
        lastTranscript = nil
        lastError = nil
    }

    public func syncProgress() {
        progress = coordinator.progress
    }
}
