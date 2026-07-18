import Foundation

/// Testable façade for the recording spike UI.
public final class RecordingSpikeViewModel: @unchecked Sendable {
    public private(set) var state: RecordingSessionState
    public private(set) var selectedMode: CaptureMode
    public private(set) var statusLine: String

    private let coordinator: RecordingSessionCoordinator

    public init(coordinator: RecordingSessionCoordinator, selectedMode: CaptureMode = .audioOnly) {
        self.coordinator = coordinator
        self.selectedMode = selectedMode
        self.state = coordinator.state
        self.statusLine = "Idle"
        sync()
    }

    public var canStart: Bool { state.canStart && !state.phase.isActiveCapture }
    public var canStop: Bool { state.canStop }
    public var isRecording: Bool { state.phase == .recording }

    public func setMode(_ mode: CaptureMode) {
        guard !state.phase.isActiveCapture else { return }
        selectedMode = mode
        statusLine = "Mode: \(mode.rawValue)"
    }

    public func prepare() async {
        await coordinator.prepare(mode: selectedMode)
        sync()
    }

    public func start(title: String = "Test recording") async {
        await coordinator.prepare(mode: selectedMode)
        await coordinator.start(title: title)
        sync()
    }

    public func stop() async {
        await coordinator.stop()
        sync()
    }

    public func reset() {
        coordinator.reset()
        sync()
        statusLine = "Reset"
    }

    public func tickElapsed(_ seconds: TimeInterval) {
        coordinator.updateElapsed(to: seconds)
        sync()
    }

    private func sync() {
        state = coordinator.state
        switch state.phase {
        case .idle:
            statusLine = "Idle — choose a mode and start a test recording."
        case .checkingPermissions, .awaitingPermission, .stopping:
            statusLine = state.phase == .stopping ? "Stopping…" : "Checking permissions…"
        case .ready:
            statusLine = "Ready (mic: \(state.microphoneStatus.displayName), screen: \(state.screenStatus.displayName))"
        case .recording:
            statusLine = "Recording \(state.formattedElapsed)"
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
