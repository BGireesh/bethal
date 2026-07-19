import Foundation

/// View-ready fields for a meetings list row.
public struct MeetingListPresentation: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var status: MeetingStatus
    public var statusLabel: String
    public var modeLabel: String
    public var whenLabel: String

    public init(
        id: String,
        title: String,
        status: MeetingStatus,
        statusLabel: String,
        modeLabel: String,
        whenLabel: String
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.statusLabel = statusLabel
        self.modeLabel = modeLabel
        self.whenLabel = whenLabel
    }

    public init(entry: MeetingIndexEntry, now: Date = Date(), calendar: Calendar = .current) {
        self.id = entry.id
        self.title = entry.title.isEmpty ? "Untitled meeting" : entry.title
        self.status = entry.status
        self.statusLabel = entry.status.displayName
        self.modeLabel = entry.captureMode == .audioVideo ? "Audio + video" : "Audio only"
        self.whenLabel = Self.formatWhen(entry.startedAt, now: now, calendar: calendar)
    }

    /// Whether the user can run (or re-run) local transcription for this meeting.
    public var canTranscribe: Bool {
        switch status {
        case .capturing:
            return false
        case .captured, .transcribed, .processedPendingReview, .completed, .failed:
            return true
        }
    }

    public var transcribeButtonTitle: String {
        switch status {
        case .transcribed, .processedPendingReview, .completed:
            return "Re-transcribe"
        case .failed:
            return "Retry transcription"
        default:
            return "Transcribe"
        }
    }

    /// Whether the user can run AI summary/todo processing (needs a transcript).
    public var canProcess: Bool {
        switch status {
        case .transcribed, .processedPendingReview, .completed, .failed:
            return true
        case .capturing, .captured:
            return false
        }
    }

    public var processButtonTitle: String {
        switch status {
        case .processedPendingReview, .completed:
            return "Re-process"
        case .failed:
            return "Retry processing"
        default:
            return "Process with AI"
        }
    }

    /// Whether the user can open the post-AI review sheet.
    public var canReview: Bool {
        switch status {
        case .processedPendingReview, .completed:
            return true
        case .capturing, .captured, .transcribed, .failed:
            return false
        }
    }

    public var reviewButtonTitle: String {
        switch status {
        case .completed:
            return "Review again"
        default:
            return "Review"
        }
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
