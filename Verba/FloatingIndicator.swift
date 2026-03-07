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
    @Published var audioLevels: [CGFloat] = Array(repeating: 0, count: 20)

    @MainActor func pushLevel(_ level: Float) {
        // Normalize: RMS is typically 0~0.3, amplify and clamp to 0~1
        let normalized = CGFloat(min(level * 5, 1.0))
        audioLevels.append(normalized)
        if audioLevels.count > 20 {
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
            state.audioLevels = Array(repeating: 0, count: 20)
        }

        if window == nil {
            let hostingView = NSHostingView(rootView: FloatingIndicatorView(state: state))
            hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 56)

            let w = NonActivatingWindow(
                contentRect: NSRect(x: 0, y: 0, width: 280, height: 56),
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
        window?.orderFrontRegardless()
    }

    @MainActor
    func hide() {
        window?.orderOut(nil)
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

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if state.isRecording {
                    // Waveform bars replace the pulse circle
                    WaveformView(levels: state.audioLevels)
                        .frame(width: 36, height: 28)
                } else {
                    Image(systemName: "mic.badge.ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.statusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(state.mode.rawValue)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            if state.isRecording {
                ElapsedTimeView()
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(width: 280, height: 56)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.black.opacity(0.75))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct WaveformView: View {
    let levels: [CGFloat]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.red)
                    .frame(width: 2, height: max(3, level * 24))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
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
