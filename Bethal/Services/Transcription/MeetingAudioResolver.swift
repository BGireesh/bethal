import Foundation

/// Resolves the on-disk audio URL for a meeting (audio file, or video container as fallback).
public enum MeetingAudioResolver: Sendable {
    public static func resolveAudioURL(
        for meeting: Meeting,
        layout: ProjectLayout,
        fileSystem: FileSystemClient
    ) throws -> URL {
        if let name = meeting.audioFileName, !name.isEmpty {
            let url = layout.meetingMediaFile(id: meeting.id, fileName: name)
            if fileSystem.fileExists(atPath: url.path) {
                return url
            }
        }

        if let name = meeting.videoFileName, !name.isEmpty {
            let url = layout.meetingMediaFile(id: meeting.id, fileName: name)
            if fileSystem.fileExists(atPath: url.path) {
                // Speech frameworks can often read the audio track from a media container.
                return url
            }
        }

        throw TranscriptionError.audioNotFound(meetingID: meeting.id)
    }
}
