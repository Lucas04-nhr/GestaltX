import Foundation

@main struct GestaltAuditTests {
    static func document(_ extra: [String: Any]) throws -> GestaltDocument {
        let root: [String: Any] = ["CacheExtra": extra, "CacheData": Data([0, 1])]
        return try GestaltDocument(data: PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0))
    }
    static func ids(_ report: GestaltAudit.Report) -> Set<String> { Set(report.findings.map(\.id)) }

    static func main() throws {
        // iPhone 13 spoofed with features and identity of an iPhone 15 Pro.
        let spoofed = try document([
            "YlEtTtHlNesRBMal1CqRaA": true,                     // Dynamic Island
            "XYlJKKkj2hztRP1NWWnhlw": 1,                        // SRD flag
            "9MZ5AdH43csAUajl/dU+IQ": [1, 2],                   // iPad apps
            "2OOJf1VhaM7NxfRok3HbWQ": false,                    // AOD present but off
            GestaltKeys.productType: "iPhone16,1",
            GestaltKeys.artwork: ["ArtworkDeviceProductDescription": "iPhone 15 Pro"],
            GestaltKeys.regionCode: "LL", GestaltKeys.regionInfo: "CH/A",
        ])
        let report = GestaltAudit.check(spoofed, machine: "iPhone14,5")
        precondition(report.model?.name == "iPhone 13")
        precondition(ids(report) == ["dynamicIsland", "srd", "ipadApps", "productType", "modelName", "region-" + GestaltKeys.regionInfo],
                     "Unexpected findings: \(ids(report))")
        precondition(report.findings.first?.certainty == .definite, "Definite findings sort first")
        precondition(report.notChecked.contains("Boot & Shutdown Chime"), "Items without a reference are listed as not checked")

        // Stock iPhone 15 Pro values produce no findings.
        let stock = try document([
            "YlEtTtHlNesRBMal1CqRaA": true, "A62OafQ85EJAiiqKn4agtg": true, "cT44WE1EohiwRzhsZ8xEsw": true,
            "9MZ5AdH43csAUajl/dU+IQ": [1], GestaltKeys.productType: "iPhone16,1",
            GestaltKeys.artwork: ["ArtworkDeviceProductDescription": "iPhone 15 Pro"],
            GestaltKeys.regionCode: "CH", GestaltKeys.regionInfo: "CH/A",
        ])
        precondition(GestaltAudit.check(stock, machine: "iPhone16,1").findings.isEmpty, "Stock values are not reported")

        // Official names may carry a generation suffix.
        let se = try document([GestaltKeys.artwork: ["ArtworkDeviceProductDescription": "iPhone SE (3rd generation)"]])
        precondition(GestaltAudit.check(se, machine: "iPhone14,6").findings.isEmpty, "Generation suffixes are accepted")

        // Unknown models are never judged by the feature table, but internal flags still are.
        let unknown = try document(["YlEtTtHlNesRBMal1CqRaA": true, "EqrsVvjcYDdxHBiQmGhAWw": true, GestaltKeys.productType: "iPhone99,1"])
        let unknownReport = GestaltAudit.check(unknown, machine: "iPhone99,1")
        precondition(unknownReport.model == nil && ids(unknownReport) == ["internal"], "Unknown models: \(ids(unknownReport))")

        // iPad-only features are not judged on iPad.
        let iPad = try document(["yhHcB0iH0d1XzPO/CFd3ow": true, "qeaj75wk3HF4DwQ8qbIi7g": true])
        precondition(GestaltAudit.check(iPad, machine: "iPad14,1").findings.isEmpty, "iPad features are not reported on iPad")
        print("PASS: unofficial-setting audit flags spoofed features, identity and region, and stays silent on stock or unknown references.")
    }
}
