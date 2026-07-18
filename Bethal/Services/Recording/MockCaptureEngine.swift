import Foundation

/// In-memory capture engine for unit tests (optionally writes a tiny audio placeholder file).
public final class MockCaptureEngine: CaptureEngine, @unchecked Sendable {
    public var prepareError: Error?
    public var startError: Error?
    public var stopError: Error?
    public var artifacts = CaptureArtifacts(
        audioFileName: "audio.m4a",
        videoFileName: nil,
        durationSeconds: 1.5,
        videoDeferredReason: nil
    )
    public private(set) var preparedMode: CaptureMode?
    public private(set) var preparedDirectory: URL?
    public private(set) var didStart = false
    public private(set) var didStop = false
    public var writePlaceholderFile = true
    private let fileSystem: FileSystemClient

    public init(fileSystem: FileSystemClient = FoundationFileSystem()) {
        self.fileSystem = fileSystem
    }

    public func prepare(mode: CaptureMode, outputDirectory: URL) async throws {
        if let prepareError { throw prepareError }
        preparedMode = mode
        preparedDirectory = outputDirectory
        try fileSystem.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    public func start() async throws {
        if let startError { throw startError }
        guard preparedDirectory != nil else { throw CaptureEngineError.notPrepared }
        didStart = true
    }

    public func stop() async throws -> CaptureArtifacts {
        if let stopError { throw stopError }
        guard didStart else { throw CaptureEngineError.notRunning }
        didStop = true
        if writePlaceholderFile, let dir = preparedDirectory, let name = artifacts.audioFileName {
            let url = dir.appendingPathComponent(name)
            try fileSystem.writeData(Data("mock-audio".utf8), to: url)
        }
        return artifacts
    }
}
