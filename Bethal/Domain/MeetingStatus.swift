/// Lifecycle status for a recorded meeting through capture and processing.
public enum MeetingStatus: String, Codable, Sendable, CaseIterable, Equatable {
    /// Recording session is active (media not finalized).
    case capturing
    /// Media written; awaiting or ready for transcription.
    case captured
    /// Transcript available; summary/todos not finished.
    case transcribed
    /// AI processing done; user has not finished review.
    case processedPendingReview
    /// User accepted review; meeting is in the library.
    case completed
    /// Unrecoverable failure in a pipeline step.
    case failed

    /// Human-readable label for lists and detail chrome.
    public var displayName: String {
        switch self {
        case .capturing: return "Recording…"
        case .captured: return "Captured"
        case .transcribed: return "Transcribed"
        case .processedPendingReview: return "Ready for review"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}
