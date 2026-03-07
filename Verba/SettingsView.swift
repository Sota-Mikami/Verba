import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                generalSection
                shortcutsSection
                languageSection
                modelSection
                apiSection
                accessibilityNote
            }
            .padding(24)
        }
        .frame(width: 520, height: 480)
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("General", icon: "gearshape")

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show in Dock")
                        .font(.body)
                    Text("Display the app icon in the Dock.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $appState.showInDock)
                    .toggleStyle(.switch)
            }
            .padding(12)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("System audio during recording")
                        .font(.body)
                    Text(systemAudioDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("", selection: $appState.systemAudioBehavior) {
                    ForEach(SystemAudioBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.rawValue).tag(behavior)
                    }
                }
                .frame(width: 160)
            }
            .padding(12)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Keyboard Shortcuts

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Keyboard Shortcuts", icon: "keyboard")

            ShortcutRow(
                title: "Push-to-talk",
                description: "Hold to record, release to transcribe and paste.",
                keys: ["Fn"]
            )

            ShortcutRow(
                title: "Hands-free",
                description: "Double-tap to start. Double-tap again to stop.",
                keys: ["Fn", "Fn"]
            )
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Language", icon: "globe")

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Speech language")
                        .font(.body)
                    Text("Language of your speech input.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("", selection: $appState.selectedLanguage) {
                    ForEach(appState.availableLanguages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                .frame(width: 160)
            }
            .padding(12)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Model

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Transcription", icon: "waveform")

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Whisper model")
                        .font(.body)
                    Text(appState.isModelLoaded ? "Loaded and ready" : "Downloading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(appState.isModelLoaded ? .green : .orange)
                    .frame(width: 8, height: 8)
            }
            .padding(12)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Output mode")
                        .font(.body)
                    Text("Fast: raw output. Formatted: AI-cleaned text.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("", selection: $appState.mode) {
                    ForEach(TranscriptionMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .frame(width: 140)
            }
            .padding(12)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - API

    private var apiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("OpenRouter API", icon: "network")

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("sk-or-...", text: $appState.openRouterApiKey)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Model")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("google/gemma-3-4b-it", text: $appState.openRouterModel)
                        .textFieldStyle(.roundedBorder)
                }

                Text("Used for Formatted mode. Recommended: gemma-3-4b-it (fast) or gemma-3-12b-it (balanced).")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Accessibility note

    private var accessibilityNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
                .font(.caption)
            Text("Set System Settings → Keyboard → \"Press 🌐 key to\" → **Do Nothing** for best results.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private var systemAudioDescription: String {
        switch appState.systemAudioBehavior {
        case .keepPlaying:
            return "Music and videos keep playing while recording."
        case .pauseMedia:
            return "Auto-pause media on record, resume when done."
        case .captureSystemAudio:
            return "Mix system audio into transcription input."
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

// MARK: - Shortcut Row

struct ShortcutRow: View {
    let title: String
    let description: String
    let keys: [String]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                    KeyBadge(key: key)
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Key Badge

struct KeyBadge: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.quaternary, lineWidth: 1)
            )
    }
}
