import Foundation

/// View-ready fields for a meetings list row.
public struct MeetingListPresentation: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var statusLabel: String
    public var modeLabel: String
    public var whenLabel: String

    public init(id: String, title: String, statusLabel: String, modeLabel: String, whenLabel: String) {
        self.id = id
        self.title = title
        self.statusLabel = statusLabel
        self.modeLabel = modeLabel
        self.whenLabel = whenLabel
    }

    public init(entry: MeetingIndexEntry, now: Date = Date(), calendar: Calendar = .current) {
        self.id = entry.id
        self.title = entry.title.isEmpty ? "Untitled meeting" : entry.title
        self.statusLabel = entry.status.displayName
        self.modeLabel = entry.captureMode == .audioVideo ? "Audio + video" : "Audio only"
        self.whenLabel = Self.formatWhen(entry.startedAt, now: now, calendar: calendar)
    }

    public static func formatWhen(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        if calendar.isDate(date, inSameDayAs: now) {
            formatter.dateFormat = "'Today' · h:mm a"
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                  calendar.isDate(date, inSameDayAs: yesterday) {
            formatter.dateFormat = "'Yesterday' · h:mm a"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            formatter.dateFormat = "MMM d · h:mm a"
        } else {
            formatter.dateFormat = "MMM d, yyyy · h:mm a"
        }
        return formatter.string(from: date)
    }
}
