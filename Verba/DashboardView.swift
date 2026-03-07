import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var appeared = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let l = appState.l10n
        switch hour {
        case 5..<12: return l.goodMorning
        case 12..<17: return l.goodAfternoon
        case 17..<22: return l.goodEvening
        default: return l.goodNight
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                header
                    .offset(y: appeared ? 0 : 8)
                    .opacity(appeared ? 1 : 0)
                modeCards
                    .offset(y: appeared ? 0 : 12)
                    .opacity(appeared ? 1 : 0)
                statsGrid
                    .offset(y: appeared ? 0 : 12)
                    .opacity(appeared ? 1 : 0)
                usageCards
                    .offset(y: appeared ? 0 : 12)
                    .opacity(appeared ? 1 : 0)
                recentSection
                    .offset(y: appeared ? 0 : 12)
                    .opacity(appeared ? 1 : 0)
            }
            .padding(28)
        }
        .background(DS.bgSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.05)) {
                appeared = true
            }
        }
        .onDisappear { appeared = false }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(DS.textNormal)
            Text(appState.l10n.activitySubtitle)
                .font(.system(size: 14))
                .foregroundStyle(DS.textMuted)
        }
    }

    // MARK: - Mode Cards

    private var modeCards: some View {
        HStack(spacing: 12) {
            ModeCard(
                icon: "mic.fill",
                iconColor: DS.blurple,
                title: appState.l10n.pushToTalk,
                shortcutKeys: [appState.pttShortcut.label],
                description: appState.l10n.holdToRecord
            )
            ModeCard(
                icon: "waveform",
                iconColor: DS.green,
                title: appState.l10n.handsFree,
                shortcutKeys: [appState.hfShortcut.label],
                description: hfCardDescription
            )
        }
    }

    private var hfCardDescription: String {
        switch appState.hfShortcut.kind {
        case .doubleTap: return "Double-tap to toggle recording."
        case .keyCombo: return "Press to toggle recording."
        case .modifierHold: return "Tap to toggle recording."
        }
    }

    // MARK: - Stats

    private var stats: (sessions: Int, words: Int, duration: TimeInterval) {
        let sessions = appState.history.count
        let words = appState.history.reduce(0) { total, record in
            let text = record.displayText
            let spaceWords = text.split(separator: " ").count
            let jpChars = text.unicodeScalars.filter { $0.value >= 0x3000 && $0.value <= 0x9FFF }.count
            return total + spaceWords + jpChars
        }
        let duration = appState.history.reduce(0.0) { $0 + $1.duration }
        return (sessions, words, duration)
    }

    private var statsGrid: some View {
        HStack(spacing: 12) {
            StatCard(icon: "bubble.left.and.bubble.right.fill", iconColor: DS.blurple, label: appState.l10n.sessions, value: "\(stats.sessions)")
            StatCard(icon: "character.cursor.ibeam", iconColor: DS.green, label: appState.l10n.words, value: formatNumber(stats.words))
            StatCard(icon: "clock.fill", iconColor: DS.orange, label: appState.l10n.timeSaved, value: formatDuration(stats.duration))
        }
    }

    private var usageCards: some View {
        HStack(spacing: 12) {
            usageCard(title: appState.l10n.modeUsage) {
                UsageBar(label: "Fast", count: appState.history.filter { $0.mode == .fast }.count, total: max(appState.history.count, 1), color: DS.orange)
                UsageBar(label: "Formatted", count: appState.history.filter { $0.mode == .formatted }.count, total: max(appState.history.count, 1), color: DS.blurple)
            }
            usageCard(title: appState.l10n.languages) {
                let grouped = Dictionary(grouping: appState.history, by: { $0.language ?? "auto" })
                let sorted = grouped.sorted { $0.value.count > $1.value.count }
                ForEach(sorted.prefix(3), id: \.key) { lang, records in
                    UsageBar(label: languageName(lang), count: records.count, total: max(appState.history.count, 1), color: DS.blurpleLight)
                }
                if sorted.isEmpty {
                    Text(appState.l10n.noDataYet)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.textFaint)
                }
            }
        }
    }

    private func usageCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DS.textMuted)
                .textCase(.uppercase)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appState.l10n.recentTranscriptions)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DS.textMuted)

            if appState.history.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appState.history.prefix(5).enumerated()), id: \.element.id) { index, record in
                        RecentRow(record: record)
                        if index < min(4, appState.history.count - 1) {
                            Divider().foregroundStyle(DS.cardBorder)
                        }
                    }
                }
                .background(DS.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(DS.textFaint)
            Text(appState.l10n.noTranscriptionsYet)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.textMuted)
            Text(appState.l10n.holdFnToStart)
                .font(.system(size: 12))
                .foregroundStyle(DS.textFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(DS.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
    }

    // MARK: - Helpers

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000) }
        return "\(n)"
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let totalMinutes = Int(t) / 60
        if totalMinutes >= 60 { return "\(totalMinutes / 60)h \(totalMinutes % 60)m" }
        if totalMinutes > 0 { return "\(totalMinutes)m \(Int(t) % 60)s" }
        return "\(Int(t))s"
    }

    private func languageName(_ code: String) -> String {
        SpeechLanguage.all.first(where: { $0.code == code })?.displayName ?? appState.l10n.autoDetect
    }
}

// MARK: - Subviews

struct ModeCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let shortcutKeys: [String]
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DS.textNormal)
            }

            HStack(spacing: 4) {
                Text("Hold")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.textMuted)
                ForEach(Array(shortcutKeys.enumerated()), id: \.offset) { i, key in
                    if i > 0 {
                        Text("+")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.textFaint)
                    }
                    Text(key)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DS.textNormal)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DS.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                }
            }

            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(DS.textFaint)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
    }
}

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.radiusMedium)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textMuted)
                Text(value)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DS.textNormal)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
    }
}

struct UsageBar: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color
    @State private var animatedWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.textMuted)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.textNormal)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DS.bgTertiary)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: animatedWidth, height: 4)
                }
                .onAppear {
                    let target = max(0, geo.size.width * CGFloat(count) / CGFloat(total))
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                        animatedWidth = target
                    }
                }
            }
            .frame(height: 4)
        }
    }
}

struct RecentRow: View {
    let record: TranscriptionRecord
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.displayText.isEmpty ? (record.errorMessage ?? "Processing...") : record.displayText)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .foregroundStyle(record.displayText.isEmpty ? DS.textFaint : DS.textNormal)

                HStack(spacing: 8) {
                    Text(record.timestamp, style: .time)
                    Text(formatDuration(record.duration))
                    Text(record.mode.rawValue)
                }
                .font(.system(size: 11))
                .foregroundStyle(DS.textFaint)
            }

            Spacer()

            if isHovered && !record.displayText.isEmpty {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(record.displayText, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.textMuted)
                        .padding(6)
                        .background(DS.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isHovered ? DS.bgModifierHover : .clear)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }

    private var statusColor: Color {
        switch record.status {
        case .success: return DS.green
        case .failed: return DS.red
        case .transcribing, .formatting: return DS.orange
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let seconds = Int(t)
        if seconds < 60 { return "\(seconds)s" }
        return "\(seconds / 60)m\(seconds % 60)s"
    }
}
