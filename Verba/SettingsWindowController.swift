import SwiftUI
import AppKit

class SettingsWindowController {
    private var window: NSWindow?

    @MainActor
    func open(appState: AppState) {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(appState)

        let hostingView = NSHostingView(rootView: settingsView)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Verba Settings"
        w.contentView = hostingView
        w.center()
        w.level = .floating
        w.isReleasedWhenClosed = false
        self.window = w

        NSApplication.shared.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}
