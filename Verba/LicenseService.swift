import Foundation
import Security
import os

private let logger = Logger(subsystem: "com.sotamikami.verba", category: "License")

// MARK: - Constants

enum LicenseConstants {
    static let trialDurationSeconds: TimeInterval = 48 * 60 * 60 // 48 hours
    static let validateIntervalSeconds: TimeInterval = 7 * 24 * 60 * 60 // Re-validate weekly
    static let keychainService = "com.sotamikami.verba.license"
    static let keychainTrialStart = "trialStartDate"
    static let keychainLicenseKey = "licenseKey"
    static let keychainActivated = "activated"
    static let keychainExpiresAt = "expiresAt"
    static let keychainLastValidated = "lastValidated"
    static let keychainLastActive = "lastActiveDate"
    static let inactiveRetrialSeconds: TimeInterval = 365 * 24 * 60 * 60 // 1 year

    // LemonSqueezy — these are public-facing, not secrets
    static let lemonSqueezyStoreURL = "https://verba-app.lemonsqueezy.com/checkout/buy/4857fb02-ce31-4fb8-8b8b-48d2e5e92629"
    static let lemonSqueezyActivateURL = "https://api.lemonsqueezy.com/v1/licenses/activate"
    static let lemonSqueezyValidateURL = "https://api.lemonsqueezy.com/v1/licenses/validate"
}

// MARK: - License Status

enum LicenseStatus: Equatable {
    case trial(remaining: TimeInterval)
    case trialExpired
    case activated(expiresAt: Date?)
    case licenseExpired
}

// MARK: - Keychain Helper

private enum KeychainHelper {

    static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: LicenseConstants.keychainService,
            kSecAttrAccount as String: key,
        ]

        // Delete existing
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Keychain save failed for \(key): \(status)")
        }
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: LicenseConstants.keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: LicenseConstants.keychainService,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - License Service

@MainActor
class LicenseService: ObservableObject {
    @Published var status: LicenseStatus = .trial(remaining: LicenseConstants.trialDurationSeconds)
    @Published var isActivating = false
    @Published var activationError: String?

    init() {
        refreshStatus()
    }

    // MARK: - Status Check

    func refreshStatus() {
        // TEMPORARILY DISABLED for testing
        // #if DEBUG
        // status = .activated(expiresAt: nil)
        // return
        // #endif

        // Check if already activated
        if KeychainHelper.load(key: LicenseConstants.keychainActivated) == "true" {
            // Check if license has expiration
            if let expiresString = KeychainHelper.load(key: LicenseConstants.keychainExpiresAt),
               let expiresTimestamp = Double(expiresString) {
                let expiresAt = Date(timeIntervalSince1970: expiresTimestamp)
                if expiresAt > Date() {
                    status = .activated(expiresAt: expiresAt)
                    // Trigger background re-validation if due
                    scheduleValidationIfNeeded()
                } else {
                    status = .licenseExpired
                }
            } else {
                // No expiration stored (legacy or lifetime) — treat as active
                status = .activated(expiresAt: nil)
                scheduleValidationIfNeeded()
            }
            return
        }

        // Check trial
        if let startString = KeychainHelper.load(key: LicenseConstants.keychainTrialStart),
           let startDate = Double(startString) {
            let elapsed = Date().timeIntervalSince1970 - startDate
            let remaining = LicenseConstants.trialDurationSeconds - elapsed
            if remaining > 0 {
                status = .trial(remaining: remaining)
            } else if shouldGrantRetrial() {
                resetTrial()
                logger.info("Re-trial granted after 1+ year of inactivity")
            } else {
                status = .trialExpired
            }
        } else {
            // First launch — start trial
            let now = String(Date().timeIntervalSince1970)
            KeychainHelper.save(key: LicenseConstants.keychainTrialStart, value: now)
            status = .trial(remaining: LicenseConstants.trialDurationSeconds)
            logger.info("Trial started")
        }
    }

    var isLocked: Bool {
        switch status {
        case .trialExpired, .licenseExpired: return true
        default: return false
        }
    }

    // MARK: - Trial Urgency

    enum TrialUrgency {
        case normal, warning24h, critical1h
    }

    var urgencyLevel: TrialUrgency {
        guard case .trial(let remaining) = status else { return .normal }
        if remaining <= 3600 { return .critical1h }
        if remaining <= 86400 { return .warning24h }
        return .normal
    }

    var isTrial: Bool {
        if case .trial = status { return true }
        return false
    }

    var trialRemainingFormatted: String? {
        guard case .trial(let remaining) = status else { return nil }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var licenseExpiresFormatted: String? {
        guard case .activated(let expiresAt) = status, let date = expiresAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Activity Tracking & Re-trial

    /// Record user activity (call on each recording session)
    func recordActivity() {
        KeychainHelper.save(key: LicenseConstants.keychainLastActive, value: String(Date().timeIntervalSince1970))
    }

    /// Check if user has been inactive for 1+ year and deserves a fresh trial
    private func shouldGrantRetrial() -> Bool {
        guard let lastActiveString = KeychainHelper.load(key: LicenseConstants.keychainLastActive),
              let lastActive = Double(lastActiveString) else {
            // No activity recorded — use trial start as proxy
            guard let startString = KeychainHelper.load(key: LicenseConstants.keychainTrialStart),
                  let startDate = Double(startString) else { return false }
            let elapsed = Date().timeIntervalSince1970 - startDate
            return elapsed >= LicenseConstants.inactiveRetrialSeconds
        }
        let elapsed = Date().timeIntervalSince1970 - lastActive
        return elapsed >= LicenseConstants.inactiveRetrialSeconds
    }

    /// Reset trial to a fresh 48-hour window
    private func resetTrial() {
        let now = String(Date().timeIntervalSince1970)
        KeychainHelper.save(key: LicenseConstants.keychainTrialStart, value: now)
        KeychainHelper.delete(key: LicenseConstants.keychainLastActive)
        status = .trial(remaining: LicenseConstants.trialDurationSeconds)
    }

    // MARK: - LemonSqueezy Activation

    func activate(licenseKey: String) async {
        let trimmed = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            activationError = "Please enter a license key"
            return
        }

        isActivating = true
        activationError = nil

        do {
            let result = try await callActivateAPI(key: trimmed)
            KeychainHelper.save(key: LicenseConstants.keychainLicenseKey, value: trimmed)
            KeychainHelper.save(key: LicenseConstants.keychainActivated, value: "true")
            KeychainHelper.save(key: LicenseConstants.keychainLastValidated, value: String(Date().timeIntervalSince1970))
            if let expiresAt = result.expiresAt {
                KeychainHelper.save(key: LicenseConstants.keychainExpiresAt, value: String(expiresAt.timeIntervalSince1970))
                status = .activated(expiresAt: expiresAt)
            } else {
                status = .activated(expiresAt: nil)
            }
            logger.info("License activated successfully")
        } catch {
            activationError = error.localizedDescription
            logger.error("Activation failed: \(error.localizedDescription)")
        }

        isActivating = false
    }

    // MARK: - Periodic Validation

    private func scheduleValidationIfNeeded() {
        guard let lastString = KeychainHelper.load(key: LicenseConstants.keychainLastValidated),
              let lastTimestamp = Double(lastString) else {
            // Never validated remotely — do it now
            triggerBackgroundValidation()
            return
        }
        let elapsed = Date().timeIntervalSince1970 - lastTimestamp
        if elapsed > LicenseConstants.validateIntervalSeconds {
            triggerBackgroundValidation()
        }
    }

    private func triggerBackgroundValidation() {
        guard let storedKey = KeychainHelper.load(key: LicenseConstants.keychainLicenseKey) else { return }
        Task {
            await validateLicense(key: storedKey)
        }
    }

    private func validateLicense(key: String) async {
        do {
            let result = try await callValidateAPI(key: key)
            KeychainHelper.save(key: LicenseConstants.keychainLastValidated, value: String(Date().timeIntervalSince1970))

            if !result.valid {
                // License revoked or invalid
                KeychainHelper.save(key: LicenseConstants.keychainActivated, value: "false")
                status = .licenseExpired
                logger.info("License validation failed — license revoked")
                return
            }

            // Update expiration from server
            if let expiresAt = result.expiresAt {
                KeychainHelper.save(key: LicenseConstants.keychainExpiresAt, value: String(expiresAt.timeIntervalSince1970))
                if expiresAt > Date() {
                    status = .activated(expiresAt: expiresAt)
                } else {
                    status = .licenseExpired
                    logger.info("License expired (server confirmed)")
                }
            }

            logger.info("License re-validated successfully")
        } catch {
            // Network error during background validation — keep current status (offline grace)
            logger.debug("Background validation failed (offline?): \(error.localizedDescription)")
        }
    }

    // MARK: - API Calls

    private struct APIResult {
        let valid: Bool
        let expiresAt: Date?
    }

    private func callActivateAPI(key: String) async throws -> APIResult {
        guard let url = URL(string: LicenseConstants.lemonSqueezyActivateURL) else {
            throw LicenseError.invalidURL
        }

        let instanceName = Host.current().localizedName ?? "Mac"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: String] = [
            "license_key": key,
            "instance_name": instanceName,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LicenseError.networkError
        }

        if httpResponse.statusCode == 200 {
            return parseAPIResponse(data: data)
        } else if httpResponse.statusCode == 404 {
            throw LicenseError.invalidKey
        } else {
            // 400, 422, etc. — parse error from response body
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? String {
                // LemonSqueezy returns descriptive errors like "license key has reached activation limit"
                if error.lowercased().contains("limit") {
                    throw LicenseError.activationLimitReached
                }
                throw LicenseError.apiError(error)
            }
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 422 {
                throw LicenseError.activationLimitReached
            }
            throw LicenseError.apiError("HTTP \(httpResponse.statusCode)")
        }
    }

    private func callValidateAPI(key: String) async throws -> APIResult {
        guard let url = URL(string: LicenseConstants.lemonSqueezyValidateURL) else {
            throw LicenseError.invalidURL
        }

        let instanceName = Host.current().localizedName ?? "Mac"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: String] = [
            "license_key": key,
            "instance_name": instanceName,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LicenseError.networkError
        }

        if httpResponse.statusCode == 200 {
            return parseAPIResponse(data: data)
        } else {
            throw LicenseError.apiError("Validation failed: HTTP \(httpResponse.statusCode)")
        }
    }

    /// Parse LemonSqueezy activate/validate response.
    /// Response shape: { "valid": bool, "license_key": { "expires_at": "ISO8601 | null", ... }, ... }
    private func parseAPIResponse(data: Data) -> APIResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.error("Failed to parse license API response JSON")
            return APIResult(valid: false, expiresAt: nil)
        }

        let valid = (json["valid"] as? Bool) ?? (json["activated"] as? Bool) ?? false

        // expires_at lives inside license_key object
        var expiresAt: Date?
        if let licenseKey = json["license_key"] as? [String: Any],
           let expiresString = licenseKey["expires_at"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            expiresAt = formatter.date(from: expiresString)
            // Retry without fractional seconds
            if expiresAt == nil {
                formatter.formatOptions = [.withInternetDateTime]
                expiresAt = formatter.date(from: expiresString)
            }
        }

        return APIResult(valid: valid, expiresAt: expiresAt)
    }

    // MARK: - Deactivate (for settings)

    func deactivate() {
        KeychainHelper.delete(key: LicenseConstants.keychainActivated)
        KeychainHelper.delete(key: LicenseConstants.keychainLicenseKey)
        KeychainHelper.delete(key: LicenseConstants.keychainExpiresAt)
        KeychainHelper.delete(key: LicenseConstants.keychainLastValidated)
        refreshStatus()
        logger.info("License deactivated")
    }
}

// MARK: - Errors

enum LicenseError: LocalizedError {
    case invalidURL
    case networkError
    case invalidKey
    case activationLimitReached
    case apiError(String)

    var errorDescription: String? {
        let ja = L10n.current.lang == .ja
        switch self {
        case .invalidURL: return ja ? "無効なURLです" : "Invalid activation URL"
        case .networkError: return ja ? "ネットワークエラー。接続を確認してください。" : "Network error. Check your connection."
        case .invalidKey: return ja ? "無効なライセンスキーです。" : "Invalid license key."
        case .activationLimitReached: return ja ? "このキーのアクティベーション回数が上限に達しました。" : "Activation limit reached for this key."
        case .apiError(let msg): return msg
        }
    }
}
