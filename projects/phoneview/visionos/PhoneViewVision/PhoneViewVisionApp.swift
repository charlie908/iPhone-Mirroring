import SwiftUI

@main
struct PhoneViewVisionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.plain)
        .defaultSize(width: 720, height: 900)
        .windowResizability(.contentMinSize)
    }
}
