# Verba

Local-first voice input for macOS. Speak naturally, get clean text pasted into any app.

**No cloud STT. No subscription. Your voice stays on your Mac.**

Verba uses [WhisperKit](https://github.com/argmaxinc/WhisperKit) for fully on-device transcription with optional LLM formatting via on-device MLX models, OpenRouter, OpenAI, or any OpenAI-compatible endpoint.

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
- **On-device** — WhisperKit models (Tiny to Large-V3-Turbo), no data leaves your Mac
- **Whisper model selection** — Choose from Auto, Tiny, Base, Small, or Large-V3-Turbo based on your needs
- **Multi-language** — Japanese, English, Vietnamese, or auto-detect
- **Fast & Formatted modes** — Raw output or AI-cleaned text (filler removal, punctuation, structure)

**Formatting Engine**
- **Local LLM (On-Device)** — Format text with MLX models (Qwen3, Gemma 3, SmolLM3) — no API key, no cloud
- **Cloud providers** — OpenRouter, OpenAI, or any custom OpenAI-compatible endpoint
- **Model selector** — Suggested models per provider with speed badges
- **Custom prompts** — Built-in General / Meeting Notes / Email templates, plus custom prompt editor
- **Dictionary** — Auto-learned proper nouns and custom term replacement

**App**
- **Guided onboarding** — First-launch wizard for permissions and model setup
- **Menu bar + Dock** — Runs in menu bar with optional Dock icon
- **Dashboard** — Session stats, mode usage, recent transcriptions
- **History** — Full transcription history with audio playback, copy, retry, and delete
- **System audio** — Keep playing, pause media, or capture system audio during recording
- **Auto-update** — Built-in Sparkle updater for seamless updates
- **Dark & Light themes** — Discord-inspired design system with system appearance support
- **Localization** — English and Japanese UI

## First Launch

### 1. Install

Download from [Releases](https://github.com/Sota-Mikami/Verba/releases):

- **`Verba-vX.X.X.dmg`** (recommended) — Open the DMG, drag Verba to Applications
- **`Verba-vX.X.X-mac.zip`** (alternative) — Unzip and move `Verba.app` to `/Applications`

### 2. Bypass Gatekeeper

Verba is not signed with an Apple Developer certificate, so macOS will block the first launch.

**Option A: Right-click → Open (recommended)**

1. Right-click (or Control-click) `Verba.app` in Finder
2. Select **Open** from the context menu
3. Click **Open** in the dialog that appears

> If the dialog only shows "Move to Trash", try Option B instead.

**Option B: Allow in System Settings**

1. Double-click `Verba.app` — macOS will block it
2. Open **System Settings → Privacy & Security**
3. Scroll down to find *"Verba" was blocked from use because it is not from an identified developer*
4. Click **Open Anyway**, then confirm

**Option C: Terminal (one-time)**

```bash
xattr -cr /Applications/Verba.app
```

### 3. Onboarding

On first launch, Verba guides you through:
1. **Microphone permission** — Required for voice recording
2. **Accessibility permission** — Required for auto-paste into active apps
3. **Whisper model download** — Downloads the speech recognition model

### 4. Optional: Formatted Mode

For AI-cleaned output, you have two options:

**Local (No API key needed)**
Go to Settings → Formatting Engine → Local (On-Device), then download a model:

| Model | Size | Best for |
|-------|------|----------|
| Qwen3 0.6B | ~400MB | Ultra-fast, basic formatting |
| Qwen3 1.7B | ~1GB | Good balance of speed and quality |
| Qwen3 4B | ~2.5GB | Best quality for most Macs |

**Cloud providers**
Go to Settings → Formatting Engine and add an API key:

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
# Product → Build (Cmd+B) or Run (Cmd+R)
```

Release build:
```bash
xcodegen generate && xcodebuild -scheme Verba -configuration Release \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
```

## Architecture

```
VerbaApp.swift            App entry (MenuBarExtra + Sparkle updater)
AppState.swift            Central state, recording pipeline, settings
HotkeyManager.swift       Custom shortcut recorder + controller
AudioRecorder.swift       AVAudioEngine + system audio capture
WhisperService.swift      WhisperKit on-device transcription
FormattingService.swift   Multi-provider LLM formatting (cloud + local)
LocalLLMService.swift     On-device MLX model management + inference
PasteService.swift        Clipboard + CGEvent Cmd+V paste
FloatingIndicator.swift   Non-activating recording overlay with error display
OnboardingView.swift      First-launch setup wizard
MainView.swift            Sidebar navigation (Dashboard/History/Settings)
DashboardView.swift       Stats, mode cards, recent transcriptions
HistoryView.swift         Full history with playback and actions
SettingsView.swift        All settings with shortcut recorder
DictionaryView.swift      Custom term dictionary management
Localization.swift        English + Japanese UI strings
DesignSystem.swift        Discord-inspired design tokens
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Speech-to-Text | [WhisperKit](https://github.com/argmaxinc/WhisperKit) (on-device) |
| Local LLM | [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) (Apple MLX) |
| Cloud LLM | OpenAI-compatible API (OpenRouter, OpenAI, custom) |
| Keyboard Shortcuts | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) |
| Auto-Update | [Sparkle](https://github.com/sparkle-project/Sparkle) |
| Project Generation | [XcodeGen](https://github.com/yonaskolb/XcodeGen) |

## Roadmap

- [ ] Real-time streaming transcription
- [ ] Context-aware formatting (read active app content)
- [ ] Audio feedback (sound effects for start/stop)
- [ ] DMG installer for easier distribution
- [ ] Export transcription history

## License

MIT
