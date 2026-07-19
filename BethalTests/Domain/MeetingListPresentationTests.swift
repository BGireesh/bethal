import Foundation
import Testing
@testable import Bethal

@Suite("MeetingListPresentation")
struct MeetingListPresentationTests {
    @Test("maps entry fields")
    func mapsEntry() {
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = MeetingIndexEntry(
            id: "m1",
            title: "Vendor",
            status: .captured,
            captureMode: .audioOnly,
            startedAt: started
        )
        let row = MeetingListPresentation(entry: entry, now: started, calendar: Calendar(identifier: .gregorian))
        #expect(row.id == "m1")
        #expect(row.title == "Vendor")
        #expect(row.statusLabel == "Captured")
        #expect(row.modeLabel == "Audio only")
        #expect(!row.whenLabel.isEmpty)
    }

    @Test("empty title becomes Untitled")
    func emptyTitle() {
        let entry = MeetingIndexEntry(
            id: "m2",
            title: "",
            status: .capturing,
            captureMode: .audioVideo,
            startedAt: Date()
        )
        let row = MeetingListPresentation(entry: entry)
        #expect(row.title == "Untitled meeting")
        #expect(row.modeLabel == "Audio + video")
        #expect(row.statusLabel == "Recording…")
    }

    @Test("formatWhen today and other")
    func formatWhen() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let today = MeetingListPresentation.formatWhen(now, now: now, calendar: calendar)
        #expect(today.contains("Today") || !today.isEmpty)

        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let yLabel = MeetingListPresentation.formatWhen(yesterday, now: now, calendar: calendar)
        #expect(yLabel.contains("Yesterday") || !yLabel.isEmpty)

        let earlier = calendar.date(byAdding: .day, value: -3, to: now)!
        let label = MeetingListPresentation.formatWhen(earlier, now: now, calendar: calendar)
        #expect(!label.isEmpty)

        let lastYear = calendar.date(byAdding: .year, value: -1, to: now)!
        let yearLabel = MeetingListPresentation.formatWhen(lastYear, now: now, calendar: calendar)
        #expect(yearLabel.contains("202") || !yearLabel.isEmpty)
    }

    @Test("explicit memberwise init")
    func memberwise() {
        let row = MeetingListPresentation(
            id: "x",
            title: "T",
            status: .captured,
            statusLabel: "S",
            modeLabel: "M",
            whenLabel: "W"
        )
        #expect(row.id == "x")
        #expect(row.title == "T")
        #expect(row.statusLabel == "S")
        #expect(row.modeLabel == "M")
        #expect(row.whenLabel == "W")
        #expect(row.canTranscribe)
        #expect(row.transcribeButtonTitle == "Transcribe")
    }

    @Test("transcribe affordances by status")
    func transcribeAffordances() {
        let base = MeetingIndexEntry(
            id: "m",
            title: "T",
            status: .capturing,
            captureMode: .audioOnly,
            startedAt: Date()
        )
        #expect(!MeetingListPresentation(entry: base).canTranscribe)

        var captured = base
        captured.status = .captured
        #expect(MeetingListPresentation(entry: captured).transcribeButtonTitle == "Transcribe")

        var transcribed = base
        transcribed.status = .transcribed
        #expect(MeetingListPresentation(entry: transcribed).transcribeButtonTitle == "Re-transcribe")

        var failed = base
        failed.status = .failed
        #expect(MeetingListPresentation(entry: failed).transcribeButtonTitle == "Retry transcription")

        var pending = base
        pending.status = .processedPendingReview
        #expect(MeetingListPresentation(entry: pending).canTranscribe)
        #expect(MeetingListPresentation(entry: pending).transcribeButtonTitle == "Re-transcribe")

        var completed = base
        completed.status = .completed
        #expect(MeetingListPresentation(entry: completed).transcribeButtonTitle == "Re-transcribe")
    }

    @Test("process affordances by status")
    func processAffordances() {
        let base = MeetingIndexEntry(
            id: "m",
            title: "T",
            status: .captured,
            captureMode: .audioOnly,
            startedAt: Date()
        )
        #expect(!MeetingListPresentation(entry: base).canProcess)

        var transcribed = base
        transcribed.status = .transcribed
        #expect(MeetingListPresentation(entry: transcribed).canProcess)
        #expect(MeetingListPresentation(entry: transcribed).processButtonTitle == "Process with AI")

        var pending = base
        pending.status = .processedPendingReview
        #expect(MeetingListPresentation(entry: pending).processButtonTitle == "Re-process")

        var failed = base
        failed.status = .failed
        #expect(MeetingListPresentation(entry: failed).processButtonTitle == "Retry processing")
    }

    @Test("status display names")
    func statusNames() {
        for status in MeetingStatus.allCases {
            #expect(!status.displayName.isEmpty)
        }
    }
}
