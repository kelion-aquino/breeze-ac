import Foundation
import OSLog
import Security

private let log = Logger(subsystem: "dev.breeze.Breeze", category: "keychain")

enum Keychain {
    private static func query(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func read(service: String, account: String) -> Data? {
        var query = query(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                log.error("Reading \(service, privacy: .public) failed: \(status) \(SecCopyErrorMessageString(status, nil) as String? ?? "", privacy: .public)")
            }
            return nil
        }
        return result as? Data
    }

    static func readString(service: String, account: String) -> String? {
        read(service: service, account: account)
            .map { String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    static func write(_ data: Data, service: String, account: String) {
        let query = query(service: service, account: account)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    static func delete(service: String, account: String) {
        SecItemDelete(query(service: service, account: account) as CFDictionary)
    }
}
