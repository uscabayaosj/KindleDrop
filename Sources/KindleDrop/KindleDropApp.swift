import SwiftUI

@main
struct KindleDropApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var history = HistoryStore.shared
    @State private var showSettings = false

    var body: some Scene {
        WindowGroup {
            ContentView(showSettings: $showSettings)
                .environmentObject(settings)
                .environmentObject(history)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Settings…") {
                    showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
