import Foundation

/// Progress snapshot for post-call AI processing UI.
public struct ProcessingProgress: Equatable, Sendable {
    public var phase: ProcessingPhase
    public var fractionCompleted: Double
    public var message: String
    public var meetingID: String?
    public var selectedProviderID: String?

    public init(
        phase: ProcessingPhase = .idle,
        fractionCompleted: Double = 0,
        message: String = "",
        meetingID: String? = nil,
        selectedProviderID: String? = nil
    ) {
        self.phase = phase
        self.fractionCompleted = min(1, max(0, fractionCompleted))
        self.message = message
        self.meetingID = meetingID
        self.selectedProviderID = selectedProviderID
    }

    public static func choosing(meetingID: String) -> ProcessingProgress {
        ProcessingProgress(
            phase: .choosingProvider,
            fractionCompleted: 0,
            message: "Choose a local AI tool",
            meetingID: meetingID
        )
    }

    public static func preparing(meetingID: String, providerID: String) -> ProcessingProgress {
        ProcessingProgress(
            phase: .preparing,
            fractionCompleted: 0.1,
            message: "Loading transcript…",
            meetingID: meetingID,
            selectedProviderID: providerID
        )
    }

    public static func running(meetingID: String, providerID: String) -> ProcessingProgress {
        ProcessingProgress(
            phase: .running,
            fractionCompleted: 0.5,
            message: "Running \(providerID)…",
            meetingID: meetingID,
            selectedProviderID: providerID
        )
    }

    public static func saving(meetingID: String, providerID: String) -> ProcessingProgress {
        ProcessingProgress(
            phase: .saving,
            fractionCompleted: 0.9,
            message: "Saving summary and todos…",
            meetingID: meetingID,
            selectedProviderID: providerID
        )
    }

    public static func completed(meetingID: String, providerID: String) -> ProcessingProgress {
        ProcessingProgress(
            phase: .completed,
            fractionCompleted: 1,
            message: "Ready for review",
            meetingID: meetingID,
            selectedProviderID: providerID
        )
    }

    public static func failed(meetingID: String, message: String) -> ProcessingProgress {
        ProcessingProgress(
            phase: .failed,
            fractionCompleted: 0,
            message: message,
            meetingID: meetingID
        )
    }
}
