import Foundation

/// One timed span of spoken text.
public struct TranscriptSegment: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var startSeconds: Double
    public var endSeconds: Double
    public var text: String
    public var speaker: String?

    public init(
        id: String = UUID().uuidString,
        startSeconds: Double,
        endSeconds: Double,
        text: String,
        speaker: String? = nil
    ) {
        self.id = id
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.text = text
        self.speaker = speaker
    }

    /// Whether `time` falls within this segment's half-open range `[start, end)`.
    /// The final segment also includes its end bound so the last instant maps cleanly.
    public func contains(timeSeconds time: Double, isLast: Bool = false) -> Bool {
        if isLast {
            return time >= startSeconds && time <= endSeconds
        }
        return time >= startSeconds && time < endSeconds
    }
}

/// Full transcript for a meeting (`meetings/<id>/transcript.json`).
public struct Transcript: Codable, Equatable, Sendable {
    public var meetingID: String
    public var languageCode: String?
    public var segments: [TranscriptSegment]
    public var createdAt: Date

    public init(
        meetingID: String,
        languageCode: String? = nil,
        segments: [TranscriptSegment] = [],
        createdAt: Date = Date()
    ) {
        self.meetingID = meetingID
        self.languageCode = languageCode
        self.segments = segments
        self.createdAt = createdAt
    }

    /// Joined segment text for search and AI prompts.
    public var fullText: String {
        segments
            .map(\.text)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Segment active at `time`, if any.
    public func segment(at timeSeconds: Double) -> TranscriptSegment? {
        guard !segments.isEmpty else { return nil }
        for (index, segment) in segments.enumerated() {
            let last = index == segments.count - 1
            if segment.contains(timeSeconds: timeSeconds, isLast: last) {
                return segment
            }
        }
        return nil
    }
}
