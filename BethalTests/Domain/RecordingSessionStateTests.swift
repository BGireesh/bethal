import Foundation
import Testing
@testable import Bethal

@Suite("RecordingSessionState")
struct RecordingSessionStateTests {
    @Test("permission check and ready path")
    func readyPath() {
        var state = RecordingSessionState()
        let began = state.beginPermissionCheck(mode: .audioOnly)
        #expect(began)
        #expect(state.phase == .checkingPermissions)
        let applied = state.applyPermissionResults(microphone: .authorized, screen: .notDetermined)
        #expect(applied)
        #expect(state.phase == .ready)
        #expect(state.permissionsSatisfied)
    }

    @Test("awaiting permission when mic not determined")
    func awaiting() {
        var state = RecordingSessionState()
        _ = state.beginPermissionCheck(mode: .audioOnly)
        _ = state.applyPermissionResults(microphone: .notDetermined, screen: .notDetermined)
        #expect(state.phase == .awaitingPermission)
    }

    @Test("mic denied fails")
    func micDenied() {
        var state = RecordingSessionState()
        _ = state.beginPermissionCheck(mode: .audioOnly)
        _ = state.applyPermissionResults(microphone: .denied, screen: .authorized)
        #expect(state.phase == .failed)
        #expect(state.errorMessage != nil)
    }

    @Test("start stop finalize")
    func recordCycle() {
        var state = RecordingSessionState(phase: .ready, microphoneStatus: .authorized)
        let started = state.startRecording(meetingID: "meet-1", at: Date(timeIntervalSince1970: 10))
        #expect(started)
        #expect(state.phase == .recording)
        state.tick(elapsedSeconds: 12.4)
        #expect(state.formattedElapsed == "00:12")
        let stopping = state.beginStop()
        #expect(stopping)
        #expect(state.phase == .stopping)
        let finalized = state.finalize(
            audioFileName: "audio.m4a",
            videoFileName: nil,
            videoDeferredReason: "later"
        )
        #expect(finalized)
        #expect(state.phase == .finalized)
        #expect(state.audioFileName == "audio.m4a")
        #expect(state.videoDeferredReason == "later")
    }

    @Test("invalid transitions rejected")
    func invalid() {
        var state = RecordingSessionState()
        let startIdle = state.startRecording(meetingID: "x", at: Date())
        #expect(!startIdle)
        let stopIdle = state.beginStop()
        #expect(!stopIdle)
        let finIdle = state.finalize(audioFileName: nil, videoFileName: nil)
        #expect(!finIdle)
        let failIdle = state.fail("nope")
        #expect(!failIdle)
        let applyIdle = state.applyPermissionResults(microphone: .authorized, screen: .authorized)
        #expect(!applyIdle)

        state = RecordingSessionState(phase: .ready, microphoneStatus: .authorized)
        let badID = state.startRecording(meetingID: "bad/id", at: Date())
        #expect(!badID)

        state = RecordingSessionState(phase: .recording, microphoneStatus: .authorized)
        let reprepare = state.beginPermissionCheck(mode: .audioOnly)
        #expect(!reprepare)
    }

    @Test("beginPermissionCheck allowed from ready")
    func reprepare() {
        var state = RecordingSessionState(phase: .ready, mode: .audioOnly, microphoneStatus: .authorized)
        let ok = state.beginPermissionCheck(mode: .audioVideo)
        #expect(ok)
        #expect(state.mode == .audioVideo)
        #expect(state.requiresScreenPermission)
    }

    @Test("permissions for av mode")
    func avPermissions() {
        var state = RecordingSessionState(mode: .audioVideo, microphoneStatus: .authorized, screenStatus: .denied)
        #expect(state.permissionsSatisfied)
        state.microphoneStatus = .denied
        #expect(!state.permissionsSatisfied)
    }

    @Test("fail and reset")
    func failReset() {
        var state = RecordingSessionState(phase: .recording, microphoneStatus: .authorized)
        let failed = state.fail("boom")
        #expect(failed)
        #expect(state.phase == .failed)
        let reset = state.reset()
        #expect(reset)
        #expect(state.phase == .idle)
        #expect(state.microphoneStatus == .authorized)
    }

    @Test("tick ignored when not recording")
    func tickIdle() {
        var state = RecordingSessionState()
        state.tick(elapsedSeconds: 5)
        #expect(state.elapsedSeconds == 0)
    }

    @Test("canStart and canStop")
    func flags() {
        var state = RecordingSessionState(phase: .ready)
        #expect(state.canStart)
        #expect(!state.canStop)
        state.phase = .idle
        #expect(state.canStart)
        state.phase = .finalized
        #expect(state.canStart)
        state.phase = .failed
        #expect(state.canStart)
        state.phase = .recording
        #expect(state.canStop)
        #expect(!state.canStart)
        #expect(RecordingPhase.finalized.isTerminal)
        #expect(RecordingPhase.failed.isTerminal)
        #expect(!RecordingPhase.ready.isTerminal)
        #expect(RecordingPhase.recording.isActiveCapture)
        #expect(RecordingPhase.stopping.isActiveCapture)
        #expect(!RecordingPhase.idle.isActiveCapture)
    }

    @Test("permission display names")
    func permissionNames() {
        for status in PermissionStatus.allCases {
            #expect(!status.displayName.isEmpty)
        }
        #expect(PermissionStatus.authorized.isUsable)
        #expect(!PermissionStatus.denied.isUsable)
    }
}
