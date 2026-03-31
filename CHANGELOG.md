# Changelog

All notable changes to Verba will be documented in this file.

## [1.4.0] - 2026-03-31

### Added
- **Onboarding model picker** — First-time users now choose their Whisper model explicitly (Tiny / Base / Small / Large V3 Turbo) instead of relying on auto-detection. Large V3 Turbo is pre-selected as the recommended default.
- **WhisperKit initialization timeout** — Model download and loading now time out after 120 seconds instead of waiting indefinitely. Prevents the app from getting stuck on launch when network, hardware, or CoreML issues cause a hang.
- **Initialization error recovery** — When model loading fails or times out, the sidebar shows an error state with a Retry button. During onboarding, users can also switch to a different model and retry.

### Changed
- **Deferred initialization for new users** — `initializeServices()` no longer runs before onboarding is complete. Model download starts only when the user reaches Step 3 and taps "Download & Continue".

### Fixed
- **Onboarding model download starting before user interaction** — Previously, the app began downloading the auto-detected model immediately on launch, before the user even saw the onboarding screen.

## [1.3.1] - 2026-03-25

### Fixed
- **Startup crash fix** — Resolved SIGTRAP crash on launch caused by `@AppStorage` with enum types receiving invalid UserDefaults values. All enum-backed settings now safely fall back to defaults.

## [1.3.0] - 2026-03-22

### Added
- **Writing Style personalization** — Each formatting prompt now has a Writing Style field. Define how your text should sound (tone, sentence endings, punctuation habits) independently from what the prompt does.
- **AI style extraction** — Paste samples of your writing and let the on-device LLM analyze your style into concrete rules. Results are a starting point you can edit.
- **Formatting settings UX** — When Output Mode is set to Fast, formatting-related sections are hidden with a hint and quick switch button to Formatted mode.

### Changed
- **Simplified prompt editor** — Removed few-shot example fields. System Prompt + Writing Style is sufficient for both local and cloud models.

### Fixed
- **Sidebar alignment** — License badge and Whisper status now share consistent indentation.

## [1.2.0] - 2026-03-20

### Added
- **Compact indicator mode** — Minimize the recording indicator to a slim bar at the bottom of the screen to avoid blocking content. Click to expand back.
- **Custom floating tooltips** — Action buttons (Stop & transcribe, Discard recording, Minimize) now show instant tooltips above the button, rendered in a separate window so they're never clipped.

### Changed
- **Recording action buttons** — Simplified to icon-only with instant tooltip labels instead of hover-expand text, reducing visual clutter when multiple buttons are present.

## [1.1.0] - 2026-03-19

### Added
- **Speech language settings** — Register the languages you speak in Settings > Transcription. Whisper uses your language list to avoid misdetection (e.g., Japanese no longer misrecognized as Korean).
- **Smart language detection** — With multiple languages registered, Verba runs language detection first and picks the best match from your list before transcribing. Single language skips detection entirely for fastest performance.
- **Detected language stored in history** — Each transcription record now includes the detected language.

## [1.0.1] - 2026-03-19

### Added
- **License status in sidebar** — Activated users see a green "Lifetime Plan" badge in the sidebar instead of the trial badge.
- **License info section in Settings** — Shows plan name, masked license key, and active status for activated users.

## [1.0.0] - 2026-03-19

### Added
- **License activation with LemonSqueezy integration** — Activate a license key to unlock the full version, powered by LemonSqueezy payment infrastructure.
- **Purchase celebration UI** — Confetti animation plays on successful license activation.
- **Terms of Service page** — Accessible from Settings and onboarding.

### Changed
- **Trial UI updates immediately after license activation** — No restart required; the UI reflects activated status instantly.

### Fixed
- **Improved error messages for license activation** — Localized EN/JA error messages for invalid keys, network failures, and expired licenses.
- **CoreML cache crash recovery for WhisperKit** — Automatically clears corrupted CoreML cache and retries model loading instead of crashing.
- **Onboarding LLM download for non-local formatting providers** — Onboarding no longer attempts to download an LLM model when cloud formatting is selected.

## [0.8.2] - 2026-03-12

### Added
- **Whisper model download progress in Settings** — Model section now shows a real-time progress bar with percentage during download and a spinner during loading, matching the sidebar indicator.

## [0.8.1] - 2026-03-12

### Fixed
- **Dashboard stats reset on history clear** — Sessions, Words, and Time Saved are now lifetime counters stored independently. Clearing history no longer resets dashboard statistics.
- **Large V3 Turbo model never finishes loading** — Incorrect model ID (`-turbo` → `_turbo`) prevented WhisperKit from finding the model. Existing users with the wrong ID are auto-migrated on launch.

## [0.8.0] - 2026-03-12

### Added
- **Compact indicator mode** — Minimize the recording indicator to a slim bar at the bottom of the screen to avoid blocking content. Click to expand back.
- **Custom floating tooltips** — Action buttons (Stop & transcribe, Discard recording, Minimize) now show instant tooltips above the button, rendered in a separate window so they're never clipped.

### Changed
- **Recording action buttons** — Simplified to icon-only with instant tooltip labels instead of hover-expand text, reducing visual clutter when multiple buttons are present.
- **Compact bar hover interaction** — Shows "Click to expand" hint with smooth animation on hover.

## [0.7.0] - 2026-03-12

### Added
- **LLM memory optimization** — Formatting model (LLM) is now loaded on-demand when recording starts and automatically unloaded after 5 minutes of idle to free memory (~2.5GB VRAM saved when idle).
- **LLM preloading** — LLM begins loading in the background while you speak, so formatting starts without delay in most cases.
- **Graceful LLM fallback** — If the formatting model fails to load (e.g. low memory), raw text is pasted with a brief notification instead of silently skipping.
- **Download-only on startup** — LLM model files are pre-downloaded at startup but not loaded into memory until first use.
- **Concurrent download guard** — Prevents duplicate model downloads that caused progress to jump back and forth.
- **Dictionary export button** — Export dictionary terms from the Dictionary view.

### Changed
- **Default formatting model** upgraded from Qwen3 0.6B to **Qwen3 4B** for significantly better formatting quality (existing users keep their current selection).
- **README roadmap** replaced inline list with link to GitHub Projects.

### Fixed
- **Progress bar regression** — Model download progress no longer jumps backwards when multiple download tasks race.

## [0.5.3] - 2026-03-09

### Fixed
- **Hotkey not responding** — Push-to-talk hold timer was blocked when the main thread was busy (e.g. during LLM model loading). Timer now runs on a background queue.

## [0.5.2] - 2026-03-09

### Added
- **Draggable floating indicator** — Drag the recording indicator anywhere on screen to avoid blocking content underneath.
- **Space-following indicator** — The indicator now follows you when switching between desktop Spaces.
- **History search** — Search through transcription history by text content.
- **History export** — Export history to Markdown file with timestamps, duration, and mode.
- **Dictionary export** — Export dictionary terms to a text file.

## [0.5.1] - 2026-03-09

### Fixed
- Minor bug fixes and stability improvements.

## [0.5.0] - 2026-03-09

### Fixed
- **Long recordings cut off after ~30 seconds** — Enabled VAD (Voice Activity Detection) chunking so WhisperKit now transcribes full audio length instead of only the first window.

## [0.4.9] - 2026-03-09

### Fixed
- **History not persisting across restarts** — Fixed date decoding mismatch that silently prevented history from loading on app launch.

## [0.4.8] - 2026-03-09

### Changed
- **Settings layout** — Voice Engine sections (Whisper model, prompt, formatting engine) are now always visible instead of hidden behind a collapsed toggle.

## [0.4.7] - 2026-03-09

### Changed
- **Default formatting to local LLM** — New users get on-device formatting (Qwen3 0.6B) out of the box, no API key needed. Auto-downloads on first launch.
- **Provider order** — Local (On-Device) is now the primary option in settings; cloud providers are secondary.

## [0.4.6] - 2026-03-09

### Added
- **History persistence** — Transcription history now survives app quit/restart. Audio and metadata saved to Application Support directory.

### Fixed
- **Floating indicator not resetting on new recording** — After cancelling a recording, waveform levels, streaming text, and timer now properly reset to zero when starting a new recording.

## [0.4.5] - 2026-03-08

### Fixed
- **Waveform barely visible** — Increased audio level amplification (×5 → ×40) so waveform bars respond visibly to normal speech
- **Timer resets to 0:00** — Elapsed time now persists correctly across view re-renders

## [0.4.4] - 2026-03-08

### Fixed
- **Transcription fails with "No speech detected"** — Fixed race condition where streaming transcription and final transcription ran concurrently on WhisperKit, causing empty results. Now waits for streaming to fully complete before final transcription.

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
