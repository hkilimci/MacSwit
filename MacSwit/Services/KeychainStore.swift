import Foundation
import Security

/// Keychain işlemlerinde oluşabilecek hata türleri.
enum KeychainError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return "Keychain error (\(status))"
        case .invalidData:
            return "Invalid data in Keychain item"
        }
    }
}

/// macOS Keychain API'sini sarmalayan yardımcı sınıf.
///
/// Tuya Access Secret gibi hassas kimlik bilgilerini güvenli biçimde saklar,
/// okur ve siler. `shared` singleton örneği üzerinden uygulama genelinde kullanılır.
final class KeychainStore {
    static let shared = KeychainStore()

    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "MacSwit") {
        self.service = service
    }

    func saveSecret(_ secret: String, account: String) throws {
        let data = Data(secret.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        // Try to update existing item first (atomic operation)
        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Item doesn't exist, add it
            var addAttributes = query
            addAttributes[kSecValueData as String] = data
            let addStatus = SecItemAdd(addAttributes as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    func readSecret(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }

    func deleteSecret(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
