import SwiftUI

@main
struct SwiftWeatherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 720, height: 900)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
