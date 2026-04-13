import Foundation
import Security

// @unchecked Sendable: no mutable state; all Keychain ops are inherently thread-safe.
public final class KeychainManager: @unchecked Sendable {
    public static let shared = KeychainManager()

    /// Creates an isolated instance with a custom account name — intended for unit tests
    /// so test operations never touch the real app key.
    public static func testInstance(account: String) -> KeychainManager {
        KeychainManager(account: account)
    }

    private init(account: String = "anthropic-api-key") {
        self.account = account
    }

    private let service = "com.akshajravi.NotchLookup"
    private let account: String

    /// Saves the API key to Keychain using a delete-then-add pattern.
    /// Returns true on success.
    @discardableResult
    public func saveAPIKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }

        // Delete any existing item first so SecItemAdd never returns errSecDuplicateItem.
        deleteAPIKey()

        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecValueData:        data,
            // Item is accessible whenever the device is unlocked; survives reboots.
            kSecAttrAccessible:   kSecAttrAccessibleWhenUnlocked,
        ]

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    /// Returns the stored API key, or nil if not found.
    public func retrieveAPIKey() -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Removes the stored API key from Keychain.
    public func deleteAPIKey() {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  service,
            kSecAttrAccount:  account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
