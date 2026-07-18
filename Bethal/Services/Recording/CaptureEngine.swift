import Foundation

/// Abstraction over microphone / screen capture backends.
public protocol CaptureEngine: AnyObject, Sendable {
    func prepare(mode: CaptureMode, outputDirectory: URL) async throws
    func start() async throws
    func stop() async throws -> CaptureArtifacts
}

public enum CaptureEngineError: Error, Equatable, Sendable, LocalizedError {
    case notPrepared
    case alreadyRunning
    case notRunning
    case permissionDenied(String)
    case ioFailure(String)
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .notPrepared: return "Capture engine is not prepared."
        case .alreadyRunning: return "Capture is already running."
        case .notRunning: return "Capture is not running."
        case .permissionDenied(let detail): return "Permission denied: \(detail)"
        case .ioFailure(let detail): return detail
        case .unsupported(let detail): return detail
        }
    }
}
