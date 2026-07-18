import Foundation

/// Full meeting metadata persisted as `meetings/<id>/meta.json`.
public struct Meeting: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var status: MeetingStatus
    public var captureMode: CaptureMode
    public var startedAt: Date
    public var endedAt: Date?
    public var calendarEventIdentifier: String?
    /// File name inside the meeting folder (e.g. `audio.m4a`), not an absolute path.
    public var audioFileName: String?
    /// File name inside the meeting folder (e.g. `video.mp4`).
    public var videoFileName: String?
    public var providerID: String?
    public var failureReason: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        title: String,
        status: MeetingStatus = .captured,
        captureMode: CaptureMode = .audioOnly,
        startedAt: Date,
        endedAt: Date? = nil,
        calendarEventIdentifier: String? = nil,
        audioFileName: String? = nil,
        videoFileName: String? = nil,
        providerID: String? = nil,
        failureReason: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.captureMode = captureMode
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.calendarEventIdentifier = calendarEventIdentifier
        self.audioFileName = audioFileName
        self.videoFileName = videoFileName
        self.providerID = providerID
        self.failureReason = failureReason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Lightweight row for `index/meetings.json`.
    public var indexEntry: MeetingIndexEntry {
        MeetingIndexEntry(
            id: id,
            title: title,
            status: status,
            captureMode: captureMode,
            startedAt: startedAt,
            endedAt: endedAt
        )
    }
}

/// Searchable index entry for the global meetings list.
public struct MeetingIndexEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var status: MeetingStatus
    public var captureMode: CaptureMode
    public var startedAt: Date
    public var endedAt: Date?

    public init(
        id: String,
        title: String,
        status: MeetingStatus,
        captureMode: CaptureMode,
        startedAt: Date,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.captureMode = captureMode
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

/// On-disk shape of `index/meetings.json`.
public struct MeetingsIndex: Codable, Equatable, Sendable {
    public var meetings: [MeetingIndexEntry]

    public init(meetings: [MeetingIndexEntry] = []) {
        self.meetings = meetings
    }
}
