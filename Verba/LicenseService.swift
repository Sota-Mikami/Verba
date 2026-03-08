import Foundation
import Security
import os

private let logger = Logger(subsystem: "com.sotamikami.verba", category: "License")

// MARK: - Constants

enum LicenseConstants {
    static let trialDurationSeconds: TimeInterval = 48 * 60 * 60 // 48 hours
    static let keychainService = "com.sotamikami.verba.license"
    static let keychainTrialStart = "trialStartDate"
    static let keychainLicenseKey = "licenseKey"
    static let keychainActivated = "activated"

    // LemonSqueezy — these are public-facing, not secrets
    static let lemonSqueezyStoreURL = "https://verba-app.lemonsqueezy.com/buy/YOUR_PRODUCT_ID" // TODO: Replace with actual product URL
    static let lemonSqueezyActivateURL = "https://api.lemonsqueezy.com/v1/licenses/activate"
}

// MARK: - License Status

enum LicenseStatus: Equatable {
    case trial(remaining: TimeInterval)
    case expired
    case activated
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
        #if DEBUG
        status = .activated
        return
        #endif

        // Check if already activated
        if KeychainHelper.load(key: LicenseConstants.keychainActivated) == "true" {
            status = .activated
            return
        }

        // Check trial
        if let startString = KeychainHelper.load(key: LicenseConstants.keychainTrialStart),
           let startDate = Double(startString) {
            let elapsed = Date().timeIntervalSince1970 - startDate
            let remaining = LicenseConstants.trialDurationSeconds - elapsed
            if remaining > 0 {
                status = .trial(remaining: remaining)
            } else {
                status = .expired
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
        if case .expired = status { return true }
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
            let activated = try await callActivateAPI(key: trimmed)
            if activated {
                KeychainHelper.save(key: LicenseConstants.keychainLicenseKey, value: trimmed)
                KeychainHelper.save(key: LicenseConstants.keychainActivated, value: "true")
                status = .activated
                logger.info("License activated successfully")
            }
        } catch {
            activationError = error.localizedDescription
            logger.error("Activation failed: \(error.localizedDescription)")
        }

        isActivating = false
    }

    private func callActivateAPI(key: String) async throws -> Bool {
        guard let url = URL(string: LicenseConstants.lemonSqueezyActivateURL) else {
            throw LicenseError.invalidURL
        }

        // Get a machine identifier for instance_name
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
            // Parse response to confirm activation
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let activated = json["activated"] as? Bool, activated {
                return true
            }
            // Some responses have "valid" instead
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let valid = json["valid"] as? Bool, valid {
                return true
            }
            return true // 200 = success
        } else if httpResponse.statusCode == 404 {
            throw LicenseError.invalidKey
        } else if httpResponse.statusCode == 422 {
            // Parse error message
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? String {
                throw LicenseError.apiError(error)
            }
            throw LicenseError.activationLimitReached
        } else {
            throw LicenseError.apiError("HTTP \(httpResponse.statusCode)")
        }
    }

    // MARK: - Deactivate (for settings)

    func deactivate() {
        KeychainHelper.delete(key: LicenseConstants.keychainActivated)
        KeychainHelper.delete(key: LicenseConstants.keychainLicenseKey)
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
        switch self {
        case .invalidURL: return "Invalid activation URL"
        case .networkError: return "Network error. Check your connection."
        case .invalidKey: return "Invalid license key."
        case .activationLimitReached: return "Activation limit reached for this key."
        case .apiError(let msg): return msg
        }
    }
}
