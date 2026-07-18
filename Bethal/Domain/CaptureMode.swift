/// How a meeting is captured on disk.
public enum CaptureMode: String, Codable, Sendable, CaseIterable, Equatable {
    case audioOnly
    case audioVideo
}
