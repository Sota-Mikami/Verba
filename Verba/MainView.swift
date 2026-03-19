import SwiftUI

enum NavigationPage: String, CaseIterable {
    case dashboard
    case history
    case dictionary
    case settings

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .history: return "clock.arrow.circlepath"
        case .dictionary: return "character.book.closed"
        case .settings: return "gearshape.fill"
        }
    }

    func localizedName(_ l10n: L10n) -> String {
        switch self {
        case .dashboard: return l10n.dashboard
        case .history: return l10n.history
        case .dictionary: return l10n.dictionaryNav
        case .settings: return l10n.settings
        }
    }
}

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPage: NavigationPage = .dashboard
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { newValue in hasCompletedOnboarding = !newValue }
        )
    }

    @State private var showLicenseModal = false
    @State private var bannerDismissed = false
    @State private var upgradeHovered = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().foregroundStyle(DS.cardBorder)
            VStack(spacing: 0) {
                // Trial expiry banner
                if !bannerDismissed,
                   appState.licenseService.isTrial,
                   appState.licenseService.urgencyLevel != .normal {
                    TrialExpiryBanner(
                        urgency: appState.licenseService.urgencyLevel,
                        l10n: appState.l10n,
                        onAction: { showLicenseModal = true },
                        onDismiss: { withAnimation { bannerDismissed = true } }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                detail
                    .id(selectedPage)
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
            }
        }
        .background(DS.bgPrimary)
        .preferredColorScheme(appState.resolvedColorScheme)
        .animation(.easeOut(duration: 0.25), value: selectedPage)
        .sheet(isPresented: showOnboarding) {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                .environmentObject(appState)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showLicenseModal, onDismiss: {
            // Ensure modal state is cleared and UI refreshes after license modal closes
            showLicenseModal = false
            appState.licenseService.objectWillChange.send()
        }) {
            LicenseView(licenseService: appState.licenseService)
                .environmentObject(appState)
                .interactiveDismissDisabled(appState.licenseService.isLocked)
        }
        .onAppear { checkLicense() }
        .onReceive(appState.licenseService.$status) { newStatus in
            switch newStatus {
            case .trialExpired, .licenseExpired:
                showLicenseModal = true
            case .activated:
                // Don't dismiss immediately — let LicenseView show success celebration
                break
            default:
                break
            }
        }
    }

    private func checkLicense() {
        appState.licenseService.refreshStatus()
        if appState.licenseService.isLocked {
            showLicenseModal = true
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DS.blurple)
                        .frame(width: 36, height: 36)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.textOnAccent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Verba")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.textNormal)
                    Text(appState.l10n.voiceInput)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.textMuted)
                }
            }
            .padding(16)
            .padding(.bottom, 4)

            // Nav items
            VStack(spacing: 2) {
                ForEach(NavigationPage.allCases, id: \.self) { page in
                    SidebarItem(
                        title: page.localizedName(appState.l10n),
                        icon: page.icon,
                        isSelected: selectedPage == page,
                        badge: page == .history ? appState.unseenHistoryCount : nil
                    ) {
                        selectedPage = page
                        if page == .history {
                            appState.markHistorySeen()
                        }
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            // Trial badge with upgrade link
            if let remaining = appState.licenseService.trialRemainingFormatted {
                HStack(spacing: 0) {
                    TrialBadge(remaining: remaining, urgency: appState.licenseService.urgencyLevel)

                    Spacer()

                    Button {
                        showLicenseModal = true
                    } label: {
                        Text(appState.l10n.upgrade)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(upgradeHovered ? DS.blurple : DS.textLink)
                    }
                    .buttonStyle(.plain)
                    .onHover { upgradeHovered = $0 }
                    .animation(.easeOut(duration: 0.12), value: upgradeHovered)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            } else if appState.licenseService.isActivated {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.green)
                    Text(appState.l10n.licensedPlan)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }

            // Status
            HStack(spacing: 8) {
                ZStack {
                    if !appState.isModelLoaded {
                        Circle()
                            .fill(DS.orange.opacity(0.3))
                            .frame(width: 12, height: 12)
                            .scaleEffect(1.5)
                            .opacity(0.5)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: appState.isModelLoaded)
                    }
                    Circle()
                        .fill(appState.isModelLoaded ? DS.green : DS.orange)
                        .frame(width: 8, height: 8)
                }
                Text(appState.isModelLoaded ? appState.l10n.whisperReady : appState.l10n.loadingModel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.textMuted)
            }
            .padding(16)
            .animation(.easeOut(duration: 0.3), value: appState.isModelLoaded)
        }
        .frame(width: 200)
        .background(DS.bgTertiary)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selectedPage {
        case .dashboard:
            DashboardView().environmentObject(appState)
        case .history:
            HistoryView().environmentObject(appState)
        case .dictionary:
            DictionaryView().environmentObject(appState)
        case .settings:
            SettingsView().environmentObject(appState)
        }
    }
}

// MARK: - Sidebar Item

struct SidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var badge: Int? = nil
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? DS.blurple : DS.textMuted)
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DS.textNormal : DS.textMuted)
                Spacer()
                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.textOnAccent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(DS.blurple)
                        .clipShape(Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusMedium)
                    .fill(isSelected ? DS.bgModifierSelected : isHovered ? DS.bgModifierHover : .clear)
            )
            // Hover feedback via background only (no scale bounce)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.2), value: isSelected)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
