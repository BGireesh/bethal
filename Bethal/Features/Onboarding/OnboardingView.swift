import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @ObservedObject var controller: OnboardingController

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(28)
            Divider()
            footer
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(AppIdentity.displayName)
                    .font(.headline)
                Text(controller.flow.step.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            stepIndicator
        }
        .padding(20)
    }

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases.filter { !$0.isTerminal }, id: \.rawValue) { step in
                Circle()
                    .fill(step <= controller.flow.step ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityLabel("Onboarding step \(controller.flow.step.rawValue + 1) of 3")
    }

    @ViewBuilder
    private var content: some View {
        switch controller.flow.step {
        case .privacy:
            privacyStep
        case .workingDirectory:
            directoryStep
        case .defaultProvider:
            providerStep
        case .finished:
            finishedStep
        }
    }

    private var privacyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Everything stays on your Mac")
                .font(.title2.weight(.semibold))
            Text(OnboardingCopy.privacyBody)
            .font(.body)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)

            Label(OnboardingCopy.privacyShield, systemImage: "lock.shield")
                .foregroundStyle(.secondary)
        }
    }

    private var directoryStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a working directory")
                .font(.title2.weight(.semibold))
            Text(OnboardingCopy.directoryBody)
            .foregroundStyle(.secondary)

            GroupBox {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected folder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(controller.flow.directoryPath ?? "No folder selected")
                            .font(.body.monospaced())
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button("Choose…") {
                        presentDirectoryPicker()
                    }
                    .keyboardShortcut("o", modifiers: [.command])
                }
                .padding(8)
            }

            if let error = controller.flow.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
    }

    private var providerStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Default AI tool (optional)")
                .font(.title2.weight(.semibold))
            Text(OnboardingCopy.providerBody)
            .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                providerRow(id: nil, title: "Ask me every time", detail: "Recommended until you settle on a default.")
                ForEach(controller.providerOptions) { option in
                    providerRow(id: option.id, title: option.displayName, detail: option.detail)
                }
            }

            if let error = controller.flow.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
    }

    private func providerRow(id: String?, title: String, detail: String) -> some View {
        let selected = controller.flow.providerID == id
        return Button {
            controller.selectProvider(id: id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var finishedStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You're set")
                .font(.title2.weight(.semibold))
            Text("Bethal is ready. Your data will live in:")
                .foregroundStyle(.secondary)
            Text(controller.flow.directoryPath ?? controller.sessionPreferences.workingDirectoryPath ?? "")
                .font(.body.monospaced())
                .textSelection(.enabled)
        }
    }

    private var footer: some View {
        HStack {
            if controller.flow.step > .privacy && !controller.flow.isComplete {
                Button("Back") {
                    controller.goBack()
                }
            }
            Spacer()
            if !controller.flow.isComplete {
                Button(controller.flow.primaryActionTitle) {
                    controller.continueOrFinish()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!controller.flow.canAdvance && controller.flow.step == .workingDirectory)
            }
        }
        .padding(20)
    }

    private func presentDirectoryPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Choose where Bethal should store meetings and todos."
        if panel.runModal() == .OK, let url = panel.url {
            controller.selectDirectory(url)
        }
    }
}
