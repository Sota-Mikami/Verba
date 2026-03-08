import SwiftUI
import Sparkle

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    let updater: SPUUpdater
    @StateObject private var updateChecker: UpdateChecker

    init(updater: SPUUpdater) {
        self.updater = updater
        self._updateChecker = StateObject(wrappedValue: UpdateChecker(updater: updater))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text(appState.mode.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Last transcription
            if !appState.lastTranscription.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text(appState.lastTranscription)
                        .font(.system(size: 12))
                        .lineLimit(3)
                        .foregroundStyle(.primary)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(appState.lastTranscription, forType: .string)
                    } label: {
                        Label(appState.l10n.copy, systemImage: "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }

            Divider()

            // Actions
            MenuBarButton(appState.l10n.openVerba, icon: "macwindow") {
                appState.mainWindow.open(appState: appState)
            }

            MenuBarButton(appState.l10n.checkForUpdates, icon: "arrow.triangle.2.circlepath") {
                updater.checkForUpdates()
            }
            .disabled(!updateChecker.canCheckForUpdates)

            Divider()

            MenuBarButton(appState.l10n.quitVerba, icon: "xmark.circle") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.bottom, 4)
        }
        .frame(width: 260)
    }

    private var statusLabel: String {
        if appState.isRecording { return appState.l10n.stopRecording }
        if appState.isProcessing { return appState.statusMessage }
        if !appState.isModelLoaded { return appState.l10n.loadingModel }
        return appState.l10n.ready
    }

    private var statusColor: Color {
        if appState.isRecording { return .red }
        if appState.isProcessing { return .orange }
        if !appState.isModelLoaded { return .yellow }
        return .green
    }
}

private struct MenuBarButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    init(_ label: String, icon: String, action: @escaping () -> Void) {
        self.label = label
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 16)
                    .foregroundStyle(.secondary)
                Text(label)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
