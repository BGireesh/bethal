import SwiftUI

struct ContentView: View {
    var session: AppSessionPreferences = .empty

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(AppIdentity.displayName)
                .font(.largeTitle.weight(.semibold))

            Text(AppIdentity.tagline)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let path = session.workingDirectoryPath {
                VStack(spacing: 4) {
                    Text("Working directory")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 4)
            }

            Text(AppIdentity.bundleIdentifier)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)

            Text("Home shell (meetings, todos, settings) arrives in the next PRs.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

#Preview {
    ContentView(
        session: AppSessionPreferences(
            hasCompletedOnboarding: true,
            workingDirectoryPath: "/Users/example/Documents/Bethal"
        )
    )
}
