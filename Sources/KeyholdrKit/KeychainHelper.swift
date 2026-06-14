import Foundation
import LocalAuthentication
import Security

public struct KeychainHelper {
    private static let service = "com.olixstudios.Keyholdr"

    @discardableResult
    public static func save(secret: String, for id: UUID) -> Bool {
        guard let data = secret.data(using: .utf8) else { return false }
        let account = id.uuidString

        // Remove existing item if present to prevent duplicate errors
        delete(for: id)

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        // Bind the item to user presence (Touch ID, Apple Watch, or login
        // password) so the OS itself enforces the gate — not just the app's
        // LocalAuthentication check before calling retrieve(). On machines
        // with no device-owner authentication at all (CI/VM), skip straight
        // to the plain-accessibility item, exactly as before.
        if LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil),
           let access = SecAccessControlCreateWithFlags(
               kCFAllocatorDefault,
               kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
               .userPresence,
               nil
           ) {
            var protectedQuery = baseQuery
            protectedQuery[kSecAttrAccessControl as String] = access
            let status = SecItemAdd(protectedQuery as CFDictionary, nil)
            if status == errSecSuccess { return true }
            // Builds without the keychain-access-groups entitlement can't
            // create access-controlled items (errSecMissingEntitlement) —
            // fall back to the plain item so saving still works.
            guard status == errSecMissingEntitlement else { return false }
        }

        var query = baseQuery
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// - Parameter context: an already-authenticated `LAContext` (from
    ///   `SecurityManager` or the CLI's `authenticateOrExit`). Passing it
    ///   lets the OS-level user-presence check on the Keychain item succeed
    ///   without prompting a second time.
    public static func retrieve(for id: UUID, context: LAContext? = nil) -> String? {
        let account = id.uuidString
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let context {
            query[kSecUseAuthenticationContext as String] = context
        }

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Metadata backup
    // A mirror of keys.json stored as a Keychain item, so the key list can be
    // restored if the file is deleted by accident. Contains no secret values.

    private static let backupAccount = "metadata.backup"

    @discardableResult
    public static func saveMetadataBackup(_ data: Data) -> Bool {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: backupAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: backupAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    public static func retrieveMetadataBackup() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: backupAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            return nil
        }
        return data
    }

    @discardableResult
    public static func delete(for id: UUID) -> Bool {
        let account = id.uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
