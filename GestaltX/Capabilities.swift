// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 huamidev
// Public MobileGestalt key mappings cross-checked against MGKeys, Nugget and mond.
// Preset behavior is independently implemented for GestaltX.
import Foundation

enum CapabilityCategory: String, CaseIterable, Identifiable {
    case display = "Display", device = "Device", ipad = "iPad", intelligence = "Intelligence", advanced = "Advanced"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .display: "display"
        case .device: "iphone"
        case .ipad: "ipad.landscape"
        case .intelligence: "sparkles"
        case .advanced: "wrench.and.screwdriver"
        }
    }
    var subtitle: String {
        switch self {
        case .display: "Dynamic Island, Always-On and Liquid Glass"
        case .device: "Charging, buttons and device identity"
        case .ipad: "Stage Manager and app compatibility"
        case .intelligence: "Region and generative model capabilities"
        case .advanced: "Internal features and research settings"
        }
    }
}

struct Capability: Identifiable {
    let id: String
    let category: CapabilityCategory
    let title: String
    let detail: String
    let keys: [String]
    var caution = false
    /// Per-key values for presets that are not a plain Boolean 1, such as the
    /// parallax switch (0) or the AOD flipbook count.
    var values: [String: Any]? = nil
    var effectHint: String {
        switch id {
        case "ai", "siriOnDevice", "audioIntelligence", "personalTranslator", "photosCleanUp",
             "handwritingSynthesis", "alwaysListeningSiri":
            "Restart required. Apple Intelligence also depends on device and region."
        case "pencil": "Restart the device, then reopen Settings. Pencil hardware support is still required."
        case "bootChime", "chargeLimit", "tapToWake", "cameraControl", "actionButton",
             "internal", "storage", "srd", "aodHighLuminance", "aodFlipbook", "aodFlipbookCount",
             "pwm", "displayPort", "collisionSOS", "internalSettings":
            "A device restart may be required."
        default: "Respring first. Restart the device if the change does not appear."
        }
    }
    var enabled: Any { id == "ipadApps" ? [1, 2] : NSNumber(value: 1) }
    func apply(_ choice: PresetChoice, to document: inout GestaltDocument, restoringFrom snapshot: DocumentSnapshot) {
        guard choice != .keep else { return }
        for key in keys {
            switch choice {
            case .keep: break
            case .enable: document.set(values?[key] ?? enabled, for: key)
            case .disable: document.set(snapshot.originalValue(for: key), for: key)
            case .removeAdded: document.set(nil, for: key)
            }
        }
    }
    static let all: [Self] = [
        .init(id: "dynamicIsland", category: .display, title: "Dynamic Island", detail: "Enable the alternate Dynamic Island capability.", keys: ["YlEtTtHlNesRBMal1CqRaA"]),
        .init(id: "aod", category: .display, title: "Always-On Display", detail: "Display behavior depends on the panel. May increase power use and burn-in risk.", keys: ["2OOJf1VhaM7NxfRok3HbWQ", "j8/Omm6s1lsmTDFsXjsBfA"], caution: true),
        .init(id: "aodVibrancy", category: .display, title: "AOD Vibrancy", detail: "Adjust Always-On rendering capabilities.", keys: ["ykpu7qyhqFweVMKtxNylWA"]),
        .init(id: "aodHighLuminance", category: .display, title: "High-Luminance Always-On Display", detail: "Allow Always-On Display to reach a higher brightness level.", keys: ["7brdL5xrEUWnlF9C0kdg5A"]),
        .init(id: "aodFlipbook", category: .display, title: "Always-On Display Flipbook", detail: "Enable AOD flipbook widgets on the Lock Screen.", keys: ["aoJSd/MXk7M40NgXTM6x+g"]),
        .init(id: "aodFlipbookCount", category: .display, title: "AOD Flipbook Count", detail: "Set how many AOD flipbook entries are allowed. Experimental; the accepted range varies by build.", keys: ["qqrspu7CpuPdZwSDxNY+Fg"], caution: true, values: ["qqrspu7CpuPdZwSDxNY+Fg": NSNumber(value: 3)]),
        .init(id: "parallax", category: .display, title: "Disable Wallpaper Parallax", detail: "Stop the wallpaper from moving with device motion.", keys: ["UIParallaxCapability"], values: ["UIParallaxCapability": NSNumber(value: 0)]),
        .init(id: "hdrPhotoDisplay", category: .display, title: "HDR Photo Display", detail: "Enable true HDR rendering for photos.", keys: ["a1r7npIrhXsZ7SmKRKC1eA"]),
        .init(id: "pwm", category: .display, title: "Pulse Width Modulation", detail: "Advertise PWM display support. Actual dimming behavior depends on the panel.", keys: ["6IejgN+1Fmu5/QrZFOIeNw"], caution: true),
        .init(id: "displayPort", category: .display, title: "DisplayPort Output", detail: "Advertise DisplayPort output support. Compatible hardware is still required.", keys: ["CoWnN4xo783YGn4wLrUatA"], caution: true),
        .init(id: "liquidGlass", category: .display, title: "Liquid Glass Low-Power Rendering", detail: "Use the low-performance rendering capability on iOS 26 and later.", keys: ["SAGvsp6O6kAQ4fEfDJpC4Q"]),
        .init(id: "bootChime", category: .device, title: "Boot & Shutdown Chime", detail: "Expose the startup and shutdown sound capability.", keys: ["QHxt+hGLaBPbQJbXiUJX3w"]),
        .init(id: "chargeLimit", category: .device, title: "Charge Limit", detail: "Show charging limit settings. Actual charging control depends on hardware.", keys: ["37NVydb//GP/GrhuTN+exg"]),
        .init(id: "tapToWake", category: .device, title: "Tap to Wake", detail: "Expose tap-to-wake on devices where it is hidden.", keys: ["yZf3GTRMGTuwSV/lD7Cagw"]),
        .init(id: "cameraControl", category: .device, title: "Camera Control", detail: "Show Camera Control settings. Does not add a physical button.", keys: ["CwvKxM2cEogD3p+HYgaW0Q", "oOV1jhJbdV3AddkcCg0AEA"]),
        .init(id: "actionButton", category: .device, title: "Action Button", detail: "Show the Action Button settings page.", keys: ["cT44WE1EohiwRzhsZ8xEsw"]),
        .init(id: "collisionSOS", category: .device, title: "Collision SOS", detail: "Show collision detection in Emergency SOS settings. Hardware support is still required.", keys: ["HCzWusHQwZDea6nNhaKndw"]),
        .init(id: "audioMix", category: .device, title: "Audio Mix", detail: "Enable the audio mix capability for supported media.", keys: ["aVL5GE3tx0LSCI/ErfrJGA"]),
        .init(id: "spatialFaceTimeAudio", category: .device, title: "Spatial FaceTime Audio", detail: "Enable spatial audio playback for FaceTime.", keys: ["/EVOCjM/Nmb2roP5ebtEFA"]),
        .init(id: "pencil", category: .ipad, title: "Apple Pencil", detail: "Expose Apple Pencil settings. Hardware support is still required.", keys: ["yhHcB0iH0d1XzPO/CFd3ow"]),
        .init(id: "stageManager", category: .ipad, title: "Stage Manager", detail: "Expose Stage Manager support. Layout behavior varies by device.", keys: ["qeaj75wk3HF4DwQ8qbIi7g"], caution: true),
        .init(id: "ipadApps", category: .ipad, title: "iPad App Compatibility", detail: "Allow iPad app compatibility types on iPhone.", keys: ["9MZ5AdH43csAUajl/dU+IQ"]),
        .init(id: "ai", category: .intelligence, title: "Apple Intelligence Capability", detail: "Set the generative models capability. Availability also depends on hardware, region and Apple services.", keys: ["A62OafQ85EJAiiqKn4agtg"]),
        .init(id: "siriOnDevice", category: .intelligence, title: "On-Device Siri", detail: "Advertise on-device Siri understanding. Availability depends on hardware and region.", keys: ["K/R1GfGfCkXvEhaPS2Vrng"], caution: true),
        .init(id: "audioIntelligence", category: .intelligence, title: "Audio Intelligence", detail: "Advertise the iOS 27 audio intelligence capability.", keys: ["rb2tKZxlj0Gm2tBmUQSLqQ"], caution: true),
        .init(id: "personalTranslator", category: .intelligence, title: "Personal Translator", detail: "Advertise the personal translator capability.", keys: ["M1n2sAqf33NAOgZRGxQYBA"], caution: true),
        .init(id: "photosCleanUp", category: .intelligence, title: "Photos Clean Up", detail: "Advertise the photos inpainting (Clean Up) capability.", keys: ["XNCjqOupLM/S8fNyxRNQTA"], caution: true),
        .init(id: "handwritingSynthesis", category: .intelligence, title: "Handwriting Synthesis", detail: "Advertise the handwriting synthesis model capability.", keys: ["YgYIIViDt1kgzyIsIV61vA"], caution: true),
        .init(id: "alwaysListeningSiri", category: .intelligence, title: "Always-Listening Hey Siri", detail: "Advertise always-listening Hey Siri support.", keys: ["TusANsf9Lfe3P/9fIXXSrQ"], caution: true),
        .init(id: "internal", category: .advanced, title: "Apple Internal Features", detail: "Expose internal menus. Some system services may behave differently.", keys: ["EqrsVvjcYDdxHBiQmGhAWw"], caution: true),
        .init(id: "storage", category: .advanced, title: "Internal Storage View", detail: "Show internal storage categories. Experimental on iPad.", keys: ["LBJfwOEzExRxzlAnSuI7eg"], caution: true),
        .init(id: "srd", category: .advanced, title: "Security Research Device", detail: "Change the SRD capability flag. This does not turn the device into an Apple SRD.", keys: ["XYlJKKkj2hztRP1NWWnhlw"], caution: true),
        .init(id: "internalSettings", category: .advanced, title: "Internal Settings Bundle", detail: "Expose Apple's internal settings bundle. Some system services may behave differently.", keys: ["Oji6HRoPi7rH7HPdWVakuw"], caution: true),
    ]
}

enum PresetChoice: Int, CaseIterable, Identifiable {
    case keep, enable, disable, removeAdded
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .keep: "Keep Current"
        case .enable: "Enable"
        case .disable: "Disable (Restore Original)"
        case .removeAdded: "Remove Added Fields"
        }
    }
}

struct RegionPreset: Identifiable {
    let id: String
    let title: String
    let code: String
    let info: String
    static let all: [Self] = [
        .init(id: "keep", title: "Keep Current", code: "", info: ""),
        .init(id: "US", title: "United States", code: "LL", info: "LL/A"),
        .init(id: "HK", title: "Hong Kong", code: "ZA", info: "ZA/A"),
        .init(id: "JP", title: "Japan", code: "J", info: "J/A"),
        .init(id: "CN", title: "China (Mainland)", code: "CH", info: "CH/A"),
        .init(id: "TW", title: "Taiwan", code: "TA", info: "TA/A"),
        .init(id: "UK", title: "United Kingdom", code: "B", info: "B/A"),
        .init(id: "CA", title: "Canada", code: "C", info: "C/A")
    ]
}

struct ModelPreset: Identifiable {
    static let restoration = Capability(id: "modelNumber", category: .intelligence, title: "Model Number",
                                        detail: "", keys: [GestaltKeys.modelNumber])
    let id: String
    let title: String
    let value: String
    static let all: [Self] = [
        .init(id: "keep", title: "Keep Current", value: ""),
        .init(id: "A3472", title: "A3472 — 18 Pro · United States", value: "A3472"),
        .init(id: "A3713", title: "A3713 — 18 Pro · Canada / Japan", value: "A3713"),
        .init(id: "A3714", title: "A3714 — 18 Pro · Other regions", value: "A3714"),
        .init(id: "A3715", title: "A3715 — 18 Pro · China mainland", value: "A3715"),
        .init(id: "A3473", title: "A3473 — 18 Pro Max · United States", value: "A3473"),
        .init(id: "A3716", title: "A3716 — 18 Pro Max · Canada / Japan", value: "A3716"),
        .init(id: "A3717", title: "A3717 — 18 Pro Max · Other regions", value: "A3717"),
        .init(id: "A3718", title: "A3718 — 18 Pro Max · China mainland", value: "A3718")
    ]

    static let usEquivalentID = "usEquivalent"

    var displayTitle: String {
        id == Self.usEquivalentID ? String(format: L("US model for this device · %@"), value) : L(title)
    }

    /// The US (LL/A) model number of this hardware. Returns nil when the hardware is unknown,
    /// already uses the US model, or a listed preset offers the same value.
    static func usEquivalent(originalModelNumber: String?, machine: String) -> Self? {
        let original = originalModelNumber ?? ""
        guard let value = USModelNumber.byModelNumber[original] ?? USModelNumber.byProductType[machine],
              value != original, !all.contains(where: { $0.value == value }) else { return nil }
        return .init(id: usEquivalentID, title: "", value: value)
    }
}

/// US (LL/A) regulatory model numbers. Adapted from Erosion-CN
/// (https://github.com/Kianuni/Erosion-CN, GPL-3.0).
enum USModelNumber {
    /// Mainland China and international model numbers, mapped to the US model of the same hardware.
    static let byModelNumber: [String: String] = [
        // iPhone 18 Pro Max, iPhone 18 Pro and iPhone Duo
        "A3718": "A3473", "A3717": "A3473", "A3716": "A3473",
        "A3715": "A3472", "A3714": "A3472", "A3713": "A3472",
        "A3721": "A3447", "A3720": "A3447", "A3719": "A3447",
        // iPhone 17, 17 Pro, 17 Pro Max, Air and 17e
        "A3520": "A3258", "A3519": "A3258",
        "A3523": "A3256", "A3522": "A3256",
        "A3526": "A3257", "A3525": "A3257",
        "A3518": "A3260", "A3517": "A3260",
        "A3635": "A3575", "A3634": "A3575",
        // iPhone 16, 16 Plus, 16 Pro, 16 Pro Max and 16e
        "A3288": "A3081", "A3287": "A3081",
        "A3291": "A3082", "A3290": "A3082",
        "A3294": "A3083", "A3293": "A3083",
        "A3297": "A3084", "A3296": "A3084",
        "A3410": "A3212", "A3409": "A3212",
        // iPhone 15, 15 Plus, 15 Pro and 15 Pro Max
        "A3092": "A2846", "A3090": "A2846",
        "A3096": "A2847", "A3094": "A2847",
        "A3104": "A2848", "A3102": "A2848",
        "A3108": "A2849", "A3106": "A2849",
    ]

    /// The US model number of each hardware model, for model numbers missing above.
    static let byProductType: [String: String] = [
        // iPhone 14 lineup
        "iPhone14,7": "A2649", "iPhone14,8": "A2632", "iPhone15,2": "A2650", "iPhone15,3": "A2651",
        // iPhone 15 lineup
        "iPhone15,4": "A2846", "iPhone15,5": "A2847", "iPhone16,1": "A2848", "iPhone16,2": "A2849",
        // iPhone 16 lineup
        "iPhone17,1": "A3083", "iPhone17,2": "A3084", "iPhone17,3": "A3081", "iPhone17,4": "A3082",
        "iPhone17,5": "A3212",
        // iPhone 17 lineup
        "iPhone18,1": "A3256", "iPhone18,2": "A3257", "iPhone18,3": "A3258", "iPhone18,4": "A3260",
        "iPhone18,5": "A3575",
        // iPhone 18 lineup, including the regional board variants
        "iPhone19,1": "A3471", "iPhone19,2": "A3472", "iPhone19,3": "A3473", "iPhone19,4": "A3447",
        "iPhone19,5": "A3471", "iPhone19,6": "A3472", "iPhone19,7": "A3473", "iPhone19,8": "A3447",
        // iPads that support Apple Intelligence
        "iPad13,4": "A2377", "iPad13,5": "A2301", "iPad13,6": "A2301", "iPad13,7": "A2301",
        "iPad13,8": "A2378", "iPad13,9": "A2379", "iPad13,10": "A2379", "iPad13,11": "A2379",
        "iPad13,16": "A2588", "iPad13,17": "A2589",
        "iPad14,3": "A2759", "iPad14,4": "A2435", "iPad14,5": "A2436", "iPad14,6": "A2764",
        "iPad14,8": "A2902", "iPad14,9": "A2903", "iPad14,10": "A2898", "iPad14,11": "A2899",
        "iPad15,3": "A3266", "iPad15,4": "A3267", "iPad15,5": "A3268", "iPad15,6": "A3269",
        "iPad16,1": "A2993", "iPad16,2": "A2995",
        "iPad16,3": "A2836", "iPad16,4": "A2837", "iPad16,5": "A2925", "iPad16,6": "A2926",
    ]
}

struct FieldDraft: Identifiable {
    let id = UUID()
    var originalKey: String?
    var key = ""
    var kind = PlistValueKind.string
    var text = ""
    private let originalValue: Any?
    private let originalText: String?

    init(originalKey: String? = nil, key: String = "", kind: PlistValueKind = .string,
         text: String = "", originalValue: Any? = nil) {
        self.originalKey = originalKey; self.key = key; self.kind = kind; self.text = text
        self.originalValue = originalValue
        self.originalText = originalValue == nil ? nil : text
    }

    func parsedValue() throws -> Any {
        // Text formats can be less precise than a binary plist, including Date
        // values nested inside an XML array or dictionary. A no-op edit or a
        // key rename must preserve the exact value that populated the editor.
        if let originalValue, kind == PlistValueKind.detect(originalValue),
           text == originalText {
            return originalValue
        }
        return try kind.parse(text)
    }
}
