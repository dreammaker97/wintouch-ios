import SwiftUI

@main
struct WinTouchApp: App {
    @UIApplicationDelegateAdaptor(OrientationAppDelegate.self) private var appDelegate
    @StateObject private var store = WinTouchStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        store.handleForegroundReturn()
                    }
                }
        }
    }
}
