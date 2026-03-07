import SwiftUI

enum NavigationPage: String, CaseIterable {
    case dashboard = "Dashboard"
    case history = "History"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape.fill"
        }
    }
}

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPage: NavigationPage = .dashboard

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().foregroundStyle(DS.cardBorder)
            detail
                .id(selectedPage)
                .transition(.opacity.animation(.easeInOut(duration: 0.15)))
        }
        .background(DS.bgPrimary)
        .environment(\.colorScheme, .dark)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: selectedPage)
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
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Verba")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.textNormal)
                    Text("Voice Input")
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
                        title: page.rawValue,
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

            // Status
            HStack(spacing: 8) {
                ZStack {
                    if !appState.isModelLoaded {
                        Circle()
                            .fill(DS.orange.opacity(0.3))
                            .frame(width: 12, height: 12)
                            .scaleEffect(appState.isModelLoaded ? 1 : 1.5)
                            .opacity(appState.isModelLoaded ? 0 : 0.5)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: appState.isModelLoaded)
                    }
                    Circle()
                        .fill(appState.isModelLoaded ? DS.green : DS.orange)
                        .frame(width: 8, height: 8)
                }
                Text(appState.isModelLoaded ? "Whisper Ready" : "Loading...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.textMuted)
            }
            .padding(16)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: appState.isModelLoaded)
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
                    .foregroundStyle(isSelected ? .white : DS.textMuted)
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : DS.textMuted)
                Spacer()
                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
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
            .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
