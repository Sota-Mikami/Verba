import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DS.textNormal)

                generalSection
                shortcutsSection
                languageSection
                modelSection
                formattingSection
                accessibilityNote
            }
            .padding(28)
        }
        .background(DS.bgSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - General

    private var generalSection: some View {
        settingsGroup("GENERAL") {
            settingsRow(title: "Show in Dock", description: "Display the app icon in the Dock.") {
                Toggle("", isOn: $appState.showInDock)
                    .toggleStyle(.switch)
                    .tint(DS.blurple)
            }
            Divider().foregroundStyle(DS.cardBorder)
            settingsRow(title: "System audio during recording", description: systemAudioDescription) {
                Picker("", selection: $appState.systemAudioBehavior) {
                    ForEach(SystemAudioBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.rawValue).tag(behavior)
                    }
                }
                .frame(width: 180)
            }
            Divider().foregroundStyle(DS.cardBorder)
            settingsRow(title: "History retention", description: "Auto-delete old recordings and transcriptions.") {
                Picker("", selection: $appState.historyRetention) {
                    ForEach(HistoryRetention.allCases, id: \.self) { retention in
                        Text(retention.rawValue).tag(retention)
                    }
                }
                .frame(width: 140)
            }
        }
    }

    private var systemAudioDescription: String {
        switch appState.systemAudioBehavior {
        case .keepPlaying: return "Music and videos keep playing while recording."
        case .pauseMedia: return "Auto-pause media on record, resume when done."
        case .captureSystemAudio: return "Mix system audio into transcription input."
        }
    }

    // MARK: - Keyboard Shortcuts

    @State private var recordingTarget: ShortcutTarget? = nil
    @State private var recorder = ShortcutRecorder()

    private enum ShortcutTarget {
        case ptt
        case hf
    }

    private var shortcutsSection: some View {
        settingsGroup("KEYBOARD SHORTCUTS") {
            EditableShortcutRow(
                title: "Push-to-talk",
                description: pttDescription,
                shortcut: appState.pttShortcut,
                isRecording: recordingTarget == .ptt,
                onRecord: { startRecording(.ptt) },
                onReset: { appState.pttShortcut = .defaultPTT }
            )
            Divider().foregroundStyle(DS.cardBorder)
            EditableShortcutRow(
                title: "Hands-free",
                description: hfDescription,
                shortcut: appState.hfShortcut,
                isRecording: recordingTarget == .hf,
                onRecord: { startRecording(.hf) },
                onReset: { appState.hfShortcut = .defaultHF }
            )

            if appState.pttShortcut != .defaultPTT || appState.hfShortcut != .defaultHF {
                Divider().foregroundStyle(DS.cardBorder)
                HStack {
                    Spacer()
                    Button {
                        appState.pttShortcut = .defaultPTT
                        appState.hfShortcut = .defaultHF
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11))
                            Text("Reset All to Default")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(DS.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(DS.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
            }
        }
    }

    private var pttDescription: String {
        switch appState.pttShortcut.kind {
        case .modifierHold: return "Hold to record, release to stop."
        case .keyCombo: return "Hold combo to record, release to stop."
        case .doubleTap: return "Double-tap to start/stop recording."
        }
    }

    private var hfDescription: String {
        switch appState.hfShortcut.kind {
        case .modifierHold: return "Tap to toggle recording on/off."
        case .keyCombo: return "Press combo to toggle recording."
        case .doubleTap: return "Double-tap to toggle recording."
        }
    }

    private func startRecording(_ target: ShortcutTarget) {
        recordingTarget = target
        appState.hotkeyController.isEnabled = false
        recorder.stop()
        recorder.onCapture = { [self] shortcut in
            switch target {
            case .ptt: appState.pttShortcut = shortcut
            case .hf: appState.hfShortcut = shortcut
            }
            recordingTarget = nil
            appState.hotkeyController.isEnabled = true
        }
        recorder.start()
    }

    // MARK: - Language

    private var languageSection: some View {
        settingsGroup("LANGUAGE") {
            settingsRow(title: "Speech language", description: "Language of your speech input.") {
                Picker("", selection: $appState.selectedLanguage) {
                    ForEach(appState.availableLanguages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                .frame(width: 160)
            }
        }
    }

    // MARK: - Model

    private var modelSection: some View {
        settingsGroup("TRANSCRIPTION") {
            settingsRow(title: "Whisper model", description: appState.isModelLoaded ? "Loaded and ready" : "Downloading...") {
                Circle()
                    .fill(appState.isModelLoaded ? DS.green : DS.orange)
                    .frame(width: 10, height: 10)
            }
            Divider().foregroundStyle(DS.cardBorder)
            settingsRow(title: "Output mode", description: "Fast: raw output. Formatted: AI-cleaned text.") {
                Picker("", selection: $appState.mode) {
                    ForEach(TranscriptionMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .frame(width: 140)
            }
        }
    }

    // MARK: - Formatting Engine

    private var formattingSection: some View {
        settingsGroup("FORMATTING ENGINE") {
            // Provider selector
            settingsRow(title: "Provider", description: "Choose how text formatting is processed.") {
                Picker("", selection: $appState.formattingProvider) {
                    ForEach(FormattingProvider.allCases, id: \.self) { provider in
                        HStack {
                            Text(provider.rawValue)
                            if !provider.isAvailable {
                                Text("(soon)")
                                    .foregroundStyle(DS.textFaint)
                            }
                        }
                        .tag(provider)
                    }
                }
                .frame(width: 180)
            }

            if appState.formattingProvider.isAvailable {
                Divider().foregroundStyle(DS.cardBorder)

                // Provider-specific settings
                VStack(alignment: .leading, spacing: 14) {
                    // API Key
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.textMuted)
                        SecureField(appState.formattingProvider.apiKeyPlaceholder, text: currentApiKeyBinding)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(8)
                            .background(DS.inputBg)
                            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                            .foregroundStyle(DS.textNormal)
                    }

                    // Custom endpoint (only for Custom provider)
                    if appState.formattingProvider == .custom {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Endpoint URL")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(DS.textMuted)
                            TextField("https://api.example.com/v1", text: $appState.customEndpoint)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(8)
                                .background(DS.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                                .foregroundStyle(DS.textNormal)
                            Text("Must be OpenAI-compatible (/chat/completions)")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.textFaint)
                        }
                    }

                    // Model selector
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Model")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.textMuted)

                        let models = appState.formattingProvider.suggestedModels
                        if !models.isEmpty {
                            VStack(spacing: 2) {
                                ForEach(models) { model in
                                    ModelRow(
                                        model: model,
                                        isSelected: currentModelBinding.wrappedValue == model.id
                                    ) {
                                        currentModelBinding.wrappedValue = model.id
                                    }
                                }
                            }
                            .background(DS.inputBg)
                            .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                        }

                        // Custom model input
                        HStack(spacing: 8) {
                            TextField("Or enter model ID...", text: currentModelBinding)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(8)
                                .background(DS.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                                .foregroundStyle(DS.textNormal)
                        }
                    }
                }
                .padding(16)
            } else {
                // Local LLM placeholder
                VStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .font(.system(size: 24))
                        .foregroundStyle(DS.textFaint)
                    Text("Local LLM support coming soon")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.textMuted)
                    Text("Run formatting models locally on your Mac using MLX. No API key needed.")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.textFaint)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            }
        }
    }

    private var currentApiKeyBinding: Binding<String> {
        switch appState.formattingProvider {
        case .openRouter: return $appState.openRouterApiKey
        case .openAI: return $appState.openAIApiKey
        case .custom: return $appState.customApiKey
        case .local: return .constant("")
        }
    }

    private var currentModelBinding: Binding<String> {
        switch appState.formattingProvider {
        case .openRouter: return $appState.openRouterModel
        case .openAI: return $appState.openAIModel
        case .custom: return $appState.customModel
        case .local: return .constant("")
        }
    }

    // MARK: - Accessibility note

    @ViewBuilder
    private var accessibilityNote: some View {
        if appState.pttShortcut.modifierKeyCode == 63 || appState.hfShortcut.modifierKeyCode == 63 {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.yellow)
                    .font(.system(size: 13))
                Text("Set System Settings → Keyboard → \"Press 🌐 key to\" → **Do Nothing** for best results.")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.textMuted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.yellow.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
        }
    }

    // MARK: - Helpers

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DS.textMuted)
            VStack(spacing: 0) {
                content()
            }
            .background(DS.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
        }
    }

    private func settingsRow<Trailing: View>(title: String, description: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.textNormal)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.textFaint)
            }
            Spacer()
            trailing()
        }
        .padding(16)
    }
}

// MARK: - Model Row

struct ModelRow: View {
    let model: ModelOption
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? DS.blurple : .clear)
                        .frame(width: 16, height: 16)
                    Circle()
                        .strokeBorder(isSelected ? DS.blurple : DS.textFaint.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    if isSelected {
                        Circle()
                            .fill(.white)
                            .frame(width: 6, height: 6)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(model.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.textNormal)
                        Badge(text: model.speed.rawValue, color: model.speed == .fast ? DS.green : DS.textMuted)
                    }
                    Text(model.id)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DS.textFaint)
                }

                Spacer()

                Text(model.description)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textFaint)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? DS.blurple.opacity(0.08) : isHovered ? DS.bgModifierHover : .clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}

// MARK: - Editable Shortcut Row

struct EditableShortcutRow: View {
    let title: String
    let description: String
    let shortcut: KeyShortcut
    let isRecording: Bool
    let onRecord: () -> Void
    let onReset: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DS.textNormal)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.textFaint)
            }
            Spacer()

            Button(action: onRecord) {
                if isRecording {
                    HStack(spacing: 6) {
                        Circle().fill(DS.red).frame(width: 6, height: 6)
                        Text("Press shortcut...")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(DS.textNormal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DS.blurple.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.radiusSmall)
                            .stroke(DS.blurple, lineWidth: 1.5)
                    )
                } else {
                    Text(shortcut.label)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DS.textNormal)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isHovered ? DS.bgModifierActive : DS.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.radiusSmall)
                                .stroke(DS.cardBorder, lineWidth: 1)
                        )
                }
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.15), value: isRecording)
        }
        .padding(16)
    }
}

// MARK: - Key Badge

struct KeyBadge: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(DS.textNormal)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(DS.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: DS.radiusSmall)
                    .stroke(DS.cardBorder, lineWidth: 1)
            )
    }
}
