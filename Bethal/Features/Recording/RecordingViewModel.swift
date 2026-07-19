import Foundation

/// Production recording session façade (title, mode, start/stop/cancel, status).
public final class RecordingViewModel: @unchecked Sendable {
    public private(set) var state: RecordingSessionState
    public private(set) var selectedMode: CaptureMode
    public private(set) var meetingTitle: String
    public private(set) var statusLine: String
    public private(set) var lastCompletedMeetingID: String?
    public private(set) var didCancelLastSession: Bool

    private let coordinator: RecordingSessionCoordinator
    private let sessionStore: AppSessionStore
    private let fileSystem: FileSystemClient

    public init(
        coordinator: RecordingSessionCoordinator,
        sessionStore: AppSessionStore = AppSessionStore(),
        fileSystem: FileSystemClient = FoundationFileSystem(),
        selectedMode: CaptureMode? = nil,
        meetingTitle: String = "Meeting"
    ) {
        self.coordinator = coordinator
        self.sessionStore = sessionStore
        self.fileSystem = fileSystem
        self.selectedMode = selectedMode ?? Self.loadDefaultMode(sessionStore: sessionStore, fileSystem: fileSystem)
        self.meetingTitle = meetingTitle
        self.state = coordinator.state
        self.statusLine = "Idle"
        self.lastCompletedMeetingID = nil
        self.didCancelLastSession = false
        sync()
    }

    public var canStart: Bool { state.canStart && !state.phase.isActiveCapture }
    public var canStop: Bool { state.canStop }
    public var canCancel: Bool { state.canCancel }
    public var isRecording: Bool { state.phase == .recording }
    public var isBusy: Bool { state.phase.isActiveCapture || state.phase == .checkingPermissions || state.phase == .awaitingPermission }

    public func setMode(_ mode: CaptureMode) {
        guard !state.phase.isActiveCapture else { return }
        selectedMode = mode
        statusLine = "Mode: \(mode == .audioVideo ? "Audio + video" : "Audio only")"
    }

    public func setTitle(_ title: String) {
        guard !state.phase.isActiveCapture else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        meetingTitle = trimmed.isEmpty ? "Meeting" : trimmed
    }

    public func prepare() async {
        didCancelLastSession = false
        await coordinator.prepare(mode: selectedMode)
        sync()
    }

    public func start() async {
        didCancelLastSession = false
        lastCompletedMeetingID = nil
        await coordinator.prepare(mode: selectedMode)
        await coordinator.start(title: meetingTitle)
        sync()
    }

    public func stop() async {
        await coordinator.stop()
        sync()
        if state.phase == .finalized {
            lastCompletedMeetingID = state.meetingID
        }
    }

    public func cancel() async {
        await coordinator.cancel()
        didCancelLastSession = true
        lastCompletedMeetingID = nil
        sync()
        statusLine = "Cancelled — recording discarded"
    }

    public func reset() {
        coordinator.reset()
        didCancelLastSession = false
        lastCompletedMeetingID = nil
        sync()
        statusLine = "Ready for a new recording"
    }

    public func tickElapsed(_ seconds: TimeInterval) {
        coordinator.updateElapsed(to: seconds)
        sync()
    }

    public static func loadDefaultMode(
        sessionStore: AppSessionStore,
        fileSystem: FileSystemClient
    ) -> CaptureMode {
        let session = sessionStore.load()
        guard let path = session.workingDirectoryPath, !path.isEmpty else {
            return RecordingSpikeDecisions.recommendedDefaultMode
        }
        let store = WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fileSystem
        )
        guard store.isInitialized, let settings = try? store.loadSettings() else {
            return RecordingSpikeDecisions.recommendedDefaultMode
        }
        return settings.defaultCaptureMode
    }

    private func sync() {
        state = coordinator.state
        switch state.phase {
        case .idle:
            statusLine = didCancelLastSession
                ? "Cancelled — recording discarded"
                : "Idle — set a title, choose a mode, then start."
        case .checkingPermissions, .awaitingPermission:
            statusLine = "Checking permissions…"
        case .ready:
            statusLine = "Ready (mic: \(state.microphoneStatus.displayName), screen: \(state.screenStatus.displayName))"
        case .recording:
            statusLine = "Recording \(state.formattedElapsed)"
        case .stopping:
            statusLine = "Stopping…"
        case .finalized:
            var line = "Saved"
            if let audio = state.audioFileName {
                line += " · \(audio)"
            } else {
                line += " · (no audio file)"
            }
            if state.videoDeferredReason != nil {
                line += " · video deferred"
            }
            statusLine = line
        case .failed:
            if let errorMessage = state.errorMessage, !errorMessage.isEmpty {
                statusLine = errorMessage
            } else {
                statusLine = "Recording failed"
            }
        }
    }
}
