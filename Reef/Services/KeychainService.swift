//
//  KeychainService.swift
//  Reef
//

import Foundation
import Security

enum KeychainService {
    private static let service = "com.reef.auth"

    enum Key: String {
        case userIdentifier = "appleUserIdentifier"
        case userName = "appleUserName"
        case userEmail = "appleUserEmail"
    }

    static func save(_ value: String, for key: Key) {
        let data = Data(value.utf8)

        // Delete existing item first
        delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        print("DEBUG Keychain: save \(key.rawValue) status: \(status) (0 = success)")
    }

    static func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            print("DEBUG Keychain: get \(key.rawValue) failed with status: \(status) (-25300 = item not found)")
            return nil
        }

        print("DEBUG Keychain: get \(key.rawValue) succeeded: \(value.prefix(20))...")
        return value
    }

    static func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        SecItemDelete(query as CFDictionary)
    }

    static func deleteAll() {
        for key in [Key.userIdentifier, Key.userName, Key.userEmail] {
            delete(key)
        }
    }
}
