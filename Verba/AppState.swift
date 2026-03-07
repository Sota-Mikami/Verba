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

    @AppStorage("openRouterApiKey") var openRouterApiKey = ""
    @AppStorage("openRouterModel") var openRouterModel = "google/gemma-3-4b-it"
    @AppStorage("showInDock") var showInDock = true {
        didSet { applyDockVisibility() }
    }
    @AppStorage("systemAudioBehavior") var systemAudioBehavior: SystemAudioBehavior = .keepPlaying

    private var audioRecorder = AudioRecorder()
    private var whisperService = WhisperService()
    private let openRouterService = OpenRouterService()
    private let pasteService = PasteService()
    private let mediaControlService = MediaControlService()
    private let floatingIndicator = FloatingIndicatorController()
    let settingsWindow = SettingsWindowController()

    private let hotkeyController = HotkeyController()
    private var recordingTrigger: RecordingTrigger = .none

    let availableLanguages = [
        ("auto", "Auto Detect"),
        ("ja", "Japanese"),
        ("en", "English"),
        ("vi", "Vietnamese"),
    ]

    init() {
        applyDockVisibility()

        // Prompt for accessibility if not granted
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
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

    func applyDockVisibility() {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    private func setupKeyboardShortcuts() {
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

    private func processAudio(_ audioData: Data) async {
        do {
            let language = selectedLanguage == "auto" ? nil : selectedLanguage
            let rawText = try await whisperService.transcribe(audioData: audioData, language: language)

            if rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                statusMessage = "No speech detected"
                isProcessing = false
                floatingIndicator.hide()
                return
            }

            var finalText = rawText

            if mode == .formatted && !openRouterApiKey.isEmpty {
                statusMessage = "Formatting..."
                floatingIndicator.show(isRecording: false, statusMessage: "Formatting...", mode: mode)
                finalText = await openRouterService.format(
                    text: rawText,
                    apiKey: openRouterApiKey,
                    model: openRouterModel
                ) ?? rawText
            }

            lastTranscription = finalText
            pasteService.paste(text: finalText)
            statusMessage = "Pasted \(finalText.count) chars"
            floatingIndicator.hide()

            try? await Task.sleep(for: .seconds(3))
            if !isRecording && !isProcessing {
                statusMessage = "Ready"
            }
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
            logger.error("Process error: \(error.localizedDescription)")
            floatingIndicator.hide()
        }

        isProcessing = false
    }
}
