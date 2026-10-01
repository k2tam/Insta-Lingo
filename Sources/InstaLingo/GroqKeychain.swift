import Foundation
import LookupCore
import Security

/// Stores each API key as its own generic password, keyed by account.
struct GroqKeychain: GroqCredentialStoring {
    private let service = "com.k2tam.InstaLingo.groq"

    func read(account: String) throws -> String? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query(account: account, returnData: true) as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw GroqKeychainError.unavailable
        }
        return key
    }

    func save(_ key: String, account: String) throws {
        let data = Data(key.utf8)
        let status = SecItemAdd(query(account: account, value: data) as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update = [kSecValueData as String: data] as CFDictionary
            guard SecItemUpdate(query(account: account) as CFDictionary, update) == errSecSuccess else {
                throw GroqKeychainError.unavailable
            }
        } else if status != errSecSuccess {
            throw GroqKeychainError.unavailable
        }
    }

    func delete(account: String) throws {
        let status = SecItemDelete(query(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GroqKeychainError.unavailable
        }
    }

    private func query(account: String, returnData: Bool = false, value: Data? = nil) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if returnData {
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        }
        if let value {
            query[kSecValueData as String] = value
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
        return query
    }
}

private enum GroqKeychainError: Error {
    case unavailable
}
