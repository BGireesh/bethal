import Foundation

/// Where a todo currently lives in the storage layout.
public enum TodoLifecycle: String, Codable, Sendable, Equatable {
    /// Candidate from AI processing; stored under the meeting folder until accepted.
    case proposed
    /// User-accepted item in the global todo index.
    case accepted
}

/// Action item extracted from a meeting or accepted into the global list.
public struct TodoItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var notes: String?
    public var isCompleted: Bool
    public var meetingID: String
    /// Denormalized meeting title for provenance UI without loading meta.
    public var meetingTitle: String
    public var lifecycle: TodoLifecycle
    public var createdAt: Date
    public var completedAt: Date?
    public var reminderAt: Date?

    public init(
        id: String = UUID().uuidString,
        title: String,
        notes: String? = nil,
        isCompleted: Bool = false,
        meetingID: String,
        meetingTitle: String,
        lifecycle: TodoLifecycle = .proposed,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        reminderAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.meetingID = meetingID
        self.meetingTitle = meetingTitle
        self.lifecycle = lifecycle
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.reminderAt = reminderAt
    }

    /// Marks complete and stamps `completedAt` (or clears it when reopening).
    public mutating func setCompleted(_ completed: Bool, at date: Date = Date()) {
        isCompleted = completed
        completedAt = completed ? date : nil
    }

    /// Accepted form for the global index (same id, lifecycle flipped).
    public func acceptedCopy() -> TodoItem {
        var copy = self
        copy.lifecycle = .accepted
        return copy
    }
}

/// On-disk shape of `index/todos.json` and per-meeting `todos.json`.
public struct TodosDocument: Codable, Equatable, Sendable {
    public var todos: [TodoItem]

    public init(todos: [TodoItem] = []) {
        self.todos = todos
    }
}
