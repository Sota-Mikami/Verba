import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentStep = 0
    @State private var micGranted = false
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var accessibilityTimer: Timer?

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? DS.blurple : DS.textFaint.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentStep ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                }
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            // Step content
            VStack(spacing: 24) {
                stepContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.3), value: currentStep)
        }
        .frame(width: 480, height: 420)
        .background(DS.bgSecondary)
        .onAppear {
            checkMicPermission()
            startAccessibilityPolling()
        }
        .onDisappear {
            accessibilityTimer?.invalidate()
        }
        .onChange(of: appState.isModelLoaded) { _, loaded in
            // Auto-advance is optional; user can still click Get Started
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            stepCard(
                icon: "mic.fill",
                title: appState.l10n.onboardingMicTitle,
                description: appState.l10n.onboardingMicDesc
            ) {
                if micGranted {
                    grantedBadge
                } else {
                    actionButton(appState.l10n.onboardingGrantAccess) {
                        requestMicPermission()
                    }
                }
            } footer: {
                nextButton(enabled: micGranted)
            }
        case 1:
            stepCard(
                icon: "hand.raised.fill",
                title: appState.l10n.onboardingAccessibilityTitle,
                description: appState.l10n.onboardingAccessibilityDesc
            ) {
                if accessibilityGranted {
                    grantedBadge
                } else {
                    actionButton(appState.l10n.onboardingOpenSettings) {
                        openAccessibilitySettings()
                    }
                }
            } footer: {
                nextButton(enabled: accessibilityGranted)
            }
        case 2:
            stepCard(
                icon: "arrow.down.circle.fill",
                title: appState.l10n.onboardingModelTitle,
                description: appState.l10n.onboardingModelDesc
            ) {
                VStack(spacing: 12) {
                    if appState.isModelLoaded {
                        grantedBadge
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .tint(DS.blurple)
                        Text(appState.statusMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.textMuted)
                    }
                }
            } footer: {
                getStartedButton
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Reusable Step Card

    private func stepCard<Action: View, Footer: View>(
        icon: String,
        title: String,
        description: String,
        @ViewBuilder action: () -> Action,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(DS.blurple.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(DS.blurple)
                }

                // Title
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DS.textNormal)

                // Description
                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 320)

                // Action area
                action()
                    .padding(.top, 4)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusLarge)
                    .fill(DS.cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.radiusLarge)
                            .stroke(DS.cardBorder, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 40)

            Spacer()

            // Footer (Next / Get Started)
            footer()
                .padding(.bottom, 32)
        }
    }

    // MARK: - Components

    private var grantedBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(DS.green)
            Text(appState.l10n.onboardingGranted)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.green)
        }
        .transition(.scale.combined(with: .opacity))
    }

    private func actionButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(DS.blurple)
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
        }
        .buttonStyle(.plain)
    }

    private func nextButton(enabled: Bool) -> some View {
        Button {
            withAnimation { currentStep += 1 }
        } label: {
            Text(appState.l10n.onboardingNext)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(enabled ? .white : DS.textFaint)
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
                .background(enabled ? DS.blurple : DS.bgModifierActive)
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var getStartedButton: some View {
        Button {
            hasCompletedOnboarding = true
        } label: {
            Text(appState.l10n.onboardingGetStarted)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
                .background(appState.isModelLoaded ? DS.blurple : DS.blurple.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
        }
        .buttonStyle(.plain)
        .disabled(!appState.isModelLoaded)
    }

    // MARK: - Permissions

    private func checkMicPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            micGranted = true
        default:
            micGranted = false
        }
    }

    private func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                withAnimation { micGranted = granted }
            }
        }
    }

    private func openAccessibilitySettings() {
        // Prompt the system dialog
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func startAccessibilityPolling() {
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let trusted = AXIsProcessTrusted()
            if trusted != accessibilityGranted {
                DispatchQueue.main.async {
                    withAnimation { accessibilityGranted = trusted }
                }
            }
        }
    }
}
