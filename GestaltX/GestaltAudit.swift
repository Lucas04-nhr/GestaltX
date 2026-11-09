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

    enum Feature { case dynamicIsland, alwaysOn, actionButton, cameraControl, appleIntelligence }

    struct OfficialModel {
        let name: String
        let features: Set<Feature>
    }

    /// iPhone models and the preset features they officially support.
    /// Models missing here are treated as unknown, never as unsupported.
    static let iPhones: [String: OfficialModel] = {
        let none: Set<Feature> = []
        let island: Set<Feature> = [.dynamicIsland]
        let pro14: Set<Feature> = [.dynamicIsland, .alwaysOn]
        let pro15: Set<Feature> = [.dynamicIsland, .alwaysOn, .actionButton, .appleIntelligence]
        let base16: Set<Feature> = [.dynamicIsland, .actionButton, .cameraControl, .appleIntelligence]
        let pro16: Set<Feature> = [.dynamicIsland, .alwaysOn, .actionButton, .cameraControl, .appleIntelligence]
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
            "iPhone14,7": .init(name: "iPhone 14", features: none),
            "iPhone14,8": .init(name: "iPhone 14 Plus", features: none),
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
            "iPhone17,5": .init(name: "iPhone 16e", features: [.actionButton, .appleIntelligence]),
            "iPhone18,3": .init(name: "iPhone 17", features: pro16),
            "iPhone18,1": .init(name: "iPhone 17 Pro", features: pro16),
            "iPhone18,2": .init(name: "iPhone 17 Pro Max", features: pro16),
            "iPhone18,4": .init(name: "iPhone Air", features: pro16),
        ]
    }()

    private static let featureOf: [String: Feature] = [
        "dynamicIsland": .dynamicIsland, "aod": .alwaysOn, "actionButton": .actionButton,
        "cameraControl": .cameraControl, "ai": .appleIntelligence,
    ]
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
        let model = iPhones[machine]
        var findings: [Finding] = []
        var notChecked: [String] = []

        for capability in Capability.all {
            let present = capability.keys.filter { extra[$0] != nil }
            let enabled = capability.keys.filter { isEnabled(extra[$0], capability: capability.id) }
            let current = present.isEmpty ? L("Not present") : present.map { describe(extra[$0]!) }.joined(separator: ", ")
            func flag(_ reason: String) {
                var fix: [String: Any] = [:]
                for key in enabled { fix[key] = officialValue(replacing: extra[key], capability: capability.id) }
                let summary = fix.values.map(describe).sorted().first ?? ""
                findings.append(Finding(id: capability.id, title: L(capability.title), keys: capability.keys,
                                        current: current, reason: reason, certainty: .definite,
                                        fix: fix, fixSummary: String(format: L("Change to %@"), summary)))
            }
            if internalOnly.contains(capability.id) {
                if !enabled.isEmpty { flag(L("This flag is only enabled on Apple internal or research devices.")) }
            } else if iPadOnly.contains(capability.id) {
                guard isPhone else { notChecked.append(L(capability.title)); continue }
                if !enabled.isEmpty { flag(L("This feature is only official on iPad.")) }
            } else if let feature = featureOf[capability.id], let model {
                if !enabled.isEmpty && !model.features.contains(feature) {
                    flag(String(format: L("%@ does not officially support this feature."), model.name))
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
        // Official names may carry a suffix such as "(3rd generation)".
        if let model, let name = document.artwork["ArtworkDeviceProductDescription"] as? String,
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
