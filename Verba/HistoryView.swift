import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var showClearConfirm = false
    @State private var searchQuery = ""
    @State private var showSearch = false
    @State private var isSearchHovered = false
    @State private var isExportHovered = false

    private var filteredHistory: [TranscriptionRecord] {
        guard !searchQuery.isEmpty else { return appState.history }
        let q = searchQuery.lowercased()
        return appState.history.filter {
            ($0.formattedText ?? $0.rawText ?? "").lowercased().contains(q)
        }
    }

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
                    HStack(spacing: 8) {
                        // Export button
                        Button {
                            exportHistory()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 11))
                                Text(appState.l10n.exportHistory)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(isExportHovered ? DS.textNormal : DS.textMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isExportHovered ? DS.bgModifierHover : DS.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                        }
                        .buttonStyle(.plain)
                        .onHover { isExportHovered = $0 }
                        .animation(.easeOut(duration: 0.12), value: isExportHovered)

                        // Clear All button
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
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 16)

            // Search bar
            if !appState.history.isEmpty {
                HStack(spacing: 0) {
                    Spacer()
                    if showSearch {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12))
                                .foregroundStyle(DS.textFaint)
                            TextField(appState.l10n.searchHistory, text: $searchQuery)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .foregroundStyle(DS.textNormal)
                                .frame(width: 200)
                            Button {
                                searchQuery = ""
                                withAnimation { showSearch = false }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DS.textFaint)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(DS.inputBg)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    } else {
                        Button {
                            withAnimation { showSearch = true }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14))
                                .foregroundStyle(isSearchHovered ? DS.textNormal : DS.textMuted)
                                .padding(8)
                                .background(isSearchHovered ? DS.bgModifierHover : DS.bgTertiary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .onHover { isSearchHovered = $0 }
                        .animation(.easeOut(duration: 0.12), value: isSearchHovered)
                        .help("Search")
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 12)
            }

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
                        ForEach(filteredHistory) { record in
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
                    .animation(.easeOut(duration: 0.3), value: filteredHistory.map(\.id))
                }
            }
        }
        .background(DS.bgSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func exportHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "verba-history.md"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var md = "# Verba History\n\n"
        for record in appState.history where record.status == .success {
            let date = dateFormatter.string(from: record.timestamp)
            let duration = Int(record.duration)
            let text = record.displayText
            md += "## \(date) (\(duration)s, \(record.mode.rawValue))\n\n\(text)\n\n---\n\n"
        }

        try? md.write(to: url, atomically: true, encoding: .utf8)
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
                        Text(record.errorMessage ?? appState.l10n.transcriptionFailed)
                            .font(.system(size: 13))
                            .foregroundStyle(DS.red)
                    } else {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.6)
                            Text(appState.l10n.processing)
                                .font(.system(size: 13))
                                .foregroundStyle(DS.textFaint)
                        }
                    }

                    // Raw text (if formatted exists)
                    if isExpanded, let formatted = record.formattedText, let raw = record.rawText, formatted != raw {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.l10n.raw)
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
                        ActionButton(icon: playback.isPlaying(record.id) ? "stop.fill" : "play.fill", tooltip: playback.isPlaying(record.id) ? "Stop" : "Play") {
                            if playback.isPlaying(record.id) {
                                playback.stop()
                            } else {
                                playback.play(record: record)
                            }
                        }

                        if !record.displayText.isEmpty {
                            ActionButton(icon: "doc.on.doc", tooltip: "Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(record.displayText, forType: .string)
                            }
                        }
                        if record.status == .failed || record.status == .success {
                            ActionButton(icon: "arrow.clockwise", tooltip: "Retry") {
                                appState.retryTranscription(record)
                            }
                        }
                        ActionButton(icon: "trash", destructive: true, tooltip: "Delete") {
                            withAnimation(.easeOut(duration: 0.25)) {
                                appState.deleteRecord(record)
                            }
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)).animation(.easeOut(duration: 0.2)),
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
    var tooltip: String = ""
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
                // Hover feedback via background only
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .help(tooltip)
    }
}
