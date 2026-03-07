# Verba Development Log

## 2026-03-07: v0.2.0 — On-Device LLM + Distribution Polish

### New Features
- **On-device LLM formatting** via mlx-swift-lm (replaces Ollama dependency)
  - Supports Qwen3 (0.6B/1.7B/4B), Gemma 3 1B, SmolLM3 3B
  - Download, load, unload, delete models from Settings UI
  - No API key or cloud service needed for text formatting
- **Onboarding wizard** — 3-step first-launch flow:
  1. Microphone permission
  2. Accessibility permission (with polling)
  3. Whisper model download progress
- **Whisper model selection** — Choose from Auto/Tiny/Base/Small/Large-V3-Turbo in Settings
- **Sparkle auto-update** — Built-in update framework with "Check for Updates" in menu bar
- **Error recovery** — Floating indicator shows error messages with 4-second auto-dismiss
- **Clear All confirmation** — Alert dialog before clearing transcription history
- **Custom formatting prompts** — Built-in General/Meeting Notes/Email + custom prompt editor
- **Dictionary system** — Auto-learned proper nouns + manual term entries with readings
- **Localization** — Full English and Japanese UI support

### Technical Changes
- Added `mlx-swift-lm` package dependency (MLXLLM + MLXLMCommon)
- Added `Sparkle` package dependency
- Added `com.apple.developer.kernel.increased-memory-limit` entitlement (for LLM inference)
- Added `com.apple.security.network.client` entitlement (for model downloads)
- Separate bundle identifiers for Debug (`com.sotamikami.verba.dev`) and Release (`com.sotamikami.verba`)
- Per-configuration app icons (colored for Release, monochrome for Debug)
- Fixed dual `@AppStorage("localModel")` definition in SettingsView

### New Files
- `LocalLLMService.swift` — MLX model management and inference
- `OnboardingView.swift` — First-launch setup wizard
- `DictionaryView.swift` — Dictionary management UI
- `Localization.swift` — L10n strings (EN/JA)

### Build Commands
```bash
# Debug (monochrome icon)
xcodebuild -project Verba.xcodeproj -scheme Verba -configuration Debug -destination "platform=macOS" build

# Release (colored icon)
xcodebuild -project Verba.xcodeproj -scheme Verba -configuration Release \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
```

---

## 2026-03-07: App Icons + Build Configuration

### Done
- Generated custom app icons (microphone + sound waves design)
  - **Release**: Purple gradient background (colored)
  - **Debug**: Dark gray background (monochrome)
- Created `AppIconDev.appiconset` for dev build
- Updated `project.yml` with per-configuration icon settings
- Self-signed certificate for code signing ("Verba Dev" in login keychain)
