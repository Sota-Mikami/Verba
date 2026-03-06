# Verba

Local-first voice input for macOS. Speak naturally, get text pasted into any app.

Uses [WhisperKit](https://github.com/argmaxinc/WhisperKit) for on-device transcription — no cloud STT required.

## Features

- **Push-to-talk** — Hold `Fn` to record, release to transcribe and paste
- **Hands-free** — Double-tap `Fn` to start, double-tap again to stop
- **Auto-paste** — Transcribed text is automatically pasted into the active app
- **Multi-language** — Japanese, English, Vietnamese, or auto-detect
- **Formatted mode** — Optional AI cleanup via OpenRouter (removes filler words, fixes punctuation)
- **Menu bar app** — Runs quietly in the menu bar, no Dock icon

## Requirements

- macOS 14+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4)
- Accessibility permission (for global shortcuts and auto-paste)
- Microphone permission

## Setup

### 1. Build

```bash
brew install xcodegen  # if not installed
xcodegen generate
open Verba.xcodeproj
# Build & Run (Cmd+R)
```

### 2. Permissions

- **Accessibility**: System Settings → Privacy & Security → Accessibility → Enable Verba
- **Microphone**: Granted on first launch
- **Fn key**: System Settings → Keyboard → "Press 🌐 key to" → **Do Nothing**

### 3. Optional: Formatted mode

For AI-cleaned output, add an [OpenRouter](https://openrouter.ai/) API key in Settings → OpenRouter API.

Recommended models:
- `google/gemma-3-4b-it` — fastest
- `google/gemma-3-12b-it` — balanced

## Architecture

```
VerbaApp.swift          App entry point (MenuBarExtra)
AppState.swift          Central state, recording/transcription pipeline
HotkeyManager.swift     Global Fn key detection (flagsChanged events)
AudioRecorder.swift     AVAudioEngine recording, 48kHz→16kHz conversion
WhisperService.swift    WhisperKit on-device transcription
PasteService.swift      Clipboard + CGEvent Cmd+V simulation
OpenRouterService.swift Optional LLM text formatting
FloatingIndicator.swift Non-activating recording indicator overlay
SettingsView.swift      Settings UI
MenuBarView.swift       Menu bar popover UI
```

## Known issues

- Accessibility permission resets on every debug build (binary signature changes). Toggle OFF→ON in System Settings after rebuilding. This does not affect signed release builds.

## License

Private project.
