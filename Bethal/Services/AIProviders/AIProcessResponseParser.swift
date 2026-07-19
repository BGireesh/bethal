import Foundation

public enum AIProcessResponseParserError: Error, Equatable, Sendable, LocalizedError {
    case empty
    case invalidJSON(String)
    case missingSummary

    public var errorDescription: String? {
        switch self {
        case .empty:
            return "AI provider returned empty output."
        case .invalidJSON(let detail):
            return "Could not parse AI JSON: \(detail)"
        case .missingSummary:
            return "AI response is missing summaryMarkdown."
        }
    }
}

/// Extracts `AIProcessJSONPayload` from CLI stdout (tolerates optional code fences).
public enum AIProcessResponseParser: Sendable {
    public static func parse(_ raw: String) throws -> AIProcessJSONPayload {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIProcessResponseParserError.empty
        }

        let jsonText = extractJSONObject(from: trimmed) ?? trimmed
        let data = Data(jsonText.utf8)

        do {
            let payload = try JSONDecoder().decode(AIProcessJSONPayload.self, from: data)
            let summary = payload.summaryMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !summary.isEmpty else {
                throw AIProcessResponseParserError.missingSummary
            }
            return AIProcessJSONPayload(summaryMarkdown: summary, todos: payload.todos)
        } catch let error as AIProcessResponseParserError {
            throw error
        } catch {
            throw AIProcessResponseParserError.invalidJSON(error.localizedDescription)
        }
    }

    /// Maps parsed payload into domain todos for a meeting.
    public static func makeResult(
        from payload: AIProcessJSONPayload,
        request: MeetingProcessRequest,
        providerID: String,
        rawOutput: String,
        clock: (() -> Date)? = nil
    ) -> MeetingProcessResult {
        let now = (clock ?? Date.init)()
        let todos = payload.todos.enumerated().compactMap { index, candidate -> TodoItem? in
            let title = candidate.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            return TodoItem(
                id: "\(request.meetingID)-todo-\(index)",
                title: title,
                notes: candidate.notes,
                meetingID: request.meetingID,
                meetingTitle: request.meetingTitle,
                lifecycle: .proposed,
                createdAt: now
            )
        }
        return MeetingProcessResult(
            summaryMarkdown: payload.summaryMarkdown,
            proposedTodos: todos,
            providerID: providerID,
            rawOutput: rawOutput
        )
    }

    /// Prefer first fenced ```json block, else first `{...}` span.
    public static func extractJSONObject(from text: String) -> String? {
        if let fenced = extractFencedJSON(from: text) {
            return fenced
        }
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start < end else {
            return nil
        }
        return String(text[start...end])
    }

    private static func extractFencedJSON(from text: String) -> String? {
        let markers = ["```json", "```JSON", "```"]
        for marker in markers {
            guard let openRange = text.range(of: marker) else { continue }
            let afterOpen = text[openRange.upperBound...]
            guard let close = afterOpen.range(of: "```") else { continue }
            let inner = String(afterOpen[..<close.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if inner.contains("{") {
                return inner
            }
        }
        return nil
    }
}
