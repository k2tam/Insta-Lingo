import Foundation
import LookupCore
import Security

struct GroqKeychain: GroqCredentialStoring {
    private let service = "com.k2tam.TransAtGlance.groq"
    private let account = "api-key"

    func read() throws -> String? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query(returnData: true) as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw GroqKeychainError.unavailable
        }
        return key
    }

    func save(_ key: String) throws {
        let data = Data(key.utf8)
        let status = SecItemAdd(query(value: data) as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update = [kSecValueData as String: data] as CFDictionary
            guard SecItemUpdate(query() as CFDictionary, update) == errSecSuccess else {
                throw GroqKeychainError.unavailable
            }
        } else if status != errSecSuccess {
            throw GroqKeychainError.unavailable
        }
    }

    func delete() throws {
        let status = SecItemDelete(query() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GroqKeychainError.unavailable
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

private enum GroqKeychainError: Error {
    case unavailable
}
