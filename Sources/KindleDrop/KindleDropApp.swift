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
                .frame(minWidth: 640, minHeight: 500)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Settings…") {
                    showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu("Send") {
                Button("Send Selected Files") {
                    NotificationCenter.default.post(name: .sendFiles, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Clear History") {
                    history.clearHistory()
                }
            }
        }
    }
}

extension Notification.Name {
    static let sendFiles = Notification.Name("sendFiles")
}