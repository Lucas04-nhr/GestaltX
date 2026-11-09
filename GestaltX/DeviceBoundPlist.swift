// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import CryptoKit
import Security

/// GestaltX exports and imports MobileGestalt plists as plain plists, so files work in other apps and never
/// depend on a key that can be lost. Earlier versions wrapped exports with an HMAC proof; those files are
/// still accepted by unwrapping the plain plist inside. A device-only Keychain key remains only to tag
/// backup archives, which fall back to identifier checks when the key is gone.
enum DeviceBoundPlist {
    static let proofKey = "GestaltXDeviceProof"
    private static let service = "com.huami.gestultx.device-proof"
    private static let lock = NSLock()
    private static var invalid: SharedPlistError { SharedPlistError(key: "This plist's device proof could not be verified on this device.") }

    /// Returns the plain plist from a file exported by an earlier version, or `data` unchanged when it has no proof.
    /// `verified` is true only when the old proof matches this installation's key.
    static func unwrapLegacy(_ data: Data) throws -> (payload: Data, verified: Bool) {
        try unwrapLegacy(data, key: try? key(create: false))
    }
    static func unwrapLegacy(_ data: Data, key: Data?) throws -> (payload: Data, verified: Bool) {
        guard data.count <= SharedPlistInbox.maximumByteCount,
              var outer = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let value = outer.removeValue(forKey: proofKey) else { return (data, false) }
        guard let proof = value as? [String: Any], proof["version"] as? Int == 1,
              let payload = proof["payload"] as? Data, payload.count <= SharedPlistInbox.maximumByteCount,
              let original = try? PropertyListSerialization.propertyList(from: payload, options: [], format: nil) as? [String: Any],
              original[proofKey] == nil, GestaltDocument.valuesEqual(outer, original) else { throw invalid }
        try SharedPlistInbox.validate(payload)
        guard let key, key.count == 32, let tag = proof["tag"] as? Data, tag.count == 32 else { return (payload, false) }
        return (payload, HMAC<SHA256>.isValidAuthenticationCode(tag, authenticating: payload, using: SymmetricKey(data: key)))
    }

    /// Authenticates a backup archive with the device-only key, separated from old plist proofs by a domain prefix.
    static func authenticateArchive(_ payload: Data) throws -> Data { authenticateArchive(payload, key: try key(create: true)) }
    static func isAuthenticArchive(_ payload: Data, tag: Data) -> Bool {
        guard let key = try? key(create: false) else { return false }
        return isAuthenticArchive(payload, tag: tag, key: key)
    }
    static func authenticateArchive(_ payload: Data, key: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: archiveDomain + payload, using: SymmetricKey(data: key)))
    }
    static func isAuthenticArchive(_ payload: Data, tag: Data, key: Data) -> Bool {
        key.count == 32 && tag.count == 32
            && HMAC<SHA256>.isValidAuthenticationCode(tag, authenticating: archiveDomain + payload, using: SymmetricKey(data: key))
    }
    private static let archiveDomain = Data("GestaltX backup archive v1\0".utf8)

    /// Deletes any copy of the key stored in iCloud Keychain. GestaltX only ever uses a device-only key.
    /// Returns true when a synced copy was found and deleted.
    @discardableResult
    static func removeSynchronizedKeys() -> Bool {
        lock.lock(); defer { lock.unlock() }
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                                     kSecAttrSynchronizable: true, kSecUseDataProtectionKeychain: true]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    private static func key(create: Bool) throws -> Data {
        lock.lock(); defer { lock.unlock() }
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                                     kSecAttrAccount: "local-v1", kSecAttrSynchronizable: false,
                                     kSecUseDataProtectionKeychain: true]
        var read = query
        read[kSecReturnData] = true; read[kSecMatchLimit] = kSecMatchLimitOne
        var found: CFTypeRef?
        let status = SecItemCopyMatching(read as CFDictionary, &found)
        if status == errSecSuccess, let bytes = found as? Data, bytes.count == 32 { return bytes }
        guard status == errSecItemNotFound, create else { throw invalid }
        var bytes = Data(count: 32)
        let generated = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        guard generated == errSecSuccess else { throw invalid }
        var add = query
        add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        add[kSecValueData] = bytes
        guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { throw invalid }
        return bytes
    }
}
