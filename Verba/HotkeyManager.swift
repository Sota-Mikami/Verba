import AppKit
import os

private let logger = Logger(subsystem: "com.sotamikami.verba", category: "Hotkey")

// MARK: - Key Shortcut Model

struct KeyShortcut: Equatable, Codable {
    enum Kind: String, Codable {
        case modifierHold    // Single modifier key (hold for PTT, tap for HF)
        case keyCombo        // Modifier + regular key
        case doubleTap       // Double-tap a modifier
    }

    let kind: Kind
    let modifierKeyCode: UInt16   // Modifier key (fn=63, ⌥L=58, etc.)
    let regularKeyCode: UInt16    // Regular key for combo (Space=49), 0 otherwise
    let label: String

    static let fnHold = KeyShortcut(kind: .modifierHold, modifierKeyCode: 63, regularKeyCode: 0, label: "fn")
    static let fnDoubleTap = KeyShortcut(kind: .doubleTap, modifierKeyCode: 63, regularKeyCode: 0, label: "fn ×2")
    static let defaultPTT = fnHold
    static let defaultHF = fnDoubleTap
}

extension KeyShortcut: RawRepresentable {
    init?(rawValue: String) {
        let p = rawValue.components(separatedBy: "||")
        guard p.count == 4,
              let kind = Kind(rawValue: p[0]),
              let mk = UInt16(p[1]),
              let rk = UInt16(p[2]) else { return nil }
        self.init(kind: kind, modifierKeyCode: mk, regularKeyCode: rk, label: p[3])
    }
    var rawValue: String {
        "\(kind.rawValue)||\(modifierKeyCode)||\(regularKeyCode)||\(label)"
    }
}

// MARK: - Key Name Helpers

enum KeyNames {
    static let modifierKeyCodes: Set<UInt16> = [63, 56, 60, 59, 62, 58, 61, 55, 54]

    static func isModifier(_ keyCode: UInt16) -> Bool {
        modifierKeyCodes.contains(keyCode)
    }

    static func modifierLabel(for keyCode: UInt16) -> String {
        switch keyCode {
        case 63: return "fn"
        case 56: return "⇧L"
        case 60: return "⇧R"
        case 59: return "⌃L"
        case 62: return "⌃R"
        case 58: return "⌥L"
        case 61: return "⌥R"
        case 55: return "⌘L"
        case 54: return "⌘R"
        default: return "Mod\(keyCode)"
        }
    }

    static func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 53: return "Esc"
        case 51: return "Delete"
        case 0: return "A"; case 1: return "S"; case 2: return "D"; case 3: return "F"
        case 4: return "H"; case 5: return "G"; case 6: return "Z"; case 7: return "X"
        case 8: return "C"; case 9: return "V"; case 11: return "B"; case 12: return "Q"
        case 13: return "W"; case 14: return "E"; case 15: return "R"; case 16: return "Y"
        case 17: return "T"; case 18: return "1"; case 19: return "2"; case 20: return "3"
        case 21: return "4"; case 22: return "6"; case 23: return "5"; case 24: return "="
        case 25: return "9"; case 26: return "7"; case 27: return "-"; case 28: return "8"
        case 29: return "0"; case 31: return "O"; case 32: return "U"; case 34: return "I"
        case 35: return "P"; case 37: return "L"; case 38: return "J"; case 40: return "K"
        case 45: return "N"; case 46: return "M"
        default: return "Key\(keyCode)"
        }
    }
}

// MARK: - Hotkey Controller

class HotkeyController {
    var onPushToTalkStart: (() -> Void)?
    var onPushToTalkStop: (() -> Void)?
    var onHandsFreeToggle: (() -> Void)?

    var pttShortcut: KeyShortcut = .defaultPTT
    var hfShortcut: KeyShortcut = .defaultHF
    var isEnabled = true {
        didSet {
            if isEnabled {
                // Cooldown after re-enable to prevent spurious triggers
                suppressUntil = Date().addingTimeInterval(0.5)
                resetState()
            }
        }
    }
    private var suppressUntil: Date?

    private var monitors: [Any] = []

    // Per-keyCode press tracking
    private var modDown: [UInt16: Bool] = [:]

    // PTT state
    private var pttHoldTimer: DispatchWorkItem?
    private var pttActive = false
    private var comboPTTActive = false

    // Double-tap state
    private var lastTapKeyCode: UInt16 = 0
    private var lastTapTime: Date?

    // Suppress modifier tap after combo
    private var lastComboTime: Date?

    private let holdThreshold: TimeInterval = 0.3
    private let doubleTapWindow: TimeInterval = 0.4

    func start(
        onPushToTalkStart: @escaping () -> Void,
        onPushToTalkStop: @escaping () -> Void,
        onHandsFreeToggle: @escaping () -> Void
    ) {
        self.onPushToTalkStart = onPushToTalkStart
        self.onPushToTalkStop = onPushToTalkStop
        self.onHandsFreeToggle = onHandsFreeToggle
        installMonitors()
        logger.info("HotkeyController started — PTT: \(self.pttShortcut.label), HF: \(self.hfShortcut.label)")
    }

    func stop() {
        for m in monitors { NSEvent.removeMonitor(m) }
        monitors.removeAll()
        resetState()
    }

    func restart() {
        guard let ptt = onPushToTalkStart, let pttStop = onPushToTalkStop, let hf = onHandsFreeToggle else { return }
        stop()
        start(onPushToTalkStart: ptt, onPushToTalkStop: pttStop, onHandsFreeToggle: hf)
    }

    private func installMonitors() {
        var mask: NSEvent.EventTypeMask = [.flagsChanged]
        if pttShortcut.kind == .keyCombo || hfShortcut.kind == .keyCombo {
            mask.insert(.keyDown)
            mask.insert(.keyUp)
        }

        if let m = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] in self?.handle($0) }) {
            monitors.append(m)
        }
        if let m = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] e in self?.handle(e); return e }) {
            monitors.append(m)
        }
    }

    private func resetState() {
        pttHoldTimer?.cancel()
        pttHoldTimer = nil
        pttActive = false
        comboPTTActive = false
        modDown.removeAll()
        lastTapTime = nil
        lastComboTime = nil
    }

    private func handle(_ event: NSEvent) {
        guard isEnabled else { return }
        if let until = suppressUntil {
            if Date() < until { return }
            suppressUntil = nil
        }
        switch event.type {
        case .flagsChanged: handleFlags(event)
        case .keyDown where !event.isARepeat: handleKeyDown(event)
        case .keyUp: handleKeyUp(event)
        default: break
        }
    }

    // MARK: Modifier events

    private func handleFlags(_ event: NSEvent) {
        let kc = event.keyCode
        guard KeyNames.isModifier(kc) else { return }

        let wasDown = modDown[kc] ?? false
        modDown[kc] = !wasDown

        if !wasDown {
            onModDown(kc)
        } else {
            onModUp(kc)
        }
    }

    private func onModDown(_ kc: UInt16) {
        if pttShortcut.kind == .modifierHold && pttShortcut.modifierKeyCode == kc {
            pttActive = false
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.modDown[kc] == true else { return }
                self.pttActive = true
                self.onPushToTalkStart?()
            }
            pttHoldTimer = work
            DispatchQueue.main.asyncAfter(deadline: .now() + holdThreshold, execute: work)
        }
    }

    private func onModUp(_ kc: UInt16) {
        let now = Date()

        // PTT modifierHold release
        if pttShortcut.kind == .modifierHold && pttShortcut.modifierKeyCode == kc {
            pttHoldTimer?.cancel()
            pttHoldTimer = nil
            if pttActive {
                pttActive = false
                onPushToTalkStop?()
                return
            }
        }

        // Suppress taps right after combo usage
        if let t = lastComboTime, now.timeIntervalSince(t) < 0.5 { return }

        // HF doubleTap
        if hfShortcut.kind == .doubleTap && hfShortcut.modifierKeyCode == kc {
            if lastTapKeyCode == kc, let t = lastTapTime, now.timeIntervalSince(t) < doubleTapWindow {
                lastTapTime = nil
                lastTapKeyCode = 0
                onHandsFreeToggle?()
            } else {
                lastTapKeyCode = kc
                lastTapTime = now
            }
            return
        }

        // HF modifierHold (tap = toggle), only if not sharing key with PTT modifierHold
        if hfShortcut.kind == .modifierHold && hfShortcut.modifierKeyCode == kc {
            let sharesPTTKey = pttShortcut.kind == .modifierHold && pttShortcut.modifierKeyCode == kc
            if !sharesPTTKey {
                onHandsFreeToggle?()
            }
        }
    }

    // MARK: Regular key events (combos)

    private func handleKeyDown(_ event: NSEvent) {
        let kc = event.keyCode
        guard !KeyNames.isModifier(kc) else { return }

        if pttShortcut.kind == .keyCombo
            && pttShortcut.regularKeyCode == kc
            && modDown[pttShortcut.modifierKeyCode] == true {
            pttHoldTimer?.cancel()
            pttHoldTimer = nil
            comboPTTActive = true
            lastComboTime = Date()
            onPushToTalkStart?()
            return
        }

        if hfShortcut.kind == .keyCombo
            && hfShortcut.regularKeyCode == kc
            && modDown[hfShortcut.modifierKeyCode] == true {
            pttHoldTimer?.cancel()
            pttHoldTimer = nil
            lastComboTime = Date()
            onHandsFreeToggle?()
            return
        }
    }

    private func handleKeyUp(_ event: NSEvent) {
        if pttShortcut.kind == .keyCombo
            && pttShortcut.regularKeyCode == event.keyCode
            && comboPTTActive {
            comboPTTActive = false
            onPushToTalkStop?()
        }
    }
}

// MARK: - Shortcut Recorder

class ShortcutRecorder {
    private var flagsMonitor: Any?
    private var keyMonitor: Any?
    private var heldModifier: UInt16?
    private var tapKeyCode: UInt16?
    private var tapTime: Date?
    private var singleTapTimer: DispatchWorkItem?

    var onCapture: ((KeyShortcut) -> Void)?

    func start() {
        heldModifier = nil
        tapKeyCode = nil
        tapTime = nil

        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] e in
            self?.handleFlags(e)
            return e
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            self?.handleKeyDown(e)
            return e
        }
    }

    func stop() {
        singleTapTimer?.cancel()
        singleTapTimer = nil
        if let m = flagsMonitor { NSEvent.removeMonitor(m) }
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        flagsMonitor = nil
        keyMonitor = nil
    }

    private func handleFlags(_ event: NSEvent) {
        let kc = event.keyCode
        guard KeyNames.isModifier(kc) else { return }

        if heldModifier == nil {
            // Modifier down
            heldModifier = kc
        } else if heldModifier == kc {
            // Modifier up (same key)
            heldModifier = nil
            singleTapTimer?.cancel()

            let now = Date()
            if tapKeyCode == kc, let t = tapTime, now.timeIntervalSince(t) < 0.4 {
                // Double-tap
                let label = KeyNames.modifierLabel(for: kc) + " ×2"
                finish(KeyShortcut(kind: .doubleTap, modifierKeyCode: kc, regularKeyCode: 0, label: label))
            } else {
                // First tap — wait 0.5s for possible second tap
                tapKeyCode = kc
                tapTime = now
                let capturedKC = kc
                let work = DispatchWorkItem { [weak self] in
                    let label = KeyNames.modifierLabel(for: capturedKC)
                    self?.finish(KeyShortcut(kind: .modifierHold, modifierKeyCode: capturedKC, regularKeyCode: 0, label: label))
                }
                singleTapTimer = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        let kc = event.keyCode
        guard let mod = heldModifier, !KeyNames.isModifier(kc) else { return }
        singleTapTimer?.cancel()
        let label = KeyNames.modifierLabel(for: mod) + " " + KeyNames.keyName(for: kc)
        finish(KeyShortcut(kind: .keyCombo, modifierKeyCode: mod, regularKeyCode: kc, label: label))
    }

    private func finish(_ shortcut: KeyShortcut) {
        onCapture?(shortcut)
        stop()
    }
}
