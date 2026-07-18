import SwiftUI

@main
struct BethalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(
            width: AppIdentity.defaultWindowWidth,
            height: AppIdentity.defaultWindowHeight
        )
    }
}
