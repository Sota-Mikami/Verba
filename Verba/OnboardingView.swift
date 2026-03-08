import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentStep = 0
    @State private var micGranted = false
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var accessibilityTimer: Timer?
    @State private var trialRecorded = false
    @State private var trialText = ""
    @State private var isTrialRecording = false
    @State private var trialTimer: Timer?
    @State private var trialElapsed: TimeInterval = 0

    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? DS.blurple : DS.textFaint.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentStep ? 1.05 : 1.0)
                        .animation(.easeOut(duration: 0.25), value: currentStep)
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
        .frame(width: 520, height: 480)
        .background(DS.bgSecondary)
        .onAppear {
            checkMicPermission()
            startAccessibilityPolling()
        }
        .onDisappear {
            accessibilityTimer?.invalidate()
            trialTimer?.invalidate()
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            // Step 1: Microphone permission
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
            // Step 2: Accessibility permission
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
            // Step 3: Whisper model download
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
                nextButton(enabled: appState.isModelLoaded)
            }
        case 3:
            // Step 4: Shortcut confirmation
            stepCard(
                icon: "keyboard.fill",
                title: appState.l10n.onboardingShortcutsTitle,
                description: appState.l10n.onboardingShortcutsDesc
            ) {
                VStack(spacing: 12) {
                    shortcutRow(
                        label: appState.l10n.pushToTalk,
                        shortcut: appState.pttShortcut.label,
                        hint: appState.l10n.holdToRecordHint
                    )
                    shortcutRow(
                        label: appState.l10n.handsFree,
                        shortcut: appState.hfShortcut.label,
                        hint: appState.l10n.doubleTapToToggleHint
                    )
                }
            } footer: {
                nextButton(enabled: true)
            }
        case 4:
            // Step 5: Try it out
            trialStep
        default:
            EmptyView()
        }
    }

    // MARK: - Trial Step (Interactive)

    private var trialStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(trialRecorded ? DS.green.opacity(0.15) : DS.warm.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: trialRecorded ? "checkmark" : "waveform")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(trialRecorded ? DS.green : DS.warm)
                }

                Text(trialRecorded ? appState.l10n.itWorks : appState.l10n.tryItOut)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DS.textNormal)

                Text(trialRecorded
                     ? appState.l10n.itWorksDesc
                     : appState.l10n.tryItOutDesc)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 320)

                // Trial area
                if trialRecorded {
                    // Show transcription result
                    VStack(spacing: 8) {
                        Text(trialText)
                            .font(.system(size: 14))
                            .foregroundStyle(DS.textNormal)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DS.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))

                        Button {
                            trialRecorded = false
                            trialText = ""
                        } label: {
                            Text(appState.l10n.tryAgain)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(DS.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                } else if isTrialRecording {
                    // Recording state
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(DS.warm)
                                .frame(width: 10, height: 10)
                            Text(String(format: "%d:%02d", Int(trialElapsed) / 60, Int(trialElapsed) % 60))
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(DS.textNormal)
                        }

                        Button {
                            stopTrialRecording()
                        } label: {
                            Text(appState.l10n.stopRecording)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DS.textOnAccent)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(DS.warm)
                                .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // Start button
                    Button {
                        startTrialRecording()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14))
                            Text(appState.l10n.startRecording)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(DS.textOnAccent)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(DS.blurple)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                    }
                    .buttonStyle(.plain)
                }
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

            // Get Started button
            Button {
                hasCompletedOnboarding = true
            } label: {
                Text(appState.l10n.onboardingGetStarted)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.textOnAccent)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(DS.blurple)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Shortcut Row

    private func shortcutRow(label: String, shortcut: String, hint: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.textNormal)
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textFaint)
            }
            Spacer()
            Text(shortcut)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(DS.textNormal)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(DS.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
        }
        .padding(12)
        .background(DS.bgTertiary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
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
                ZStack {
                    Circle()
                        .fill(DS.blurple.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(DS.blurple)
                }

                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DS.textNormal)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 320)

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
                .foregroundStyle(DS.textOnAccent)
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
                .foregroundStyle(enabled ? DS.textOnAccent : DS.textFaint)
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
                .background(enabled ? DS.blurple : DS.bgModifierActive)
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Trial Recording

    private func startTrialRecording() {
        guard appState.isModelLoaded else { return }
        do {
            let recorder = AudioRecorder()
            recorder.selectedDeviceUID = appState.selectedMicDeviceUID
            try recorder.startRecording()
            isTrialRecording = true
            trialElapsed = 0
            // Store recorder temporarily
            trialRecorderRef = recorder
            trialTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                DispatchQueue.main.async {
                    trialElapsed += 0.1
                }
            }
        } catch {
            // Silently fail — permissions should already be granted
        }
    }

    private func stopTrialRecording() {
        trialTimer?.invalidate()
        trialTimer = nil
        isTrialRecording = false

        guard let recorder = trialRecorderRef else { return }
        let audioData = recorder.stopRecording()
        trialRecorderRef = nil

        Task {
            do {
                let text = try await appState.transcribeAudio(audioData)
                await MainActor.run {
                    withAnimation {
                        trialText = text.isEmpty ? appState.l10n.noSpeechDetectedShort : text
                        trialRecorded = true
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        trialText = appState.l10n.transcriptionFailedShort
                        trialRecorded = true
                    }
                }
            }
        }
    }

    @State private var trialRecorderRef: AudioRecorder?

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
