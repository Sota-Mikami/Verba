import AppKit
import os

private let logger = Logger(subsystem: "com.sotamikami.verba", category: "Hotkey")

/// Unified hotkey controller using only flagsChanged events (confirmed to work globally).
/// - Fn hold (>0.3s) → push-to-talk
/// - Fn double-tap (<0.4s between taps) → hands-free toggle
class HotkeyController {
    var onPushToTalkStart: (() -> Void)?
    var onPushToTalkStop: (() -> Void)?
    var onHandsFreeToggle: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private var fnIsDown = false
    private var fnPressTime: Date?
    private var lastTapTime: Date?        // Time of last short tap (for double-tap detection)
    private var holdActivated = false       // Push-to-talk was activated (held long enough)
    private var holdTimer: DispatchWorkItem?

    private let holdThreshold: TimeInterval = 0.3   // Hold > 0.3s = push-to-talk
    private let doubleTapWindow: TimeInterval = 0.4  // Double-tap within 0.4s

    func start(
        onPushToTalkStart: @escaping () -> Void,
        onPushToTalkStop: @escaping () -> Void,
        onHandsFreeToggle: @escaping () -> Void
    ) {
        self.onPushToTalkStart = onPushToTalkStart
        self.onPushToTalkStop = onPushToTalkStop
        self.onHandsFreeToggle = onHandsFreeToggle

        let mask: NSEvent.EventTypeMask = [.flagsChanged]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleEvent(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleEvent(event)
            return event
        }
        logger.info("HotkeyController started")
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
        localMonitor = nil
        holdTimer?.cancel()
    }

    private func handleEvent(_ event: NSEvent) {
        guard event.type == .flagsChanged && event.keyCode == 63 else { return }

        let now = Date()

        if !fnIsDown {
            // --- Fn PRESSED ---
            fnIsDown = true
            fnPressTime = now
            holdActivated = false

            // Schedule hold activation
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.fnIsDown else { return }
                self.holdActivated = true
                self.onPushToTalkStart?()
            }
            holdTimer = work
            DispatchQueue.main.asyncAfter(deadline: .now() + holdThreshold, execute: work)
        } else {
            // --- Fn RELEASED ---
            fnIsDown = false
            holdTimer?.cancel()
            holdTimer = nil

            if holdActivated {
                // Was a hold → stop push-to-talk
                holdActivated = false
                onPushToTalkStop?()
            } else {
                // Was a short tap → check for double-tap
                if let last = lastTapTime, now.timeIntervalSince(last) < doubleTapWindow {
                    // Double-tap detected!
                    lastTapTime = nil
                    onHandsFreeToggle?()
                } else {
                    // First tap — remember it
                    lastTapTime = now
                }
            }
        }
    }
}
