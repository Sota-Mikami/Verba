import SwiftUI
import Combine
import os
import ServiceManagement

private let logger = Logger(subsystem: "com.sotamikami.verba", category: "AppState")

enum TranscriptionMode: String, CaseIterable {
    case fast = "Fast"
    case formatted = "Formatted"
}

enum SystemAudioBehavior: String, CaseIterable {
    case keepPlaying = "Keep Playing"
    case pauseMedia = "Pause Media"
    case captureSystemAudio = "Capture System Audio"
}

private enum RecordingTrigger {
    case none
    case pushToTalk
    case handsFree
}

@MainActor
class AppState: ObservableObject {
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var isModelLoaded = false
    @Published var isInitializing = false
    @Published var mode: TranscriptionMode = .formatted
    @Published var lastTranscription = ""
    @Published var statusMessage = ""
    @Published var history: [TranscriptionRecord] = []
    @Published var resolvedColorScheme: ColorScheme = .dark
    private var appearanceObservation: NSKeyValueObservation?
    @Published var unseenHistoryCount = 0

    @AppStorage("formattingProvider") var formattingProvider: FormattingProvider = .openRouter
    @AppStorage("openRouterApiKey") var openRouterApiKey = ""
    @AppStorage("openRouterModel") var openRouterModel = "google/gemma-3-4b-it"
    @AppStorage("openAIApiKey") var openAIApiKey = ""
    @AppStorage("openAIModel") var openAIModel = "gpt-4o-mini"
    @AppStorage("customApiKey") var customApiKey = ""
    @AppStorage("customModel") var customModel = ""
    @AppStorage("customEndpoint") var customEndpoint = ""
    @AppStorage("localModel") var localModel = "gemma3:4b"
    @AppStorage("selectedPromptId") var selectedPromptId = FormattingPrompt.builtInGeneral.id.uuidString
    @AppStorage("uiLanguage") var uiLanguage: String = "en" {
        didSet { l10n = L10n(UILanguage(rawValue: uiLanguage) ?? .en) }
    }
    @AppStorage("appearance") var appearance: AppAppearance = .dark {
        didSet { applyAppearance() }
    }
    @Published var customPrompts: [FormattingPrompt] = [] {
        didSet { saveCustomPrompts() }
    }
    @Published var builtInOverrides: [String: FormattingPrompt] = [:] {
        didSet { saveBuiltInOverrides() }
    }
    @Published var dictionaryEntries: [DictionaryEntry] = [] {
        didSet { saveDictionary() }
    }
    @Published var l10n = L10n.current
    @AppStorage("historyRetention") var historyRetention: HistoryRetention = .thirtyDays
    @Published var launchAtLogin = false
    @AppStorage("showInDock") var showInDock = true {
        didSet { applyDockVisibility() }
    }
    @AppStorage("whisperModel") var whisperModel = "auto"
    @AppStorage("selectedMicDeviceUID") var selectedMicDeviceUID = "" // empty = system default
    @AppStorage("systemAudioBehavior") var systemAudioBehavior: SystemAudioBehavior = .keepPlaying {
        didSet {
            if systemAudioBehavior == .captureSystemAudio && !SystemAudioCapture.hasPermission {
                SystemAudioCapture.requestPermission()
            }
        }
    }
    @AppStorage("pttShortcut") var pttShortcut: KeyShortcut = .defaultPTT {
        didSet {
            hotkeyController.pttShortcut = pttShortcut
            hotkeyController.restart()
        }
    }
    @AppStorage("hfShortcut") var hfShortcut: KeyShortcut = .defaultHF {
        didSet {
            hotkeyController.hfShortcut = hfShortcut
            hotkeyController.restart()
        }
    }

    private var audioRecorder = AudioRecorder()
    private var whisperService = WhisperService()
    private let formattingService = FormattingService()
    let localLLMService = LocalLLMService()
    private let pasteService = PasteService()
    private let mediaControlService = MediaControlService()
    private let floatingIndicator = FloatingIndicatorController()
    let mainWindow = MainWindowController()
    private static let maxHistoryCount = 50

    let hotkeyController = HotkeyController()
    private var recordingTrigger: RecordingTrigger = .none
    private var streamingTask: Task<Void, Never>?

    var allPrompts: [FormattingPrompt] {
        let builtIns = FormattingPrompt.allBuiltIn.map { original in
            builtInOverrides[original.id.uuidString] ?? original
        }
        return builtIns + customPrompts
    }

    var selectedPrompt: FormattingPrompt {
        guard let uuid = UUID(uuidString: selectedPromptId) else { return .builtInGeneral }
        return allPrompts.first { $0.id == uuid } ?? .builtInGeneral
    }

    init() {
        loadCustomPrompts()
        loadBuiltInOverrides()
        loadDictionary()
        syncLaunchAtLogin()
        applyAppearance()
        applyDockVisibility()
        pruneExpiredHistory()

        // Prompt for accessibility if not granted
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        pasteService.onAccessibilityNeeded = { [weak self] in
            Task { @MainActor [weak self] in
                self?.statusMessage = self?.l10n.accessibilityNeeded ?? "⚠ Accessibility permission needed"
                // Re-prompt for accessibility
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
                AXIsProcessTrustedWithOptions(options)
            }
        }
        audioRecorder.onAudioLevel = { [weak self] (level: Float) in
            Task { @MainActor [weak self] in
                self?.floatingIndicator.updateAudioLevel(level)
            }
        }
        setupFloatingIndicatorCallbacks()
        setupKeyboardShortcuts()
        Task {
            await initializeServices()
        }
    }

    var currentApiKey: String {
        switch formattingProvider {
        case .openRouter: return openRouterApiKey
        case .openAI: return openAIApiKey
        case .custom: return customApiKey
        case .local: return ""
        }
    }

    var currentModel: String {
        switch formattingProvider {
        case .openRouter: return openRouterModel
        case .openAI: return openAIModel
        case .custom: return customModel
        case .local: return localModel
        }
    }

    func applyDockVisibility() {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    private func syncLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            logger.error("Launch at login error: \(error.localizedDescription)")
            syncLaunchAtLogin()
        }
    }

    func applyAppearance() {
        appearanceObservation = nil

        switch appearance {
        case .system:
            NSApp.appearance = nil
            updateResolvedSchemeFromSystem()
            // KVO observe NSApp.effectiveAppearance for system theme changes
            appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    guard self?.appearance == .system else { return }
                    self?.updateResolvedSchemeFromSystem()
                }
            }
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
            DS.activeScheme = .light
            resolvedColorScheme = .light
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
            DS.activeScheme = .dark
            resolvedColorScheme = .dark
        }
        objectWillChange.send()
    }

    private func updateResolvedSchemeFromSystem() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        DS.activeScheme = isDark ? .dark : .light
        resolvedColorScheme = isDark ? .dark : .light
    }

    private func setupFloatingIndicatorCallbacks() {
        let state = floatingIndicator.state
        state.onModeChanged = { [weak self] newMode in
            Task { @MainActor [weak self] in
                self?.mode = newMode
            }
        }
        state.onPromptSelected = { [weak self] promptId in
            Task { @MainActor [weak self] in
                self?.selectedPromptId = promptId
            }
        }
        state.onErrorDismissed = { [weak self] in
            Task { @MainActor [weak self] in
                self?.floatingIndicator.hide()
            }
        }
        state.onStopRecording = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                self.recordingTrigger = .none
                self.stopRecording()
            }
        }
        state.onCancelRecording = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                self.cancelRecording()
            }
        }
    }

    private func syncFloatingIndicatorState() {
        let state = floatingIndicator.state
        state.selectedPromptId = selectedPromptId
        state.allPrompts = allPrompts
    }

    private func setupKeyboardShortcuts() {
        hotkeyController.pttShortcut = pttShortcut
        hotkeyController.hfShortcut = hfShortcut
        hotkeyController.start(
            onPushToTalkStart: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    // If hands-free is active, ignore Fn hold
                    guard self.recordingTrigger != .handsFree else { return }
                    guard !self.isRecording, !self.isProcessing else { return }
                    self.recordingTrigger = .pushToTalk
                    self.startRecording(hint: "Recording... (release Fn to stop)")
                }
            },
            onPushToTalkStop: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    // Only stop if it was push-to-talk
                    guard self.recordingTrigger == .pushToTalk else { return }
                    self.recordingTrigger = .none
                    if self.isRecording {
                        self.stopRecording()
                    }
                }
            },
            onHandsFreeToggle: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    if self.recordingTrigger == .pushToTalk {
                        // Switch from push-to-talk to hands-free (keep recording)
                        self.recordingTrigger = .handsFree
                        self.statusMessage = "Recording... (Fn×2 to stop)"
                        self.syncFloatingIndicatorState()
                        self.floatingIndicator.show(isRecording: true, statusMessage: "Recording... (Fn×2 to stop)", mode: self.mode)
                    } else if self.recordingTrigger == .handsFree {
                        // Stop hands-free
                        self.recordingTrigger = .none
                        if self.isRecording {
                            self.stopRecording()
                        }
                    } else {
                        // Start hands-free
                        guard !self.isProcessing else { return }
                        self.recordingTrigger = .handsFree
                        self.startRecording(hint: "Recording... (Fn×2 to stop)")
                    }
                }
            }
        )
    }

    /// Quick transcription for onboarding trial — uses already-loaded Whisper model
    func transcribeAudio(_ audioData: Data) async throws -> String {
        let dictHint = formattingService.dictionaryHint(dictionary: dictionaryEntries)
        return try await whisperService.transcribe(audioData: audioData, language: nil, initialPrompt: dictHint)
    }

    /// Cancel recording without transcribing — discard audio
    func cancelRecording() {
        streamingTask?.cancel()
        streamingTask = nil
        recordingTrigger = .none
        isRecording = false
        _ = audioRecorder.stopRecording() // discard audio data
        if systemAudioBehavior == .pauseMedia {
            mediaControlService.resumeIfPaused()
        }
        statusMessage = l10n.cancelled
        floatingIndicator.hide()
        Task {
            try? await Task.sleep(for: .seconds(2))
            if !isRecording && !isProcessing {
                statusMessage = l10n.ready
            }
        }
    }

    func toggleRecording() {
        if isRecording {
            recordingTrigger = .none
            stopRecording()
        } else {
            recordingTrigger = .handsFree
            startRecording(hint: "Recording... (Fn×2 to stop)")
        }
    }

    func initializeServices() async {
        guard !isInitializing && !isModelLoaded else { return }
        isInitializing = true
        statusMessage = l10n.downloadingModel

        do {
            let micGranted = await audioRecorder.requestMicPermission()
            if !micGranted {
                statusMessage = l10n.micPermissionDenied
                isInitializing = false
                return
            }

            try await whisperService.loadModel(variant: whisperModel)
            isModelLoaded = true
            statusMessage = l10n.ready
        } catch {
            let msg = String(describing: error)
            statusMessage = "Error: \(msg.prefix(80))"
            logger.error("Model load error: \(msg)")
        }
        isInitializing = false
    }

    func reloadWhisperModel() async {
        isModelLoaded = false
        isInitializing = true
        statusMessage = l10n.downloadingModel
        whisperService = WhisperService()
        do {
            try await whisperService.loadModel(variant: whisperModel)
            isModelLoaded = true
            statusMessage = l10n.ready
        } catch {
            let msg = String(describing: error)
            statusMessage = "Error: \(msg.prefix(80))"
            logger.error("Model reload error: \(msg)")
        }
        isInitializing = false
    }

    private func startRecording(hint: String) {
        guard isModelLoaded else {
            statusMessage = l10n.modelNotLoaded
            return
        }
        guard !isProcessing else { return }

        do {
            pasteService.saveTargetApp()

            if systemAudioBehavior == .pauseMedia {
                Task { await mediaControlService.pauseIfPlaying() }
            }

            audioRecorder.captureSystemAudio = (systemAudioBehavior == .captureSystemAudio)
            audioRecorder.selectedDeviceUID = selectedMicDeviceUID
            try audioRecorder.startRecording()
            isRecording = true
            statusMessage = hint
            syncFloatingIndicatorState()
            floatingIndicator.show(isRecording: true, statusMessage: hint, mode: mode)
            SoundFeedback.playRecordingStart()
            startStreamingTranscription()
        } catch {
            statusMessage = "Mic error: \(error.localizedDescription)"
            logger.error("Recording error: \(error.localizedDescription)")
        }
    }

    private func stopRecording() {
        streamingTask?.cancel()
        streamingTask = nil
        isRecording = false
        isProcessing = true
        statusMessage = l10n.transcribing
        SoundFeedback.playRecordingStop()
        floatingIndicator.show(isRecording: false, statusMessage: "Transcribing...", mode: mode)

        if systemAudioBehavior == .pauseMedia {
            mediaControlService.resumeIfPaused()
        }

        Task {
            let audioData: Data
            if systemAudioBehavior == .captureSystemAudio {
                audioData = await audioRecorder.stopRecordingAsync()
            } else {
                audioData = audioRecorder.stopRecording()
            }
            await processAudio(audioData)
        }
    }

    // MARK: - Streaming Transcription

    private func startStreamingTranscription() {
        streamingTask = Task { [weak self] in
            // Wait for initial audio to accumulate
            try? await Task.sleep(for: .seconds(1.5))

            while !Task.isCancelled {
                guard let self else { return }
                guard self.isRecording else { return }

                let buffer = self.audioRecorder.getCurrentBuffer()
                let sampleCount = buffer.count / MemoryLayout<Float>.size
                let seconds = Float(sampleCount) / 16000.0

                if seconds >= 1.0 {
                    do {
                        let hint = self.formattingService.dictionaryHint(dictionary: self.dictionaryEntries)
                        let text = try await self.whisperService.transcribe(audioData: buffer, language: nil, initialPrompt: hint)
                        if !Task.isCancelled && self.isRecording && !text.isEmpty {
                            self.floatingIndicator.updateStreamingText(text)
                        }
                    } catch {
                        logger.debug("Streaming transcription error: \(error.localizedDescription)")
                    }
                }

                // Wait before next transcription cycle
                try? await Task.sleep(for: .seconds(1.0))
            }
        }
    }

    private func processAudio(_ audioData: Data, paste: Bool = true) async {
        var record = TranscriptionRecord(audioData: audioData, language: nil, mode: mode)
        history.insert(record, at: 0)
        unseenHistoryCount += 1
        if history.count > Self.maxHistoryCount {
            history.removeLast()
        }

        do {
            let dictHint = formattingService.dictionaryHint(dictionary: dictionaryEntries)
            let rawText = try await whisperService.transcribe(audioData: audioData, language: nil, initialPrompt: dictHint)

            if rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updateRecord(record.id) { $0.status = .failed; $0.errorMessage = "No speech detected" }
                statusMessage = l10n.noSpeechDetected
                isProcessing = false
                floatingIndicator.showError("No speech detected")
                return
            }

            updateRecord(record.id) { $0.rawText = rawText; $0.status = .success }

            var finalText = rawText

            if mode == .formatted && formattingProvider.isAvailable && (formattingProvider == .local ? localLLMService.isReady : !currentApiKey.isEmpty) {
                updateRecord(record.id) { $0.status = .formatting }
                statusMessage = l10n.formatting
                floatingIndicator.show(isRecording: false, statusMessage: "Formatting...", mode: mode)
                finalText = await formattingService.format(
                    text: rawText,
                    provider: formattingProvider,
                    apiKey: currentApiKey,
                    model: currentModel,
                    customEndpoint: customEndpoint,
                    prompt: selectedPrompt,
                    dictionary: dictionaryEntries,
                    localLLMService: localLLMService
                ) ?? rawText
                updateRecord(record.id) { $0.formattedText = finalText; $0.status = .success }
            }

            lastTranscription = finalText
            if paste {
                let accessibilityOK = AXIsProcessTrusted()
                pasteService.paste(text: finalText)
                if accessibilityOK {
                    statusMessage = l10n.pastedChars(finalText.count)
                }
                // If not trusted, onAccessibilityNeeded callback already set statusMessage
            } else {
                statusMessage = l10n.retranscribedChars(finalText.count)
            }
            floatingIndicator.hideWithSuccess()

            try? await Task.sleep(for: .seconds(3))
            if !isRecording && !isProcessing {
                statusMessage = l10n.ready
            }
        } catch {
            updateRecord(record.id) { $0.status = .failed; $0.errorMessage = error.localizedDescription }
            statusMessage = "Error: \(error.localizedDescription)"
            logger.error("Process error: \(error.localizedDescription)")
            floatingIndicator.showError(error.localizedDescription)
        }

        isProcessing = false
    }

    private func updateRecord(_ id: UUID, _ update: (inout TranscriptionRecord) -> Void) {
        if let index = history.firstIndex(where: { $0.id == id }) {
            update(&history[index])
        }
    }

    func retryTranscription(_ record: TranscriptionRecord) {
        guard !isProcessing else { return }
        isProcessing = true
        statusMessage = l10n.retranscribing
        deleteRecord(record)
        Task {
            await processAudio(record.audioData, paste: false)
        }
    }

    func clearHistory() {
        AudioPlaybackService.shared.stop()
        history.removeAll()
        unseenHistoryCount = 0
    }

    func markHistorySeen() {
        unseenHistoryCount = 0
    }

    func deleteRecord(_ record: TranscriptionRecord) {
        if AudioPlaybackService.shared.isPlaying(record.id) {
            AudioPlaybackService.shared.stop()
        }
        history.removeAll { $0.id == record.id }
    }

    // MARK: - Prompt Management

    func addPrompt(_ prompt: FormattingPrompt) {
        customPrompts.append(prompt)
        selectedPromptId = prompt.id.uuidString
    }

    func updatePrompt(_ prompt: FormattingPrompt) {
        if let index = customPrompts.firstIndex(where: { $0.id == prompt.id }) {
            customPrompts[index] = prompt
        }
    }

    func deletePrompt(_ prompt: FormattingPrompt) {
        customPrompts.removeAll { $0.id == prompt.id }
        if selectedPromptId == prompt.id.uuidString {
            selectedPromptId = FormattingPrompt.builtInGeneral.id.uuidString
        }
    }

    func updateBuiltInPrompt(_ prompt: FormattingPrompt) {
        builtInOverrides[prompt.id.uuidString] = prompt
    }

    func resetBuiltInPrompt(_ prompt: FormattingPrompt) {
        builtInOverrides.removeValue(forKey: prompt.id.uuidString)
    }

    func isBuiltInModified(_ prompt: FormattingPrompt) -> Bool {
        builtInOverrides[prompt.id.uuidString] != nil
    }

    // MARK: - Dictionary Management

    func addDictionaryEntry(_ entry: DictionaryEntry) {
        dictionaryEntries.append(entry)
    }

    func updateDictionaryEntry(_ entry: DictionaryEntry) {
        if let index = dictionaryEntries.firstIndex(where: { $0.id == entry.id }) {
            dictionaryEntries[index] = entry
        }
    }

    func deleteDictionaryEntry(_ entry: DictionaryEntry) {
        dictionaryEntries.removeAll { $0.id == entry.id }
    }

    private func saveDictionary() {
        if let data = try? JSONEncoder().encode(dictionaryEntries) {
            UserDefaults.standard.set(data, forKey: "dictionaryEntries")
        }
    }

    private func loadDictionary() {
        guard let data = UserDefaults.standard.data(forKey: "dictionaryEntries"),
              let entries = try? JSONDecoder().decode([DictionaryEntry].self, from: data) else { return }
        dictionaryEntries = entries
    }

    private func saveCustomPrompts() {
        if let data = try? JSONEncoder().encode(customPrompts) {
            UserDefaults.standard.set(data, forKey: "customFormattingPrompts")
        }
    }

    private func loadCustomPrompts() {
        guard let data = UserDefaults.standard.data(forKey: "customFormattingPrompts"),
              let prompts = try? JSONDecoder().decode([FormattingPrompt].self, from: data) else { return }
        customPrompts = prompts
    }

    private func saveBuiltInOverrides() {
        if let data = try? JSONEncoder().encode(builtInOverrides) {
            UserDefaults.standard.set(data, forKey: "builtInPromptOverrides")
        }
    }

    private func loadBuiltInOverrides() {
        guard let data = UserDefaults.standard.data(forKey: "builtInPromptOverrides"),
              let overrides = try? JSONDecoder().decode([String: FormattingPrompt].self, from: data) else { return }
        builtInOverrides = overrides
    }

    private func pruneExpiredHistory() {
        guard let days = historyRetention.days else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        history.removeAll { $0.timestamp < cutoff }
    }
}
