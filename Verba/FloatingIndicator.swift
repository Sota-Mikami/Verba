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
    let state = FloatingIndicatorState()

    @MainActor
    func show(isRecording: Bool, statusMessage: String, mode: TranscriptionMode) {
        state.isRecording = isRecording
        state.statusMessage = statusMessage
        state.mode = mode
        if !isRecording {
            state.audioLevels = Array(repeating: 0, count: 30)
        }

        if window == nil {
            let hostingView = NSHostingView(rootView: FloatingIndicatorView(state: state))
            hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 72)

            let w = NonActivatingWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 72),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            w.level = .floating
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = true
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            w.ignoresMouseEvents = true
            w.contentView = hostingView
            self.window = w
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
        HStack(spacing: 14) {
            // Left: status icon
            ZStack {
                if state.isRecording {
                    // Pulsing glow ring
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
        .padding(.vertical, 14)
        .frame(width: 300, height: 72)
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
