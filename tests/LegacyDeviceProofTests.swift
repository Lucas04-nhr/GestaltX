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
    root[LegacyDeviceProof.proofKey] = ["version": 1, "payload": plain, "tag": tag]
    return try PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0)
}
@main struct LegacyDeviceProofTests {
    static func main() throws {
        let root: [String: Any] = ["CacheExtra": ["integer": 1, "boolean": true, "value": "fixture"], "CacheData": Data([1, 2, 3])]
        let plain = try PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0)

        let passedThrough = try LegacyDeviceProof.plainPlist(plain)
        precondition(passedThrough == plain, "A plain plist is imported as is")
        let exported = try legacyExport(plain, key: Data(repeating: 19, count: 32))
        let opened = try LegacyDeviceProof.plainPlist(exported)
        precondition(opened == plain, "An old export unwraps to the exact plain plist, whatever key made it")
        let unwrapped = try GestaltDocument(data: opened)
        precondition(!unwrapped.root.keys.contains(LegacyDeviceProof.proofKey))

        var outer = try PropertyListSerialization.propertyList(from: exported, options: [], format: nil) as! [String: Any]
        var changed = root["CacheExtra"] as! [String: Any]
        changed["integer"] = true
        outer["CacheExtra"] = changed
        let inconsistent = try PropertyListSerialization.data(fromPropertyList: outer, format: .binary, options: 0)
        try reject { _ = try LegacyDeviceProof.plainPlist(inconsistent) }
        outer[LegacyDeviceProof.proofKey] = "not a proof"
        try reject { _ = try LegacyDeviceProof.plainPlist(PropertyListSerialization.data(fromPropertyList: outer, format: .binary, options: 0)) }
        print("PASS: plain plists pass through, old exports unwrap to the exact plist, and inconsistent wrappers are rejected.")
    }
}
