// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import Security

/// GestaltX exports and imports plain MobileGestalt plists and does not verify where an imported file came from;
/// the user confirms its source. Earlier versions wrapped exports with a device proof and kept a key in the
/// Keychain. Those files are still accepted by taking the plain plist inside, and the old key is deleted.
enum LegacyDeviceProof {
    static let proofKey = "GestaltXDeviceProof"
    private static let service = "com.huami.gestultx.device-proof"

    /// Returns the plain plist inside a file exported by an earlier version, or `data` unchanged when it has no proof.
    static func plainPlist(_ data: Data) throws -> Data {
        guard var outer = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let value = outer.removeValue(forKey: proofKey) else { return data }
        guard let proof = value as? [String: Any], let payload = proof["payload"] as? Data,
              payload.count <= SharedPlistInbox.maximumByteCount,
              let original = try? PropertyListSerialization.propertyList(from: payload, options: [], format: nil) as? [String: Any],
              original[proofKey] == nil, GestaltDocument.valuesEqual(outer, original) else {
            throw SharedPlistError(key: "Choose a MobileGestalt plist with a CacheExtra dictionary.")
        }
        try SharedPlistInbox.validate(payload)
        return payload
    }

    /// Deletes the key earlier versions stored, on this device and in iCloud Keychain. Returns true when one was deleted.
    @discardableResult
    static func removeKeys() -> Bool {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                                     kSecAttrSynchronizable: kSecAttrSynchronizableAny, kSecUseDataProtectionKeychain: true]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
