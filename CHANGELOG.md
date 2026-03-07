# Changelog

All notable changes to Verba will be documented in this file.

## [0.2.0] - 2026-03-07

### Added
- On-device LLM formatting via Apple MLX (no API key required)
  - Supports Qwen3 0.6B/1.7B/4B, Gemma 3 1B, SmolLM3 3B
  - Download, load, and manage models directly from Settings
- First-launch onboarding wizard (mic, accessibility, model download)
- Whisper model selection (Auto, Tiny, Base, Small, Large-V3-Turbo)
- Sparkle auto-update framework with "Check for Updates" in menu bar
- Custom formatting prompts (General, Meeting Notes, Email + custom editor)
- Dictionary system with auto-learned proper nouns
- Clear All confirmation dialog
- Error display in floating indicator with auto-dismiss
- English and Japanese UI localization
- GitHub Pages landing page

### Changed
- Formatting engine now supports Local (On-Device) as a provider
- Floating indicator shows error messages instead of silently hiding
- Separate bundle identifiers for Debug and Release builds

### Fixed
- Duplicate `@AppStorage("localModel")` definition in SettingsView

## [0.1.0] - 2026-03-06

### Added
- Initial release
- On-device speech-to-text via WhisperKit
- Push-to-talk and hands-free recording modes
- Custom keyboard shortcuts
- Auto-paste into active app
- Multi-provider formatting (OpenRouter, OpenAI, custom endpoint)
- Dashboard with session stats
- Transcription history with audio playback
- System audio capture option
- Menu bar + Dock icon modes
- Discord-inspired dark theme
