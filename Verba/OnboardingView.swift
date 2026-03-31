import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var micGranted = false
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var accessibilityTimer: Timer?
    @State private var trialRecorded = false
    @State private var trialInputText = ""
    @State private var historyCountBeforeTrial = 0
    @State private var trialAccuracy: Int?
    @State private var selectedWhisperModel: String = "openai_whisper-large-v3-turbo"
    @FocusState private var trialFieldFocused: Bool

    private let totalSteps = 8 // 0: value prop, 1-4: permissions/model/shortcut, 5: PTT trial, 6: HF trial, 7: completion

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: language toggle
            HStack {
                Spacer()
                languageToggle
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)

            // Progress dots (skip step 0 and last step from dots for cleaner look)
            if currentStep > 0 && currentStep < totalSteps - 1 {
                HStack(spacing: 8) {
                    ForEach(1..<(totalSteps - 1), id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? DS.blurple : DS.textFaint.opacity(0.4))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentStep ? 1.05 : 1.0)
                            .animation(.easeOut(duration: 0.25), value: currentStep)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }

            // Step content
            VStack(spacing: 24) {
                stepContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.3), value: currentStep)
        }
        .frame(width: 520, height: 540)
        .background(DS.bgSecondary)
        .onAppear {
            checkMicPermission()
            startAccessibilityPolling()
        }
        .onDisappear {
            accessibilityTimer?.invalidate()
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            // Step 0: Value Proposition
            valuePropStep
        case 1:
            // Step 1: Microphone permission
            stepCard(
                icon: "mic.fill",
                title: appState.l10n.onboardingMicTitle,
                description: appState.l10n.onboardingMicDesc,
                reason: appState.l10n.onboardingMicReason
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
        case 2:
            // Step 2: Accessibility permission
            stepCard(
                icon: "hand.raised.fill",
                title: appState.l10n.onboardingAccessibilityTitle,
                description: appState.l10n.onboardingAccessibilityDesc,
                reason: appState.l10n.onboardingAccessibilityReason
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
        case 3:
            // Step 3: Model selection + download
            stepCard(
                icon: "arrow.down.circle.fill",
                title: appState.l10n.onboardingModelTitle,
                description: needsLocalLLM ? appState.l10n.onboardingModelDescBoth : appState.l10n.onboardingModelDesc
            ) {
                VStack(spacing: 12) {
                    if bothModelsDownloaded {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(DS.green)
                            Text(appState.l10n.modelsReady)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(DS.green)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else if appState.isInitializing {
                        // Download/load in progress
                        VStack(spacing: 12) {
                            modelProgressRow(
                                label: appState.l10n.whisperModelLabel,
                                isComplete: appState.isModelLoaded,
                                progress: nil
                            )
                            if needsLocalLLM {
                                modelProgressRow(
                                    label: appState.l10n.formattingModelLabel,
                                    isComplete: llmDownloaded,
                                    progress: llmDownloadProgress
                                )
                            }
                        }
                    } else if let error = appState.initError {
                        // Error state with retry
                        VStack(spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(DS.warm)
                                Text(errorMessage(for: error))
                                    .font(.system(size: 12))
                                    .foregroundStyle(DS.textMuted)
                                    .multilineTextAlignment(.center)
                            }

                            HStack(spacing: 12) {
                                Button {
                                    Task { await retryModelInit() }
                                } label: {
                                    Text(appState.l10n.retry)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(DS.textLink)
                                }
                                .buttonStyle(.plain)

                                Text("·")
                                    .foregroundStyle(DS.textFaint)

                                Button {
                                    // Cycle to a simpler model
                                    selectFallbackModel()
                                    Task { await retryModelInit() }
                                } label: {
                                    Text(appState.l10n.changeModel)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(DS.textLink)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        // Model picker (before download starts)
                        VStack(spacing: 8) {
                            ForEach(onboardingModelOptions) { option in
                                modelOptionRow(option)
                            }
                        }

                        HoverAccentButton(label: appState.l10n.onboardingDownloadBtn) {
                            appState.whisperModel = selectedWhisperModel
                            Task { await appState.initializeServices() }
                            startLLMDownloadIfNeeded()
                        }
                        .padding(.top, 4)
                    }
                }
            } footer: {
                nextButton(enabled: bothModelsDownloaded) {
                    // When advancing from Step 3, start loading LLM into memory
                    Task { await appState.loadLLMForOnboarding() }
                }
            }
        case 4:
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

                    Text(appState.l10n.onboardingShortcutsNote)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.textFaint)
                }
            } footer: {
                nextButton(enabled: true)
            }
        case 5:
            // Step 5: PTT trial
            trialStep(
                title: appState.l10n.trialPttTitle,
                sampleText: appState.l10n.trialPttSample,
                shortcutLabel: appState.pttShortcut.label,
                shortcutHintText: appState.l10n.holdToRecordHint
            )
        case 6:
            // Step 6: HF trial
            trialStep(
                title: appState.l10n.trialHfTitle,
                sampleText: appState.l10n.trialHfSample,
                shortcutLabel: appState.hfShortcut.label,
                shortcutHintText: appState.l10n.doubleTapToToggleHint
            )
        case 7:
            // Step 7: Completion with trial info
            completionStep
        default:
            EmptyView()
        }
    }

    // MARK: - Step 0: Value Proposition

    private var valuePropStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Icon pair
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(DS.warm.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(DS.warm)
                    }
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.textFaint)
                    ZStack {
                        Circle()
                            .fill(DS.blurple.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "doc.text")
                            .font(.system(size: 18))
                            .foregroundStyle(DS.blurple)
                    }
                }

                // Title
                Text(appState.l10n.onboardingValueTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DS.textNormal)
                    .multilineTextAlignment(.center)

                // Features
                VStack(alignment: .leading, spacing: 10) {
                    featureRow(icon: "lock.shield", text: appState.l10n.onboardingValueFeature1)
                    featureRow(icon: "doc.on.clipboard", text: appState.l10n.onboardingValueFeature2)
                    featureRow(icon: "clock", text: appState.l10n.onboardingValueFeature3)
                }
                .padding(.horizontal, 20)
            }
            .padding(24)
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

            HoverAccentButton(label: appState.l10n.onboardingGetStartedBtn, horizontalPadding: 36, verticalPadding: 12, fontSize: 15) {
                withAnimation { currentStep += 1 }
            }
            .padding(.bottom, 24)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(DS.green)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(DS.textMuted)
        }
    }

    // MARK: - Trial Step (Interactive via real shortcut)

    private func trialStep(title: String, sampleText: String, shortcutLabel: String, shortcutHintText: String) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                // Title
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DS.textNormal)

                // Sample text with left accent bar (blockquote style)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.textFaint)
                        Text(appState.l10n.trySampleLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DS.textFaint)
                    }

                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(DS.blurple)
                            .frame(width: 3)

                        Text(sampleText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DS.textNormal)
                            .lineSpacing(3)
                            .padding(.leading, 12)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Real text input area - text gets pasted here via normal flow
                ZStack(alignment: .topLeading) {
                    if trialInputText.isEmpty && !trialFieldFocused {
                        Text(appState.l10n.tryInputPlaceholder)
                            .font(.system(size: 13))
                            .foregroundStyle(DS.textFaint)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                    }

                    TextEditor(text: $trialInputText)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.textNormal)
                        .scrollContentBackground(.hidden)
                        .focused($trialFieldFocused)
                }
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(DS.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.radiusMedium)
                        .stroke(trialFieldFocused ? DS.blurple.opacity(0.5) : trialRecorded ? DS.green.opacity(0.5) : DS.cardBorder, lineWidth: 1)
                )
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        trialFieldFocused = true
                    }
                }

                // Bottom: accuracy result or shortcut hint
                if trialRecorded, let accuracy = trialAccuracy {
                    HStack(spacing: 12) {
                        // Accuracy badge
                        HStack(spacing: 4) {
                            Text("\(accuracy)%")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(accuracy >= 80 ? DS.green : DS.warm)
                            Text(appState.l10n.trialAccuracy)
                                .font(.system(size: 12))
                                .foregroundStyle(DS.textFaint)
                        }

                        Spacer()

                        Button {
                            trialRecorded = false
                            trialInputText = ""
                            trialAccuracy = nil
                            historyCountBeforeTrial = appState.history.count
                            trialFieldFocused = true
                        } label: {
                            Text(appState.l10n.tryAgain)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(DS.textLink)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    shortcutHint(key: shortcutLabel, label: shortcutHintText)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusLarge)
                    .fill(DS.cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.radiusLarge)
                            .stroke(DS.cardBorder, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 40)
            .onAppear {
                // Reset state for this trial phase
                trialRecorded = false
                trialInputText = ""
                trialAccuracy = nil
                historyCountBeforeTrial = appState.history.count
                appState.isOnboardingTrial = true
            }
            .onChange(of: trialInputText) { newValue in
                // Text was pasted into the field via normal Verba flow
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && !trialRecorded {
                    let accuracy = Self.textSimilarity(expected: sampleText, actual: trimmed)
                    withAnimation {
                        trialAccuracy = accuracy
                        trialRecorded = true
                    }
                }
            }

            Spacer()

            // Next button
            HoverAccentButton(label: appState.l10n.onboardingNext) {
                withAnimation { currentStep += 1 }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Text Similarity

    /// Word-level similarity between expected sample text and actual transcription (0–100)
    private static func textSimilarity(expected: String, actual: String) -> Int {
        let normalize: (String) -> [String] = { text in
            text.lowercased()
                .replacingOccurrences(of: "[。、！？.,!?\"'\\-—:;()（）「」]", with: " ", options: .regularExpression)
                .split(separator: " ")
                .map(String.init)
                .filter { !$0.isEmpty }
        }
        let expectedWords = normalize(expected)
        let actualWords = normalize(actual)
        guard !expectedWords.isEmpty else { return 0 }

        // Longest Common Subsequence for word-level similarity
        let m = expectedWords.count
        let n = actualWords.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                if expectedWords[i - 1] == actualWords[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }
        let lcs = dp[m][n]
        let score = Double(lcs) / Double(m) * 100
        return min(Int(score.rounded()), 100)
    }

    // MARK: - Step 6: Completion with Trial Info

    private var completionStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(DS.green.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(DS.green)
                }

                Text(appState.l10n.allSetup)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DS.textNormal)

                VStack(spacing: 6) {
                    Text(appState.l10n.onboardingTrialStarted)
                        .font(.system(size: 14))
                        .foregroundStyle(DS.textNormal)
                    Text(appState.l10n.onboardingTrialExplore)
                        .font(.system(size: 14))
                        .foregroundStyle(DS.textMuted)
                }
                .multilineTextAlignment(.center)
            }
            .padding(24)
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

            VStack(spacing: 8) {
                HoverAccentButton(label: appState.l10n.startUsingVerba, horizontalPadding: 36, verticalPadding: 12, fontSize: 15) {
                    appState.isOnboardingTrial = false
                    appState.hasCompletedOnboarding = true
                }

                VStack(spacing: 2) {
                    Text(appState.l10n.onboardingPriceInfo)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.textMuted)

                    HoverTextLink(label: appState.l10n.onboardingPriceDetail) {
                        if let url = URL(string: LicenseConstants.lemonSqueezyStoreURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Shortcut Hint (for trial step)

    private func shortcutHint(key: String, label: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.textNormal)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(DS.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.radiusSmall)
                        .stroke(DS.cardBorder, lineWidth: 1)
                )

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(DS.textFaint)
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
        reason: String? = nil,
        @ViewBuilder action: () -> Action,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(DS.blurple.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(DS.blurple)
                }

                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DS.textNormal)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 340)
                    .fixedSize(horizontal: false, vertical: true)

                // "Why is this needed?" explanation
                if let reason {
                    Text(reason)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.textFaint)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .frame(maxWidth: 320)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(DS.bgTertiary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                }

                action()
                    .padding(.top, 4)
            }
            .padding(24)
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
                .padding(.bottom, 24)
        }
    }

    // MARK: - Components

    private var languageToggle: some View {
        Button {
            let next: String = appState.uiLanguage == "en" ? "ja" : "en"
            appState.uiLanguage = next
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 11))
                Text(appState.uiLanguage == "en" ? "日本語" : "English")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(DS.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(DS.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
        }
        .buttonStyle(.plain)
    }

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
        HoverAccentButton(label: label, action: action)
    }

    private func nextButton(enabled: Bool, extraAction: (() -> Void)? = nil) -> some View {
        HoverAccentButton(label: appState.l10n.onboardingNext, enabled: enabled) {
            extraAction?()
            withAnimation { currentStep += 1 }
        }
    }

    // MARK: - Model Download Helpers

    private var llmDownloaded: Bool {
        switch appState.localLLMService.modelState {
        case .downloaded, .loading, .ready: return true
        default: return false
        }
    }

    private var llmDownloadProgress: Double? {
        switch appState.localLLMService.modelState {
        case .downloading(let progress): return progress
        default: return nil
        }
    }

    private var needsLocalLLM: Bool {
        appState.formattingProvider == .local
    }

    private var bothModelsDownloaded: Bool {
        if needsLocalLLM {
            return appState.isModelLoaded && llmDownloaded
        } else {
            return appState.isModelLoaded
        }
    }

    private func startLLMDownloadIfNeeded() {
        guard appState.formattingProvider == .local else { return }
        appState.localLLMService.checkModelStatus(modelId: appState.localModel)
        if appState.localLLMService.modelState == .notDownloaded {
            Task { await appState.localLLMService.downloadOnly(modelId: appState.localModel) }
        }
    }

    private func modelProgressRow(label: String, isComplete: Bool, progress: Double?) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.textMuted)
                .frame(width: 90, alignment: .trailing)

            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DS.green)
                Spacer()
            } else {
                ProgressView(value: progress ?? 0)
                    .tint(DS.blurple)
                    .frame(maxWidth: .infinity)

                if let progress {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DS.textFaint)
                        .frame(width: 36, alignment: .trailing)
                } else {
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: 36)
                }
            }
        }
    }

    // MARK: - Model Selection Helpers

    /// Models shown during onboarding (excludes "auto" — user picks explicitly)
    private var onboardingModelOptions: [WhisperModelOption] {
        WhisperModelOption.recommended.filter { $0.id != "auto" }
    }

    private func modelOptionRow(_ option: WhisperModelOption) -> some View {
        let isSelected = selectedWhisperModel == option.id
        return Button {
            selectedWhisperModel = option.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.name)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(DS.textNormal)
                    Text("\(option.description) · \(option.sizeLabel)")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.textFaint)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DS.blurple)
                } else {
                    Circle()
                        .stroke(DS.textFaint.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? DS.blurple.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
        }
        .buttonStyle(.plain)
    }

    private func errorMessage(for error: WhisperInitError) -> String {
        switch error {
        case .timedOut:
            return appState.l10n.modelLoadTimedOut
        case .failed(let msg):
            return "\(appState.l10n.modelLoadFailed): \(msg.prefix(60))"
        }
    }

    private func retryModelInit() async {
        appState.whisperModel = selectedWhisperModel
        await appState.initializeServices()
        startLLMDownloadIfNeeded()
    }

    /// Select a simpler model when current one fails
    private func selectFallbackModel() {
        let fallbackOrder = ["openai_whisper-small", "openai_whisper-base", "openai_whisper-tiny"]
        for modelId in fallbackOrder {
            if modelId != selectedWhisperModel {
                selectedWhisperModel = modelId
                return
            }
        }
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
