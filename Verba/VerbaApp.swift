import SwiftUI
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let appState {
            appState.mainWindow.open(appState: appState)
        }
        return false
    }
}

@main
struct VerbaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(updater: updaterController.updater)
                .environmentObject(appState)
                .onAppear { appDelegate.appState = appState }
        } label: {
            Image(systemName: appState.isRecording ? "mic.fill" : "mic")
                .symbolRenderingMode(.hierarchical)
        }
    }
}
