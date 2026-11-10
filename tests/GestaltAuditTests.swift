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
        precondition(report.notChecked.contains("Audio Mix"), "Items without a reference are listed as not checked")

        // Applying every fix makes the document official, keeping number types.
        var fixed = spoofed
        for finding in report.findings { finding.apply(to: &fixed) }
        precondition(GestaltAudit.check(fixed, machine: "iPhone14,5").findings.isEmpty, "All fixes resolve their findings")
        precondition(PlistValueKind.detect(fixed.extra["YlEtTtHlNesRBMal1CqRaA"]!) == .boolean, "Boolean flags stay Boolean")
        precondition(PlistValueKind.detect(fixed.extra["XYlJKKkj2hztRP1NWWnhlw"]!) == .integer, "Integer flags stay integers")
        precondition((fixed.extra["9MZ5AdH43csAUajl/dU+IQ"] as? [NSNumber]) == [1], "iPad apps return to the iPhone family")
        precondition(fixed.extra[GestaltKeys.productType] as? String == "iPhone14,5")
        precondition(fixed.artwork["ArtworkDeviceProductDescription"] as? String == "iPhone 13")
        precondition(fixed.extra[GestaltKeys.regionCode] as? String == "CH", "Region code follows the sales-region suffix")
        precondition(fixed.extra["2OOJf1VhaM7NxfRok3HbWQ"] as? Bool == false, "Unflagged keys are untouched")

        // Stock iPhone 15 Pro values produce no findings.
        let stock = try document([
            "YlEtTtHlNesRBMal1CqRaA": true, "A62OafQ85EJAiiqKn4agtg": true, "cT44WE1EohiwRzhsZ8xEsw": true,
            "9MZ5AdH43csAUajl/dU+IQ": [1], GestaltKeys.productType: "iPhone16,1",
            GestaltKeys.artwork: ["ArtworkDeviceProductDescription": "iPhone 15 Pro"],
            GestaltKeys.regionCode: "LL", GestaltKeys.regionInfo: "LL/A", "37NVydb//GP/GrhuTN+exg": true,
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
        // iPads are in the reference table: iPhone-only features are flagged, Apple Intelligence follows the chip.
        let spoofedPad = try document(["YlEtTtHlNesRBMal1CqRaA": true, "A62OafQ85EJAiiqKn4agtg": true, "cT44WE1EohiwRzhsZ8xEsw": true,
                                       GestaltKeys.artwork: ["ArtworkDeviceProductDescription": "iPad (9th generation) Wi-Fi"]])
        let padReport = GestaltAudit.check(spoofedPad, machine: "iPad12,1")
        precondition(padReport.model?.name == "iPad (9th generation)")
        precondition(ids(padReport) == ["dynamicIsland", "ai", "actionButton"], "iPad findings: \(ids(padReport))")
        let m4 = try document(["A62OafQ85EJAiiqKn4agtg": true])
        precondition(GestaltAudit.check(m4, machine: "iPad16,3").findings.isEmpty, "M4 iPads officially support Apple Intelligence")
        precondition(GestaltAudit.iPads.keys.allSatisfy { $0.hasPrefix("iPad") } && GestaltAudit.models.count == GestaltAudit.iPhones.count + GestaltAudit.iPads.count,
                     "iPad and iPhone identifiers do not overlap")
        // Charge limit: official on iPhone 15 and later, and on iPads released in 2024 or later.
        let charge = try document(["37NVydb//GP/GrhuTN+exg": true])
        precondition(ids(GestaltAudit.check(charge, machine: "iPad13,16")) == ["chargeLimit"], "Air (5th generation) has no charge limit")
        precondition(ids(GestaltAudit.check(charge, machine: "iPhone14,5")) == ["chargeLimit"], "iPhone 13 has no charge limit")
        precondition(GestaltAudit.check(charge, machine: "iPhone15,4").findings.isEmpty, "iPhone 15 has a charge limit")
        for machine in ["iPad15,7", "iPad16,1", "iPad14,8", "iPad15,5", "iPad16,3"] {
            precondition(GestaltAudit.check(charge, machine: machine).findings.isEmpty, "\(machine) has a charge limit")
        }

        // Mainland China models do not offer Apple Intelligence, even on supported chips.
        let chinaAI = try document(["A62OafQ85EJAiiqKn4agtg": true, GestaltKeys.regionCode: "CH", GestaltKeys.regionInfo: "CH/A"])
        let chinaReport = GestaltAudit.check(chinaAI, machine: "iPad13,16")
        precondition(ids(chinaReport) == ["ai"] && chinaReport.findings[0].certainty == .likely, "China AI: \(ids(chinaReport))")
        var chinaFixed = chinaAI
        chinaReport.findings[0].apply(to: &chinaFixed)
        precondition(GestaltAudit.check(chinaFixed, machine: "iPad13,16").findings.isEmpty, "The China AI fix resolves its finding")
        // A spoofed region code does not hide the sales region.
        let spoofedCode = try document(["A62OafQ85EJAiiqKn4agtg": true, GestaltKeys.regionCode: "LL", GestaltKeys.regionInfo: "CH/A"])
        precondition(ids(GestaltAudit.check(spoofedCode, machine: "iPad13,16")) == ["ai", "region-" + GestaltKeys.regionInfo])
        let usAI = try document(["A62OafQ85EJAiiqKn4agtg": true, GestaltKeys.regionCode: "LL", GestaltKeys.regionInfo: "LL/A"])
        precondition(GestaltAudit.check(usAI, machine: "iPad13,16").findings.isEmpty, "AI outside China is official")

        // Collision SOS and the boot chime start with iPhone 14, PWM with iPhone 17. Only the
        // Collision SOS list matches a published Apple reference, so the other two are likely.
        let extras = try document(["HCzWusHQwZDea6nNhaKndw": true, "QHxt+hGLaBPbQJbXiUJX3w": true, "6IejgN+1Fmu5/QrZFOIeNw": true])
        let olderReport = GestaltAudit.check(extras, machine: "iPhone14,5")
        let certainty = Dictionary(uniqueKeysWithValues: olderReport.findings.map { ($0.id, $0.certainty) })
        precondition(certainty == ["collisionSOS": .definite, "bootChime": .likely, "pwm": .likely], "iPhone 13: \(certainty)")
        precondition(ids(GestaltAudit.check(extras, machine: "iPhone14,7")) == ["pwm"], "iPhone 14 has Collision SOS and the boot chime")
        precondition(ids(GestaltAudit.check(extras, machine: "iPhone17,5")) == ["pwm"], "iPhone 16e has Collision SOS and the boot chime")
        precondition(GestaltAudit.check(extras, machine: "iPhone18,3").findings.isEmpty, "iPhone 17 has all three")
        precondition(ids(GestaltAudit.check(extras, machine: "iPad16,3")) == ["collisionSOS", "bootChime", "pwm"], "No iPad has them")

        // Built-in features follow the same table; unknown models and unreferenced presets never count.
        precondition(GestaltAudit.isBuiltIn("collisionSOS", machine: "iPhone14,7"))
        precondition(GestaltAudit.isBuiltIn("pwm", machine: "iPhone18,1") && !GestaltAudit.isBuiltIn("pwm", machine: "iPhone17,1"))
        precondition(GestaltAudit.isBuiltIn("dynamicIsland", machine: "iPhone16,1") && !GestaltAudit.isBuiltIn("dynamicIsland", machine: "iPhone17,5"))
        precondition(!GestaltAudit.isBuiltIn("dynamicIsland", machine: "iPhone99,1"), "Unknown models have no built-in features")
        precondition(!GestaltAudit.isBuiltIn("audioMix", machine: "iPhone18,1"), "Presets without a reference are never built in")

        // The US model comes from the original model number first, then from the hardware model.
        precondition(ModelPreset.usEquivalent(originalModelNumber: "A3523", machine: "iPhone18,1")?.value == "A3256", "China 17 Pro")
        precondition(ModelPreset.usEquivalent(originalModelNumber: "A9999", machine: "iPhone18,1")?.value == "A3256", "Hardware fallback")
        precondition(ModelPreset.usEquivalent(originalModelNumber: nil, machine: "iPhone14,7")?.value == "A2649", "No original value")
        precondition(ModelPreset.usEquivalent(originalModelNumber: "A3256", machine: "iPhone18,1") == nil, "Already the US model")
        precondition(ModelPreset.usEquivalent(originalModelNumber: "A3715", machine: "iPhone19,2") == nil, "A listed preset offers the US model")
        precondition(ModelPreset.usEquivalent(originalModelNumber: "A9999", machine: "iPhone99,1") == nil, "Unknown hardware")
        let usPreset = ModelPreset.usEquivalent(originalModelNumber: "A3104", machine: "iPhone16,1")!
        precondition(usPreset.id == ModelPreset.usEquivalentID && usPreset.displayTitle.hasSuffix("A2848"), usPreset.displayTitle)
        print("PASS: unofficial-setting audit flags spoofed features, identity and region, and stays silent on stock or unknown references, and fixes resolve every finding; built-in features and US model numbers follow the reference tables.")
    }
}
