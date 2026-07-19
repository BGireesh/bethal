import Foundation

/// In-memory editable state for post-AI review (before accept into global todos).
public struct ReviewDraft: Equatable, Sendable {
    public var meetingID: String
    public var meetingTitle: String
    public var summaryMarkdown: String
    public var transcriptPreview: String
    public var candidates: [TodoItem]

    public init(
        meetingID: String,
        meetingTitle: String,
        summaryMarkdown: String = "",
        transcriptPreview: String = "",
        candidates: [TodoItem] = []
    ) {
        self.meetingID = meetingID
        self.meetingTitle = meetingTitle
        self.summaryMarkdown = summaryMarkdown
        self.transcriptPreview = transcriptPreview
        self.candidates = candidates
    }

    public var isEmpty: Bool { candidates.isEmpty }
    public var candidateCount: Int { candidates.count }

    /// Updates title (and optional notes) for a candidate by id. Empty titles are rejected.
    public mutating func updateCandidate(id: String, title: String, notes: String? = nil) -> Bool {
        guard let index = candidates.firstIndex(where: { $0.id == id }) else { return false }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        candidates[index].title = trimmed
        if let notes {
            let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            candidates[index].notes = n.isEmpty ? nil : n
        }
        return true
    }

    /// Removes a candidate (reject).
    @discardableResult
    public mutating func removeCandidate(id: String) -> Bool {
        let before = candidates.count
        candidates.removeAll { $0.id == id }
        return candidates.count < before
    }

    /// Removes all candidates.
    public mutating func removeAllCandidates() {
        candidates.removeAll()
    }

    /// IDs of candidates that will be accepted.
    public var acceptIDs: Set<String> {
        Set(candidates.map(\.id))
    }

    /// Builds accepted copies for global store merge.
    public func acceptedTodos() -> [TodoItem] {
        candidates.map { $0.acceptedCopy() }
    }
}

/// Pure merge rules for accepting reviewed todos into the global list.
public enum TodoAcceptMerge: Sendable {
    /// Upserts accepted items by id; preserves order of existing globals not in the batch.
    public static func merge(existing: [TodoItem], accepting: [TodoItem]) -> [TodoItem] {
        var result = existing.map { todo -> TodoItem in
            var copy = todo
            copy.lifecycle = .accepted
            return copy
        }
        for item in accepting {
            let accepted = item.acceptedCopy()
            if let index = result.firstIndex(where: { $0.id == accepted.id }) {
                result[index] = accepted
            } else {
                result.append(accepted)
            }
        }
        return result
    }
}
