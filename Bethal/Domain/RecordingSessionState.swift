import Foundation

/// Pure state machine for a single recording session (no AV dependencies).
public struct RecordingSessionState: Equatable, Sendable {
    public var phase: RecordingPhase
    public var mode: CaptureMode
    public var meetingID: String?
    public var startedAt: Date?
    public var elapsedSeconds: TimeInterval
    public var microphoneStatus: PermissionStatus
    public var screenStatus: PermissionStatus
    public var errorMessage: String?
    public var audioFileName: String?
    public var videoFileName: String?
    /// Set when A/V mode could not fully capture video in this spike.
    public var videoDeferredReason: String?

    public init(
        phase: RecordingPhase = .idle,
        mode: CaptureMode = .audioOnly,
        meetingID: String? = nil,
        startedAt: Date? = nil,
        elapsedSeconds: TimeInterval = 0,
        microphoneStatus: PermissionStatus = .notDetermined,
        screenStatus: PermissionStatus = .notDetermined,
        errorMessage: String? = nil,
        audioFileName: String? = nil,
        videoFileName: String? = nil,
        videoDeferredReason: String? = nil
    ) {
        self.phase = phase
        self.mode = mode
        self.meetingID = meetingID
        self.startedAt = startedAt
        self.elapsedSeconds = elapsedSeconds
        self.microphoneStatus = microphoneStatus
        self.screenStatus = screenStatus
        self.errorMessage = errorMessage
        self.audioFileName = audioFileName
        self.videoFileName = videoFileName
        self.videoDeferredReason = videoDeferredReason
    }

    public var canStart: Bool {
        phase == .ready || phase == .idle || phase == .finalized || phase == .failed
    }

    public var canStop: Bool {
        phase == .recording
    }

    /// Active capture can be discarded without saving a finished meeting.
    public var canCancel: Bool {
        phase == .recording || phase == .stopping
    }

    public var requiresScreenPermission: Bool {
        mode == .audioVideo
    }

    /// Whether current permission snapshot allows capture to begin.
    public var permissionsSatisfied: Bool {
        guard microphoneStatus.isUsable else { return false }
        if requiresScreenPermission {
            // Spike allows A/V to proceed with audio when screen is authorized;
            // if screen denied we still can record audio-only fallback after user ack in coordinator.
            return screenStatus.isUsable || screenStatus == .denied
        }
        return true
    }

    // MARK: - Transitions

    @discardableResult
    public mutating func beginPermissionCheck(mode: CaptureMode) -> Bool {
        guard phase == .idle || phase == .finalized || phase == .failed || phase == .ready else {
            return false
        }
        self.mode = mode
        phase = .checkingPermissions
        errorMessage = nil
        meetingID = nil
        startedAt = nil
        elapsedSeconds = 0
        audioFileName = nil
        videoFileName = nil
        videoDeferredReason = nil
        return true
    }

    @discardableResult
    public mutating func applyPermissionResults(
        microphone: PermissionStatus,
        screen: PermissionStatus
    ) -> Bool {
        guard phase == .checkingPermissions || phase == .awaitingPermission else { return false }
        microphoneStatus = microphone
        screenStatus = screen

        if microphone == .notDetermined || (requiresScreenPermission && screen == .notDetermined) {
            phase = .awaitingPermission
            return true
        }

        if !microphone.isUsable {
            phase = .failed
            errorMessage = "Microphone access is required to record meetings."
            return true
        }

        phase = .ready
        errorMessage = nil
        return true
    }

    @discardableResult
    public mutating func startRecording(meetingID: String, at date: Date) -> Bool {
        guard phase == .ready, microphoneStatus.isUsable else { return false }
        guard ProjectLayout.isValidMeetingID(meetingID) else { return false }
        self.meetingID = meetingID
        startedAt = date
        elapsedSeconds = 0
        phase = .recording
        errorMessage = nil
        return true
    }

    public mutating func tick(elapsedSeconds value: TimeInterval) {
        guard phase == .recording else { return }
        elapsedSeconds = max(0, value)
    }

    @discardableResult
    public mutating func beginStop() -> Bool {
        guard phase == .recording else { return false }
        phase = .stopping
        return true
    }

    @discardableResult
    public mutating func finalize(
        audioFileName: String?,
        videoFileName: String?,
        videoDeferredReason: String? = nil
    ) -> Bool {
        guard phase == .stopping || phase == .recording else { return false }
        self.audioFileName = audioFileName
        self.videoFileName = videoFileName
        self.videoDeferredReason = videoDeferredReason
        phase = .finalized
        errorMessage = nil
        return true
    }

    @discardableResult
    public mutating func fail(_ message: String) -> Bool {
        guard phase != .idle else { return false }
        phase = .failed
        errorMessage = message
        return true
    }

    @discardableResult
    public mutating func reset() -> Bool {
        self = RecordingSessionState(
            microphoneStatus: microphoneStatus,
            screenStatus: screenStatus
        )
        return true
    }

    /// Discards an in-progress or stopping session back to idle (keeps permission snapshot).
    @discardableResult
    public mutating func markCancelled() -> Bool {
        guard canCancel || phase == .ready || phase == .failed else { return false }
        let mic = microphoneStatus
        let screen = screenStatus
        self = RecordingSessionState(microphoneStatus: mic, screenStatus: screen)
        return true
    }

    public var formattedElapsed: String {
        let total = Int(elapsedSeconds.rounded(.down))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
