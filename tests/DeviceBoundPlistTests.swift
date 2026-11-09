import Foundation
import CryptoKit
struct ProofTestError: Error {}
func reject(_ action: () throws -> Void) throws {
    do { try action() } catch is ProofTestError { throw ProofTestError() } catch { return }
    throw ProofTestError()
}
/// Builds a file in the format earlier GestaltX versions exported.
func legacyExport(_ plain: Data, key: Data) throws -> Data {
    var root = try PropertyListSerialization.propertyList(from: plain, options: [], format: nil) as! [String: Any]
    let tag = Data(HMAC<SHA256>.authenticationCode(for: plain, using: SymmetricKey(data: key)))
    root[DeviceBoundPlist.proofKey] = ["version": 1, "payload": plain, "tag": tag]
    return try PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0)
}
@main struct DeviceBoundPlistTests {
    static func main() throws {
        let root: [String: Any] = ["CacheExtra": ["integer": 1, "boolean": true, "value": "fixture"], "CacheData": Data([1, 2, 3])]
        let plain = try PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0)
        let key = Data(repeating: 19, count: 32), otherDevice = Data(repeating: 23, count: 32)

        let unchanged = try DeviceBoundPlist.unwrapLegacy(plain, key: key)
        precondition(unchanged.payload == plain && !unchanged.verified, "A plain plist is imported as is and is not proof-verified")

        let exported = try legacyExport(plain, key: key)
        let opened = try DeviceBoundPlist.unwrapLegacy(exported, key: key)
        precondition(opened.payload == plain && opened.verified, "An old export from this installation unwraps to the exact plain plist")
        let unwrapped = try GestaltDocument(data: opened.payload)
        precondition(!unwrapped.root.keys.contains(DeviceBoundPlist.proofKey))
        let foreign = try DeviceBoundPlist.unwrapLegacy(exported, key: otherDevice)
        precondition(foreign.payload == plain && !foreign.verified, "Another key still unwraps the plist but does not verify it")
        let keyless = try DeviceBoundPlist.unwrapLegacy(exported, key: nil)
        precondition(keyless.payload == plain && !keyless.verified, "Without a key the plist is still unwrapped")

        var outer = try PropertyListSerialization.propertyList(from: exported, options: [], format: nil) as! [String: Any]
        var changed = root["CacheExtra"] as! [String: Any]
        changed["integer"] = true
        outer["CacheExtra"] = changed
        let tampered = try PropertyListSerialization.data(fromPropertyList: outer, format: .binary, options: 0)
        try reject { _ = try DeviceBoundPlist.unwrapLegacy(tampered, key: key) }
        outer = try PropertyListSerialization.propertyList(from: exported, options: [], format: nil) as! [String: Any]
        var proof = outer[DeviceBoundPlist.proofKey] as! [String: Any]
        proof["tag"] = Data(repeating: 0, count: 32)
        outer[DeviceBoundPlist.proofKey] = proof
        let badTag = try DeviceBoundPlist.unwrapLegacy(PropertyListSerialization.data(fromPropertyList: outer, format: .binary, options: 0), key: key)
        precondition(badTag.payload == plain && !badTag.verified, "A wrong tag is not treated as proof")

        let archivePayload = Data("archive payload".utf8)
        let archiveTag = DeviceBoundPlist.authenticateArchive(archivePayload, key: key)
        precondition(DeviceBoundPlist.isAuthenticArchive(archivePayload, tag: archiveTag, key: key))
        precondition(!DeviceBoundPlist.isAuthenticArchive(archivePayload, tag: archiveTag, key: otherDevice), "Another device's key rejects the archive")
        precondition(!DeviceBoundPlist.isAuthenticArchive(archivePayload + Data([0]), tag: archiveTag, key: key), "A changed archive is rejected")
        precondition(archiveTag != Data(HMAC<SHA256>.authenticationCode(for: archivePayload, using: SymmetricKey(data: key))),
                     "Archive tags are domain-separated from plist proofs")
        print("PASS: plain plists pass through, old proofs unwrap to the exact plist, only this installation's key verifies them, and inconsistent wrappers are rejected.")
    }
}
