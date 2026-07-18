import Foundation
import Testing
@testable import Bethal

@Suite("Transcript")
struct TranscriptTests {
    @Test("fullText joins non-empty segments")
    func fullText() {
        let transcript = Transcript(
            meetingID: "m1",
            segments: [
                TranscriptSegment(id: "1", startSeconds: 0, endSeconds: 1, text: " Hello "),
                TranscriptSegment(id: "2", startSeconds: 1, endSeconds: 2, text: "  "),
                TranscriptSegment(id: "3", startSeconds: 2, endSeconds: 3, text: "world"),
            ]
        )
        #expect(transcript.fullText == "Hello world")
    }

    @Test("segment at time uses half-open ranges and includes end of last")
    func segmentAtTime() {
        let segments = [
            TranscriptSegment(id: "a", startSeconds: 0, endSeconds: 5, text: "a"),
            TranscriptSegment(id: "b", startSeconds: 5, endSeconds: 10, text: "b"),
        ]
        let transcript = Transcript(meetingID: "m", segments: segments)
        #expect(transcript.segment(at: 0)?.id == "a")
        #expect(transcript.segment(at: 4.9)?.id == "a")
        #expect(transcript.segment(at: 5)?.id == "b")
        #expect(transcript.segment(at: 10)?.id == "b")
        #expect(transcript.segment(at: 10.1) == nil)
        #expect(Transcript(meetingID: "m").segment(at: 1) == nil)
    }

    @Test("contains time honors isLast")
    func containsTime() {
        let segment = TranscriptSegment(id: "x", startSeconds: 1, endSeconds: 2, text: "x")
        #expect(segment.contains(timeSeconds: 1, isLast: false))
        #expect(!segment.contains(timeSeconds: 2, isLast: false))
        #expect(segment.contains(timeSeconds: 2, isLast: true))
        #expect(!segment.contains(timeSeconds: 0.5, isLast: true))
    }

    @Test("transcript JSON round-trip")
    func jsonRoundTrip() throws {
        let transcript = Transcript(
            meetingID: "m1",
            languageCode: "en-US",
            segments: [
                TranscriptSegment(id: "s1", startSeconds: 0, endSeconds: 1.5, text: "Hi", speaker: "A"),
            ],
            createdAt: Date(timeIntervalSince1970: 50)
        )
        let data = try JSONCoding.encode(transcript)
        let decoded = try JSONCoding.decode(Transcript.self, from: data)
        #expect(decoded == transcript)
    }
}
