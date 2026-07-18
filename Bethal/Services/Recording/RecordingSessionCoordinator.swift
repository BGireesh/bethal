import Foundation

/// Orchestrates permissions, capture engine, and working-directory meeting persistence.
public final class RecordingSessionCoordinator: @unchecked Sendable {
    public private(set) var state: RecordingSessionState

    private let permissions: PermissionChecking
    private let engine: CaptureEngine
    private let fileSystem: FileSystemClient
    private let sessionStore: AppSessionStore
    private let clock: () -> Date
    private let idGenerator: () -> String

    public init(
        permissions: PermissionChecking = SystemPermissionChecker(),
        engine: CaptureEngine,
        fileSystem: FileSystemClient = FoundationFileSystem(),
        sessionStore: AppSessionStore = AppSessionStore(),
        clock: @escaping () -> Date = Date.init,
        idGenerator: @escaping () -> String = { UUID().uuidString },
        initialState: RecordingSessionState = RecordingSessionState()
    ) {
        self.permissions = permissions
        self.engine = engine
        self.fileSystem = fileSystem
        self.sessionStore = sessionStore
        self.clock = clock
        self.idGenerator = idGenerator
        self.state = initialState
    }

    /// Ensures permissions for `mode` and transitions to `.ready` when possible.
    public func prepare(mode: CaptureMode) async {
        guard state.beginPermissionCheck(mode: mode) else { return }

        var mic = permissions.microphoneStatus()
        var screen = permissions.screenStatus()

        if mic == .notDetermined {
            mic = await permissions.requestMicrophoneAccess()
        }
        if mode == .audioVideo, screen == .notDetermined {
            screen = await permissions.requestScreenAccess()
        }

        _ = state.applyPermissionResults(microphone: mic, screen: screen)
    }

    /// Starts capture into a new meeting folder under the working directory.
    public func start(title: String = "Recording") async {
        if state.phase != .ready {
            await prepare(mode: state.mode)
        }
        guard state.phase == .ready else { return }

        let session = sessionStore.load()
        guard let path = session.workingDirectoryPath, !path.isEmpty else {
            _ = state.fail("Working directory is not configured.")
            return
        }

        let meetingID = sanitizeMeetingID(idGenerator())
        let root = URL(fileURLWithPath: path, isDirectory: true)
        let layout = ProjectLayout(root: root)
        let meetingDir = layout.meetingDirectory(id: meetingID)

        do {
            let now = clock()
            guard state.startRecording(meetingID: meetingID, at: now) else {
                _ = state.fail("Could not transition into recording.")
                return
            }

            try fileSystem.createDirectory(at: meetingDir, withIntermediateDirectories: true)
            try await engine.prepare(mode: state.mode, outputDirectory: meetingDir)
            try await engine.start()

            let store = WorkingDirectoryStore(root: root, fileSystem: fileSystem, clock: clock)
            _ = try store.initialize()
            try store.createMeeting(
                Meeting(
                    id: meetingID,
                    title: title,
                    status: .capturing,
                    captureMode: state.mode,
                    startedAt: now,
                    createdAt: now,
                    updatedAt: now
                )
            )
        } catch {
            _ = state.fail(error.localizedDescription)
        }
    }

    /// Stops capture and finalizes meeting meta + media filenames.
    public func stop() async {
        guard state.canStop || state.phase == .recording else { return }
        _ = state.beginStop()

        do {
            let artifacts = try await engine.stop()
            state.tick(elapsedSeconds: artifacts.durationSeconds)
            _ = state.finalize(
                audioFileName: artifacts.audioFileName,
                videoFileName: artifacts.videoFileName,
                videoDeferredReason: artifacts.videoDeferredReason
            )

            try persistFinalizedMeeting(artifacts: artifacts)
        } catch {
            _ = state.fail(error.localizedDescription)
        }
    }

    public func reset() {
        _ = state.reset()
    }

    public func updateElapsed(to seconds: TimeInterval) {
        state.tick(elapsedSeconds: seconds)
    }

    // MARK: - Private

    private func persistFinalizedMeeting(artifacts: CaptureArtifacts) throws {
        guard let meetingID = state.meetingID else { return }
        let session = sessionStore.load()
        guard let path = session.workingDirectoryPath else { return }
        let root = URL(fileURLWithPath: path, isDirectory: true)
        let store = WorkingDirectoryStore(root: root, fileSystem: fileSystem, clock: clock)
        var meeting = try store.loadMeeting(id: meetingID)
        meeting.status = .captured
        meeting.endedAt = clock()
        meeting.audioFileName = artifacts.audioFileName
        meeting.videoFileName = artifacts.videoFileName
        if let deferred = artifacts.videoDeferredReason {
            meeting.failureReason = nil
            // Stash deferred note in failureReason only if no audio? Prefer notes via status only.
            _ = deferred
        }
        meeting.updatedAt = clock()
        try store.updateMeeting(meeting)
    }

    private func sanitizeMeetingID(_ raw: String) -> String {
        let cleaned = raw.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        if ProjectLayout.isValidMeetingID(cleaned) {
            return cleaned
        }
        return UUID().uuidString
    }
}
