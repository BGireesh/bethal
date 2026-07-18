import SwiftUI

@main
struct BethalApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .defaultSize(
            width: AppIdentity.defaultWindowWidth,
            height: AppIdentity.defaultWindowHeight
        )
    }
}
