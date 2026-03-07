# Verba

Local-first voice input for macOS. Speak naturally, get clean text pasted into any app.

**No cloud STT. No subscription. Just your voice → text.**

Verba uses [WhisperKit](https://github.com/argmaxinc/WhisperKit) for fully on-device transcription with optional LLM formatting via OpenRouter, OpenAI, or any OpenAI-compatible endpoint.

## Download

**[Download latest release](https://github.com/Sota-Mikami/Verba/releases/latest)**

> Requires macOS 14+ (Sonoma) and Apple Silicon (M1/M2/M3/M4)

## Features

**Voice Input**
- **Push-to-talk** — Hold a key to record, release to transcribe and paste
- **Hands-free** — Toggle recording with a key combo or double-tap
- **Custom shortcuts** — Set any modifier key, key combo (e.g. `fn Space`), or double-tap as trigger
- **Auto-paste** — Transcribed text is pasted into the active app automatically

**Transcription**
- **On-device** — WhisperKit `large-v3-turbo` model, no data leaves your Mac
- **Multi-language** — Japanese, English, Vietnamese, or auto-detect
- **Fast & Formatted modes** — Raw output or AI-cleaned text (filler removal, punctuation, structure)

**Formatting Engine**
- **Multi-provider** — OpenRouter, OpenAI, or any custom OpenAI-compatible endpoint
- **Model selector** — Suggested models per provider with speed badges
- **Hardened prompts** — Formatting-only output, no conversational responses

**App**
- **Menu bar + Dock** — Runs in menu bar with optional Dock icon
- **Dashboard** — Session stats, mode usage, recent transcriptions
- **History** — Full transcription history with audio playback, copy, retry, and delete
- **System audio** — Keep playing, pause media, or capture system audio during recording
- **Dark theme** — Discord-inspired design system

## First Launch

### 1. Install

Download `Verba-vX.X.X-mac.zip` from [Releases](https://github.com/Sota-Mikami/Verba/releases), unzip, and move `Verba.app` to `/Applications`.

On first open, macOS may show "unidentified developer" warning. Right-click → Open to bypass.

### 2. Grant Permissions

- **Accessibility**: System Settings → Privacy & Security → Accessibility → Enable Verba
- **Microphone**: Granted on first launch prompt
- **Fn key** (if using fn as trigger): System Settings → Keyboard → "Press 🌐 key to" → **Do Nothing**

### 3. Optional: Formatted Mode

For AI-cleaned output, go to Settings → Formatting Engine and add an API key:

| Provider | Get API key | Recommended model |
|----------|------------|-------------------|
| [OpenRouter](https://openrouter.ai/) | Free tier available | `google/gemma-3-4b-it` (fastest) |
| [OpenAI](https://platform.openai.com/) | Pay-as-you-go | `gpt-4.1-nano` (fastest) |

Typical cost: **less than $1/month** for daily use.

## Build from Source

```bash
brew install xcodegen  # if not installed
cd Verba
xcodegen generate
open Verba.xcodeproj
# Product → Build (⌘B) or Run (⌘R)
```

Release build:
```bash
xcodebuild -scheme Verba -configuration Release build
```

## Architecture

```
VerbaApp.swift            App entry (MenuBarExtra + AppDelegate)
AppState.swift            Central state, recording pipeline, settings
HotkeyManager.swift       Custom shortcut recorder + controller
AudioRecorder.swift       AVAudioEngine + system audio capture
WhisperService.swift      WhisperKit on-device transcription
FormattingService.swift   Multi-provider LLM formatting
PasteService.swift        Clipboard + CGEvent Cmd+V paste
FloatingIndicator.swift   Non-activating recording overlay
MainView.swift            Sidebar navigation (Dashboard/History/Settings)
DashboardView.swift       Stats, mode cards, recent transcriptions
HistoryView.swift         Full history with playback and actions
SettingsView.swift        All settings with shortcut recorder
DesignSystem.swift        Discord-inspired design tokens
```

## Roadmap

- [ ] Custom formatting prompts (per-context templates)
- [ ] Local LLM formatting via MLX (no API key needed)
- [ ] GitHub Pages landing page
- [ ] Real-time streaming transcription
- [ ] Context-aware formatting (read active app content)

## License

MIT
