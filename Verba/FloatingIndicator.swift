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
    var onPromptSelected: ((String) -> Void)?
    var onModeChanged: ((TranscriptionMode) -> Void)?

    @MainActor func pushLevel(_ level: Float) {
        let normalized = CGFloat(min(level * 5, 1.0))
        audioLevels.append(normalized)
        if audioLevels.count > 30 {
            audioLevels.removeFirst()
        }
    }
}

class FloatingIndicatorController {
    private var window: NonActivatingWindow?
    private var errorDismissTask: Task<Void, Never>?
    let state = FloatingIndicatorState()

    @MainActor
    func show(isRecording: Bool, statusMessage: String, mode: TranscriptionMode) {
        state.isRecording = isRecording
        state.statusMessage = statusMessage
        state.mode = mode
        if !isRecording {
            state.audioLevels = Array(repeating: 0, count: 30)
        }

        let indicatorHeight: CGFloat = isRecording ? 96 : 72

        if window == nil {
            let hostingView = NSHostingView(rootView: FloatingIndicatorView(state: state))
            hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: indicatorHeight)

            let w = NonActivatingWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: indicatorHeight),
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
            // Update window size
            if let w = window {
                var frame = w.frame
                let oldHeight = frame.height
                frame.size.height = indicatorHeight
                frame.origin.y -= (indicatorHeight - oldHeight)
                w.setFrame(frame, display: true, animate: false)
                (w.contentView as? NSHostingView<FloatingIndicatorView>)?.frame.size.height = indicatorHeight
            }
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
    func hide() {
        state.isVisible = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window?.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
        })
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
            hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: indicatorHeight)

            let w = NonActivatingWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: indicatorHeight),
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

        errorDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
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
    @State private var dotPulse = false

    var body: some View {
        VStack(spacing: 0) {
            if let error = state.errorMessage {
                // Error state
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            } else {
            HStack(spacing: 14) {
                // Left: status icon
                ZStack {
                    if state.isRecording {
                        Circle()
                            .fill(.red.opacity(0.2))
                            .frame(width: 18, height: 18)
                            .scaleEffect(dotPulse ? 1.4 : 1.0)
                            .opacity(dotPulse ? 0 : 0.6)
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                            .shadow(color: .red.opacity(0.6), radius: 6)
                    } else {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.white)
                    }
                }
                .frame(width: 20)
                .onChange(of: state.isRecording) { recording in
                    if recording {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                            dotPulse = true
                        }
                    } else {
                        dotPulse = false
                    }
                }

                if state.isRecording {
                    WaveformView(levels: state.audioLevels)
                        .frame(height: 44)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                } else {
                    Text(state.statusMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }

                Spacer(minLength: 4)

                if state.isRecording {
                    ElapsedTimeView()
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Text(state.mode.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, state.isRecording ? 6 : 14)
            } // end else (non-error state)

            // Controls row during recording
            if state.isRecording && state.errorMessage == nil {
                RecordingControlsRow(state: state)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.isRecording)
    }
}

struct WaveformView: View {
    let levels: [CGFloat]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(barColor(for: level))
                    .frame(width: 2.5, height: max(3, level * 44))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
    }

    private func barColor(for level: CGFloat) -> Color {
        if level > 0.7 { return .red }
        if level > 0.4 { return .orange }
        return .white.opacity(0.7)
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
                        HStack(spacing: 6) {
                            Image(systemName: mode == .formatted ? "sparkles" : "bolt.fill")
                                .frame(width: 14)
                            Text(mode.rawValue)
                            Spacer()
                            if mode == state.mode {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                            }
                        }
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
                            HStack(spacing: 6) {
                                Text(prompt.name)
                                Spacer()
                                if prompt.id.uuidString == state.selectedPromptId {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                }
                            }
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
                    .opacity(0.6)
            }
            .foregroundStyle(.white.opacity(isHovered ? 0.95 : 0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(isHovered ? 0.18 : 0.08))
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}

struct ElapsedTimeView: View {
    @State private var elapsed: TimeInterval = 0
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(formatTime(elapsed))
            .onReceive(timer) { _ in
                elapsed += 0.1
            }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
