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
            MenuBarButton(appState.l10n.openVerba, icon: "macwindow") {
                appState.mainWindow.open(appState: appState)
            }

            Divider()

            // Mode picker (same UX as prompt picker)
            Menu {
                ForEach(TranscriptionMode.allCases, id: \.self) { mode in
                    Button {
                        appState.mode = mode
                    } label: {
                        HStack {
                            Text(mode.rawValue)
                            if appState.mode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: appState.mode == .fast ? "bolt.fill" : "sparkles")
                        .frame(width: 16)
                        .foregroundStyle(.secondary)
                    Text(appState.mode.rawValue)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .contentShape(Rectangle())

            // Prompt picker (greyed out in Fast mode)
            Menu {
                ForEach(appState.allPrompts) { prompt in
                    Button {
                        appState.selectedPromptId = prompt.id.uuidString
                    } label: {
                        HStack {
                            Text(prompt.name)
                            if prompt.id.uuidString == appState.selectedPromptId {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "text.quote")
                        .frame(width: 16)
                        .foregroundStyle(.secondary)
                    Text(currentPromptName)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .opacity(appState.mode == .fast ? 0.4 : 1.0)
            .disabled(appState.mode == .fast)

            Divider()

            // Recent history (submenu, same UX as mode/prompt)
            Menu {
                let recent = Array(appState.history.prefix(10))
                if recent.isEmpty {
                    Text(appState.l10n.noHistory)
                } else {
                    ForEach(recent) { record in
                        let text = record.displayText
                        if !text.isEmpty {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(text, forType: .string)
                            } label: {
                                Text(String(text.prefix(50)))
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .frame(width: 16)
                        .foregroundStyle(.secondary)
                    Text(appState.l10n.recent)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .contentShape(Rectangle())

            Divider()

            MenuBarButton(appState.l10n.checkForUpdates, icon: "arrow.triangle.2.circlepath") {
                updater.checkForUpdates()
            }
            .disabled(!updateChecker.canCheckForUpdates)

            MenuBarButton(appState.l10n.quitVerba, icon: "xmark.circle") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.bottom, 4)
        }
        .frame(width: 260)
    }

    private var currentPromptName: String {
        appState.allPrompts.first(where: { $0.id.uuidString == appState.selectedPromptId })?.name ?? "General"
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
