import Foundation
import Testing
@testable import Bethal

@Suite("Meeting models")
struct MeetingModelsTests {
    @Test("MeetingStatus has expected cases")
    func meetingStatusCases() {
        let raw = MeetingStatus.allCases.map(\.rawValue)
        #expect(raw.contains("captured"))
        #expect(raw.contains("processedPendingReview"))
        #expect(raw.contains("completed"))
        #expect(MeetingStatus(rawValue: "failed") == .failed)
    }

    @Test("CaptureMode round-trips")
    func captureMode() {
        #expect(CaptureMode.audioOnly.rawValue == "audioOnly")
        #expect(CaptureMode.audioVideo.rawValue == "audioVideo")
        #expect(CaptureMode(rawValue: "audioOnly") == .audioOnly)
    }

    @Test("Meeting index entry mirrors core fields")
    func indexEntry() {
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let meeting = Meeting(
            id: "m1",
            title: "Vendor sync",
            status: .captured,
            captureMode: .audioVideo,
            startedAt: started,
            endedAt: started.addingTimeInterval(60)
        )
        let entry = meeting.indexEntry
        #expect(entry.id == "m1")
        #expect(entry.title == "Vendor sync")
        #expect(entry.status == .captured)
        #expect(entry.captureMode == .audioVideo)
        #expect(entry.startedAt == started)
        #expect(entry.endedAt == started.addingTimeInterval(60))
    }

    @Test("MeetingsIndex defaults empty")
    func meetingsIndexDefault() {
        #expect(MeetingsIndex().meetings.isEmpty)
    }

    @Test("Meeting encodes and decodes via JSONCoding")
    func meetingJSONRoundTrip() throws {
        let meeting = Meeting(
            id: "abc-123",
            title: "Partner call",
            status: .transcribed,
            captureMode: .audioOnly,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200),
            calendarEventIdentifier: "cal-1",
            audioFileName: "audio.m4a",
            providerID: "claude",
            createdAt: Date(timeIntervalSince1970: 90),
            updatedAt: Date(timeIntervalSince1970: 110)
        )
        let data = try JSONCoding.encode(meeting)
        let decoded = try JSONCoding.decode(Meeting.self, from: data)
        #expect(decoded == meeting)
    }
}
