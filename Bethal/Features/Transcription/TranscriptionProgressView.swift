import SwiftUI

/// Lightweight progress panel for an in-flight or finished transcription job.
struct TranscriptionProgressView: View {
    let progress: TranscriptionProgress
    let errorMessage: String?
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.md) {
            Text("Transcription")
                .font(.headline)
            Text(progress.message.isEmpty ? progress.phase.displayName : progress.message)
                .font(.body)
                .foregroundStyle(.secondary)

            ProgressView(value: progress.fractionCompleted)
                .progressViewStyle(.linear)

            if let errorMessage, progress.phase == .failed {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.red)
            }

            HStack {
                if progress.phase == .failed, let onRetry {
                    Button("Retry", action: onRetry)
                }
                if progress.phase == .completed || progress.phase == .failed, let onDismiss {
                    Button("Done", action: onDismiss)
                }
                Spacer()
            }
        }
        .padding(DesignSpacing.lg)
        .frame(minWidth: 320)
    }
}
