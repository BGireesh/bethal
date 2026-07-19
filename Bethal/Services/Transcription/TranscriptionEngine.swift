import Foundation

/// Engine that turns an audio/media file into a timestamped transcript.
public protocol TranscriptionEngine: Sendable {
    func transcribe(
        audioURL: URL,
        meetingID: String,
        languageCode: String?,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> Transcript
}

public enum TranscriptionError: Error, Equatable, Sendable, LocalizedError {
    case audioNotFound(meetingID: String)
    case meetingNotEligible(String)
    case notAuthorized
    case unavailable
    case emptyResult
    case engineFailed(String)

    public var errorDescription: String? {
        switch self {
        case .audioNotFound(let id):
            return "No audio file found for meeting \(id)."
        case .meetingNotEligible(let detail):
            return detail
        case .notAuthorized:
            return "Speech recognition is not authorized."
        case .unavailable:
            return "Speech recognition is unavailable on this Mac."
        case .emptyResult:
            return "Transcription produced no text."
        case .engineFailed(let detail):
            return detail
        }
    }
}

/// Deterministic engine for unit tests.
public final class MockTranscriptionEngine: TranscriptionEngine, @unchecked Sendable {
    public var result: Transcript?
    public var error: Error?
    public private(set) var lastAudioURL: URL?
    public private(set) var callCount = 0
    public var progressSteps: [Double] = [0.2, 0.6, 1.0]

    public init(result: Transcript? = nil, error: Error? = nil) {
        self.result = result
        self.error = error
    }

    public func transcribe(
        audioURL: URL,
        meetingID: String,
        languageCode: String?,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> Transcript {
        callCount += 1
        lastAudioURL = audioURL
        for step in progressSteps {
            onProgress(step)
        }
        if let error { throw error }
        if let result { return result }
        return Transcript(
            meetingID: meetingID,
            languageCode: languageCode ?? "en-US",
            segments: [
                TranscriptSegment(id: "s1", startSeconds: 0, endSeconds: 1.5, text: "Hello from mock transcription."),
            ],
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}
