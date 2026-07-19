import Foundation

/// Structured output from a local AI provider run.
public struct MeetingProcessResult: Equatable, Sendable {
    public var summaryMarkdown: String
    public var proposedTodos: [TodoItem]
    public var providerID: String
    public var rawOutput: String?

    public init(
        summaryMarkdown: String,
        proposedTodos: [TodoItem] = [],
        providerID: String,
        rawOutput: String? = nil
    ) {
        self.summaryMarkdown = summaryMarkdown
        self.proposedTodos = proposedTodos
        self.providerID = providerID
        self.rawOutput = rawOutput
    }
}

/// Intermediate decoded shape before mapping into `TodoItem`s.
public struct AITodoCandidate: Codable, Equatable, Sendable {
    public var title: String
    public var notes: String?

    public init(title: String, notes: String? = nil) {
        self.title = title
        self.notes = notes
    }
}

/// Expected JSON envelope from CLI prompts.
public struct AIProcessJSONPayload: Codable, Equatable, Sendable {
    public var summaryMarkdown: String
    public var todos: [AITodoCandidate]

    public init(summaryMarkdown: String, todos: [AITodoCandidate] = []) {
        self.summaryMarkdown = summaryMarkdown
        self.todos = todos
    }
}
