import Foundation

/// Files produced by a capture engine for one session.
public struct CaptureArtifacts: Equatable, Sendable {
    public var audioFileName: String?
    public var videoFileName: String?
    public var durationSeconds: TimeInterval
    public var videoDeferredReason: String?

    public init(
        audioFileName: String? = nil,
        videoFileName: String? = nil,
        durationSeconds: TimeInterval = 0,
        videoDeferredReason: String? = nil
    ) {
        self.audioFileName = audioFileName
        self.videoFileName = videoFileName
        self.durationSeconds = durationSeconds
        self.videoDeferredReason = videoDeferredReason
    }
}
