// SPDX-License-Identifier: GPL-3.0-only
import Foundation
func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

enum GestaltBrand {
    static let developer = "huamidev"
    static let github = URL(string: "https://github.com/huamidev")!
    static let projects = URL(string: "https://github.com/huamidev/GestaltX")!
    static let buildDate: String = {
        guard let url = Bundle.main.url(forResource: "BuildDate", withExtension: "txt"),
              let date = try? String(contentsOf: url, encoding: .utf8) else { return "2026-11-09" }
        return date.trimmingCharacters(in: .whitespacesAndNewlines)
    }()
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    /// Short commit hash of the built source, written to BuildCommit.txt at build time.
    static let commit: String? = {
        guard let url = Bundle.main.url(forResource: "BuildCommit", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let hash = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return hash.isEmpty ? nil : hash
    }()
    /// The marketing version with the commit hash, such as 1.0.3-abc1234.
    static var displayVersion: String { commit.map { version + "-" + $0 } ?? version }
    static let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
}
