import SwiftUI

@main
struct KindleDropApp: App {
    var body: some Scene {
        WindowGroup {
            SendToKindleView()
                .frame(minWidth: 700, minHeight: 500)
        }
        .windowResizability(.contentSize)
    }
}
