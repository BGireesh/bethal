import SwiftUI

/// Legacy entry kept for previews; production uses `HomeShellView` via `RootView`.
struct ContentView: View {
    var session: AppSessionPreferences = .empty

    var body: some View {
        HomeShellView()
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
