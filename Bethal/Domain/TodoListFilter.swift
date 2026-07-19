import Foundation

/// Filter for the global todos list.
public enum TodoListFilter: String, CaseIterable, Identifiable, Sendable, Equatable {
    case incomplete
    case completed
    case all

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .incomplete: return "Open"
        case .completed: return "Done"
        case .all: return "All"
        }
    }

    /// Filters and sorts todos for list display.
    /// Incomplete first (by createdAt desc), then completed (by completedAt desc).
    public func apply(to todos: [TodoItem]) -> [TodoItem] {
        let filtered: [TodoItem]
        switch self {
        case .incomplete:
            filtered = todos.filter { !$0.isCompleted }
        case .completed:
            filtered = todos.filter(\.isCompleted)
        case .all:
            filtered = todos
        }

        return filtered.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted && rhs.isCompleted
            }
            if lhs.isCompleted {
                let l = completedSortKey(lhs)
                let r = completedSortKey(rhs)
                return l > r
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func completedSortKey(_ todo: TodoItem) -> Date {
        if let completedAt = todo.completedAt {
            return completedAt
        }
        return todo.createdAt
    }
}

/// View-ready row for a global todo.
public struct TodoListPresentation: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var notes: String?
    public var isCompleted: Bool
    public var meetingID: String
    public var meetingTitle: String
    public var provenanceLabel: String
    public var reminderLabel: String?
    public var hasReminder: Bool

    public init(
        id: String,
        title: String,
        notes: String? = nil,
        isCompleted: Bool,
        meetingID: String,
        meetingTitle: String,
        provenanceLabel: String,
        reminderLabel: String? = nil,
        hasReminder: Bool = false
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.meetingID = meetingID
        self.meetingTitle = meetingTitle
        self.provenanceLabel = provenanceLabel
        self.reminderLabel = reminderLabel
        self.hasReminder = hasReminder
    }

    public init(todo: TodoItem, now: Date = Date(), calendar: Calendar = .current) {
        self.id = todo.id
        self.title = todo.title
        self.notes = todo.notes
        self.isCompleted = todo.isCompleted
        self.meetingID = todo.meetingID
        self.meetingTitle = todo.meetingTitle.isEmpty ? "Untitled meeting" : todo.meetingTitle
        self.provenanceLabel = Self.makeProvenance(
            meetingTitle: self.meetingTitle,
            createdAt: todo.createdAt,
            now: now,
            calendar: calendar
        )
        if let reminderAt = todo.reminderAt {
            self.hasReminder = true
            self.reminderLabel = Self.formatReminder(reminderAt, now: now, calendar: calendar)
        } else {
            self.hasReminder = false
            self.reminderLabel = nil
        }
    }

    public static func makeProvenance(
        meetingTitle: String,
        createdAt: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let when = MeetingListPresentation.formatWhen(createdAt, now: now, calendar: calendar)
        return "From: \(meetingTitle) · \(when)"
    }

    public static func formatReminder(
        _ date: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        if date < now {
            return "Reminder overdue"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        if calendar.isDate(date, inSameDayAs: now) {
            formatter.dateFormat = "'Remind today' · h:mm a"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
                  calendar.isDate(date, inSameDayAs: tomorrow) {
            formatter.dateFormat = "'Remind tomorrow' · h:mm a"
        } else {
            formatter.dateFormat = "'Remind' MMM d · h:mm a"
        }
        return formatter.string(from: date)
    }
}

/// Relative reminder presets for the UI.
public enum TodoReminderPreset: String, CaseIterable, Identifiable, Sendable, Equatable {
    case inOneHour
    case tomorrowMorning
    case inThreeDays

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .inOneHour: return "In 1 hour"
        case .tomorrowMorning: return "Tomorrow 9:00 AM"
        case .inThreeDays: return "In 3 days"
        }
    }

    public func fireDate(from now: Date = Date(), calendar: Calendar = .current) -> Date {
        switch self {
        case .inOneHour:
            return now.addingTimeInterval(3600)
        case .tomorrowMorning:
            // Start of next local day + 9 hours (no optional calendar math).
            let dayStart = calendar.startOfDay(for: now)
            return dayStart.addingTimeInterval(86_400 + 9 * 3600)
        case .inThreeDays:
            return now.addingTimeInterval(3 * 86_400)
        }
    }
}
