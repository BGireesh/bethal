import AVFoundation
import Foundation

/// Microphone capture via `AVAudioRecorder` writing AAC/M4A into the meeting folder.
///
/// Audio+video mode records microphone audio in this spike and defers full
/// ScreenCaptureKit video multiplex to sub-task 06 (see `docs/recording-notes.md`).
public final class AVAudioCaptureEngine: NSObject, CaptureEngine, @unchecked Sendable {
    public static let audioFileName = "audio.m4a"

    private var mode: CaptureMode = .audioOnly
    private var outputDirectory: URL?
    private var recorder: AVAudioRecorder?
    private var startedAt: Date?
    private var isRunning = false
    private let clock: () -> Date
    private let permissionChecker: PermissionChecking

    public init(
        permissionChecker: PermissionChecking = SystemPermissionChecker(),
        clock: @escaping () -> Date = Date.init
    ) {
        self.permissionChecker = permissionChecker
        self.clock = clock
        super.init()
    }

    public func prepare(mode: CaptureMode, outputDirectory: URL) async throws {
        self.mode = mode
        self.outputDirectory = outputDirectory

        let mic = permissionChecker.microphoneStatus()
        guard mic.isUsable else {
            throw CaptureEngineError.permissionDenied("microphone")
        }

        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let audioURL = outputDirectory.appendingPathComponent(Self.audioFileName)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let recorder = try AVAudioRecorder(url: audioURL, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.prepareToRecord() else {
            throw CaptureEngineError.ioFailure("AVAudioRecorder failed to prepare.")
        }
        self.recorder = recorder
        self.isRunning = false
        self.startedAt = nil
    }

    public func start() async throws {
        guard let recorder else { throw CaptureEngineError.notPrepared }
        guard !isRunning else { throw CaptureEngineError.alreadyRunning }
        guard recorder.record() else {
            throw CaptureEngineError.ioFailure("AVAudioRecorder failed to start.")
        }
        isRunning = true
        startedAt = clock()
    }

    public func stop() async throws -> CaptureArtifacts {
        guard isRunning, let recorder, let startedAt else {
            throw CaptureEngineError.notRunning
        }
        recorder.stop()
        isRunning = false
        let duration = clock().timeIntervalSince(startedAt)
        self.recorder = nil

        var deferred: String?
        if mode == .audioVideo {
            deferred = RecordingSpikeDecisions.videoDeferredReason
        }

        return CaptureArtifacts(
            audioFileName: Self.audioFileName,
            videoFileName: nil,
            durationSeconds: max(0, duration),
            videoDeferredReason: deferred
        )
    }
}

/// Documented product decisions locked by the recording spike.
public enum RecordingSpikeDecisions: Sendable {
    public static let recommendedDefaultMode: CaptureMode = .audioOnly

    public static let videoDeferredReason =
        "Full ScreenCaptureKit video + system-audio multiplex is deferred to sub-task 06; spike records microphone audio for A/V mode."

    public static let audioAPI = "AVAudioRecorder (AAC/M4A @ 44.1kHz mono)"
    public static let videoAPIPlanned = "ScreenCaptureKit (display/window + optional app audio)"
}
