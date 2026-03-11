import SwiftUI
import AppKit

/// NSWindow subclass that never becomes key or main — prevents stealing focus
class NonActivatingWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

class FloatingIndicatorState: ObservableObject {
    @Published var isRecording = false
    @Published var statusMessage = ""
    @Published var mode: TranscriptionMode = .formatted
    @Published var audioLevels: [CGFloat] = Array(repeating: 0, count: 30)
    @Published var isVisible = false
    @Published var selectedPromptId = ""
    @Published var allPrompts: [FormattingPrompt] = []
    @Published var errorMessage: String?
    @Published var streamingText: String = ""
    @Published var isStreamingActive = false
    @Published var showSuccess = false
    @Published var recordingSessionId = UUID()
    var onPromptSelected: ((String) -> Void)?
    var onModeChanged: ((TranscriptionMode) -> Void)?
    var onErrorDismissed: (() -> Void)?
    var onStopRecording: (() -> Void)?
    var onCancelRecording: (() -> Void)?

    @MainActor func pushLevel(_ level: Float) {
        // Typical speech RMS is 0.005–0.05; amplify so it fills the waveform visually
        let normalized = CGFloat(min(level * 40, 1.0))
        audioLevels.append(normalized)
        if audioLevels.count > 30 {
            audioLevels.removeFirst()
        }
    }

    @MainActor func resetStreaming() {
        streamingText = ""
        isStreamingActive = false
    }
}

class FloatingIndicatorController {
    private var window: NonActivatingWindow?
    private var errorDismissTask: Task<Void, Never>?
    let state = FloatingIndicatorState()

    private static let indicatorWidth: CGFloat = 340

    @MainActor
    func show(isRecording: Bool, statusMessage: String, mode: TranscriptionMode) {
        state.isRecording = isRecording
        state.statusMessage = statusMessage
        state.mode = mode
        state.errorMessage = nil
        state.audioLevels = Array(repeating: 0, count: 30)
        state.resetStreaming()
        if isRecording {
            state.recordingSessionId = UUID()
        }

        let indicatorHeight: CGFloat = isRecording ? 96 : 72

        if window == nil {
            let hostingView = NSHostingView(rootView: FloatingIndicatorView(state: state))
            hostingView.frame = NSRect(x: 0, y: 0, width: Self.indicatorWidth, height: indicatorHeight)

            let w = NonActivatingWindow(
                contentRect: NSRect(x: 0, y: 0, width: Self.indicatorWidth, height: indicatorHeight),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            w.level = .floating
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = true
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            w.ignoresMouseEvents = false
            w.contentView = hostingView
            self.window = w
        } else {
            updateWindowHeight(indicatorHeight)
        }

        positionAtBottom()
        window?.alphaValue = 0
        window?.orderFrontRegardless()

        // Animate in
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().alphaValue = 1
        }
        state.isVisible = true
    }

    @MainActor
    func updateWindowHeight(_ newHeight: CGFloat) {
        guard let w = window else { return }
        var frame = w.frame
        let oldHeight = frame.height
        guard abs(oldHeight - newHeight) > 1 else { return }
        // Keep bottom edge pinned — grow upward
        // macOS coords: origin.y = bottom edge, so keep it unchanged
        frame.size.height = newHeight
        // origin.y stays the same → window grows upward
        w.setFrame(frame, display: true, animate: false)
        (w.contentView as? NSHostingView<FloatingIndicatorView>)?.frame.size.height = newHeight
    }

    /// Fixed height when streaming text is active — controls always visible
    private static let streamingHeight: CGFloat = 180

    @MainActor
    func updateStreamingText(_ text: String) {
        state.streamingText = text
        state.isStreamingActive = true
        if !text.isEmpty {
            updateWindowHeight(Self.streamingHeight)
        }
    }

    @MainActor
    func hide() {
        state.isVisible = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window?.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
            self?.state.showSuccess = false
        })
    }

    /// Show green checkmark briefly, then fade out
    @MainActor
    func hideWithSuccess() {
        state.showSuccess = true
        state.isRecording = false
        state.statusMessage = ""
        SoundFeedback.playPasteSuccess()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            hide()
        }
    }

    @MainActor
    func showError(_ message: String) {
        errorDismissTask?.cancel()
        state.errorMessage = message
        state.isRecording = false
        state.statusMessage = ""

        let indicatorHeight: CGFloat = 72

        if window == nil {
            let hostingView = NSHostingView(rootView: FloatingIndicatorView(state: state))
            hostingView.frame = NSRect(x: 0, y: 0, width: Self.indicatorWidth, height: indicatorHeight)

            let w = NonActivatingWindow(
                contentRect: NSRect(x: 0, y: 0, width: Self.indicatorWidth, height: indicatorHeight),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            w.level = .floating
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = true
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            w.ignoresMouseEvents = false
            w.contentView = hostingView
            self.window = w
        }

        positionAtBottom()
        window?.alphaValue = 0
        window?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().alphaValue = 1
        }
        state.isVisible = true

        // Auto-dismiss after 8 seconds (longer than before), but user can dismiss manually
        errorDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            state.errorMessage = nil
            hide()
        }
    }

    @MainActor
    func updateAudioLevel(_ level: Float) {
        state.pushLevel(level)
    }

    @MainActor
    private func positionAtBottom() {
        guard let window else { return }
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - window.frame.width / 2
        let y = screenFrame.minY + 32
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

struct FloatingIndicatorView: View {
    @ObservedObject var state: FloatingIndicatorState
    @State private var breathe = false

    private var hasStreamingText: Bool {
        state.isRecording && state.isStreamingActive && !state.streamingText.isEmpty
    }

    // Branded warm glass colors
    private let glassBg = Color(hex: 0x15141a).opacity(0.85)
    private let glassBorderTop = Color.white.opacity(0.12)
    private let glassBorderBottom = Color.white.opacity(0.04)
    private let warmAmber = Color(hex: 0xf0a060)

    var body: some View {
        VStack(spacing: 0) {
            if let error = state.errorMessage {
                // Error state — persistent, with dismiss button
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: 0xf04747))
                        .frame(width: 8, height: 8)
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: 0xede8e1))
                        .lineLimit(3)
                    Spacer()
                    Button {
                        state.errorMessage = nil
                        state.onErrorDismissed?()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x9a948a))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            } else {
                // Main content row
                Group {
                if state.showSuccess {
                    // Success state — green checkmark
                    HStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(hex: 0x3dd68c))
                        Text("Done")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(hex: 0x3dd68c))
                        Spacer()
                    }
                    .transition(.opacity)
                } else {
                    HStack(spacing: 10) {
                        // Recording dot — warm amber with breath animation
                        ZStack {
                            if state.isRecording {
                                Circle()
                                    .fill(warmAmber.opacity(0.15))
                                    .frame(width: 20, height: 20)
                                    .scaleEffect(breathe ? 1.3 : 1.0)
                                Circle()
                                    .fill(warmAmber)
                                    .frame(width: 10, height: 10)
                                    .shadow(color: warmAmber.opacity(0.5), radius: 8)
                            } else {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(Color(hex: 0x9a948a))
                            }
                        }
                        .frame(width: 20)
                        .onChange(of: state.isRecording) { recording in
                            if recording {
                                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                                    breathe = true
                                }
                            } else {
                                breathe = false
                            }
                        }

                        if state.isRecording {
                            if hasStreamingText {
                                MiniWaveformView(levels: state.audioLevels)
                                    .frame(width: 60, height: 16)
                            } else {
                                // Minimal waveform — just audio feedback
                                WaveformView(levels: state.audioLevels)
                                    .frame(height: 28)
                            }
                        } else {
                            AnimatedDotsText(base: state.statusMessage)
                        }

                        Spacer(minLength: 4)

                        if state.isRecording {
                            ElapsedTimeView()
                                .id(state.recordingSessionId)
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color(hex: 0xede8e1).opacity(0.7))
                        } else {
                            Text(state.mode.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(hex: 0x9a948a))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                }
                } // Group
                .padding(.horizontal, 16)
                .padding(.top, hasStreamingText ? 10 : 14)
                .padding(.bottom, hasStreamingText ? 0 : (state.isRecording ? 6 : 14))

                // Streaming text area — fills remaining space, scrolls internally
                if hasStreamingText {
                    Divider()
                        .background(Color.white.opacity(0.06))
                        .padding(.horizontal, 16)

                    StreamingTextView(text: state.streamingText)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                }
            }

            // Controls row during recording — always pinned at bottom
            if state.isRecording && state.errorMessage == nil {
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    RecordingControlsRow(state: state)

                    Spacer()

                    HStack(spacing: 6) {
                        // Cancel (discard) — muted, destructive hint
                        RecordingActionButton(
                            icon: "trash",
                            label: "Cancel",
                            style: .cancel
                        ) {
                            state.onCancelRecording?()
                        }

                        // Done (confirm & transcribe) — accent, primary action
                        RecordingActionButton(
                            icon: "checkmark",
                            label: "Done",
                            style: .confirm
                        ) {
                            state.onStopRecording?()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, hasStreamingText ? 4 : 0)
                .padding(.bottom, 10)
            }
        }
        .frame(width: 340)
        .background(
            ZStack {
                // Branded warm glass — not system material
                RoundedRectangle(cornerRadius: 16)
                    .fill(glassBg)
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial.opacity(0.4))
                    .environment(\.colorScheme, .dark)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [glassBorderTop, glassBorderBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color(hex: 0x3c2814).opacity(0.3), radius: 20, y: 8)
        .environment(\.colorScheme, .dark)
        .animation(.easeOut(duration: 0.25), value: state.isRecording)
        .animation(.easeOut(duration: 0.2), value: hasStreamingText)
    }
}

// MARK: - Streaming Text View

struct StreamingTextView: View {
    let text: String
    @State private var confirmedText = ""
    @State private var newText = ""
    @State private var revealProgress: CGFloat = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Confirmed text (fully revealed)
                    if !confirmedText.isEmpty {
                        Text(confirmedText)
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundStyle(Color(hex: 0xede8e1).opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // New text with shimmer reveal
                    if !newText.isEmpty {
                        Text(newText)
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundStyle(Color(hex: 0xf0a060).opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .mask(
                                GeometryReader { geo in
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                stops: [
                                                    .init(color: .white, location: max(0, revealProgress - 0.1)),
                                                    .init(color: .white.opacity(0.3), location: revealProgress),
                                                    .init(color: .clear, location: min(1, revealProgress + 0.15)),
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width, height: geo.size.height)
                                }
                            )
                    }
                }
                .id("streamingBottom")
            }
            .frame(maxHeight: 72)
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(colors: [.white.opacity(0.3), .white], startPoint: .top, endPoint: .bottom)
                        .frame(height: 10)
                    Color.white
                }
            )
            .onChange(of: text) { newValue in
                // Find what's new compared to confirmed
                if newValue.hasPrefix(confirmedText) {
                    newText = String(newValue.dropFirst(confirmedText.count))
                } else {
                    // Full replacement (re-transcription changed everything)
                    confirmedText = ""
                    newText = newValue
                }

                // Animate reveal
                revealProgress = 0
                withAnimation(.easeOut(duration: 0.6)) {
                    revealProgress = 1.2
                }

                // After reveal completes, move new text to confirmed
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.7))
                    confirmedText = newValue
                    newText = ""
                    revealProgress = 0
                }

                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("streamingBottom", anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Mini Waveform (compact, for use alongside streaming text)

struct MiniWaveformView: View {
    let levels: [CGFloat]
    private let warmAmber = Color(hex: 0xf0a060)

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(Array(levels.suffix(12).enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(warmAmber.opacity(0.5))
                    .frame(width: 2, height: max(2, level * 16))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
    }
}

struct WaveformView: View {
    let levels: [CGFloat]
    private let warmAmber = Color(hex: 0xf0a060)
    private let accent = Color(hex: 0x7c6cfc)

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(barColor(for: level))
                    .frame(width: 2.5, height: max(3, level * 28))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
    }

    private func barColor(for level: CGFloat) -> Color {
        if level > 0.7 { return warmAmber }
        if level > 0.4 { return warmAmber.opacity(0.7) }
        return accent.opacity(0.5)
    }
}

// MARK: - Recording Controls Row

struct RecordingControlsRow: View {
    @ObservedObject var state: FloatingIndicatorState

    var body: some View {
        HStack(spacing: 6) {
            // Mode picker
            FloatingPickerPill(
                label: state.mode.rawValue,
                icon: state.mode == .formatted ? "sparkles" : "bolt.fill"
            ) {
                ForEach(TranscriptionMode.allCases, id: \.self) { mode in
                    Button {
                        state.mode = mode
                        state.onModeChanged?(mode)
                    } label: {
                        Label(mode.rawValue, systemImage: mode == .formatted ? "sparkles" : "bolt.fill")
                    }
                }
            }

            // Prompt picker (only in formatted mode)
            if state.mode == .formatted && !state.allPrompts.isEmpty {
                FloatingPickerPill(
                    label: currentPromptName,
                    icon: "text.quote"
                ) {
                    ForEach(state.allPrompts) { prompt in
                        Button {
                            state.selectedPromptId = prompt.id.uuidString
                            state.onPromptSelected?(prompt.id.uuidString)
                        } label: {
                            Text(prompt.name)
                        }
                    }
                }
            }
        }
    }

    private var currentPromptName: String {
        state.allPrompts.first(where: { $0.id.uuidString == state.selectedPromptId })?.name ?? "General"
    }
}

struct FloatingPickerPill<MenuContent: View>: View {
    let label: String
    let icon: String
    @ViewBuilder let menuContent: () -> MenuContent
    @State private var isHovered = false

    var body: some View {
        Menu {
            menuContent()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 7))
                    .opacity(0.7)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(isHovered ? 0.25 : 0.15))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}

// MARK: - Recording Action Buttons (Cancel / Done)

struct RecordingActionButton: View {
    enum Style { case cancel, confirm }

    let icon: String
    let label: String
    let style: Style
    let action: () -> Void
    @State private var isHovered = false

    private var fg: Color {
        switch style {
        case .cancel:  return isHovered ? Color(hex: 0xf04747) : Color(hex: 0x9a948a)
        case .confirm: return .white
        }
    }

    private var bg: Color {
        switch style {
        case .cancel:  return Color.white.opacity(isHovered ? 0.12 : 0.06)
        case .confirm: return isHovered ? Color(hex: 0x7c6cfc) : Color(hex: 0x7c6cfc).opacity(0.8)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                if isHovered {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .foregroundStyle(fg)
            .padding(.horizontal, isHovered ? 10 : 6)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(bg)
            )
            .overlay(
                Capsule()
                    .strokeBorder(style == .confirm ? Color(hex: 0x7c6cfc).opacity(0.4) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .help(style == .cancel ? "Discard recording" : "Stop & transcribe")
    }
}

struct ElapsedTimeView: View {
    @State private var startDate = Date()
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @State private var displaySeconds: Int = 0

    var body: some View {
        HStack(spacing: 0) {
            // Minutes
            Text("\(displaySeconds / 60)")
            Text(":")
            // Tens digit of seconds
            FlipDigit(digit: (displaySeconds % 60) / 10)
            // Ones digit of seconds
            FlipDigit(digit: (displaySeconds % 60) % 10)
        }
        .onReceive(timer) { now in
            let newSeconds = Int(ceil(now.timeIntervalSince(startDate)))
            if newSeconds != displaySeconds {
                displaySeconds = newSeconds
            }
        }
    }
}

/// A single digit that flips (slides up) on change
private struct FlipDigit: View {
    let digit: Int

    var body: some View {
        Text("\(digit)")
            .contentTransition(.numericText())
            .animation(.easeOut(duration: 0.2), value: digit)
    }
}

/// Animated dots for status messages ending with "..."
/// "Transcribing..." cycles through 1-3 dots
struct AnimatedDotsText: View {
    let base: String
    @State private var dotCount = 3
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    private var stripped: String {
        var s = base
        while s.hasSuffix(".") { s.removeLast() }
        return s
    }

    private var hasDots: Bool { base.hasSuffix("...") }

    var body: some View {
        if hasDots {
            HStack(spacing: 0) {
                Text(stripped)
                Text(String(repeating: ".", count: dotCount))
                    .frame(width: 16, alignment: .leading)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color(hex: 0xede8e1))
            .lineLimit(1)
            .onReceive(timer) { _ in
                dotCount = (dotCount % 3) + 1
            }
        } else {
            Text(base)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: 0xede8e1))
                .lineLimit(1)
        }
    }
}

/// Sound feedback for recording lifecycle
enum SoundFeedback {
    /// Soft "pop" on recording start
    static func playRecordingStart() {
        NSSound(named: "Pop")?.play()
    }

    /// Gentle "tock" on recording stop
    static func playRecordingStop() {
        NSSound(named: "Tink")?.play()
    }

    /// Subtle confirmation on paste success
    static func playPasteSuccess() {
        NSSound(named: "Morse")?.play()
    }
}
