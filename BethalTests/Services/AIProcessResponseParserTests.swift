import Foundation
import Testing
@testable import Bethal

@Suite("AIProcessResponseParser and prompts")
struct AIProcessResponseParserTests {
    private let fixedNow = Date(timeIntervalSince1970: 5_100_000_000)

    @Test("parses pure JSON")
    func pureJSON() throws {
        let raw = """
        {"summaryMarkdown":"## Hello","todos":[{"title":"Ship it","notes":"soon"}]}
        """
        let payload = try AIProcessResponseParser.parse(raw)
        #expect(payload.summaryMarkdown == "## Hello")
        #expect(payload.todos.count == 1)
        #expect(payload.todos[0].title == "Ship it")
    }

    @Test("parses fenced JSON")
    func fenced() throws {
        let raw = """
        Here you go:
        ```json
        {"summaryMarkdown":"S","todos":[]}
        ```
        """
        let payload = try AIProcessResponseParser.parse(raw)
        #expect(payload.summaryMarkdown == "S")
    }

    @Test("parses embedded braces")
    func embedded() throws {
        let raw = "noise {\"summaryMarkdown\":\"Z\",\"todos\":[]} trailing"
        let payload = try AIProcessResponseParser.parse(raw)
        #expect(payload.summaryMarkdown == "Z")
    }

    @Test("empty and invalid")
    func failures() {
        #expect(throws: AIProcessResponseParserError.self) {
            _ = try AIProcessResponseParser.parse("   ")
        }
        #expect(throws: AIProcessResponseParserError.self) {
            _ = try AIProcessResponseParser.parse("not json")
        }
        #expect(throws: AIProcessResponseParserError.self) {
            _ = try AIProcessResponseParser.parse("{\"summaryMarkdown\":\"\",\"todos\":[]}")
        }
        #expect(AIProcessResponseParserError.empty.errorDescription != nil)
        #expect(AIProcessResponseParserError.invalidJSON("x").errorDescription?.contains("x") == true)
        #expect(AIProcessResponseParserError.missingSummary.errorDescription != nil)
    }

    @Test("makeResult maps todos and drops empty titles")
    func makeResult() throws {
        let request = MeetingProcessRequest(meetingID: "m1", meetingTitle: "Call", transcriptText: "hi")
        let payload = AIProcessJSONPayload(
            summaryMarkdown: "Sum",
            todos: [
                AITodoCandidate(title: "  Task  ", notes: "n"),
                AITodoCandidate(title: "   ", notes: nil),
            ]
        )
        let result = AIProcessResponseParser.makeResult(
            from: payload,
            request: request,
            providerID: "claude",
            rawOutput: "{}",
            clock: { fixedNow }
        )
        #expect(result.summaryMarkdown == "Sum")
        #expect(result.proposedTodos.count == 1)
        #expect(result.proposedTodos[0].title == "Task")
        #expect(result.proposedTodos[0].lifecycle == .proposed)
        #expect(result.proposedTodos[0].meetingID == "m1")
        #expect(result.providerID == "claude")
    }

    @Test("prompt includes transcript and schema")
    func prompt() {
        let request = MeetingProcessRequest(
            meetingID: "m",
            meetingTitle: "Standup",
            transcriptText: "We shipped feature X",
            languageCode: "en-US"
        )
        let prompt = PromptTemplates.summaryAndTodosPrompt(for: request)
        #expect(prompt.contains("Standup"))
        #expect(prompt.contains("We shipped feature X"))
        #expect(prompt.contains("summaryMarkdown"))
        #expect(prompt.contains("en-US"))
        #expect(!PromptTemplates.jsonSchemaHint.isEmpty)
    }

    @Test("CLIProvider happy path")
    func cliProvider() async throws {
        let json = #"{"summaryMarkdown":"Done","todos":[{"title":"Follow up"}]}"#
        let runner = MockProcessRunner(result: ProcessRunResult(exitCode: 0, standardOutput: json))
        let provider = CLIProvider(
            blueprint: .claude,
            executableURL: URL(fileURLWithPath: "/usr/local/bin/claude"),
            runner: runner
            // default clock
        )
        let result = try await provider.process(
            MeetingProcessRequest(meetingID: "m", meetingTitle: "T", transcriptText: "body")
        )
        #expect(result.summaryMarkdown == "Done")
        #expect(result.proposedTodos.count == 1)
        #expect(runner.lastArguments?.contains(where: { $0.contains("body") || $0 == "-p" }) == true)

        let payload = try AIProcessResponseParser.parse(json)
        let withDefaultClock = AIProcessResponseParser.makeResult(
            from: payload,
            request: MeetingProcessRequest(meetingID: "m", meetingTitle: "T", transcriptText: "body"),
            providerID: "claude",
            rawOutput: json
        )
        #expect(withDefaultClock.proposedTodos.count == 1)
    }

    @Test("plain fence without json tag")
    func plainFence() throws {
        let raw = """
        ```
        {"summaryMarkdown":"P","todos":[]}
        ```
        """
        let payload = try AIProcessResponseParser.parse(raw)
        #expect(payload.summaryMarkdown == "P")
    }

    @Test("CLIProvider failure paths")
    func cliFailures() async {
        let failRunner = MockProcessRunner(
            result: ProcessRunResult(exitCode: 1, standardOutput: "", standardError: "nope")
        )
        let provider = CLIProvider(
            blueprint: .codex,
            executableURL: URL(fileURLWithPath: "/bin/codex"),
            runner: failRunner,
            clock: { fixedNow }
        )
        await #expect(throws: ProcessRunnerError.self) {
            _ = try await provider.process(
                MeetingProcessRequest(meetingID: "m", meetingTitle: "T", transcriptText: "x")
            )
        }

        let emptyOut = MockProcessRunner(result: ProcessRunResult(exitCode: 0, standardOutput: "  "))
        let emptyProvider = CLIProvider(
            blueprint: .grok,
            executableURL: URL(fileURLWithPath: "/bin/grok"),
            runner: emptyOut,
            clock: { fixedNow }
        )
        await #expect(throws: ProcessRunnerError.self) {
            _ = try await emptyProvider.process(
                MeetingProcessRequest(meetingID: "m", meetingTitle: "T", transcriptText: "x")
            )
        }
    }
}
