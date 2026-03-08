# Changelog

All notable changes to Verba will be documented in this file.

## [0.4.3] - 2026-03-08

### Changed
- **App icon** — Brand gradient background (purple + amber), cleaned wave arcs to 2 tiers

### Fixed
- **Radio button contrast** — Selected dot now uses textOnAccent for visibility on accent backgrounds in light mode
- **Clean rebuild** — Full clean build to ensure all v0.4.x features ship correctly

## [0.4.1] - 2026-03-08

### Added
- **Audio feedback** — Sound cues for recording start (pop), stop (tink), and paste confirmation (morse)
- **Paste success indicator** — Green checkmark briefly shown in floating indicator before fade-out
- **Animated formatting dots** — "Formatting..." cycles dots for visible progress
- **Timer flip animation** — Elapsed time digits animate with numericText transition

### Changed
- **App icon** — Updated colors to match brand palette
- **Timer accuracy** — Elapsed time now uses Date-based calculation instead of cumulative increment
- **Formatting center alignment** — Status text now vertically centered in indicator during transcribing/formatting
- **Dictionary terminology** — Unified to "Add Term" (was mixed "New word" / "Add Term")
- **Button contrast** — Fixed accent buttons (Add Term, Save) using textOnAccent for readability in light mode
- **Dictionary Enter key** — Term can be added by pressing Enter

## [0.4.0] - 2026-03-08

### Added
- **Floating indicator stop/cancel buttons** — "Done" (checkmark, accent) confirms & transcribes, "Cancel" (trash, muted→red on hover) discards recording. Hover reveals label for clarity.
- **Menu bar enhancements** — Mode picker (Fast/Formatted), prompt selector (greyed in Fast mode), recent history submenu (max 10, copy on click)
- **5-step onboarding** — Added shortcut confirmation (step 4) and interactive trial recording (step 5) to first-launch wizard
- **Real-time streaming transcription** — Partial transcription updates during recording, live text preview in floating indicator
- **Full EN/JA localization** — 30+ previously hardcoded strings now localized across all views, status messages, and onboarding

### Changed
- **Design system migration** — Discord-cold grays replaced with warm plum-black palette, warm off-white text, two-accent system (purple + amber)
- **Light mode overhaul** — Warm off-whites and warm text grays replace cold Discord grays; `DS.textOnAccent` ensures readability on accent backgrounds
- **Floating indicator rebrand** — Branded warm glass, amber recording dot with breathe animation, two-accent waveform, forced dark mode
- **Streaming text layout** — Fixed height (180px) with internal scroll, bottom controls always pinned visible
- **Settings restructured** — 2-tier layout: basic settings always visible, Voice Engine collapsed by default
- **Animation cleanup** — All `.spring()` replaced with `.easeOut()`, removed bounce effects
- **Menu bar simplified** — Removed inline status/mode badge, uses macOS-standard system colors
- **Dictionary simplified** — Term-only list, injected as Whisper prompt tokens for better accuracy

### Fixed
- Floating indicator controls hidden when streaming text grows (window grew downward off-screen)
- Light mode text unreadable on accent backgrounds
- Picker/Select text invisible in light mode (color scheme mismatch)

## [0.2.0] - 2026-03-07

### Added
- On-device LLM formatting via Apple MLX (no API key required)
  - Supports Qwen3 0.6B/1.7B/4B, Gemma 3 1B, SmolLM3 3B
  - Download, load, and manage models directly from Settings
- First-launch onboarding wizard (mic, accessibility, model download)
- Whisper model selection (Auto, Tiny, Base, Small, Large-V3-Turbo)
- Sparkle auto-update framework with "Check for Updates" in menu bar
- Custom formatting prompts (General, Meeting Notes, Email + custom editor)
- Dictionary system for custom term correction
- Hover interactions and tooltips on all actionable buttons
- Release automation script (`scripts/release.sh`)
- English and Japanese UI localization
- GitHub Pages landing page

### Changed
- Formatting engine now supports Local (On-Device) as a provider
- Floating indicator shows error messages with auto-dismiss
- Separate bundle identifiers for Debug and Release builds

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
