import SwiftUI

/// Production recording session UI: title, mode, live timer, start/stop/cancel.
struct RecordingSessionView: View {
    @StateObject private var controller: RecordingSessionController
    var prefilledTitle: String?
    var onSessionEnded: (() -> Void)?

    init(
        controller: RecordingSessionController? = nil,
        prefilledTitle: String? = nil,
        onSessionEnded: (() -> Void)? = nil
    ) {
        _controller = StateObject(wrappedValue: controller ?? RecordingSessionController())
        self.prefilledTitle = prefilledTitle
        self.onSessionEnded = onSessionEnded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.lg) {
            header
            titleField
            modePicker
            permissionRow
            statusBlock
            controls
            footerNote
        }
        .padding(DesignSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(AppSection.record.title)
        .onAppear {
            if let prefilledTitle, !prefilledTitle.isEmpty {
                controller.setTitle(prefilledTitle)
            }
        }
        .onChange(of: prefilledTitle) { _, newValue in
            if let newValue, !newValue.isEmpty {
                controller.setTitle(newValue)
            }
        }
        .onDisappear { controller.stopTimer() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            Text("Record a meeting")
                .font(.title2.weight(.semibold))
            Text("Capture stays on this Mac. Stop to save, or Cancel to discard the session.")
                .foregroundStyle(.secondary)
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xs) {
            Text("Title")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Meeting title", text: titleBinding)
                .textFieldStyle(.roundedBorder)
                .disabled(controller.isRecording)
        }
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xs) {
            Text("Capture mode")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Mode", selection: modeBinding) {
                Text("Audio only").tag(CaptureMode.audioOnly)
                Text("Audio + video").tag(CaptureMode.audioVideo)
            }
            .pickerStyle(.segmented)
            .disabled(controller.isRecording)
        }
    }

    private var permissionRow: some View {
        HStack(spacing: DesignSpacing.md) {
            chip("Microphone", controller.microphoneLabel, ok: controller.micOK)
            chip("Screen", controller.screenLabel, ok: controller.screenOK)
            if controller.isRecording {
                Label("Live", systemImage: "circle.fill")
                    .foregroundStyle(Color.red)
                    .font(.caption.weight(.semibold))
            }
        }
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            Text(controller.statusLine)
                .font(.body.monospaced())
                .textSelection(.enabled)
            if controller.isRecording {
                Text(controller.elapsedLabel)
                    .font(.system(size: 44, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.primary)
            }
            if let note = controller.deferredVideoNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Color.orange)
            }
            if controller.didCancel {
                Text("Last session was discarded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let id = controller.lastCompletedMeetingID {
                Text("Saved meeting id: \(id)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: DesignSpacing.md) {
            Button("Prepare") {
                Task { await controller.prepare() }
            }
            .disabled(controller.isRecording)

            Button(controller.isRecording ? "Recording…" : "Start recording") {
                Task {
                    await controller.start()
                    controller.startTimer()
                }
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(!controller.canStart || controller.isRecording)

            Button("Stop") {
                Task {
                    controller.stopTimer()
                    await controller.stop()
                    onSessionEnded?()
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!controller.canStop)

            Button("Cancel", role: .destructive) {
                Task {
                    controller.stopTimer()
                    await controller.cancel()
                    onSessionEnded?()
                }
            }
            .disabled(!controller.canCancel)

            Button("New session") {
                controller.stopTimer()
                controller.reset()
            }
            .disabled(controller.isRecording)
        }
    }

    private var footerNote: some View {
        Text("Default mode comes from Settings when available. Full screen/system-audio video capture expands in a later update.")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    private func chip(_ title: String, _ value: String, ok: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.medium))
                .foregroundStyle(ok ? Color.primary : Color.orange)
        }
        .padding(DesignSpacing.sm)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { controller.meetingTitle },
            set: { controller.setTitle($0) }
        )
    }

    private var modeBinding: Binding<CaptureMode> {
        Binding(
            get: { controller.selectedMode },
            set: { controller.setMode($0) }
        )
    }
}

@MainActor
final class RecordingSessionController: ObservableObject {
    @Published private(set) var selectedMode: CaptureMode
    @Published private(set) var meetingTitle: String
    @Published private(set) var statusLine: String
    @Published private(set) var elapsedLabel: String
    @Published private(set) var microphoneLabel: String
    @Published private(set) var screenLabel: String
    @Published private(set) var canStart: Bool
    @Published private(set) var canStop: Bool
    @Published private(set) var canCancel: Bool
    @Published private(set) var isRecording: Bool
    @Published private(set) var isBusy: Bool
    @Published private(set) var micOK: Bool
    @Published private(set) var screenOK: Bool
    @Published private(set) var deferredVideoNote: String?
    @Published private(set) var lastCompletedMeetingID: String?
    @Published private(set) var didCancel: Bool

    private let viewModel: RecordingViewModel
    private var timer: Timer?
    private var timerStartedAt: Date?

    init(viewModel: RecordingViewModel? = nil) {
        let engine = AVAudioCaptureEngine()
        let coordinator = RecordingSessionCoordinator(engine: engine)
        let vm = viewModel ?? RecordingViewModel(coordinator: coordinator)
        self.viewModel = vm
        self.selectedMode = vm.selectedMode
        self.meetingTitle = vm.meetingTitle
        self.statusLine = vm.statusLine
        self.elapsedLabel = "00:00"
        self.microphoneLabel = vm.state.microphoneStatus.displayName
        self.screenLabel = vm.state.screenStatus.displayName
        self.canStart = vm.canStart
        self.canStop = vm.canStop
        self.canCancel = vm.canCancel
        self.isRecording = vm.isRecording
        self.isBusy = vm.isBusy
        self.micOK = vm.state.microphoneStatus.isUsable
        self.screenOK = vm.state.screenStatus.isUsable || vm.selectedMode == .audioOnly
        self.deferredVideoNote = vm.state.videoDeferredReason
        self.lastCompletedMeetingID = vm.lastCompletedMeetingID
        self.didCancel = vm.didCancelLastSession
    }

    func setMode(_ mode: CaptureMode) {
        viewModel.setMode(mode)
        sync()
    }

    func setTitle(_ title: String) {
        viewModel.setTitle(title)
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

    func cancel() async {
        await viewModel.cancel()
        sync()
    }

    func reset() {
        viewModel.reset()
        sync()
    }

    func startTimer() {
        stopTimer()
        timerStartedAt = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, let started = self.timerStartedAt else { return }
            Task { @MainActor in
                self.viewModel.tickElapsed(Date().timeIntervalSince(started))
                self.sync()
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerStartedAt = nil
    }

    private func sync() {
        selectedMode = viewModel.selectedMode
        meetingTitle = viewModel.meetingTitle
        statusLine = viewModel.statusLine
        elapsedLabel = viewModel.state.formattedElapsed
        microphoneLabel = viewModel.state.microphoneStatus.displayName
        screenLabel = viewModel.state.screenStatus.displayName
        canStart = viewModel.canStart
        canStop = viewModel.canStop
        canCancel = viewModel.canCancel
        isRecording = viewModel.isRecording
        isBusy = viewModel.isBusy
        micOK = viewModel.state.microphoneStatus.isUsable
        screenOK = viewModel.selectedMode == .audioOnly || viewModel.state.screenStatus.isUsable
        deferredVideoNote = viewModel.state.videoDeferredReason
        lastCompletedMeetingID = viewModel.lastCompletedMeetingID
        didCancel = viewModel.didCancelLastSession
    }
}
