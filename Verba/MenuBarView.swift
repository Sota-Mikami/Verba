import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

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
                    shortcutHint(label: "Push-to-talk", shortcut: "Hold Fn")
                    shortcutHint(label: "Hands-free", shortcut: "Fn × 2")
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
                            Text("Stop Recording")
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }

                Divider()

                // Language picker
                Picker("Language", selection: $appState.selectedLanguage) {
                    ForEach(appState.availableLanguages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                // Mode picker
                Picker("Mode", selection: $appState.mode) {
                    ForEach(TranscriptionMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            } else {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text("Loading model...")
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
                    Text("Last transcription")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(appState.lastTranscription)
                        .font(.system(size: 12))
                        .lineLimit(3)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(appState.lastTranscription, forType: .string)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }

            Divider()

            Button("Open Verba") {
                appState.mainWindow.open(appState: appState)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Button("Quit Verba") {
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
