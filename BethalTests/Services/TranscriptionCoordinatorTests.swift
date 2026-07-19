import Foundation
import Testing
@testable import Bethal

@Suite("TranscriptionCoordinator")
struct TranscriptionCoordinatorTests {
    private let fixedNow = Date(timeIntervalSince1970: 4_000_000_000)

    private func seeded(
        id: String = "m-tx-1",
        status: MeetingStatus = .captured,
        audioFileName: String? = "audio.m4a",
        videoFileName: String? = nil,
        writeAudio: Bool = true
    ) throws -> (AppSessionStore, InMemoryFileSystem, String) {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalTx"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs, clock: { fixedNow })
        _ = try store.initialize()
        try store.createMeeting(
            Meeting(
                id: id,
                title: "Call",
                status: status,
                captureMode: .audioOnly,
                startedAt: fixedNow,
                endedAt: fixedNow,
                audioFileName: audioFileName,
                videoFileName: videoFileName,
                createdAt: fixedNow,
                updatedAt: fixedNow
            )
        )
        if writeAudio, let audioFileName {
            let url = store.layout.meetingMediaFile(id: id, fileName: audioFileName)
            try fs.writeData(Data("fake-audio".utf8), to: url)
        }
        if let videoFileName {
            let url = store.layout.meetingMediaFile(id: id, fileName: videoFileName)
            try fs.writeData(Data("fake-video".utf8), to: url)
        }
        return (session, fs, path)
    }

    @Test("transcribe saves transcript and updates status")
    func success() async throws {
        let (session, fs, path) = try seeded()
        let engine = MockTranscriptionEngine()
        let coordinator = TranscriptionCoordinator(
            engine: engine,
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow },
            languageCode: "en-US"
        )
        let transcript = try await coordinator.transcribeMeeting(id: "m-tx-1")
        #expect(transcript.meetingID == "m-tx-1")
        #expect(engine.callCount == 1)
        #expect(coordinator.progress.phase == .completed)

        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs)
        let meeting = try store.loadMeeting(id: "m-tx-1")
        #expect(meeting.status == .transcribed)
        let loaded = try store.loadTranscript(meetingID: "m-tx-1")
        #expect(loaded?.fullText.contains("mock") == true)
    }

    @Test("missing working directory fails")
    func noWorkingDirectory() async {
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        let coordinator = TranscriptionCoordinator(
            engine: MockTranscriptionEngine(),
            sessionStore: session,
            fileSystem: InMemoryFileSystem(),
            clock: { fixedNow }
        )
        await #expect(throws: TranscriptionError.self) {
            _ = try await coordinator.transcribeMeeting(id: "x")
        }
        #expect(coordinator.progress.phase == .failed)
    }

    @Test("capturing meeting is not eligible")
    func capturingIneligible() async throws {
        let (session, fs, _) = try seeded(status: .capturing)
        let coordinator = TranscriptionCoordinator(
            engine: MockTranscriptionEngine(),
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        await #expect(throws: TranscriptionError.self) {
            _ = try await coordinator.transcribeMeeting(id: "m-tx-1")
        }
    }

    @Test("missing audio fails and marks meeting failed")
    func missingAudio() async throws {
        let (session, fs, path) = try seeded(writeAudio: false)
        let coordinator = TranscriptionCoordinator(
            engine: MockTranscriptionEngine(),
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        await #expect(throws: TranscriptionError.self) {
            _ = try await coordinator.transcribeMeeting(id: "m-tx-1")
        }
        let meeting = try WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fs
        ).loadMeeting(id: "m-tx-1")
        #expect(meeting.status == .failed)
        #expect(meeting.failureReason != nil)
    }

    @Test("engine failure marks meeting failed")
    func engineFailure() async throws {
        let (session, fs, path) = try seeded()
        let engine = MockTranscriptionEngine(error: TranscriptionError.engineFailed("boom"))
        let coordinator = TranscriptionCoordinator(
            engine: engine,
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        await #expect(throws: TranscriptionError.self) {
            _ = try await coordinator.transcribeMeeting(id: "m-tx-1")
        }
        let meeting = try WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fs
        ).loadMeeting(id: "m-tx-1")
        #expect(meeting.status == .failed)
    }

    @Test("uses video file when audio missing")
    func videoFallback() async throws {
        let (session, fs, _) = try seeded(audioFileName: nil, videoFileName: "video.mp4", writeAudio: false)
        let engine = MockTranscriptionEngine()
        let coordinator = TranscriptionCoordinator(
            engine: engine,
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        _ = try await coordinator.transcribeMeeting(id: "m-tx-1")
        #expect(engine.lastAudioURL?.lastPathComponent == "video.mp4")
    }

    @Test("reset progress")
    func reset() async throws {
        let (session, fs, _) = try seeded()
        let coordinator = TranscriptionCoordinator(
            engine: MockTranscriptionEngine(),
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        _ = try await coordinator.transcribeMeeting(id: "m-tx-1")
        coordinator.resetProgress()
        #expect(coordinator.progress.phase == .idle)
    }

    @Test("validateEligible allows re-transcribe states")
    func validate() throws {
        let meeting = Meeting(
            id: "a",
            title: "t",
            status: .completed,
            captureMode: .audioOnly,
            startedAt: fixedNow
        )
        try TranscriptionCoordinator.validateEligible(meeting)
        var capturing = meeting
        capturing.status = .capturing
        #expect(throws: TranscriptionError.self) {
            try TranscriptionCoordinator.validateEligible(capturing)
        }
    }

    @Test("audio resolver prefers audio file")
    func resolver() throws {
        let (session, fs, path) = try seeded()
        _ = session
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs)
        let meeting = try store.loadMeeting(id: "m-tx-1")
        let url = try MeetingAudioResolver.resolveAudioURL(for: meeting, layout: store.layout, fileSystem: fs)
        #expect(url.lastPathComponent == "audio.m4a")
    }

    @Test("audio resolver falls back when audio missing on disk")
    func resolverFallsBackToVideo() throws {
        let (session, fs, path) = try seeded(
            audioFileName: "audio.m4a",
            videoFileName: "video.mp4",
            writeAudio: false
        )
        _ = session
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs)
        let meeting = try store.loadMeeting(id: "m-tx-1")
        let url = try MeetingAudioResolver.resolveAudioURL(for: meeting, layout: store.layout, fileSystem: fs)
        #expect(url.lastPathComponent == "video.mp4")
    }

    @Test("mock engine returns provided result")
    func mockResult() async throws {
        let (session, fs, _) = try seeded()
        let custom = Transcript(
            meetingID: "m-tx-1",
            languageCode: "en-US",
            segments: [TranscriptSegment(id: "c1", startSeconds: 0, endSeconds: 2, text: "Custom")],
            createdAt: fixedNow
        )
        let engine = MockTranscriptionEngine(result: custom)
        let coordinator = TranscriptionCoordinator(
            engine: engine,
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        let out = try await coordinator.transcribeMeeting(id: "m-tx-1")
        #expect(out.fullText == "Custom")
    }

    @Test("re-transcribe clears prior failure and completes")
    func reTranscribe() async throws {
        let (session, fs, path) = try seeded(status: .failed)
        let coordinator = TranscriptionCoordinator(
            engine: MockTranscriptionEngine(),
            sessionStore: session,
            fileSystem: fs,
            clock: { fixedNow }
        )
        _ = try await coordinator.transcribeMeeting(id: "m-tx-1")
        let meeting = try WorkingDirectoryStore(
            root: URL(fileURLWithPath: path, isDirectory: true),
            fileSystem: fs
        ).loadMeeting(id: "m-tx-1")
        #expect(meeting.status == .transcribed)
        #expect(meeting.failureReason == nil)
    }

    @Test("default clock and initialize-if-needed path")
    func defaultClockAndInitStore() async {
        let fs = InMemoryFileSystem()
        let path = "/Users/test/BethalTxDefault"
        let session = AppSessionStore(keyValueStore: InMemoryKeyValueStore())
        try? session.save(AppSessionPreferences(hasCompletedOnboarding: true, workingDirectoryPath: path))
        // Uses default clock; empty working dir → coordinator initializes then fails on missing meeting.
        let coordinator = TranscriptionCoordinator(
            engine: MockTranscriptionEngine(),
            sessionStore: session,
            fileSystem: fs
        )
        await #expect(throws: Error.self) {
            _ = try await coordinator.transcribeMeeting(id: "missing")
        }
        #expect(coordinator.progress.phase == .failed)
        let store = WorkingDirectoryStore(root: URL(fileURLWithPath: path, isDirectory: true), fileSystem: fs)
        #expect(store.isInitialized)
    }

    @Test("transcription error descriptions")
    func errorDescriptions() {
        #expect(TranscriptionError.audioNotFound(meetingID: "m").errorDescription?.contains("m") == true)
        #expect(TranscriptionError.meetingNotEligible("x").errorDescription == "x")
        #expect(TranscriptionError.notAuthorized.errorDescription != nil)
        #expect(TranscriptionError.unavailable.errorDescription != nil)
        #expect(TranscriptionError.emptyResult.errorDescription != nil)
        #expect(TranscriptionError.engineFailed("e").errorDescription == "e")
    }

    @Test("progress helpers")
    func progressHelpers() {
        #expect(TranscriptionProgress.preparing(meetingID: "a").phase == .preparing)
        #expect(TranscriptionProgress.transcribing(meetingID: "a", fraction: 2).fractionCompleted == 1)
        #expect(TranscriptionProgress.saving(meetingID: "a").phase == .saving)
        #expect(TranscriptionProgress.completed(meetingID: "a").fractionCompleted == 1)
        #expect(TranscriptionProgress.failed(meetingID: "a", message: "x").phase == .failed)
        #expect(TranscriptionPhase.transcribing.isInProgress)
        #expect(TranscriptionPhase.completed.displayName == "Completed")
        for phase in TranscriptionPhase.allCases {
            #expect(!phase.displayName.isEmpty)
        }
    }
}
