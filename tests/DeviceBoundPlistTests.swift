import Foundation
import CryptoKit
struct ProofTestError: Error {}
func reject(_ action: () throws -> Void) throws {
    do { try action() } catch is ProofTestError { throw ProofTestError() } catch { return }
    throw ProofTestError()
}
@main struct DeviceBoundPlistTests {
    static func main() throws {
        let root: [String: Any] = ["CacheExtra": ["integer": 1, "boolean": true, "value": "fixture"], "CacheData": Data([1, 2, 3])]
        let plain = try PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0)
        let key = Data(repeating: 19, count: 32), otherDevice = Data(repeating: 23, count: 32)
        let exported = try DeviceBoundPlist.seal(plain, key: key)
        let opened = try DeviceBoundPlist.verify(exported, key: key)
        let before = try GestaltDocument(data: plain), after = try GestaltDocument(data: opened)
        precondition(before.matches(after))
        precondition(!after.root.keys.contains(DeviceBoundPlist.proofKey))
        try reject { _ = try DeviceBoundPlist.verify(exported, key: otherDevice) }
        var outer = try PropertyListSerialization.propertyList(from: exported, options: [], format: nil) as! [String: Any]
        var changed = root["CacheExtra"] as! [String: Any]
        changed["integer"] = true
        outer["CacheExtra"] = changed
        let tampered = try PropertyListSerialization.data(fromPropertyList: outer, format: .binary, options: 0)
        try reject { _ = try DeviceBoundPlist.verify(tampered, key: key) }
        var proof = outer[DeviceBoundPlist.proofKey] as! [String: Any]
        proof["tag"] = Data(repeating: 0, count: 32)
        outer[DeviceBoundPlist.proofKey] = proof
        let invalid = try PropertyListSerialization.data(fromPropertyList: outer, format: .binary, options: 0)
        try reject { _ = try DeviceBoundPlist.verify(invalid, key: key) }
        let archivePayload = Data("archive payload".utf8)
        let archiveTag = DeviceBoundPlist.authenticateArchive(archivePayload, key: key)
        precondition(DeviceBoundPlist.isAuthenticArchive(archivePayload, tag: archiveTag, key: key))
        precondition(!DeviceBoundPlist.isAuthenticArchive(archivePayload, tag: archiveTag, key: otherDevice), "Another device's key rejects the archive")
        precondition(!DeviceBoundPlist.isAuthenticArchive(archivePayload + Data([0]), tag: archiveTag, key: key), "A changed archive is rejected")
        precondition(archiveTag != Data(HMAC<SHA256>.authenticationCode(for: archivePayload, using: SymmetricKey(data: key))),
                     "Archive tags are domain-separated from plist proofs")
        print("PASS: device-bound export proof, foreign-key rejection, exact typed payload, tampering rejection and proof stripping before restoration.")
    }
}
