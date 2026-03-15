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

    @State private var showLicenseSheet = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                header
                    .offset(y: appeared ? 0 : 8)
                    .opacity(appeared ? 1 : 0)
                if appState.licenseService.isTrial {
                    trialStatusCard
                        .offset(y: appeared ? 0 : 10)
                        .opacity(appeared ? 1 : 0)
                }
                modeCards
                    .offset(y: appeared ? 0 : 12)
                    .opacity(appeared ? 1 : 0)
                statsGrid
                    .offset(y: appeared ? 0 : 12)
                    .opacity(appeared ? 1 : 0)
                recentSection
                    .offset(y: appeared ? 0 : 12)
                    .opacity(appeared ? 1 : 0)
            }
            .padding(28)
        }
        .sheet(isPresented: $showLicenseSheet) {
            LicenseView(licenseService: appState.licenseService)
                .environmentObject(appState)
        }
        .background(DS.bgSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.05)) {
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
                actionVerb: pttActionVerb,
                shortcutKeys: [appState.pttShortcut.label],
                description: appState.l10n.holdToRecord
            )
            ModeCard(
                icon: "waveform",
                iconColor: DS.green,
                title: appState.l10n.handsFree,
                actionVerb: hfActionVerb,
                shortcutKeys: [appState.hfShortcut.label],
                description: hfCardDescription
            )
        }
    }

    private var pttActionVerb: String {
        switch appState.pttShortcut.kind {
        case .modifierHold: return appState.l10n.holdAction
        case .keyCombo: return appState.l10n.pressAction
        case .doubleTap: return appState.l10n.doubleTapAction
        }
    }

    private var hfActionVerb: String {
        switch appState.hfShortcut.kind {
        case .doubleTap: return appState.l10n.doubleTapAction
        case .keyCombo: return appState.l10n.pressAction
        case .modifierHold: return appState.l10n.tapAction
        }
    }

    private var hfCardDescription: String {
        switch appState.hfShortcut.kind {
        case .doubleTap: return appState.l10n.toggleRecordingDesc(appState.l10n.doubleTapAction)
        case .keyCombo: return appState.l10n.toggleRecordingDesc(appState.l10n.pressAction)
        case .modifierHold: return appState.l10n.toggleRecordingDesc(appState.l10n.tapAction)
        }
    }

    // MARK: - Stats

    private var stats: (sessions: Int, words: Int, duration: TimeInterval) {
        (appState.lifetimeSessions, appState.lifetimeWords, appState.lifetimeDuration)
    }

    private var statsGrid: some View {
        HStack(spacing: 12) {
            StatCard(icon: "bubble.left.and.bubble.right.fill", iconColor: DS.blurple, label: appState.l10n.sessions, value: "\(stats.sessions)")
            StatCard(icon: "character.cursor.ibeam", iconColor: DS.green, label: appState.l10n.words, value: formatNumber(stats.words))
            StatCard(icon: "clock.fill", iconColor: DS.orange, label: appState.l10n.timeSaved, value: formatDuration(stats.duration))
        }
    }


    // MARK: - Trial Status Banner

    @State private var pricingHovered = false

    private var trialStatusCard: some View {
        let remaining = appState.licenseService.trialRemainingFormatted ?? ""
        let urgency = appState.licenseService.urgencyLevel
        let accentColor: Color = urgency == .critical1h ? DS.red : DS.blurple
        let trialProgress: Double = {
            guard case .trial(let rem) = appState.licenseService.status else { return 0 }
            return max(0, min(1, rem / LicenseConstants.trialDurationSeconds))
        }()

        return HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundStyle(accentColor)

            Text("\(appState.l10n.trialStatusTitle): \(remaining) \(appState.l10n.trialRemaining2)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.textNormal)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DS.bgTertiary)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor)
                        .frame(width: geo.size.width * trialProgress, height: 4)
                }
            }
            .frame(height: 6)

            Button {
                showLicenseSheet = true
            } label: {
                Text(appState.l10n.seePricing)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(pricingHovered ? accentColor.opacity(0.7) : accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accentColor.opacity(pricingHovered ? 0.15 : 0.08))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .onHover { pricingHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: pricingHovered)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(DS.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusMedium)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
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

}

// MARK: - Subviews

struct ModeCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let actionVerb: String
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
                Text(actionVerb)
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

struct RecentRow: View {
    let record: TranscriptionRecord
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.displayText.isEmpty ? (record.errorMessage ?? L10n.current.processing) : record.displayText)
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
                .help(L10n.current.copy)
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
