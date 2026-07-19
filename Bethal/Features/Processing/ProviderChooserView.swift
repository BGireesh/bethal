import SwiftUI

/// Sheet: pick a local AI tool (or show empty install guidance) and show run progress.
struct ProviderChooserView: View {
    let providers: [AIProviderDescriptor]
    let availableProviders: [AIProviderDescriptor]
    let progress: ProcessingProgress
    let errorMessage: String?
    let emptyHowTo: String
    let preferredID: String?
    let onSelect: (String) -> Void
    let onRetry: () -> Void
    let onRefresh: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.md) {
            Text("Process with AI")
                .font(.headline)

            if progress.phase == .choosingProvider {
                chooserBody
            } else {
                progressBody
            }
        }
        .padding(DesignSpacing.lg)
        .frame(minWidth: 380, minHeight: 220)
    }

    @ViewBuilder
    private var chooserBody: some View {
        Text(progress.message.isEmpty ? "Choose a local AI tool" : progress.message)
            .font(.body)
            .foregroundStyle(.secondary)

        if availableProviders.isEmpty {
            Text("No local AI tools detected.")
                .font(.callout)
            Text(emptyHowTo)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            HStack {
                Button("Refresh", action: onRefresh)
                Button("Close", action: onDismiss)
                Spacer()
            }
        } else {
            List(availableProviders) { provider in
                Button {
                    onSelect(provider.id)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(provider.displayName)
                                .font(.body.weight(.medium))
                            if provider.id == preferredID {
                                Text("Default")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(provider.executablePath ?? provider.executableName)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: 120)
            HStack {
                Button("Refresh", action: onRefresh)
                Button("Cancel", action: onDismiss)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var progressBody: some View {
        Text(progress.message.isEmpty ? progress.phase.displayName : progress.message)
            .font(.body)
            .foregroundStyle(.secondary)

        ProgressView(value: progress.fractionCompleted)
            .progressViewStyle(.linear)

        if let errorMessage, progress.phase == .failed {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(Color.red)
                .textSelection(.enabled)
        }

        if progress.phase == .completed, let provider = progress.selectedProviderID {
            Text("Provider: \(provider)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        HStack {
            if progress.phase == .failed {
                Button("Retry", action: onRetry)
            }
            if progress.phase == .completed || progress.phase == .failed {
                Button("Done", action: onDismiss)
            }
            Spacer()
        }
    }
}
