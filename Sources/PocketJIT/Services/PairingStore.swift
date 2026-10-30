import Foundation
import Security

/// Persists the device pairing record (the thing that normally lives at
/// `~/.pymobiledevice3` / `rp_pairing_file.plist` on a computer) in the
/// Keychain, so it survives app relaunches but never leaves the device.
enum PairingStore {
    private static let account = "pocketjit.pairing-record"
    private static let service = "com.pocketjit.app"

    static func save(_ data: Data) throws {
        var query = baseQuery()
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PairingStoreError.keychain(status)
        }
    }

    static func currentPairingData() -> Data? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static var isPaired: Bool { currentPairingData() != nil }

    static func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

enum PairingStoreError: LocalizedError {
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keychain(let status):
            return "Keychain error while storing pairing record (status \(status))."
        }
    }
}
