# Verba

Local-first voice input for macOS. Speak naturally, get clean text pasted into any app.

**No cloud STT. No subscription. Your voice stays on your Mac.**

[![Download](https://img.shields.io/github/v/release/Sota-Mikami/Verba?label=Download&color=7c5cfc)](https://github.com/Sota-Mikami/Verba/releases/latest)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-blue.svg)]()

> **[Download latest release](https://github.com/Sota-Mikami/Verba/releases/latest)** | **[Landing Page](https://sota-mikami.github.io/Verba/)**

## Highlights

- **Fully on-device** — [WhisperKit](https://github.com/argmaxinc/WhisperKit) for speech recognition, [MLX](https://github.com/ml-explore/mlx-swift-lm) for text formatting. No data leaves your Mac.
- **Real-time streaming** — See transcribed text appear live in the floating indicator as you speak.
- **Auto-paste** — Transcribed text is pasted directly into the active app. Works everywhere.
- **Multi-language** — Japanese, English, Vietnamese, and 50+ languages with auto-detect.

## Features

**Voice Input**
- Push-to-talk (hold key) and hands-free (toggle) recording modes
- Custom shortcuts — any modifier key, key combo (e.g. `fn Space`), or double-tap
- Real-time streaming transcription with live text preview
- Auto-paste into the active app via Accessibility API

**Transcription & Formatting**
- On-device Whisper models: Tiny, Base, Small, Large-V3-Turbo
- Fast mode (raw output) or Formatted mode (AI-cleaned text)
- On-device LLM formatting via Apple MLX — no API key needed
- Cloud providers: OpenRouter, OpenAI, or any OpenAI-compatible endpoint
- Custom formatting prompts (General, Meeting Notes, Email + your own)
- Dictionary for custom term correction

**App**
- Menu bar native with optional Dock icon
- Guided first-launch onboarding
- Dashboard with session stats and recent transcriptions
- Full history with audio playback, copy, retry, delete
- System audio capture option
- Auto-update via Sparkle
- Dark, Light, and System themes
- English and Japanese UI

## Quick Start

### 1. Install

Download **[Verba-vX.X.X.dmg](https://github.com/Sota-Mikami/Verba/releases/latest)** from Releases, open the DMG, drag to Applications.

### 2. Bypass Gatekeeper

Verba is not notarized. On first launch:

- **Right-click** `Verba.app` → **Open** → click **Open** in the dialog
- Or: `xattr -cr /Applications/Verba.app` in Terminal

### 3. Onboarding

Verba walks you through microphone permission, accessibility permission, and Whisper model download.

### 4. Use

| Action | Shortcut |
|--------|----------|
| Push-to-talk | Hold `fn` (300ms) → release to transcribe |
| Hands-free | Double-tap `fn` → double-tap again to stop |

### 5. Optional: Formatted Mode

**Local (no API key):** Settings → Formatting Engine → Local → download a model (Qwen3 4B recommended).

**Cloud:** Settings → Formatting Engine → add API key (OpenRouter free tier works).

## Build from Source

```bash
brew install xcodegen
cd Verba
xcodegen generate
open Verba.xcodeproj
# Cmd+R to run
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Speech-to-Text | [WhisperKit](https://github.com/argmaxinc/WhisperKit) (on-device) |
| Local LLM | [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) (Apple MLX) |
| Cloud LLM | OpenAI-compatible API |
| Shortcuts | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) |
| Auto-Update | [Sparkle](https://github.com/sparkle-project/Sparkle) |

## Roadmap

- [x] Real-time streaming transcription
- [ ] Context-aware formatting (read active app content)
- [ ] Audio feedback (sound effects for start/stop)
- [ ] Export transcription history

## License

MIT
