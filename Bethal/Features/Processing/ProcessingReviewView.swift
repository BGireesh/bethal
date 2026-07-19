import SwiftUI

/// Review sheet: summary + transcript peek + editable/deletable todo candidates.
struct ProcessingReviewView: View {
    let draft: ReviewDraft?
    let phase: ReviewPhase
    let errorMessage: String?
    let lastAcceptedCount: Int
    let onUpdateTitle: (String, String) -> Void
    let onRemove: (String) -> Void
    let onAccept: () -> Void
    let onDiscard: () -> Void
    let onDismiss: () -> Void

    @State private var editingTitles: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.md) {
            HStack {
                Text("Review processing")
                    .font(.headline)
                Spacer()
                if phase == .completed {
                    Button("Done", action: onDismiss)
                }
            }

            if phase == .loading {
                ProgressView("Loading…")
            } else if let draft {
                content(draft)
            } else if phase == .failed, let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(Color.red)
                Button("Close", action: onDismiss)
            } else {
                Text("Nothing to review.")
                    .foregroundStyle(.secondary)
                Button("Close", action: onDismiss)
            }
        }
        .padding(DesignSpacing.lg)
        .frame(minWidth: 440, minHeight: 360)
        .onAppear {
            if let draft {
                editingTitles = Dictionary(uniqueKeysWithValues: draft.candidates.map { ($0.id, $0.title) })
            }
        }
        .onChange(of: draft?.candidates.map(\.id) ?? []) { _, ids in
            guard let draft else { return }
            for id in ids where editingTitles[id] == nil {
                if let todo = draft.candidates.first(where: { $0.id == id }) {
                    editingTitles[id] = todo.title
                }
            }
            editingTitles = editingTitles.filter { ids.contains($0.key) }
        }
    }

    @ViewBuilder
    private func content(_ draft: ReviewDraft) -> some View {
        Text(draft.meetingTitle)
            .font(.title3.weight(.semibold))

        GroupBox("Summary") {
            ScrollView {
                Text(draft.summaryMarkdown.isEmpty ? "No summary." : draft.summaryMarkdown)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 120)
        }

        if !draft.transcriptPreview.isEmpty {
            GroupBox("Transcript preview") {
                ScrollView {
                    Text(draft.transcriptPreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 80)
            }
        }

        GroupBox("Proposed todos (\(draft.candidateCount))") {
            if draft.candidates.isEmpty {
                Text("No todos left — accept to finish without new items, or discard to re-process.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(draft.candidates) { todo in
                        HStack(alignment: .top) {
                            TextField(
                                "Todo",
                                text: Binding(
                                    get: { editingTitles[todo.id] ?? todo.title },
                                    set: { editingTitles[todo.id] = $0 }
                                ),
                                onCommit: {
                                    let title = editingTitles[todo.id] ?? todo.title
                                    onUpdateTitle(todo.id, title)
                                }
                            )
                            Button(role: .destructive) {
                                onRemove(todo.id)
                                editingTitles[todo.id] = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Reject this todo")
                        }
                    }
                }
                .frame(minHeight: 100, maxHeight: 180)
            }
        }

        if let errorMessage, phase == .failed {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(Color.red)
        }

        if phase == .completed {
            Text(lastAcceptedCount == 0
                 ? "Review finished. No new todos accepted."
                 : "Accepted \(lastAcceptedCount) todo\(lastAcceptedCount == 1 ? "" : "s") into the global list.")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            HStack {
                Button("Discard", role: .destructive, action: onDiscard)
                    .disabled(phase.isBusy)
                Spacer()
                Button("Accept remaining") {
                    // Commit any uncommitted text field edits first.
                    for todo in draft.candidates {
                        let title = editingTitles[todo.id] ?? todo.title
                        onUpdateTitle(todo.id, title)
                    }
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
                .disabled(phase.isBusy)
                Button("Cancel", action: onDismiss)
                    .disabled(phase.isBusy)
            }
        }
    }
}
