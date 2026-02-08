import Foundation
import OSLog
import Security

/// Keychain persists across app reinstalls, making it suitable for small identifiers and flags.
struct KeychainService {
    private let logger = Logger(subsystem: "OnePlace", category: "KeychainService")
    private let service: String

    init(service: String = "com.tools-source.oneplace") {
        self.service = service
    }

    func setString(_ value: String, for key: KeychainKeys) throws {
        let data = Data(value.utf8)
        var query = baseQuery(for: key)
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            try updateItem(data: data, for: key)
        default:
            logger.error("Keychain add failed for \(key.rawValue, privacy: .public): \(status)")
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func getString(for key: KeychainKeys) throws -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                return nil
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            logger.error("Keychain read failed for \(key.rawValue, privacy: .public): \(status)")
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func setBool(_ value: Bool, for key: KeychainKeys) throws {
        try setString(value ? "1" : "0", for: key)
    }

    func getBool(for key: KeychainKeys) throws -> Bool? {
        guard let stringValue = try getString(for: key) else {
            return nil
        }
        return stringValue == "1"
    }

    func deleteValue(for key: KeychainKeys) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            logger.error("Keychain delete failed for \(key.rawValue, privacy: .public): \(status)")
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func updateItem(data: Data, for key: KeychainKeys) throws {
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery(for: key) as CFDictionary, attributes as CFDictionary)
        if status != errSecSuccess {
            logger.error("Keychain update failed for \(key.rawValue, privacy: .public): \(status)")
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func baseQuery(for key: KeychainKeys) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
    }
}

enum KeychainError: Error {
    case unexpectedStatus(OSStatus)
}
