import Foundation
import Security

/// Manages secure storage of SMTP password and Kindle email in the macOS Keychain
struct KeychainManager {

    static let serviceName = "com.kindledrop.app"

    // MARK: - Save password

    static func savePassword(_ password: String, account: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }

        // Delete existing item first
        deletePassword(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Read password

    static func readPassword(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete password

    @discardableResult
    static func deletePassword(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Convenience for SMTP and Kindle

    static func saveSMTPPassword(_ password: String) -> Bool {
        return savePassword(password, account: "smtp_password")
    }

    static func readSMTPPassword() -> String? {
        return readPassword(account: "smtp_password")
    }

    static func saveKindleEmail(_ email: String) -> Bool {
        return savePassword(email, account: "kindle_email")
    }

    static func readKindleEmail() -> String? {
        return readPassword(account: "kindle_email")
    }
}