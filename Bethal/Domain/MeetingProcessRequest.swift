import Foundation

/// Input for local AI summarization / todo extraction.
public struct MeetingProcessRequest: Equatable, Sendable {
    public var meetingID: String
    public var meetingTitle: String
    public var transcriptText: String
    public var languageCode: String?

    public init(
        meetingID: String,
        meetingTitle: String,
        transcriptText: String,
        languageCode: String? = nil
    ) {
        self.meetingID = meetingID
        self.meetingTitle = meetingTitle
        self.transcriptText = transcriptText
        self.languageCode = languageCode
    }
}
