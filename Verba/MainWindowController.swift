import SwiftUI
import AppKit

class MainWindowController {
    private var window: NSWindow?

    @MainActor
    func open(appState: AppState) {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let mainView = MainView()
            .environmentObject(appState)

        let hostingView = NSHostingView(rootView: mainView)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 560),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Verba"
        w.contentView = hostingView
        w.center()
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 640, height: 420)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.appearance = NSAppearance(named: .darkAqua)
        w.backgroundColor = NSColor(red: 0x2B/255, green: 0x2D/255, blue: 0x31/255, alpha: 1)
        self.window = w

        NSApplication.shared.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}
