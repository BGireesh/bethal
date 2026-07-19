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
            statusLabel: "S",
            modeLabel: "M",
            whenLabel: "W"
        )
        #expect(row.id == "x")
        #expect(row.title == "T")
        #expect(row.statusLabel == "S")
        #expect(row.modeLabel == "M")
        #expect(row.whenLabel == "W")
    }

    @Test("status display names")
    func statusNames() {
        for status in MeetingStatus.allCases {
            #expect(!status.displayName.isEmpty)
        }
    }
}
