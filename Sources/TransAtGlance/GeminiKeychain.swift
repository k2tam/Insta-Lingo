import Foundation
import LookupCore
import Security

struct GeminiKeychain: GeminiCredentialStoring {
    private let service = "com.k2tam.TransAtGlance.gemini"
    private let account = "api-key"

    func read() throws -> String? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query(returnData: true) as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw GeminiKeychainError.unavailable
        }
        return key
    }

    func save(_ key: String) throws {
        let data = Data(key.utf8)
        let status = SecItemAdd(query(value: data) as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update = [kSecValueData as String: data] as CFDictionary
            guard SecItemUpdate(query() as CFDictionary, update) == errSecSuccess else {
                throw GeminiKeychainError.unavailable
            }
        } else if status != errSecSuccess {
            throw GeminiKeychainError.unavailable
        }
    }

    func delete() throws {
        let status = SecItemDelete(query() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GeminiKeychainError.unavailable
        }
    }

    private func query(returnData: Bool = false, value: Data? = nil) -> [String: Any] {
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

private enum GeminiKeychainError: Error {
    case unavailable
}
