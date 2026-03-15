import SwiftUI

struct LicenseView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var licenseService: LicenseService
    @State private var licenseKey = ""
    @State private var showKeyInput = false
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss

    // Hover states
    @State private var buyHovered = false
    @State private var keyToggleHovered = false
    @State private var activateHovered = false
    @State private var sponsorHovered = false
    @State private var closeHovered = false
    @State private var startHovered = false
    @State private var autoDismissTask: DispatchWorkItem?

    private var usageStats: (sessions: Int, words: Int, timeSaved: String) {
        let sessions = appState.lifetimeSessions
        let words = appState.lifetimeWords
        let totalMinutes = Int(appState.lifetimeDuration) / 60
        let timeSaved: String
        if totalMinutes >= 60 {
            timeSaved = "\(totalMinutes / 60)h \(totalMinutes % 60)m"
        } else if totalMinutes > 0 {
            timeSaved = "~\(totalMinutes)min"
        } else {
            timeSaved = "~\(Int(appState.lifetimeDuration))s"
        }
        return (sessions, words, timeSaved)
    }

    private var canDismiss: Bool {
        !licenseService.isLocked
    }

    var body: some View {
        VStack(spacing: 0) {
            // Close button (only when trial is still active)
            if canDismiss {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(closeHovered ? DS.textNormal : DS.textMuted)
                            .padding(8)
                            .background(closeHovered ? DS.bgModifierActive : DS.bgModifierHover)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .onHover { closeHovered = $0 }
                    .animation(.easeOut(duration: 0.12), value: closeHovered)
                }
                .padding(.top, 12)
                .padding(.trailing, 12)
            }

            if showSuccess {
                successView
            } else {
                expiredView
            }
        }
        .frame(width: 420)
        .background(DS.bgSecondary)
        .onChange(of: licenseService.status) { newStatus in
            if case .activated = newStatus {
                withAnimation(.easeOut(duration: 0.3)) {
                    showSuccess = true
                }
            }
        }
    }

    // MARK: - Expired / Purchase View

    private var expiredView: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(DS.blurple.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(DS.blurple)
                }

                Text("Verba")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DS.textNormal)
            }
            .padding(.top, canDismiss ? 8 : 32)
            .padding(.bottom, 20)

            // Usage stats summary
            if usageStats.sessions > 0 {
                VStack(spacing: 10) {
                    Text(appState.l10n.trialResults)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.textFaint)
                        .textCase(.uppercase)
                        .tracking(1)

                    HStack(spacing: 8) {
                        miniStat(icon: "bubble.left.and.bubble.right.fill", value: "\(usageStats.sessions)", label: appState.l10n.sessions)
                        miniStat(icon: "character.cursor.ibeam", value: "\(usageStats.words)", label: appState.l10n.words)
                        miniStat(icon: "clock.fill", value: usageStats.timeSaved, label: appState.l10n.timeSaved)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }

            Divider().foregroundStyle(DS.cardBorder).padding(.horizontal, 24)

            // CTA section
            VStack(spacing: 16) {
                Text(headerMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.textNormal)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)

                // Primary CTA: Purchase button
                Button {
                    if let url = URL(string: LicenseConstants.lemonSqueezyStoreURL) {
                        NSWorkspace.shared.open(url)
                    }
                    // Auto-expand key input when user returns from purchase
                    withAnimation(.easeOut(duration: 0.2)) {
                        showKeyInput = true
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(appState.l10n.buyForPrice("¥5,800"))
                            .font(.system(size: 15, weight: .bold))
                        Text(appState.l10n.opensInBrowser)
                            .font(.system(size: 10))
                            .opacity(0.7)
                    }
                    .foregroundStyle(DS.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(buyHovered ? DS.accentLight : DS.blurple)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                    .scaleEffect(buyHovered ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { buyHovered = $0 }
                .animation(.easeOut(duration: 0.12), value: buyHovered)

                // Secondary: License key input (collapsed by default)
                VStack(spacing: 10) {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showKeyInput.toggle()
                        }
                    } label: {
                        Text(appState.l10n.alreadyHaveKey)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(keyToggleHovered ? DS.textNormal : DS.textMuted)
                    }
                    .buttonStyle(.plain)
                    .onHover { keyToggleHovered = $0 }
                    .animation(.easeOut(duration: 0.12), value: keyToggleHovered)

                    if showKeyInput {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX", text: $licenseKey)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(10)
                                .background(DS.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                                .foregroundStyle(DS.textNormal)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.radiusMedium)
                                        .stroke(isValidKeyFormat ? DS.green.opacity(0.5) : Color.clear, lineWidth: 1)
                                )

                            if let error = licenseService.activationError {
                                Text(error)
                                    .font(.system(size: 11))
                                    .foregroundStyle(DS.red)
                            }

                            Button {
                                Task { await licenseService.activate(licenseKey: licenseKey) }
                            } label: {
                                HStack {
                                    if licenseService.isActivating {
                                        ProgressView()
                                            .controlSize(.small)
                                            .scaleEffect(0.8)
                                    }
                                    Text(appState.l10n.activateLicense)
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    licenseKey.isEmpty
                                        ? DS.blurple.opacity(0.4)
                                        : activateHovered ? DS.accentLight : DS.blurple
                                )
                                .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                            }
                            .buttonStyle(.plain)
                            .disabled(licenseKey.isEmpty || licenseService.isActivating)
                            .onHover { activateHovered = $0 }
                            .animation(.easeOut(duration: 0.12), value: activateHovered)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(24)

            Divider().foregroundStyle(DS.cardBorder)

            // Sponsors link
            VStack(spacing: 8) {
                Button {
                    if let url = URL(string: "https://github.com/sponsors/Sota-Mikami") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "heart")
                            .font(.system(size: 12))
                        Text(appState.l10n.sponsorOnGitHub)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(sponsorHovered ? DS.textNormal : DS.textMuted)
                }
                .buttonStyle(.plain)
                .onHover { sponsorHovered = $0 }
                .animation(.easeOut(duration: 0.12), value: sponsorHovered)

                Text(appState.l10n.supportNote)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textFaint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .padding(.vertical, 14)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Success View

    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var confettiPieces: [ConfettiPiece] = []

    private var successView: some View {
        ZStack {
            // Confetti layer
            ForEach(confettiPieces) { piece in
                ConfettiView(piece: piece)
            }

            VStack(spacing: 20) {
                Spacer()

                // Animated icon
                ZStack {
                    // Glow ring
                    Circle()
                        .fill(DS.blurple.opacity(0.1))
                        .frame(width: 96, height: 96)
                        .scaleEffect(iconScale * 1.2)
                        .opacity(iconOpacity * 0.6)

                    Circle()
                        .fill(DS.blurple.opacity(0.15))
                        .frame(width: 72, height: 72)
                        .scaleEffect(iconScale)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(DS.blurple)
                        .scaleEffect(iconScale)
                }
                .opacity(iconOpacity)

                VStack(spacing: 8) {
                    Text(appState.l10n.licenseActivatedSuccess)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(DS.textNormal)

                    Text(appState.l10n.welcomeToVerba)
                        .font(.system(size: 14))
                        .foregroundStyle(DS.textMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .opacity(textOpacity)

                Spacer()

                Button {
                    autoDismissTask?.cancel()
                    dismiss()
                } label: {
                    Text(appState.l10n.startUsingVerba)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.textOnAccent)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                        .background(startHovered ? DS.accentLight : DS.blurple)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                        .scaleEffect(startHovered ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { startHovered = $0 }
                .animation(.easeOut(duration: 0.12), value: startHovered)
                .opacity(buttonOpacity)
                .padding(.bottom, 32)
            }
        }
        .frame(height: 360)
        .clipped()
        .onAppear {
            // Staggered entrance animations
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                textOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                buttonOpacity = 1.0
            }

            // Launch confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                confettiPieces = (0..<60).map { _ in ConfettiPiece() }
            }

            // Auto-dismiss after 8s
            let task = DispatchWorkItem { dismiss() }
            autoDismissTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: task)
        }
    }

    // MARK: - Helpers

    private func miniStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(DS.blurple)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DS.textNormal)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(DS.textFaint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(DS.bgTertiary)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
    }

    private var headerMessage: String {
        if case .licenseExpired = licenseService.status {
            return appState.l10n.licenseExpiredMessage
        }
        return appState.l10n.continueUsingVerba
    }

    private var isValidKeyFormat: Bool {
        let trimmed = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 8
    }
}

// MARK: - Trial Badge (for sidebar/dashboard)

struct TrialBadge: View {
    let remaining: String
    var urgency: LicenseService.TrialUrgency = .normal

    private var badgeColor: Color {
        switch urgency {
        case .normal: return DS.orange
        case .warning24h: return DS.orange
        case .critical1h: return DS.red
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 9))
            Text(remaining)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(badgeColor.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Trial Expiry Banner

struct TrialExpiryBanner: View {
    let urgency: LicenseService.TrialUrgency
    let l10n: L10n
    let onAction: () -> Void
    let onDismiss: () -> Void

    @State private var actionHovered = false
    @State private var closeHovered = false

    private var bannerColor: Color {
        switch urgency {
        case .normal: return DS.orange
        case .warning24h: return DS.orange
        case .critical1h: return DS.red
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: urgency == .critical1h ? "exclamationmark.triangle.fill" : "clock.fill")
                .font(.system(size: 12))

            Text(urgency == .critical1h ? l10n.trialExpiresIn1h : l10n.trialExpiresIn24h)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            Spacer()

            Button(action: onAction) {
                Text(urgency == .critical1h ? l10n.buyNow : l10n.learnMore)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(bannerColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(actionHovered ? 0.25 : 0.15))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .onHover { actionHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: actionHovered)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(closeHovered ? 1.0 : 0.7))
            }
            .buttonStyle(.plain)
            .onHover { closeHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: closeHovered)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(bannerColor)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
    }
}

// MARK: - Confetti

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let x: CGFloat
    let rotation: Double
    let rotationSpeed: Double
    let size: CGFloat
    let duration: Double
    let delay: Double
    let drift: CGFloat

    init() {
        let colors: [Color] = [
            DS.blurple, DS.green, DS.orange,
            Color.pink, Color.yellow, Color.cyan,
        ]
        color = colors.randomElement()!
        x = CGFloat.random(in: 0...1)
        rotation = Double.random(in: 0...360)
        rotationSpeed = Double.random(in: 180...720)
        size = CGFloat.random(in: 4...8)
        duration = Double.random(in: 1.8...3.0)
        delay = Double.random(in: 0...0.4)
        drift = CGFloat.random(in: -40...40)
    }
}

struct ConfettiView: View {
    let piece: ConfettiPiece
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            let startX = piece.x * geo.size.width
            RoundedRectangle(cornerRadius: 1)
                .fill(piece.color)
                .frame(width: piece.size, height: piece.size * 0.6)
                .rotationEffect(.degrees(animate ? piece.rotation + piece.rotationSpeed : piece.rotation))
                .position(
                    x: startX + (animate ? piece.drift : 0),
                    y: animate ? geo.size.height + 20 : -10
                )
                .opacity(animate ? 0 : 1)
                .onAppear {
                    withAnimation(
                        .easeIn(duration: piece.duration)
                        .delay(piece.delay)
                    ) {
                        animate = true
                    }
                }
        }
        .allowsHitTesting(false)
    }
}
