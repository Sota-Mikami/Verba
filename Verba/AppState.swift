import SwiftUI
import Combine
import os

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
    @Published var statusMessage = "Starting..."
    @Published var selectedLanguage = "auto"
    @Published var history: [TranscriptionRecord] = []
    @Published var unseenHistoryCount = 0

    @AppStorage("formattingProvider") var formattingProvider: FormattingProvider = .openRouter
    @AppStorage("openRouterApiKey") var openRouterApiKey = ""
    @AppStorage("openRouterModel") var openRouterModel = "google/gemma-3-4b-it"
    @AppStorage("openAIApiKey") var openAIApiKey = ""
    @AppStorage("openAIModel") var openAIModel = "gpt-4o-mini"
    @AppStorage("customApiKey") var customApiKey = ""
    @AppStorage("customModel") var customModel = ""
    @AppStorage("customEndpoint") var customEndpoint = ""
    @AppStorage("historyRetention") var historyRetention: HistoryRetention = .thirtyDays
    @AppStorage("showInDock") var showInDock = true {
        didSet { applyDockVisibility() }
    }
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
    private let pasteService = PasteService()
    private let mediaControlService = MediaControlService()
    private let floatingIndicator = FloatingIndicatorController()
    let mainWindow = MainWindowController()
    private static let maxHistoryCount = 50

    let hotkeyController = HotkeyController()
    private var recordingTrigger: RecordingTrigger = .none

    let availableLanguages = [
        ("auto", "Auto Detect"),
        ("ja", "Japanese"),
        ("en", "English"),
        ("vi", "Vietnamese"),
    ]

    init() {
        applyDockVisibility()
        pruneExpiredHistory()

        // Prompt for accessibility if not granted
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        pasteService.onAccessibilityNeeded = { [weak self] in
            Task { @MainActor [weak self] in
                self?.statusMessage = "⚠ Accessibility permission needed — text copied to clipboard"
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
        case .local: return ""
        }
    }

    func applyDockVisibility() {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
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
        statusMessage = "Downloading Whisper model..."

        do {
            let micGranted = await audioRecorder.requestMicPermission()
            if !micGranted {
                statusMessage = "Microphone permission denied"
                isInitializing = false
                return
            }

            try await whisperService.loadModel()
            isModelLoaded = true
            statusMessage = "Ready"
        } catch {
            let msg = String(describing: error)
            statusMessage = "Error: \(msg.prefix(80))"
            logger.error("Model load error: \(msg)")
        }
        isInitializing = false
    }

    private func startRecording(hint: String) {
        guard isModelLoaded else {
            statusMessage = "Model not loaded yet"
            return
        }
        guard !isProcessing else { return }

        do {
            pasteService.saveTargetApp()

            if systemAudioBehavior == .pauseMedia {
                Task { await mediaControlService.pauseIfPlaying() }
            }

            audioRecorder.captureSystemAudio = (systemAudioBehavior == .captureSystemAudio)
            try audioRecorder.startRecording()
            isRecording = true
            statusMessage = hint
            floatingIndicator.show(isRecording: true, statusMessage: hint, mode: mode)
        } catch {
            statusMessage = "Mic error: \(error.localizedDescription)"
            logger.error("Recording error: \(error.localizedDescription)")
        }
    }

    private func stopRecording() {
        isRecording = false
        isProcessing = true
        statusMessage = "Transcribing..."
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

    private func processAudio(_ audioData: Data, paste: Bool = true) async {
        let language = selectedLanguage == "auto" ? nil : selectedLanguage
        var record = TranscriptionRecord(audioData: audioData, language: language, mode: mode)
        history.insert(record, at: 0)
        unseenHistoryCount += 1
        if history.count > Self.maxHistoryCount {
            history.removeLast()
        }

        do {
            let rawText = try await whisperService.transcribe(audioData: audioData, language: language)

            if rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updateRecord(record.id) { $0.status = .failed; $0.errorMessage = "No speech detected" }
                statusMessage = "No speech detected"
                isProcessing = false
                floatingIndicator.hide()
                return
            }

            updateRecord(record.id) { $0.rawText = rawText; $0.status = .success }

            var finalText = rawText

            if mode == .formatted && !currentApiKey.isEmpty && formattingProvider.isAvailable {
                updateRecord(record.id) { $0.status = .formatting }
                statusMessage = "Formatting..."
                floatingIndicator.show(isRecording: false, statusMessage: "Formatting...", mode: mode)
                finalText = await formattingService.format(
                    text: rawText,
                    provider: formattingProvider,
                    apiKey: currentApiKey,
                    model: currentModel,
                    customEndpoint: customEndpoint
                ) ?? rawText
                updateRecord(record.id) { $0.formattedText = finalText; $0.status = .success }
            }

            lastTranscription = finalText
            if paste {
                let accessibilityOK = AXIsProcessTrusted()
                pasteService.paste(text: finalText)
                if accessibilityOK {
                    statusMessage = "Pasted \(finalText.count) chars"
                }
                // If not trusted, onAccessibilityNeeded callback already set statusMessage
            } else {
                statusMessage = "Retranscribed \(finalText.count) chars"
            }
            floatingIndicator.hide()

            try? await Task.sleep(for: .seconds(3))
            if !isRecording && !isProcessing {
                statusMessage = "Ready"
            }
        } catch {
            updateRecord(record.id) { $0.status = .failed; $0.errorMessage = error.localizedDescription }
            statusMessage = "Error: \(error.localizedDescription)"
            logger.error("Process error: \(error.localizedDescription)")
            floatingIndicator.hide()
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
        statusMessage = "Retranscribing..."
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

    private func pruneExpiredHistory() {
        guard let days = historyRetention.days else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        history.removeAll { $0.timestamp < cutoff }
    }
}
