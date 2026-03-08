import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var engineExpanded = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                Text(appState.l10n.settings)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DS.textNormal)

                // Tier 1: General settings
                uiLanguageSection
                appearanceSection
                generalSection
                shortcutsSection

                // Tier 2: Voice Engine (collapsed by default)
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            engineExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(DS.textMuted)
                                .rotationEffect(.degrees(engineExpanded ? 90 : 0))
                            Text(appState.l10n.voiceEngine)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DS.textMuted)
                            Spacer()
                            Text(engineSummary)
                                .font(.system(size: 11))
                                .foregroundStyle(DS.textFaint)
                        }
                    }
                    .buttonStyle(.plain)

                    if engineExpanded {
                        modelSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        promptSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        formattingSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(28)
        }
        .background(DS.bgSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { availableMics = AudioRecorder.availableInputDevices() }
    }

    private var engineSummary: String {
        let provider = appState.formattingProvider
        let model = appState.currentModel
        let shortModel = model.components(separatedBy: "/").last ?? model
        return "\(provider.rawValue) · \(shortModel)"
    }

    // MARK: - General

    // MARK: - UI Language

    private var uiLanguageSection: some View {
        settingsGroup(appState.l10n.uiLanguage) {
            settingsRow(title: appState.l10n.uiLanguage, description: appState.l10n.uiLanguageDesc) {
                Picker("", selection: $appState.uiLanguage) {
                    ForEach(UILanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .frame(width: 180)
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        settingsGroup(appState.l10n.appearance) {
            settingsRow(title: appState.l10n.theme, description: appState.l10n.appearanceDesc) {
                Picker("", selection: $appState.appearance) {
                    ForEach(AppAppearance.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .frame(width: 140)
            }
        }
    }

    @State private var availableMics: [MicDevice] = []

    private var generalSection: some View {
        settingsGroup(appState.l10n.general) {
            settingsRow(title: appState.l10n.launchAtLogin, description: appState.l10n.launchAtLoginDesc) {
                Toggle("", isOn: Binding(
                    get: { appState.launchAtLogin },
                    set: { appState.setLaunchAtLogin($0) }
                ))
                    .toggleStyle(.switch)
                    .tint(DS.blurple)
            }
            Divider().foregroundStyle(DS.cardBorder)
            settingsRow(title: appState.l10n.showInDock, description: appState.l10n.showInDockDesc) {
                Toggle("", isOn: $appState.showInDock)
                    .toggleStyle(.switch)
                    .tint(DS.blurple)
            }
            Divider().foregroundStyle(DS.cardBorder)
            settingsRow(title: appState.l10n.microphone, description: appState.l10n.microphoneDesc) {
                Picker("", selection: $appState.selectedMicDeviceUID) {
                    Text(appState.l10n.systemDefault).tag("")
                    ForEach(availableMics) { mic in
                        Text(mic.name).tag(mic.uid)
                    }
                }
                .frame(width: 200)
            }
            Divider().foregroundStyle(DS.cardBorder)
            settingsRow(title: appState.l10n.systemAudioDuringRecording, description: systemAudioDescription) {
                Picker("", selection: $appState.systemAudioBehavior) {
                    ForEach(SystemAudioBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.rawValue).tag(behavior)
                    }
                }
                .frame(width: 180)
            }
            Divider().foregroundStyle(DS.cardBorder)
            settingsRow(title: appState.l10n.historyRetention, description: appState.l10n.historyRetentionDesc) {
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
        settingsGroup(appState.l10n.keyboardShortcuts) {
            EditableShortcutRow(
                title: appState.l10n.pushToTalk,
                description: pttDescription,
                shortcut: appState.pttShortcut,
                isRecording: recordingTarget == .ptt,
                onRecord: { startRecording(.ptt) },
                onReset: { appState.pttShortcut = .defaultPTT }
            )
            Divider().foregroundStyle(DS.cardBorder)
            EditableShortcutRow(
                title: appState.l10n.handsFree,
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
                    SettingsActionButton(
                        label: appState.l10n.resetAllToDefault,
                        icon: "arrow.counterclockwise",
                        style: .secondary
                    ) {
                        appState.pttShortcut = .defaultPTT
                        appState.hfShortcut = .defaultHF
                    }
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

    // MARK: - Model

    @State private var pendingWhisperModel: String? = nil

    private var modelSection: some View {
        settingsGroup(appState.l10n.transcription) {
            settingsRow(title: appState.l10n.whisperModel, description: appState.isModelLoaded ? appState.l10n.loadedAndReady : appState.l10n.downloading) {
                Circle()
                    .fill(appState.isModelLoaded ? DS.green : DS.orange)
                    .frame(width: 10, height: 10)
            }
            Divider().foregroundStyle(DS.cardBorder)

            // Whisper model picker
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.l10n.whisperModelDesc)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textFaint)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                VStack(spacing: 2) {
                    ForEach(WhisperModelOption.recommended) { option in
                        WhisperModelRow(
                            option: option,
                            isSelected: appState.whisperModel == option.id,
                            onSelect: {
                                if appState.whisperModel != option.id {
                                    appState.whisperModel = option.id
                                    pendingWhisperModel = option.id
                                }
                            }
                        )
                    }
                }
                .padding(4)

                if pendingWhisperModel != nil {
                    HStack(spacing: 8) {
                        Text(appState.l10n.restartRequired)
                            .font(.system(size: 11))
                            .foregroundStyle(DS.textFaint)
                        Spacer()
                        SettingsActionButton(
                            label: appState.l10n.reloadModel,
                            style: .primary
                        ) {
                            pendingWhisperModel = nil
                            Task {
                                await appState.reloadWhisperModel()
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }
            }

            Divider().foregroundStyle(DS.cardBorder)
            settingsRow(title: appState.l10n.outputMode, description: appState.l10n.outputModeDesc) {
                Picker("", selection: $appState.mode) {
                    ForEach(TranscriptionMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .frame(width: 140)
            }
        }
    }

    // MARK: - Formatting Prompts

    @State private var editingPrompt: FormattingPrompt? = nil
    @State private var isCreatingPrompt = false

    private var promptSection: some View {
        settingsGroup(appState.l10n.formattingPrompt) {
            // Prompt selector
            VStack(spacing: 2) {
                ForEach(appState.allPrompts) { prompt in
                    PromptRow(
                        prompt: prompt,
                        isSelected: appState.selectedPromptId == prompt.id.uuidString,
                        isModified: prompt.isBuiltIn && appState.isBuiltInModified(prompt),
                        onSelect: { appState.selectedPromptId = prompt.id.uuidString },
                        onEdit: { editingPrompt = prompt },
                        onDelete: prompt.isBuiltIn ? nil : { appState.deletePrompt(prompt) },
                        onReset: prompt.isBuiltIn && appState.isBuiltInModified(prompt) ? { appState.resetBuiltInPrompt(prompt) } : nil
                    )
                }
            }
            .padding(4)

            Divider().foregroundStyle(DS.cardBorder)

            // Add new prompt button
            SettingsActionButton(
                label: appState.l10n.addCustomPrompt,
                icon: "plus.circle.fill",
                style: .text,
                expand: true
            ) {
                isCreatingPrompt = true
                editingPrompt = FormattingPrompt(
                    name: "",
                    systemPrompt: "あなたはテキスト整形専用のプロセッサです。入力は音声認識の生テキストです。\n\n【やること】\n- \n\n【絶対にやらないこと】\n- テキストの内容に返事・回答・応答をしない\n- 前置きを付けない\n\n整形後のテキストだけを出力してください。"
                )
            }
        }
        .sheet(item: $editingPrompt) { prompt in
            PromptEditorSheet(
                prompt: prompt,
                isNew: isCreatingPrompt,
                showResetButton: prompt.isBuiltIn && appState.isBuiltInModified(prompt),
                onSave: { saved in
                    if isCreatingPrompt {
                        appState.addPrompt(saved)
                    } else if saved.isBuiltIn {
                        appState.updateBuiltInPrompt(saved)
                    } else {
                        appState.updatePrompt(saved)
                    }
                    editingPrompt = nil
                    isCreatingPrompt = false
                },
                onCancel: {
                    editingPrompt = nil
                    isCreatingPrompt = false
                },
                onReset: prompt.isBuiltIn ? {
                    appState.resetBuiltInPrompt(prompt)
                    editingPrompt = nil
                    isCreatingPrompt = false
                } : nil
            )
        }
    }

    // MARK: - Formatting Engine

    private var formattingSection: some View {
        settingsGroup(appState.l10n.formattingEngine) {
            // Provider selector
            settingsRow(title: appState.l10n.provider, description: appState.l10n.providerDesc) {
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

            Divider().foregroundStyle(DS.cardBorder)

            // Provider-specific settings
            VStack(alignment: .leading, spacing: 14) {
                // API Key (not needed for local)
                if appState.formattingProvider != .local {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.l10n.apiKey)
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
                }

                // Custom endpoint (for Custom provider)
                if appState.formattingProvider == .custom {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.l10n.endpointURL)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.textMuted)
                        TextField("https://api.example.com/v1", text: $appState.customEndpoint)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(8)
                            .background(DS.inputBg)
                            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                            .foregroundStyle(DS.textNormal)
                        Text(appState.l10n.openAICompatibleHint)
                            .font(.system(size: 11))
                            .foregroundStyle(DS.textFaint)
                    }
                }

                // Local model management
                if appState.formattingProvider == .local {
                    LocalModelSection(localLLMService: appState.localLLMService, localModelId: $appState.localModel)
                }

                // Cloud model selector (not for local)
                if appState.formattingProvider != .local {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appState.l10n.model)
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

                        HStack(spacing: 8) {
                            TextField(appState.l10n.orEnterModelId, text: currentModelBinding)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(8)
                                .background(DS.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                                .foregroundStyle(DS.textNormal)
                        }
                    }
                }
            }
            .padding(16)
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
        case .local: return $appState.localModel
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
                            .fill(DS.textNormal)
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
                        Text(L10n.current.pressShortcut)
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

// MARK: - Whisper Model Row

struct WhisperModelRow: View {
    let option: WhisperModelOption
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
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
                            .fill(DS.textNormal)
                            .frame(width: 6, height: 6)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(option.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.textNormal)
                        Badge(text: option.sizeLabel, color: DS.textFaint)
                    }
                    Text(option.description)
                        .font(.system(size: 10))
                        .foregroundStyle(DS.textFaint)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isHovered ? DS.cardBorder.opacity(0.3) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Prompt Row

struct PromptRow: View {
    let prompt: FormattingPrompt
    let isSelected: Bool
    var isModified: Bool = false
    let onSelect: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onReset: (() -> Void)?
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
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
                            .fill(DS.textNormal)
                            .frame(width: 6, height: 6)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(prompt.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.textNormal)
                        if prompt.isBuiltIn {
                            if isModified {
                                Badge(text: "Modified", color: DS.orange)
                            } else {
                                Badge(text: "Built-in", color: DS.textFaint)
                            }
                        }
                    }
                    Text(prompt.systemPrompt.prefix(60).replacingOccurrences(of: "\n", with: " ") + "...")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.textFaint)
                        .lineLimit(1)
                }

                Spacer()

                if isHovered {
                    HStack(spacing: 4) {
                        if let onReset {
                            Button(action: onReset) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 11))
                                    .foregroundStyle(DS.orange)
                                    .padding(4)
                                    .background(DS.bgTertiary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                            .help(L10n.current.resetToDefault)
                        }
                        if let onEdit {
                            Button(action: onEdit) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11))
                                    .foregroundStyle(DS.textMuted)
                                    .padding(4)
                                    .background(DS.bgTertiary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                            .help("Edit")
                        }
                        if let onDelete {
                            Button(action: onDelete) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(DS.red)
                                    .padding(4)
                                    .background(DS.bgTertiary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                            .help("Delete")
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? DS.blurple.opacity(0.08) : isHovered ? DS.bgModifierHover : .clear)
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}

// MARK: - Prompt Editor Sheet

struct PromptEditorSheet: View {
    @State var prompt: FormattingPrompt
    let isNew: Bool
    var showResetButton: Bool = false
    let onSave: (FormattingPrompt) -> Void
    let onCancel: () -> Void
    var onReset: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text(isNew ? "New Formatting Prompt" : "Edit Prompt")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DS.textNormal)
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 20)

            Divider().foregroundStyle(DS.cardBorder)

            // Scrollable form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.current.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.textMuted)
                        TextField("e.g. Code Review, Slack Message...", text: $prompt.name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(10)
                            .background(DS.inputBg)
                            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                            .foregroundStyle(DS.textNormal)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.current.systemPrompt)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.textMuted)
                        TextEditor(text: $prompt.systemPrompt)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(8)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .background(DS.inputBg)
                            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                            .foregroundStyle(DS.textNormal)
                    }

                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L10n.current.exampleInput)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(DS.textMuted)
                                TextEditor(text: $prompt.fewShotUser)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(8)
                                    .frame(minHeight: 60)
                                    .scrollContentBackground(.hidden)
                                    .background(DS.inputBg)
                                    .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                                    .foregroundStyle(DS.textNormal)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(L10n.current.expectedOutput)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(DS.textMuted)
                                TextEditor(text: $prompt.fewShotAssistant)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(8)
                                    .frame(minHeight: 60)
                                    .scrollContentBackground(.hidden)
                                    .background(DS.inputBg)
                                    .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                                    .foregroundStyle(DS.textNormal)
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text(L10n.current.fewShotExample)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.textMuted)
                    }
                    .tint(DS.textMuted)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
            }

            // Footer
            Divider().foregroundStyle(DS.cardBorder)

            HStack {
                Button(action: onCancel) {
                    Text(L10n.current.cancel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.textMuted)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(DS.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                }
                .buttonStyle(.plain)

                Spacer()

                if showResetButton, let onReset {
                    Button(action: onReset) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 11))
                            Text(L10n.current.resetToDefault)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(DS.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(DS.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    onSave(prompt)
                } label: {
                    Text(isNew ? L10n.current.addPromptBtn : L10n.current.saveChanges)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.textNormal)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(prompt.name.isEmpty ? DS.blurple.opacity(0.4) : DS.blurple)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                }
                .buttonStyle(.plain)
                .disabled(prompt.name.isEmpty)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
        .frame(width: 520)
        .frame(minHeight: 440, maxHeight: 660)
        .background(DS.bgSecondary)
    }
}

// MARK: - Dictionary Editor Sheet

struct DictionaryEditorSheet: View {
    @State var entry: DictionaryEntry
    let isNew: Bool
    let l10n: L10n
    let onSave: (DictionaryEntry) -> Void
    let onCancel: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? l10n.addTerm : l10n.term)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DS.textNormal)

            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.term)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DS.textMuted)
                TextField(l10n.termPlaceholder, text: $entry.term)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(8)
                    .background(DS.inputBg)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                    .foregroundStyle(DS.textNormal)
                Text(l10n.dictionaryDesc)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textFaint)
            }

            Spacer()

            HStack {
                Button(action: onCancel) {
                    Text(l10n.cancel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.textMuted)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(DS.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    onSave(entry)
                } label: {
                    Text(isNew ? l10n.addTerm : l10n.saveChanges)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.textNormal)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(entry.term.isEmpty ? DS.blurple.opacity(0.4) : DS.blurple)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                }
                .buttonStyle(.plain)
                .disabled(entry.term.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420, height: 220)
        .background(DS.bgSecondary)
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

// MARK: - Local Model Section

struct LocalModelSection: View {
    @ObservedObject var localLLMService: LocalLLMService
    @Binding var localModelId: String
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Info banner
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.blurple)
                Text(L10n.current.localModelLongDesc)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.textMuted)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.blurple.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))

            // Model list
            Text(L10n.current.model.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DS.textFaint)

            VStack(spacing: 2) {
                ForEach(LocalModelOption.recommended) { option in
                    LocalModelRow(
                        option: option,
                        isSelected: localModelId == option.id,
                        state: localModelId == option.id ? localLLMService.modelState : .notDownloaded,
                        onSelect: {
                            localModelId = option.id
                            localLLMService.checkModelStatus(modelId: option.id)
                        },
                        onDownload: {
                            localModelId = option.id
                            Task { await localLLMService.downloadAndLoad(modelId: option.id) }
                        },
                        onLoad: {
                            Task { await localLLMService.loadModel(modelId: option.id) }
                        },
                        onDelete: {
                            localLLMService.deleteModel(modelId: option.id)
                        }
                    )
                }
            }
            .background(DS.inputBg)
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))

            // Status
            if let error = localLLMService.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.red)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.red)
                        .lineLimit(2)
                }
            }
        }
        .onAppear {
            if !localModelId.isEmpty {
                localLLMService.checkModelStatus(modelId: localModelId)
            }
        }
    }
}

struct LocalModelRow: View {
    let option: LocalModelOption
    let isSelected: Bool
    let state: LocalModelState
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onLoad: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Radio button
                ZStack {
                    Circle()
                        .fill(isSelected ? DS.blurple : .clear)
                        .frame(width: 16, height: 16)
                    Circle()
                        .strokeBorder(isSelected ? DS.blurple : DS.textFaint.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    if isSelected {
                        Circle()
                            .fill(DS.textNormal)
                            .frame(width: 6, height: 6)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(option.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.textNormal)
                        Badge(text: option.sizeLabel, color: DS.textFaint)
                    }
                    Text(option.description)
                        .font(.system(size: 10))
                        .foregroundStyle(DS.textFaint)
                }

                Spacer()

                // State indicator / action button
                if isSelected {
                    stateView
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? DS.blurple.opacity(0.08) : isHovered ? DS.bgModifierHover : .clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }

    @ViewBuilder
    private var stateView: some View {
        switch state {
        case .notDownloaded:
            HoverPillButton(
                label: "Download",
                icon: "arrow.down.circle.fill",
                color: DS.blurple,
                action: onDownload
            )

        case .downloading(let progress):
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(DS.textMuted)
            }

        case .downloaded:
            HStack(spacing: 4) {
                HoverPillButton(
                    label: "Load",
                    icon: "play.circle.fill",
                    color: DS.green,
                    action: onLoad
                )

                HoverIconButton(
                    icon: "trash",
                    color: DS.red,
                    tooltip: "Delete",
                    action: onDelete
                )
            }

        case .loading:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.current.loading)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textMuted)
            }

        case .ready:
            HStack(spacing: 4) {
                Circle()
                    .fill(DS.green)
                    .frame(width: 6, height: 6)
                Text(L10n.current.ready)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.green)

                HoverIconButton(
                    icon: "trash",
                    color: DS.red,
                    tooltip: "Delete",
                    action: onDelete
                )
            }
        }
    }
}

// MARK: - Hover Button Components

struct HoverPillButton: View {
    let label: String
    var icon: String? = nil
    let color: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(isHovered ? 0.2 : 0.12))
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

struct HoverIconButton: View {
    let icon: String
    let color: Color
    var tooltip: String = ""
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .padding(4)
                .background(isHovered ? DS.bgModifierActive : DS.bgModifierHover)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .help(tooltip)
    }
}

// MARK: - Settings Action Button

struct SettingsActionButton: View {
    let label: String
    var icon: String? = nil
    var style: Style = .secondary
    var expand: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    enum Style { case primary, secondary, text }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: style == .text ? 13 : 11))
                }
                Text(label)
                    .font(.system(size: style == .text ? 13 : 12, weight: .medium))
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: expand ? .infinity : nil)
            .padding(.horizontal, style == .text ? 0 : 12)
            .padding(.vertical, style == .text ? 10 : 6)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: style == .text ? 0 : 6))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return DS.textOnAccent
        case .secondary: return isHovered ? DS.textNormal : DS.textMuted
        case .text: return isHovered ? DS.blurple.opacity(0.7) : DS.blurple
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return isHovered ? DS.blurple.opacity(0.8) : DS.blurple
        case .secondary: return isHovered ? DS.bgModifierHover : DS.bgTertiary
        case .text: return .clear
        }
    }
}
