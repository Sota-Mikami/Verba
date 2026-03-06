import SwiftUI
import AppKit

/// NSWindow subclass that never becomes key or main — prevents stealing focus
class NonActivatingWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

class FloatingIndicatorController {
    private var window: NonActivatingWindow?

    @MainActor
    func show(isRecording: Bool, statusMessage: String, mode: TranscriptionMode) {
        let hostingView = NSHostingView(rootView: FloatingIndicatorView(
            isRecording: isRecording,
            statusMessage: statusMessage,
            mode: mode
        ))
        hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 56)

        if let window {
            window.contentView = hostingView
        } else {
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
    let isRecording: Bool
    let statusMessage: String
    let mode: TranscriptionMode

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if isRecording {
                    Circle()
                        .fill(.red.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .scaleEffect(pulseScale)
                }
                Image(systemName: isRecording ? "mic.fill" : "mic.badge.ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isRecording ? .red : .orange)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(mode == .formatted ? "Formatted" : "Fast")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            if isRecording {
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
        .onAppear {
            if isRecording {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseScale = 1.4
                }
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
