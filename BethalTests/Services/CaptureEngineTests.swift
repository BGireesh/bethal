import Foundation
import Testing
@testable import Bethal

@Suite("CaptureEngine")
struct CaptureEngineTests {
    @Test("mock engine writes placeholder and returns artifacts")
    func mockHappyPath() async throws {
        let fs = InMemoryFileSystem()
        let engine = MockCaptureEngine(fileSystem: fs)
        let dir = URL(fileURLWithPath: "/tmp/mock-cap", isDirectory: true)
        try await engine.prepare(mode: .audioOnly, outputDirectory: dir)
        try await engine.start()
        let artifacts = try await engine.stop()
        #expect(artifacts.audioFileName == "audio.m4a")
        #expect(engine.didStart && engine.didStop)
        #expect(fs.fileExists(atPath: dir.appendingPathComponent("audio.m4a").path))
    }

    @Test("mock engine error paths")
    func mockErrors() async {
        let engine = MockCaptureEngine()
        engine.prepareError = CaptureEngineError.notPrepared
        await #expect(throws: CaptureEngineError.self) {
            try await engine.prepare(mode: .audioOnly, outputDirectory: URL(fileURLWithPath: "/tmp/x"))
        }

        let engine2 = MockCaptureEngine()
        await #expect(throws: CaptureEngineError.self) {
            try await engine2.start()
        }

        let engine3 = MockCaptureEngine()
        try? await engine3.prepare(mode: .audioOnly, outputDirectory: URL(fileURLWithPath: "/tmp/y"))
        await #expect(throws: CaptureEngineError.self) {
            try await engine3.stop()
        }

        let engine4 = MockCaptureEngine()
        engine4.startError = CaptureEngineError.alreadyRunning
        try? await engine4.prepare(mode: .audioOnly, outputDirectory: URL(fileURLWithPath: "/tmp/z"))
        await #expect(throws: CaptureEngineError.self) {
            try await engine4.start()
        }
    }

    @Test("capture engine error descriptions")
    func errorDescriptions() {
        #expect(CaptureEngineError.notPrepared.errorDescription != nil)
        #expect(CaptureEngineError.alreadyRunning.errorDescription != nil)
        #expect(CaptureEngineError.notRunning.errorDescription != nil)
        #expect(CaptureEngineError.permissionDenied("mic").errorDescription?.contains("mic") == true)
        #expect(CaptureEngineError.ioFailure("x").errorDescription == "x")
        #expect(CaptureEngineError.unsupported("y").errorDescription?.contains("y") == true)
    }

    @Test("spike decisions constants")
    func decisions() {
        #expect(RecordingSpikeDecisions.recommendedDefaultMode == .audioOnly)
        #expect(!RecordingSpikeDecisions.videoDeferredReason.isEmpty)
        #expect(RecordingSpikeDecisions.audioAPI.contains("AVAudioRecorder"))
        #expect(RecordingSpikeDecisions.videoAPIPlanned.contains("ScreenCaptureKit"))
    }

    @Test("AV authorization mapper")
    func avMapper() {
        #expect(AVAuthorizationMapper.map(.authorized) == .authorized)
        #expect(AVAuthorizationMapper.map(.denied) == .denied)
        #expect(AVAuthorizationMapper.map(.restricted) == .restricted)
        #expect(AVAuthorizationMapper.map(.notDetermined) == .notDetermined)
    }
}
