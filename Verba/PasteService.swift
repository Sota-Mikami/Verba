import AppKit
import os

private let logger = Logger(subsystem: "com.sotamikami.verba", category: "Paste")

class PasteService {
    /// The app that was frontmost when recording started
    private var targetApp: NSRunningApplication?

    /// Set by caller to show accessibility warnings
    var onAccessibilityNeeded: (() -> Void)?

    /// Call when recording starts to remember which app to paste into
    func saveTargetApp() {
        targetApp = NSWorkspace.shared.frontmostApplication
    }

    func paste(text: String) {
        guard AXIsProcessTrusted() else {
            logger.warning("Accessibility not granted — cannot paste")
            // Still copy to clipboard so user can manually paste
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            onAccessibilityNeeded?()
            return
        }

        let pasteboard = NSPasteboard.general
        let savedItems = savePasteboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Activate the target app first, then paste
        if let app = targetApp, !app.isTerminated {
            app.activate()

            // Give the app a moment to come to front, then paste
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.simulatePaste()
                // Restore clipboard after paste completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.restorePasteboard(pasteboard, items: savedItems)
                }
            }
        } else {
            // No saved target — just paste into whatever is frontmost
            simulatePaste()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.restorePasteboard(pasteboard, items: savedItems)
            }
        }
    }

    private func simulatePaste() {

        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Pasteboard save/restore

    private func savePasteboard(_ pasteboard: NSPasteboard) -> [[(NSPasteboard.PasteboardType, Data)]] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        }
    }

    private func restorePasteboard(_ pasteboard: NSPasteboard, items: [[(NSPasteboard.PasteboardType, Data)]]) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let pasteboardItems = items.map { entries -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entries {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(pasteboardItems)
    }
}
