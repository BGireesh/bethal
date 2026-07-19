import Foundation

/// Builds prompts for local CLIs. Output is required to be pure JSON.
public enum PromptTemplates: Sendable {
    public static let jsonSchemaHint = """
    Respond with ONLY a single JSON object (no markdown fences, no prose) using this shape:
    {
      "summaryMarkdown": "string — markdown summary of the meeting",
      "todos": [
        { "title": "string — actionable item", "notes": "optional string" }
      ]
    }
    """

    public static func summaryAndTodosPrompt(for request: MeetingProcessRequest) -> String {
        let language = request.languageCode.map { "Language hint: \($0)\n" } ?? ""
        return """
        You are processing a meeting transcript for the local app Bethal.
        Meeting title: \(request.meetingTitle)
        Meeting id: \(request.meetingID)
        \(language)
        \(jsonSchemaHint)

        Rules:
        - summaryMarkdown: concise markdown (bullets ok); no fabricated attendees.
        - todos: only concrete action items; empty array if none.
        - Do not include text outside the JSON object.

        Transcript:
        ---
        \(request.transcriptText)
        ---
        """
    }
}
