import Foundation
import Speech

/// On-device speech transcription via `SFSpeechRecognizer` (Apple Speech).
///
/// Prefers `supportsOnDeviceRecognition` when available. Requires Speech Recognition permission.
public final class AppleSpeechTranscriptionEngine: TranscriptionEngine, @unchecked Sendable {
    private let locale: Locale

    public init(locale: Locale = .current) {
        self.locale = locale
    }

    public func transcribe(
        audioURL: URL,
        meetingID: String,
        languageCode: String?,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> Transcript {
        let status = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard status == .authorized else {
            throw TranscriptionError.notAuthorized
        }

        let recognizerLocale = languageCode.map { Locale(identifier: $0) } ?? locale
        guard let recognizer = SFSpeechRecognizer(locale: recognizerLocale), recognizer.isAvailable else {
            throw TranscriptionError.unavailable
        }

        onProgress(0.1)
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        request.shouldReportPartialResults = true

        let transcript = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Transcript, Error>) in
            var hasResumed = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    if !hasResumed {
                        hasResumed = true
                        cont.resume(throwing: TranscriptionError.engineFailed(error.localizedDescription))
                    }
                    return
                }
                guard let result else { return }
                onProgress(result.isFinal ? 1.0 : 0.55)
                if result.isFinal, !hasResumed {
                    hasResumed = true
                    let segments = Self.segments(from: result, meetingID: meetingID)
                    if segments.isEmpty {
                        cont.resume(throwing: TranscriptionError.emptyResult)
                    } else {
                        cont.resume(
                            returning: Transcript(
                                meetingID: meetingID,
                                languageCode: recognizerLocale.identifier,
                                segments: segments,
                                createdAt: Date()
                            )
                        )
                    }
                }
            }
        }
        return transcript
    }

    public static func segments(from result: SFSpeechRecognitionResult, meetingID: String) -> [TranscriptSegment] {
        let transcription = result.bestTranscription
        if transcription.segments.isEmpty {
            let text = transcription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return [] }
            return [
                TranscriptSegment(id: "\(meetingID)-0", startSeconds: 0, endSeconds: 0, text: text),
            ]
        }

        return transcription.segments.enumerated().map { index, segment in
            let start = segment.timestamp
            let end = start + segment.duration
            return TranscriptSegment(
                id: "\(meetingID)-\(index)",
                startSeconds: start.isFinite ? start : 0,
                endSeconds: end.isFinite ? max(start, end) : start,
                text: segment.substring
            )
        }
        .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
