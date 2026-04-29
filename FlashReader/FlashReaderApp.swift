import SwiftUI

@main
struct FlashReaderApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}
