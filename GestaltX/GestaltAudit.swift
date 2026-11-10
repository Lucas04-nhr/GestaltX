// SPDX-License-Identifier: GPL-3.0-only
import Foundation

/// Read-only check for values that are not official for this device.
/// Only keys with a reliable reference are judged; everything else is listed as not checked.
enum GestaltAudit {
    enum Certainty: Int, Comparable {
        case likely, definite
        static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    }

    struct Finding: Identifiable {
        let id: String
        let title: String
        let keys: [String]
        let current: String
        let reason: String
        let certainty: Certainty
        /// Top-level CacheExtra values that make this item official again.
        let fix: [String: Any]
        let fixSummary: String

        func apply(to document: inout GestaltDocument) {
            for (key, value) in fix { document.set(value, for: key) }
        }
    }

    struct Report {
        let machine: String
        let model: OfficialModel?
        let findings: [Finding]
        let notChecked: [String]
    }

    enum Feature {
        case dynamicIsland, alwaysOn, actionButton, cameraControl, appleIntelligence, chargeLimit
        case collisionSOS, bootChime, pwm
    }

    struct OfficialModel {
        let name: String
        let features: Set<Feature>
    }

    /// iPhone models and the preset features they officially support.
    /// Models missing here are treated as unknown, never as unsupported.
    /// Every model in the reference table.
    static let models: [String: OfficialModel] = iPhones.merging(iPads) { phone, _ in phone }

    /// iPads and the preset features they officially support. No iPad has Dynamic Island,
    /// Always-On Display, the Action Button or Camera Control. Apple Intelligence needs M1 or
    /// later, or A17 Pro. iPad-only features (Apple Pencil, Stage Manager) are not judged on iPad.
    /// Charge limit settings are official on models released in 2024 or later.
    static let iPads: [String: OfficialModel] = {
        let none: Set<Feature> = []
        let ai: Set<Feature> = [.appleIntelligence]
        func pair(_ ids: [String], _ name: String, _ features: Set<Feature>) -> [(String, OfficialModel)] {
            ids.map { ($0, OfficialModel(name: name, features: features)) }
        }
        let newNone: Set<Feature> = [.chargeLimit]
        let newAI: Set<Feature> = [.appleIntelligence, .chargeLimit]
        let entries: [(String, OfficialModel)] =
            pair(["iPad11,6", "iPad11,7"], "iPad (8th generation)", none)
            + pair(["iPad12,1", "iPad12,2"], "iPad (9th generation)", none)
            + pair(["iPad13,18", "iPad13,19"], "iPad (10th generation)", none)
            + pair(["iPad15,7", "iPad15,8"], "iPad (A16)", newNone)
            + pair(["iPad11,1", "iPad11,2"], "iPad mini (5th generation)", none)
            + pair(["iPad14,1", "iPad14,2"], "iPad mini (6th generation)", none)
            + pair(["iPad16,1", "iPad16,2"], "iPad mini (A17 Pro)", newAI)
            + pair(["iPad11,3", "iPad11,4"], "iPad Air (3rd generation)", none)
            + pair(["iPad13,1", "iPad13,2"], "iPad Air (4th generation)", none)
            + pair(["iPad13,16", "iPad13,17"], "iPad Air (5th generation)", ai)
            + pair(["iPad14,8", "iPad14,9"], "iPad Air 11-inch (M2)", newAI)
            + pair(["iPad14,10", "iPad14,11"], "iPad Air 13-inch (M2)", newAI)
            + pair(["iPad15,3", "iPad15,4"], "iPad Air 11-inch (M3)", newAI)
            + pair(["iPad15,5", "iPad15,6"], "iPad Air 13-inch (M3)", newAI)
            + pair(["iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4"], "iPad Pro 11-inch (1st generation)", none)
            + pair(["iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8"], "iPad Pro 12.9-inch (3rd generation)", none)
            + pair(["iPad8,9", "iPad8,10"], "iPad Pro 11-inch (2nd generation)", none)
            + pair(["iPad8,11", "iPad8,12"], "iPad Pro 12.9-inch (4th generation)", none)
            + pair(["iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7"], "iPad Pro 11-inch (3rd generation)", ai)
            + pair(["iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11"], "iPad Pro 12.9-inch (5th generation)", ai)
            + pair(["iPad14,3", "iPad14,4"], "iPad Pro 11-inch (4th generation)", ai)
            + pair(["iPad14,5", "iPad14,6"], "iPad Pro 12.9-inch (6th generation)", ai)
            + pair(["iPad16,3", "iPad16,4"], "iPad Pro 11-inch (M4)", newAI)
            + pair(["iPad16,5", "iPad16,6"], "iPad Pro 13-inch (M4)", newAI)
        return Dictionary(uniqueKeysWithValues: entries)
    }()

    /// The Collision SOS, boot chime and PWM lists are adapted from Erosion-CN
    /// (https://github.com/Kianuni/Erosion-CN, GPL-3.0).
    static let iPhones: [String: OfficialModel] = {
        let none: Set<Feature> = []
        // Crash Detection and the boot chime start with the iPhone 14 lineup.
        let base14: Set<Feature> = [.collisionSOS, .bootChime]
        // Charge limit settings start with the iPhone 15 lineup.
        let pro14 = base14.union([.dynamicIsland, .alwaysOn])
        let island = base14.union([.dynamicIsland, .chargeLimit])
        let pro15 = base14.union([.dynamicIsland, .alwaysOn, .actionButton, .appleIntelligence, .chargeLimit])
        let base16 = base14.union([.dynamicIsland, .actionButton, .cameraControl, .appleIntelligence, .chargeLimit])
        let pro16 = base16.union([.alwaysOn])
        // The PWM display setting starts with the iPhone 17 lineup.
        let pro17 = pro16.union([.pwm])
        return [
            "iPhone12,1": .init(name: "iPhone 11", features: none),
            "iPhone12,3": .init(name: "iPhone 11 Pro", features: none),
            "iPhone12,5": .init(name: "iPhone 11 Pro Max", features: none),
            "iPhone12,8": .init(name: "iPhone SE", features: none),
            "iPhone13,1": .init(name: "iPhone 12 mini", features: none),
            "iPhone13,2": .init(name: "iPhone 12", features: none),
            "iPhone13,3": .init(name: "iPhone 12 Pro", features: none),
            "iPhone13,4": .init(name: "iPhone 12 Pro Max", features: none),
            "iPhone14,4": .init(name: "iPhone 13 mini", features: none),
            "iPhone14,5": .init(name: "iPhone 13", features: none),
            "iPhone14,2": .init(name: "iPhone 13 Pro", features: none),
            "iPhone14,3": .init(name: "iPhone 13 Pro Max", features: none),
            "iPhone14,6": .init(name: "iPhone SE", features: none),
            "iPhone14,7": .init(name: "iPhone 14", features: base14),
            "iPhone14,8": .init(name: "iPhone 14 Plus", features: base14),
            "iPhone15,2": .init(name: "iPhone 14 Pro", features: pro14),
            "iPhone15,3": .init(name: "iPhone 14 Pro Max", features: pro14),
            "iPhone15,4": .init(name: "iPhone 15", features: island),
            "iPhone15,5": .init(name: "iPhone 15 Plus", features: island),
            "iPhone16,1": .init(name: "iPhone 15 Pro", features: pro15),
            "iPhone16,2": .init(name: "iPhone 15 Pro Max", features: pro15),
            "iPhone17,3": .init(name: "iPhone 16", features: base16),
            "iPhone17,4": .init(name: "iPhone 16 Plus", features: base16),
            "iPhone17,1": .init(name: "iPhone 16 Pro", features: pro16),
            "iPhone17,2": .init(name: "iPhone 16 Pro Max", features: pro16),
            "iPhone17,5": .init(name: "iPhone 16e", features: base14.union([.actionButton, .appleIntelligence, .chargeLimit])),
            "iPhone18,3": .init(name: "iPhone 17", features: pro17),
            "iPhone18,1": .init(name: "iPhone 17 Pro", features: pro17),
            "iPhone18,2": .init(name: "iPhone 17 Pro Max", features: pro17),
            "iPhone18,4": .init(name: "iPhone Air", features: pro17),
        ]
    }()

    private static let featureOf: [String: Feature] = [
        "dynamicIsland": .dynamicIsland, "aod": .alwaysOn, "actionButton": .actionButton,
        "cameraControl": .cameraControl, "ai": .appleIntelligence, "chargeLimit": .chargeLimit,
        "collisionSOS": .collisionSOS, "bootChime": .bootChime, "pwm": .pwm,
    ]
    /// Features whose model lists have no Apple reference to check them against. A missing
    /// feature is reported as likely, so its fix is not selected by default.
    private static let unconfirmedFeatures: Set<Feature> = [.bootChime, .pwm]

    /// Whether this hardware officially has the feature that a preset turns on.
    /// Unknown models and presets without a reference never count as built in.
    static func isBuiltIn(_ capabilityID: String, machine: String) -> Bool {
        guard let feature = featureOf[capabilityID], let model = models[machine] else { return false }
        return model.features.contains(feature)
    }
    private static let iPadOnly: Set<String> = ["pencil", "stageManager", "ipadApps"]
    private static let internalOnly: Set<String> = ["internal", "storage", "srd"]
    private static let modelNameKeys = ["Z/dqyWS6OZTRy10UcmUAhw", "bbtR9jQx50Fv5Af/affNtA"]

    /// The real model identifier, read from the kernel rather than the MobileGestalt cache.
    static func liveMachine() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        var size = 0
        guard sysctlbyname("hw.machine", nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.machine", &bytes, &size, nil, 0) == 0 else { return "" }
        return String(cString: bytes)
    }

    static func check(_ document: GestaltDocument, machine: String) -> Report {
        let extra = document.extra
        let isPhone = machine.hasPrefix("iPhone")
        let model = models[machine]
        var findings: [Finding] = []
        var notChecked: [String] = []
        let region = salesRegion(extra)

        for capability in Capability.all {
            let present = capability.keys.filter { extra[$0] != nil }
            let enabled = capability.keys.filter { isEnabled(extra[$0], capability: capability.id) }
            let current = present.isEmpty ? L("Not present") : present.map { describe(extra[$0]!) }.joined(separator: ", ")
            func flag(_ reason: String, _ certainty: Certainty = .definite) {
                var fix: [String: Any] = [:]
                for key in enabled { fix[key] = officialValue(replacing: extra[key], capability: capability.id) }
                let summary = fix.values.map(describe).sorted().first ?? ""
                findings.append(Finding(id: capability.id, title: L(capability.title), keys: capability.keys,
                                        current: current, reason: reason, certainty: certainty,
                                        fix: fix, fixSummary: String(format: L("Change to %@"), summary)))
            }
            if internalOnly.contains(capability.id) {
                if !enabled.isEmpty { flag(L("This flag is only enabled on Apple internal or research devices.")) }
            } else if iPadOnly.contains(capability.id) {
                guard isPhone else { notChecked.append(L(capability.title)); continue }
                if !enabled.isEmpty { flag(L("This feature is only official on iPad.")) }
            } else if let feature = featureOf[capability.id], let model {
                if enabled.isEmpty { continue }
                if !model.features.contains(feature) {
                    flag(String(format: L("%@ does not officially support this feature."), model.name),
                         unconfirmedFeatures.contains(feature) ? .likely : .definite)
                } else if feature == .appleIntelligence, region == "CH" {
                    // Mainland China models do not offer Apple Intelligence. The region comes from the
                    // cache itself, so a spoofed region makes this a likely, not a definite, finding.
                    flag(L("Apple Intelligence is not officially available on mainland China models."), .likely)
                }
            } else {
                notChecked.append(L(capability.title))
            }
        }

        if !machine.isEmpty, let cached = extra[GestaltKeys.productType] as? String, cached != machine {
            findings.append(Finding(id: "productType", title: L("Product Type"), keys: [GestaltKeys.productType], current: cached,
                                    reason: String(format: L("The cached product type is %@, but this device reports %@."), cached, machine),
                                    certainty: .definite, fix: [GestaltKeys.productType: machine],
                                    fixSummary: String(format: L("Change to %@"), machine)))
        }
        // Official names may carry a suffix such as "(3rd generation)". iPad names vary too much
        // in their official form to compare reliably, so only iPhone names are checked.
        if isPhone, let model, let name = document.artwork["ArtworkDeviceProductDescription"] as? String,
           name != model.name, !name.hasPrefix(model.name + " (") {
            var artwork = document.artwork
            artwork["ArtworkDeviceProductDescription"] = model.name
            var fix: [String: Any] = [GestaltKeys.artwork: artwork]
            // GestaltX writes a changed name to these keys as well; fix them only if they hold the same name.
            for key in modelNameKeys where extra[key] as? String == name { fix[key] = model.name }
            findings.append(Finding(id: "modelName", title: L("Model Name"), keys: fix.keys.sorted(), current: name,
                                    reason: String(format: L("The model name is %@, but this device is %@."), name, model.name),
                                    certainty: .likely, fix: fix, fixSummary: String(format: L("Change to %@"), model.name)))
        }
        if let code = extra[GestaltKeys.regionCode] as? String {
            for key in [GestaltKeys.regionInfo, GestaltKeys.legacyRegionInfo] {
                guard let info = extra[key] as? String, let prefix = info.split(separator: "/").first, String(prefix) != code else { continue }
                findings.append(Finding(id: "region-" + key, title: L("Region Code"), keys: [GestaltKeys.regionCode, key], current: code + " · " + info,
                                        reason: String(format: L("The region code %@ does not match the sales-region suffix %@."), code, info),
                                        certainty: .likely, fix: [GestaltKeys.regionCode: String(prefix)],
                                        fixSummary: String(format: L("Change the region code to %@"), String(prefix))))
                break
            }
        }
        findings.sort { $0.certainty != $1.certainty ? $0.certainty > $1.certainty : $0.title < $1.title }
        return Report(machine: machine, model: model, findings: findings, notChecked: notChecked)
    }

    /// The sales region, such as CH for mainland China. The sales-region suffix wins over the region code,
    /// because region spoofing usually changes the code.
    private static func salesRegion(_ extra: [String: Any]) -> String? {
        for key in [GestaltKeys.regionInfo, GestaltKeys.legacyRegionInfo] {
            if let info = extra[key] as? String, let prefix = info.split(separator: "/").first { return String(prefix) }
        }
        return extra[GestaltKeys.regionCode] as? String
    }

    private static func isEnabled(_ value: Any?, capability: String) -> Bool {
        if capability == "ipadApps" {
            // iPhone apps report family 1 only; family 2 is iPad.
            return (value as? [Any])?.contains { ($0 as? NSNumber)?.intValue == 2 } ?? false
        }
        return (value as? NSNumber)?.boolValue ?? false
    }

    /// The unsupported value, keeping the stored number type.
    private static func officialValue(replacing value: Any?, capability: String) -> Any {
        if capability == "ipadApps" { return [NSNumber(value: 1)] }
        if let value, PlistValueKind.detect(value) == .integer { return NSNumber(value: 0) }
        return NSNumber(value: false)
    }

    private static func describe(_ value: Any) -> String {
        let text = PlistValueKind.detect(value).text(for: value)
        return text.count > 60 ? String(text.prefix(60)) + "…" : text
    }
}
