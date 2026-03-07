import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var showClearConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.l10n.history)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(DS.textNormal)
                    Text("\(appState.history.count) \(appState.l10n.transcriptions)")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.textMuted)
                }
                Spacer()
                if !appState.history.isEmpty {
                    Button {
                        showClearConfirm = true
                    } label: {
                        Text(appState.l10n.clearAll)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(DS.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                    }
                    .buttonStyle(.plain)
                    .alert(appState.l10n.clearAllConfirmTitle, isPresented: $showClearConfirm) {
                        Button(appState.l10n.clearAll, role: .destructive) {
                            appState.clearHistory()
                        }
                        Button(appState.l10n.cancel, role: .cancel) {}
                    } message: {
                        Text(appState.l10n.clearAllConfirmMessage)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 16)

            if appState.history.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundStyle(DS.textFaint)
                    Text(appState.l10n.noHistoryYet)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.textMuted)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(appState.history) { record in
                            HistoryRow(record: record)
                                .environmentObject(appState)
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 16)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: appState.history.map(\.id))
                }
            }
        }
        .background(DS.bgSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct HistoryRow: View {
    let record: TranscriptionRecord
    @EnvironmentObject var appState: AppState
    @ObservedObject private var playback = AudioPlaybackService.shared
    @State private var isHovered = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Status icon
                ZStack {
                    RoundedRectangle(cornerRadius: DS.radiusMedium)
                        .fill(statusColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: statusIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Badges row
                    HStack(spacing: 6) {
                        Text(record.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.system(size: 11))
                            .foregroundStyle(DS.textFaint)

                        Badge(text: formatDuration(record.duration), color: DS.textFaint)
                        Badge(text: record.mode.rawValue, color: record.mode == .fast ? DS.orange : DS.blurple)
                    }

                    // Content
                    if let text = record.formattedText ?? record.rawText {
                        Text(text)
                            .font(.system(size: 13))
                            .lineLimit(isExpanded ? nil : 2)
                            .foregroundStyle(DS.textNormal)
                            .onTapGesture { isExpanded.toggle() }
                    } else if record.status == .failed {
                        Text(record.errorMessage ?? "Transcription failed")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.red)
                    } else {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.6)
                            Text("Processing...")
                                .font(.system(size: 13))
                                .foregroundStyle(DS.textFaint)
                        }
                    }

                    // Raw text (if formatted exists)
                    if isExpanded, let formatted = record.formattedText, let raw = record.rawText, formatted != raw {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("RAW")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(DS.textFaint)
                            Text(raw)
                                .font(.system(size: 12))
                                .foregroundStyle(DS.textFaint)
                        }
                        .padding(8)
                        .background(DS.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                    }
                }

                Spacer()

                // Actions
                if isHovered || playback.isPlaying(record.id) {
                    HStack(spacing: 4) {
                        // Play/Stop audio
                        ActionButton(icon: playback.isPlaying(record.id) ? "stop.fill" : "play.fill") {
                            if playback.isPlaying(record.id) {
                                playback.stop()
                            } else {
                                playback.play(record: record)
                            }
                        }

                        if !record.displayText.isEmpty {
                            ActionButton(icon: "doc.on.doc") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(record.displayText, forType: .string)
                            }
                        }
                        if record.status == .failed || record.status == .success {
                            ActionButton(icon: "arrow.clockwise") {
                                appState.retryTranscription(record)
                            }
                        }
                        ActionButton(icon: "trash", destructive: true) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                appState.deleteRecord(record)
                            }
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)).animation(.spring(response: 0.25, dampingFraction: 0.8)),
                        removal: .opacity.animation(.easeOut(duration: 0.15))
                    ))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusMedium)
                    .fill(isHovered ? DS.bgModifierHover : .clear)
            )
        }
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }

    private var statusColor: Color {
        switch record.status {
        case .success: return DS.green
        case .failed: return DS.red
        case .transcribing: return DS.orange
        case .formatting: return DS.blurple
        }
    }

    private var statusIcon: String {
        switch record.status {
        case .success: return "checkmark"
        case .failed: return "exclamationmark.triangle"
        case .transcribing: return "waveform"
        case .formatting: return "sparkles"
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let seconds = Int(t)
        if seconds < 60 { return "\(seconds)s" }
        return "\(seconds / 60)m\(seconds % 60)s"
    }
}

// MARK: - Shared Components

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
    }
}

struct ActionButton: View {
    let icon: String
    var destructive = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(destructive ? DS.red : isHovered ? DS.textNormal : DS.textMuted)
                .frame(width: 28, height: 28)
                .background(isHovered ? DS.bgModifierActive : DS.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                .scaleEffect(isHovered ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
    }
}
