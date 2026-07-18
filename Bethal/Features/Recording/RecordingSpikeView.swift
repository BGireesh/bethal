import SwiftUI

/// Minimal UI to exercise capture permissions and a short on-disk recording.
struct RecordingSpikeView: View {
    @StateObject private var controller: RecordingSpikeController
    @State private var timer: Timer?

    init(controller: RecordingSpikeController? = nil) {
        _controller = StateObject(wrappedValue: controller ?? RecordingSpikeController())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.lg) {
            Text("Recording spike")
                .font(.title2.weight(.semibold))
            Text(
                "Proves microphone capture and permission prompts. Audio is written under your working directory. Full A/V ScreenCaptureKit lands in the next PR."
            )
            .foregroundStyle(.secondary)

            Picker("Mode", selection: modeBinding) {
                Text("Audio only").tag(CaptureMode.audioOnly)
                Text("Audio + video (spike)").tag(CaptureMode.audioVideo)
            }
            .pickerStyle(.segmented)
            .disabled(controller.isRecording)

            HStack(spacing: DesignSpacing.md) {
                permissionChip("Mic", controller.microphoneLabel)
                permissionChip("Screen", controller.screenLabel)
            }

            Text(controller.statusLine)
                .font(.body.monospaced())
                .textSelection(.enabled)

            if controller.isRecording {
                Text(controller.elapsedLabel)
                    .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
            }

            HStack(spacing: DesignSpacing.md) {
                Button("Prepare permissions") {
                    Task { await controller.prepare() }
                }
                .disabled(controller.isRecording)

                Button("Start test recording") {
                    Task {
                        await controller.start()
                        startTimer()
                    }
                }
                .disabled(!controller.canStart || controller.isRecording)
                .keyboardShortcut("r", modifiers: [.command])

                Button("Stop") {
                    Task {
                        stopTimer()
                        await controller.stop()
                    }
                }
                .disabled(!controller.canStop)
                .keyboardShortcut(.cancelAction)

                Button("Reset") {
                    stopTimer()
                    controller.reset()
                }
                .disabled(controller.isRecording)
            }

            if let note = controller.deferredVideoNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(DesignSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Record")
        .onDisappear { stopTimer() }
    }

    private var modeBinding: Binding<CaptureMode> {
        Binding(
            get: { controller.selectedMode },
            set: { controller.setMode($0) }
        )
    }

    private func permissionChip(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.medium))
        }
        .padding(DesignSpacing.sm)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
    }

    private func startTimer() {
        stopTimer()
        let started = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            controller.tick(Date().timeIntervalSince(started))
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

@MainActor
final class RecordingSpikeController: ObservableObject {
    @Published private(set) var selectedMode: CaptureMode
    @Published private(set) var statusLine: String
    @Published private(set) var elapsedLabel: String
    @Published private(set) var microphoneLabel: String
    @Published private(set) var screenLabel: String
    @Published private(set) var canStart: Bool
    @Published private(set) var canStop: Bool
    @Published private(set) var isRecording: Bool
    @Published private(set) var deferredVideoNote: String?

    private let viewModel: RecordingSpikeViewModel

    init(viewModel: RecordingSpikeViewModel? = nil) {
        let engine = AVAudioCaptureEngine()
        let coordinator = RecordingSessionCoordinator(engine: engine)
        let vm = viewModel ?? RecordingSpikeViewModel(coordinator: coordinator)
        self.viewModel = vm
        self.selectedMode = vm.selectedMode
        self.statusLine = vm.statusLine
        self.elapsedLabel = "00:00"
        self.microphoneLabel = vm.state.microphoneStatus.displayName
        self.screenLabel = vm.state.screenStatus.displayName
        self.canStart = vm.canStart
        self.canStop = vm.canStop
        self.isRecording = vm.isRecording
        self.deferredVideoNote = vm.state.videoDeferredReason
    }

    func setMode(_ mode: CaptureMode) {
        viewModel.setMode(mode)
        sync()
    }

    func prepare() async {
        await viewModel.prepare()
        sync()
    }

    func start() async {
        await viewModel.start()
        sync()
    }

    func stop() async {
        await viewModel.stop()
        sync()
    }

    func reset() {
        viewModel.reset()
        sync()
    }

    func tick(_ seconds: TimeInterval) {
        viewModel.tickElapsed(seconds)
        sync()
    }

    private func sync() {
        selectedMode = viewModel.selectedMode
        statusLine = viewModel.statusLine
        elapsedLabel = viewModel.state.formattedElapsed
        microphoneLabel = viewModel.state.microphoneStatus.displayName
        screenLabel = viewModel.state.screenStatus.displayName
        canStart = viewModel.canStart
        canStop = viewModel.canStop
        isRecording = viewModel.isRecording
        deferredVideoNote = viewModel.state.videoDeferredReason
    }
}
