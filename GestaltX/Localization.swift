// SPDX-License-Identifier: GPL-3.0-only
import Foundation
func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

enum GestaltBrand {
    static let developer = "Lucas04-nhr"
    static let github = URL(string: "https://github.com/Lucas04-nhr")!
    static let projects = URL(string: "https://github.com/Lucas04-nhr/GestaltX")!
    /// The original project this fork is based on.
    static let upstreamDeveloper = "huamidev"
    static let upstreamProject = URL(string: "https://github.com/huamidev/GestaltX")!
    static let buildDate: String = {
        guard let url = Bundle.main.url(forResource: "BuildDate", withExtension: "txt"),
              let date = try? String(contentsOf: url, encoding: .utf8) else { return "2026-11-09" }
        return date.trimmingCharacters(in: .whitespacesAndNewlines)
    }()
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    static let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
}
