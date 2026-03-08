import SwiftUI

struct LicenseView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var licenseService: LicenseService
    @State private var licenseKey = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(DS.blurple.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(DS.blurple)
                }

                Text("Verba")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DS.textNormal)

                Text(headerMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            Divider().foregroundStyle(DS.cardBorder)

            // License key input
            VStack(alignment: .leading, spacing: 12) {
                Text(appState.l10n.licenseKey)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DS.textMuted)

                TextField("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX", text: $licenseKey)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(10)
                    .background(DS.inputBg)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                    .foregroundStyle(DS.textNormal)

                if let error = licenseService.activationError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.red)
                }

                // Activate button
                Button {
                    Task { await licenseService.activate(licenseKey: licenseKey) }
                } label: {
                    HStack {
                        if licenseService.isActivating {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.8)
                        }
                        Text(appState.l10n.activateLicense)
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(licenseKey.isEmpty ? DS.blurple.opacity(0.4) : DS.blurple)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                }
                .buttonStyle(.plain)
                .disabled(licenseKey.isEmpty || licenseService.isActivating)
            }
            .padding(24)

            Divider().foregroundStyle(DS.cardBorder)

            // Purchase + Sponsors links
            VStack(spacing: 10) {
                Button {
                    if let url = URL(string: LicenseConstants.lemonSqueezyStoreURL) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "cart")
                            .font(.system(size: 12))
                        Text(appState.l10n.purchaseLicense)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(DS.blurple)
                }
                .buttonStyle(.plain)

                Button {
                    if let url = URL(string: "https://github.com/sponsors/Sota-Mikami") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "heart")
                            .font(.system(size: 12))
                        Text(appState.l10n.sponsorOnGitHub)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(DS.textMuted)
                }
                .buttonStyle(.plain)

                Text(appState.l10n.supportNote)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textFaint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .padding(.vertical, 16)
            .padding(.bottom, 8)
        }
        .frame(width: 420)
        .background(DS.bgSecondary)
        .onChange(of: licenseService.status) { newStatus in
            if case .activated = newStatus {
                dismiss()
            }
        }
    }

    private var headerMessage: String {
        if case .licenseExpired = licenseService.status {
            return appState.l10n.licenseExpiredMessage
        }
        return appState.l10n.trialExpiredMessage
    }
}

// MARK: - Trial Banner (for sidebar/dashboard)

struct TrialBadge: View {
    let remaining: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 9))
            Text(remaining)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(DS.orange)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(DS.orange.opacity(0.15))
        .clipShape(Capsule())
    }
}
