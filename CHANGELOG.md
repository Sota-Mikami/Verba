# Changelog

All notable changes to Verba will be documented in this file.

## [0.3.2] - 2026-03-08

### Changed
- Dictionary simplified to term-only list (removed readings/auto-added concepts)
- Dictionary terms now injected into Whisper as promptTokens for better recognition accuracy
- Dictionary terms passed directly to LLM formatting prompt
- Formatting prompt rewritten to be English-based, multilingual-aware, and explicitly prohibit markdown
- Menu bar simplified: removed Mode/Prompt pickers, cleaner layout with icons
- Landing page: improved nav button visibility, version-independent download links

### Removed
- `applyDictionary()` Fast-mode string replacement (replaced by Whisper prompt injection)
- Readings field from Dictionary editor
- Auto-added/manual filter from Dictionary

## [0.3.0] - 2026-03-08

### Added
- Real-time streaming transcription — see text appear in the floating indicator while you speak
  - Partial transcription updates every ~1 second during recording
  - Mini waveform + streaming text replaces full waveform when text is available
  - Auto-scrolling text view with fade mask for readability
- Thread-safe audio buffer access for concurrent streaming reads

### Changed
- Floating indicator width increased from 300px to 340px for better text readability
- Floating indicator dynamically resizes height to accommodate streaming text

### Fixed
- Picker/Select text invisible in light mode (color scheme mismatch between DS and native controls)
- System appearance changes now properly tracked via KVO observation

## [0.2.3] - 2026-03-08

### Added
- GitHub-style usage heatmap on Dashboard (removed — favoring visible recent transcriptions)
- Hover interactions and tooltips on all actionable buttons across the app

### Changed
- Dashboard simplified: removed usage trend chart to keep recent transcriptions visible
- DMG is now the standard distribution format (replaced zip)

## [0.2.2] - 2026-03-08

### Added
- Sparkle auto-update now fully functional (EdDSA signed, appcast.xml on GitHub Pages)
- Hover interactions on all actionable buttons across the app
- Tooltips on Dictionary and Settings icon buttons (Edit, Delete, Reset)
- Reusable hover button components (HoverPillButton, HoverIconButton)
- Release automation script (`scripts/release.sh`)

### Changed
- "Check for Updates" button is now disabled until Sparkle is ready
- Auto-update check enabled on launch for Release builds only

## [0.2.1] - 2026-03-08

### Added
- Dashboard usage trend chart (7-day bar chart)
- Tooltips on history action buttons (Play, Copy, Retry, Delete)
- Built-in formatting prompts are now editable with "Reset to Default" option

### Changed
- Removed Languages and Mode Usage sections from Dashboard
- Dictionary is now manual-only (removed auto-add of proper nouns)
- Simplified Dictionary UI (removed filter tabs)

### Fixed
- Action buttons in history were not discoverable (no labels on hover)

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
