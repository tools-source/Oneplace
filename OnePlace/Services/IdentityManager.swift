import Foundation
import OSLog

/// Manages identifiers and entitlement flags that must persist across reinstalls.
final class IdentityManager {
    static let shared = IdentityManager()

    private let logger = Logger(subsystem: "OnePlace", category: "IdentityManager")
    private let keychain = KeychainService()

    private init() {}

    func getOrCreateAnonymousId() -> String {
        do {
            if let existing = try keychain.getString(for: .anonymousId) {
                return existing
            }

            let newId = UUID().uuidString
            try keychain.setString(newId, for: .anonymousId)
            return newId
        } catch {
            logger.error("Failed to access anonymous ID in Keychain: \(error.localizedDescription, privacy: .public)")
            return UUID().uuidString
        }
    }

    func setProUnlocked(_ value: Bool) {
        do {
            try keychain.setBool(value, for: .proUnlocked)
        } catch {
            logger.error("Failed to set pro unlock flag: \(error.localizedDescription, privacy: .public)")
        }
    }

    func isProUnlocked() -> Bool {
        do {
            return try keychain.getBool(for: .proUnlocked) ?? false
        } catch {
            logger.error("Failed to read pro unlock flag: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func setEarlyUser(_ value: Bool) {
        do {
            try keychain.setBool(value, for: .earlyUser)
        } catch {
            logger.error("Failed to set early user flag: \(error.localizedDescription, privacy: .public)")
        }
    }

    func isEarlyUser() -> Bool {
        do {
            return try keychain.getBool(for: .earlyUser) ?? false
        } catch {
            logger.error("Failed to read early user flag: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
