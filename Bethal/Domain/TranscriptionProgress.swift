import Foundation

/// Progress snapshot for UI and tests.
public struct TranscriptionProgress: Equatable, Sendable {
    public var phase: TranscriptionPhase
    /// 0...1 when known; otherwise 0.
    public var fractionCompleted: Double
    public var message: String
    public var meetingID: String?

    public init(
        phase: TranscriptionPhase = .idle,
        fractionCompleted: Double = 0,
        message: String = "",
        meetingID: String? = nil
    ) {
        self.phase = phase
        self.fractionCompleted = min(1, max(0, fractionCompleted))
        self.message = message
        self.meetingID = meetingID
    }

    public static func preparing(meetingID: String) -> TranscriptionProgress {
        TranscriptionProgress(
            phase: .preparing,
            fractionCompleted: 0.05,
            message: "Locating audio…",
            meetingID: meetingID
        )
    }

    public static func transcribing(meetingID: String, fraction: Double) -> TranscriptionProgress {
        TranscriptionProgress(
            phase: .transcribing,
            fractionCompleted: fraction,
            message: "Transcribing speech…",
            meetingID: meetingID
        )
    }

    public static func saving(meetingID: String) -> TranscriptionProgress {
        TranscriptionProgress(
            phase: .saving,
            fractionCompleted: 0.95,
            message: "Saving transcript…",
            meetingID: meetingID
        )
    }

    public static func completed(meetingID: String) -> TranscriptionProgress {
        TranscriptionProgress(
            phase: .completed,
            fractionCompleted: 1,
            message: "Transcript ready",
            meetingID: meetingID
        )
    }

    public static func failed(meetingID: String, message: String) -> TranscriptionProgress {
        TranscriptionProgress(
            phase: .failed,
            fractionCompleted: 0,
            message: message,
            meetingID: meetingID
        )
    }
}
