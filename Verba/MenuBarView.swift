import SwiftUI
import Sparkle

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    let updater: SPUUpdater

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(appState.statusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                Spacer()
                if appState.isModelLoaded {
                    Text(appState.mode.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if appState.isModelLoaded {
                // Shortcuts hint
                VStack(spacing: 6) {
                    shortcutHint(label: appState.l10n.pushToTalk, shortcut: appState.pttShortcut.label)
                    shortcutHint(label: appState.l10n.handsFree, shortcut: appState.hfShortcut.label)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                if appState.isRecording {
                    Button {
                        appState.toggleRecording()
                    } label: {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                                .foregroundStyle(.red)
                            Text(appState.l10n.stopRecording)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }

                Divider()

                // Mode picker
                Picker(appState.l10n.mode, selection: $appState.mode) {
                    ForEach(TranscriptionMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                // Prompt picker (only in Formatted mode)
                if appState.mode == .formatted {
                    Picker(appState.l10n.prompt, selection: $appState.selectedPromptId) {
                        ForEach(appState.allPrompts) { prompt in
                            Text(prompt.name).tag(prompt.id.uuidString)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
            } else {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text(appState.l10n.loadingModel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            // Last transcription
            if !appState.lastTranscription.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.l10n.lastTranscription)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(appState.lastTranscription)
                        .font(.system(size: 12))
                        .lineLimit(3)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Button(appState.l10n.copy) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(appState.lastTranscription, forType: .string)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }

            Divider()

            Button(appState.l10n.openVerba) {
                appState.mainWindow.open(appState: appState)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Button(appState.l10n.checkForUpdates) {
                updater.checkForUpdates()
            }
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Button(appState.l10n.quitVerba) {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .padding(.bottom, 4)
        }
        .frame(width: 240)
    }

    private func shortcutHint(label: String, shortcut: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(shortcut)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        if appState.isRecording { return .red }
        if appState.isProcessing { return .orange }
        if !appState.isModelLoaded { return .yellow }
        return .green
    }
}
