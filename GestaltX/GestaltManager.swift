// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 huamidev
import Foundation
import SwiftUI
import Combine

struct PlistImportOffer: Identifiable {
    let id = UUID()
    let data: Data
    let name: String
    let sharedSource: (SharedPlistInbox, SharedPlistEntry)?
    /// Set when the file is a GestaltX backup archive rather than a MobileGestalt plist.
    var archive: ArchiveOffer? = nil
}

struct ArchiveOffer {
    let payload: Data
    let backupCount: Int
}

@MainActor
final class GestaltManager: ObservableObject {
    @Published private(set) var snapshot: DocumentSnapshot?
    @Published private(set) var working: GestaltDocument?
    @Published private(set) var isBusy = false
    @Published private(set) var status = "Connect to your device or open a plist."
    @Published private(set) var deviceAccessible = false
    @Published private(set) var backups: [BackupRecord] = []
    @Published private(set) var logs: [String] = []
    @Published var message: String?
    @Published var isRespringing = false
    @Published var needsRespring = false
    @Published var choices: [String: PresetChoice] = [:]
    @Published var regionID = "keep"
    @Published var regionCodeID = "keep"
    @Published var modelID = "keep"
    @Published var changesName = false
    @Published var modelName = ""
    @Published var subtype = 0
    @Published private(set) var wapiChoice: WAPIChoice = .keep
    @Published private(set) var cacheOptionChoice: CacheOptionChoice = .keep
    private let files: GestaltFileStore
    private var exploitLogObserver: NSObjectProtocol?

    init() {
        let defaults = UserDefaults.standard
        let deviceID = defaults.string(forKey: "GestaltX.installationID") ?? UUID().uuidString
        defaults.set(deviceID, forKey: "GestaltX.installationID")
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GestaltX/Backups", isDirectory: true)
        files = GestaltFileStore(deviceURL: URL(fileURLWithPath: GestaltKeys.devicePath), backupDirectory: directory,
                                deviceID: deviceID, acquire: {
            let target = (GestaltKeys.devicePath as NSString).deletingLastPathComponent
            return try DeviceFileAccess.acquire(target)
        }, release: { worse_query_release($0) }, eventSink: { text in
            NotificationCenter.default.post(name: Notification.Name("GestaltX.worse_query.log"), object: nil,
                                            userInfo: ["message": text])
        })
        exploitLogObserver = NotificationCenter.default.addObserver(forName: Notification.Name("GestaltX.worse_query.log"), object: nil, queue: nil) { [weak self] notification in
            guard let text = notification.userInfo?["message"] as? String else { return }
            DispatchQueue.main.async { [weak self] in self?.log("[worse_query] " + text) }
        }
        if LegacyDeviceProof.removeKeys() { log("[keychain] Removed the device-proof key used by earlier versions") }
    }

    deinit { if let exploitLogObserver { NotificationCenter.default.removeObserver(exploitLogObserver) } }

    var changeKeys: [String] {
        guard let before = snapshot?.document.extra, let after = preview?.extra else { return [] }
        return Set(before.keys).union(after.keys).filter { key in
            switch (before[key], after[key]) {
            case (nil, nil): return false
            case (nil, _), (_, nil): return true
            case (let a?, let b?): return !GestaltDocument.valuesEqual(a, b)
            }
        }.sorted()
    }
    var cacheDataChanges: [CachedBooleanChange] {
        guard let original = snapshot?.document, let edited = preview else { return [] }
        return DeviceCacheOptions.changes(from: original, to: edited)
    }
    var changeCount: Int { changeKeys.count + cacheDataChanges.count }
    var hasDocument: Bool { snapshot != nil }
    var sourceIsDevice: Bool { snapshot?.source == .device }
    var artworkEditingError: GestaltFailure? {
        guard let working, !working.canEditArtwork else { return nil }
        return GestaltFailure("The artwork field is not a dictionary. Edit it in MG Control before using these presets.")
    }
    var displayedName: String {
        working?.artwork["ArtworkDeviceProductDescription"] as? String ?? working?.extra["Z/dqyWS6OZTRy10UcmUAhw"] as? String ?? UIDevice.current.model
    }
    var preview: GestaltDocument? {
        guard var doc = working, let snapshot else { return nil }
        for capability in Capability.all {
            capability.apply(choices[capability.id] ?? .keep, to: &doc, restoringFrom: snapshot)
        }
        if subtype != 0, doc.setArtwork(NSNumber(value: subtype), for: "ArtworkDeviceSubType") {
            doc.set(NSNumber(value: true), for: "YlEtTtHlNesRBMal1CqRaA")
        }
        if changesName, doc.setArtwork(modelName.trimmingCharacters(in: .whitespacesAndNewlines), for: "ArtworkDeviceProductDescription") {
            doc.set(modelName.trimmingCharacters(in: .whitespacesAndNewlines), for: "Z/dqyWS6OZTRy10UcmUAhw")
            doc.set(modelName.trimmingCharacters(in: .whitespacesAndNewlines), for: "bbtR9jQx50Fv5Af/affNtA")
        }
        doc.applyRegion(salesRegion: RegionPreset.all.first { $0.id == regionID },
                        regionCode: RegionPreset.all.first { $0.id == regionCodeID })
        doc.applyModel(modelPresets.first { $0.id == modelID })
        return doc
    }
    /// The model number presets, with the US model of this hardware when it is known.
    var modelPresets: [ModelPreset] {
        let original = snapshot?.originalValue(for: GestaltKeys.modelNumber) as? String
        let usModel = ModelPreset.usEquivalent(originalModelNumber: original, machine: GestaltAudit.liveMachine())
        return ModelPreset.all + (usModel.map { [$0] } ?? [])
    }

    private func log(_ text: String) {
        let time = Date.now.formatted(date: .omitted, time: .standard)
        logs.append("[\(time)] \(text)")
        if logs.count > 1000 { logs.removeFirst(logs.count - 1000) }
    }
    private func failed(_ error: Error) { message = error.localizedDescription; log(error.localizedDescription) }
    private func accept(_ loaded: DocumentSnapshot) {
        snapshot = loaded; working = loaded.document
        choices = [:]; regionID = "keep"; regionCodeID = "keep"; modelID = "keep"; changesName = false; subtype = 0
        cacheOptionChoice = .keep
        wapiChoice = .keep
        modelName = loaded.document.artwork["ArtworkDeviceProductDescription"] as? String ?? ""
    }
    func clearStaged() {
        if let snapshot { accept(snapshot) }
    }

    func stageCacheOption(_ choice: CacheOptionChoice) {
        guard !isBusy, var document = working, let snapshot else { return }
        do {
            let flags: CachedOptionFlags
            switch choice {
            case .keep: flags = try DeviceCacheOptions.flags(in: snapshot.document)
            case .enable: flags = .enabled
            case .restoreOriginal: flags = try snapshot.originalCachedOptionFlags()
            }
            try document.setCacheOptions(flags)
            working = document
            cacheOptionChoice = choice
        } catch { failed(error) }
    }

    func stageWAPI(_ choice: WAPIChoice) {
        guard !isBusy, var document = working, let snapshot else { return }
        do {
            let value: Bool
            switch choice {
            case .keep: value = try DeviceCacheOptions.wapi(in: snapshot.document)
            case .disable: value = false
            case .restoreOriginal: value = try snapshot.originalWAPI()
            }
            try document.setWAPI(value)
            working = document
            wapiChoice = choice
        } catch { failed(error) }
    }

    var canRestoreCacheOption: Bool {
        guard !isBusy, let snapshot, let working,
              let original = try? snapshot.originalCachedOptionFlags(),
              let current = try? DeviceCacheOptions.flags(in: working) else { return false }
        return cacheOptionChoice != .keep || current != original
    }

    func restoreCacheOption() async {
        guard !isBusy, let before = snapshot, let pending = working else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            var restored = before.document
            try restored.setCacheOptions(before.originalCachedOptionFlags())
            let result: DocumentSnapshot
            if restored.matches(before.document) {
                result = before
            } else {
                logChanges(from: before.document, to: restored, prefix: "[restore-option] ")
                result = try await files.commit(restored, expected: before)
                needsRespring = result.source == .device
                message = L(result.source == .device
                            ? "Write verified. Some features require a device restart."
                            : "Local changes saved. Export the plist to keep a copy.")
            }
            snapshot = result
            working = before.rebasingPendingEdits(pending, onto: result.document, excluding: [], preservingCacheData: false)
            if let value = try? DeviceCacheOptions.wapi(in: pending),
               (try? DeviceCacheOptions.wapi(in: before.document)) != value { try working?.setWAPI(value) }
            cacheOptionChoice = .keep
            log("[restore-option] " + L("Original values restored."))
            await reloadBackups()
        } catch { failed(error); await reloadBackups() }
    }

    func canRestore(_ capability: Capability) -> Bool {
        guard !isBusy, snapshot != nil, working != nil else { return false }
        if (choices[capability.id] ?? .keep) != .keep { return true }
        if capability.id == "dynamicIsland" && subtype != 0 { return true }
        if capability.id == ModelPreset.restoration.id && modelID != "keep" { return true }
        return differsFromOriginal(capability)
    }

    /// Whether the open document holds values for these keys that differ from the originals.
    func differsFromOriginal(_ capability: Capability) -> Bool {
        guard let snapshot, let working else { return false }
        return capability.keys.contains { key in
            switch (snapshot.originalValue(for: key), working.extra[key]) {
            case (nil, nil): false
            case (let a?, let b?): !GestaltDocument.valuesEqual(a, b)
            default: true
            }
        }
    }

    func restoreCapability(_ capability: Capability) async {
        guard !isBusy, let before = snapshot, let pending = working else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            var restored = before.document
            let removesAdded = choices[capability.id] == .removeAdded
            let absentKeys = removesAdded ? Set(capability.keys) : Set<String>()
            capability.apply(removesAdded ? .removeAdded : .disable, to: &restored, restoringFrom: before)
            let result: DocumentSnapshot
            if restored.matches(before.document) && absentKeys.isEmpty {
                result = before
            } else {
                for line in diffLines(before.document.extra, restored.extra) { log("[restore-field] " + line) }
                result = try await files.commit(restored, expected: before, originallyAbsentKeys: absentKeys)
                needsRespring = result.source == .device
                message = L(result.source == .device ? "Original values restored." : "Local changes saved. Export the plist to keep a copy.")
            }
            snapshot = result
            working = before.rebasingPendingEdits(pending, onto: result.document, excluding: Set(capability.keys))
            choices[capability.id] = .keep
            if capability.id == "dynamicIsland" { subtype = 0 }
            if capability.id == ModelPreset.restoration.id { modelID = "keep" }
            log("[restore-field] " + L(capability.title) + ": " + L("Original values restored."))
            await reloadBackups()
        } catch { failed(error); await reloadBackups() }
    }
    func clearLog() { logs = [] }

    // MARK: - Exploit-process logging

    private func describe(_ value: Any?) -> String {
        guard let value else { return "∅" }
        if let data = value as? Data { return "\(data.count) bytes" }
        let text = PlistValueKind.detect(value).text(for: value)
        return text.count > 80 ? String(text.prefix(80)) + "…" : text
    }

    private func diffLines(_ before: [String: Any], _ after: [String: Any], prefix: String = "") -> [String] {
        var lines: [String] = []
        for key in Set(before.keys).union(after.keys).sorted() {
            let path = prefix.isEmpty ? key : prefix + "." + key
            switch (before[key], after[key]) {
            case (nil, let value?): lines.append("+ \(path) = \(describe(value))")
            case (let value?, nil): lines.append("- \(path)  (was \(describe(value)))")
            case (let oldValue?, let newValue?):
                guard !GestaltDocument.valuesEqual(oldValue, newValue) else { continue }
                if let oldDict = oldValue as? [String: Any], let newDict = newValue as? [String: Any] {
                    lines.append(contentsOf: diffLines(oldDict, newDict, prefix: path))
                } else {
                    lines.append("~ \(path): \(describe(oldValue)) → \(describe(newValue))")
                }
            default: break
            }
        }
        return lines
    }

    private func summarize(_ document: GestaltDocument) -> [String] {
        var lines = ["CacheExtra: \(document.extra.count) keys"]
        if let cacheData = document.root["CacheData"] as? Data { lines.append("CacheData: \(cacheData.count) bytes") }
        do {
            let layout = try MobileGestaltCacheLayout.resolve(in: document)
            lines.append("Cache layout: \(layout.uuid), \(layout.slotCount) slots")
            lines.append(String(format: "green-tea: index %d, offset 0x%X; not-green-tea: index %d, offset 0x%X",
                                layout.greenTeaIndex, layout.greenTeaOffset, layout.notGreenTeaIndex, layout.notGreenTeaOffset))
        } catch { lines.append("Cache offsets: " + error.localizedDescription) }
        if let model = document.artwork["ArtworkDeviceProductDescription"] as? String { lines.append("model name: \(model)") }
        if let subtype = document.artwork["ArtworkDeviceSubType"] { lines.append("subtype: \(describe(subtype))") }
        if let region = document.extra[GestaltKeys.regionCode] as? String { lines.append("region code: \(region)") }
        for key in [GestaltKeys.regionInfo, GestaltKeys.legacyRegionInfo] {
            if let info = document.extra[key] as? String { lines.append("region info: \(info)") }
        }
        if let product = document.extra[GestaltKeys.productType] as? String { lines.append("product type: \(product)") }
        return lines
    }

    private func logChanges(from original: GestaltDocument, to edited: GestaltDocument, prefix: String) {
        for line in diffLines(original.root, edited.root) { log(prefix + line) }
        for change in DeviceCacheOptions.changes(from: original, to: edited) {
            log(prefix + "CacheData.\(change.name) @\(String(format: "0x%X", change.offset)): \(change.before) → \(change.after)")
        }
    }

    func connect(showErrorAlert: Bool = true) async {
        guard !isBusy else { return }
        isBusy = true; status = "Checking device access…"
        log("[read] Starting MobileGestalt access")
        defer { isBusy = false }
        do {
            let result = try await files.loadDevice()
            accept(result); deviceAccessible = true; status = "Device connected"
            log("[read] plist: \(result.data.count) bytes")
            for line in summarize(result.document) { log("[read] " + line) }
            log(L("Device connected"))
        } catch {
            deviceAccessible = false; status = "Device access unavailable"
            if showErrorAlert { failed(error) } else { log(error.localizedDescription) }
        }
        await reloadBackups()
    }

    #if targetEnvironment(simulator)
    func open(_ url: URL) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) <= 16 * 1024 * 1024 else { throw GestaltFailure("Choose a plist smaller than 16 MB.") }
            let result = try await files.loadLocal(data: Data(contentsOf: url), name: url.lastPathComponent)
            accept(result); status = "Local file opened"; needsRespring = false
            log("[open] \(url.lastPathComponent): \(result.data.count) bytes")
            for line in summarize(result.document) { log("[open] " + line) }
            log(L("Local file opened") + ": " + url.lastPathComponent)
        } catch { failed(error) }
    }

    #endif

    /// Imports are not verified. The confirmation asks the user to make sure of the file's source.
    private func prepareImport(_ bytes: Data, name: String, sharedSource: (SharedPlistInbox, SharedPlistEntry)?) throws -> PlistImportOffer {
        PlistImportOffer(data: try LegacyDeviceProof.plainPlist(bytes), name: name, sharedSource: sharedSource)
    }

    func prepareSharedPlist(_ entry: SharedPlistEntry, from inbox: SharedPlistInbox) async -> SharedImportPreparation<PlistImportOffer> {
        guard !isBusy else { return .deferred(nil) }
        isBusy = true
        defer { isBusy = false }
        do {
            let offer = try prepareImport(inbox.read(entry), name: entry.name, sharedSource: (inbox, entry))
            log("[share] \(entry.name): waiting for import confirmation")
            return .ready(offer)
        } catch {
            // Imports are not verified, so a failure here is the file itself; set it aside.
            log("[share] " + error.localizedDescription)
            inbox.reject(entry)
            return .rejected(error.localizedDescription)
        }
    }

    func prepareFileImport(_ url: URL) async -> PlistImportOffer? {
        guard !isBusy else { return nil }
        isBusy = true
        defer { isBusy = false }
        do {
            let bytes = try SharedPlistInbox.readFile(at: url, limit: BackupArchive.maximumByteCount)
            if let payload = try BackupArchive.payload(of: bytes) {
                let root = try? PropertyListSerialization.propertyList(from: payload, options: [], format: nil) as? [String: Any]
                let count = (root?["backups"] as? [Any])?.count ?? 0
                log("[archive] \(url.lastPathComponent): \(count) backups")
                return PlistImportOffer(data: Data(), name: url.lastPathComponent, sharedSource: nil,
                                        archive: ArchiveOffer(payload: payload, backupCount: count))
            }
            try SharedPlistInbox.validate(bytes)
            return try prepareImport(bytes, name: url.lastPathComponent, sharedSource: nil)
        } catch { failed(error); return nil }
    }

    /// Settings saved in a backup archive. The installation ID is not restored; imported backups are rebound instead.
    static let archivedSettingKeys = ["GestaltX.acceptedWelcome.v1", "GestaltX.sharedImportNotice.v1"]

    /// Exports every backup, the original-value record and the app settings as one file.
    func exportAllBackups() async -> URL? {
        guard !isBusy else { return nil }
        isBusy = true; defer { isBusy = false }
        do {
            var settings: [String: Any] = [:]
            for key in Self.archivedSettingKeys { if let value = UserDefaults.standard.object(forKey: key) { settings[key] = value } }
            let payload = try await files.archivePayload(settings: settings)
            let file = try BackupArchive.file(payload: payload)
            log("[archive] Exported \(backups.count) backups, \(file.count) bytes")
            return try exportData(file, name: "GestaltX-Backups-" + timestamp(.now) + ".plist")
        } catch { failed(error); return nil }
    }

    private func importArchive(_ archive: ArchiveOffer) async throws {
        let result = try await files.importArchive(archive.payload)
        for key in Self.archivedSettingKeys { if let value = result.settings[key] as? Bool { UserDefaults.standard.set(value, forKey: key) } }
        var lines = [String(format: L("Added %lld backups. %lld were already in the list."), Int64(result.added), Int64(result.alreadyPresent))]
        if result.invalid > 0 { lines.append(String(format: L("%lld entries could not be read and were skipped."), Int64(result.invalid))) }
        if result.originalsRestored { lines.append(L("The original-value record was restored.")) }
        if result.originalsKept { lines.append(L("The current original-value record was kept.")) }
        message = lines.joined(separator: "\n")
        log("[archive] " + lines.joined(separator: " "))
        await reloadBackups()
    }

    /// Saves an imported plist to the backup library. It does not open or write it.
    @discardableResult
    func acceptImport(_ offer: PlistImportOffer) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        do {
            if let archive = offer.archive { try await importArchive(archive); return true }
            let record = try await files.saveImport(offer.data)
            discardImport(offer)
            log("[import] \(offer.name): \(offer.data.count) bytes saved as backup \(record.filename)")
            message = L("Saved to Backups. Restore it from the Backups tab.")
            await reloadBackups()
            return true
        } catch { failed(error); return false }
    }

    func discardImport(_ offer: PlistImportOffer) {
        if let (inbox, entry) = offer.sharedSource {
            do { try inbox.acknowledge(entry) }
            catch { log("[share] Inbox cleanup failed") }
        }
    }

    func stage(_ draft: FieldDraft) throws {
        let key = draft.key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw GestaltFailure("Enter a field key.") }
        guard var doc = working else { throw GestaltFailure("Load a document first.") }
        if draft.originalKey != key && doc.extra[key] != nil { throw GestaltFailure("That key already exists. Edit the existing field instead.") }
        let value = try draft.parsedValue()
        if let originalKey = draft.originalKey, originalKey != key { doc.set(nil, for: originalKey) }
        doc.set(value, for: key); working = doc
        // Explicit field edits take precedence: discard presets that would overwrite the key.
        discardPresets(touching: Set([key, draft.originalKey].compactMap { $0 }))
    }
    private func discardPresets(touching changedKeys: Set<String>) {
        for capability in Capability.all where !changedKeys.isDisjoint(with: capability.keys) { choices[capability.id] = .keep }
        if !changedKeys.isDisjoint(with: [GestaltKeys.regionCode, GestaltKeys.regionInfo, GestaltKeys.legacyRegionInfo]) { regionID = "keep"; regionCodeID = "keep" }
        // A staged Dynamic Island layout also sets the Dynamic Island flag.
        if changedKeys.contains(GestaltKeys.artwork) || changedKeys.contains("YlEtTtHlNesRBMal1CqRaA") { subtype = 0 }
        if changedKeys.contains(GestaltKeys.modelNumber) { modelID = "keep" }
        if !changedKeys.isDisjoint(with: [GestaltKeys.artwork, "Z/dqyWS6OZTRy10UcmUAhw", "bbtR9jQx50Fv5Af/affNtA"]) { changesName = false }
    }
    /// Stages audit fixes like any other edit. Nothing is written until the changes are applied.
    func stageFixes(_ findings: [GestaltAudit.Finding]) {
        guard !isBusy, var document = working, !findings.isEmpty else { return }
        for finding in findings { finding.apply(to: &document) }
        working = document
        discardPresets(touching: Set(findings.flatMap(\.fix.keys)))
        log("[audit] Staged fixes: " + findings.map(\.id).joined(separator: ", "))
    }
    func removeField(_ key: String) {
        working?.set(nil, for: key)
        for capability in Capability.all where capability.keys.contains(key) { choices[capability.id] = .keep }
        if [GestaltKeys.regionCode, GestaltKeys.regionInfo, GestaltKeys.legacyRegionInfo].contains(key) { regionID = "keep"; regionCodeID = "keep" }
        if key == GestaltKeys.artwork { subtype = 0 }
        if key == GestaltKeys.modelNumber { modelID = "keep" }
        if [GestaltKeys.artwork, "Z/dqyWS6OZTRy10UcmUAhw", "bbtR9jQx50Fv5Af/affNtA"].contains(key) { changesName = false }
    }

    func apply() async {
        guard !isBusy, let snapshot, let edited = preview else { return }
        if (changesName || subtype != 0), let error = artworkEditingError { failed(error); return }
        guard changeCount > 0 else { return }
        if changesName && modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { failed(GestaltFailure("Enter a model name before applying.")); return }
        isBusy = true
        defer { isBusy = false }
        do {
            log("[apply] source=\(snapshot.source.rawValue) fields=\(changeCount)")
            logChanges(from: snapshot.document, to: edited, prefix: "[diff] ")
            let absentKeys = Set(Capability.all.filter { choices[$0.id] == .removeAdded }.flatMap(\.keys))
            let result = try await files.commit(edited, expected: snapshot, originallyAbsentKeys: absentKeys)
            accept(result); needsRespring = result.source == .device
            status = result.source == .device ? "Changes verified on device" : "Local changes saved"
            let changedCacheOption = !DeviceCacheOptions.changes(from: snapshot.document, to: edited).isEmpty
            message = L(result.source == .device
                        ? (changedCacheOption ? "Write verified. Some features require a device restart." : "Write verified. Some features require a device restart.")
                        : "Local changes saved. Export the plist to keep a copy.")
            log(L(status)); await reloadBackups()
        } catch { failed(error); await reloadBackups() }
    }

    var canCreateBackup: Bool { !isBusy && deviceAccessible }
    var canExportDocument: Bool { !isBusy && hasDocument && changeCount == 0 }
    func canRestore(_ record: BackupRecord) -> Bool { !isBusy && changeCount == 0 && record.source == .device }

    /// Backs up the live device file, whatever document is currently open.
    func backup() async {
        guard canCreateBackup else { return }
        isBusy = true; defer { isBusy = false }
        do { try await files.backupDevice(); log(L("Backup saved")); message = L("Backup saved"); await reloadBackups() }
        catch { failed(error) }
    }
    func reloadBackups() async {
        do { backups = try await files.backups() } catch { failed(error) }
    }
    /// Restoring always targets this device, regardless of the open document.
    func restore(_ record: BackupRecord) async {
        guard !isBusy else { return }
        guard changeCount == 0 else { failed(GestaltFailure("Apply or discard your staged changes before restoring a backup.")); return }
        isBusy = true; defer { isBusy = false }
        do {
            let live = try await files.loadDevice()
            deviceAccessible = true
            let restored = try GestaltDocument(data: await files.backupData(record))
            log("[restore] \(record.filename) · \(record.byteCount) bytes · reason=\(record.reason)")
            logChanges(from: live.document, to: restored, prefix: "[restore-diff] ")
            let result = try await files.restore(record, onto: live)
            accept(result); needsRespring = true
            status = "Changes verified on device"
            message = L("Backup restored and verified.") + " " + L("Some changes require a device restart.")
            log(message ?? ""); await reloadBackups()
        } catch { failed(error); await reloadBackups() }
    }
    /// Opens a backup for viewing or editing. Saving it never changes the device.
    func openBackup(_ record: BackupRecord) async {
        guard !isBusy else { return }
        guard changeCount == 0 else { failed(GestaltFailure("Save or discard your current changes before opening another plist.")); return }
        isBusy = true; defer { isBusy = false }
        do {
            let data = try await files.backupData(record)
            let loaded = try await files.loadLocal(data: data, name: exportName(for: record.date, title: record.name))
            accept(loaded); status = "Local file opened"; needsRespring = false
            log("[open] \(record.filename) opened as a local document")
        } catch { failed(error) }
    }
    func renameBackup(_ record: BackupRecord, to name: String) async {
        guard !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        do {
            let renamed = try await files.renameBackup(record, to: name)
            log("[backup] \(record.filename) renamed to \(renamed.name ?? "(none)")")
            await reloadBackups()
        } catch { failed(error); await reloadBackups() }
    }
    func deleteBackup(_ record: BackupRecord) async {
        guard !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        do { try await files.deleteBackup(record); await reloadBackups() } catch { failed(error) }
    }
    /// Exports the backup's plain plist, exactly as saved.
    func exportBackup(_ record: BackupRecord) async -> URL? {
        do {
            return try exportData(await files.backupData(record), name: exportName(for: record.date, title: record.name))
        } catch { failed(error); return nil }
    }
    /// Exports the open document as last read or saved. Staged changes are never exported.
    func exportDocument() -> URL? {
        guard canExportDocument, let snapshot else { return nil }
        do {
            return try exportData(snapshot.data, name: exportName(for: .now))
        }
        catch { failed(error); return nil }
    }
    private func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
    private func exportName(for date: Date, title: String? = nil) -> String {
        let stamp = "MobileGestalt-" + timestamp(date)
        // Keep the name file-system safe; the date keeps names unique.
        let safe = (title ?? "").map { "/\\:*?\"<>|".contains($0) || $0.isNewline ? "-" : $0 }
        let cleaned = String(safe).trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return (cleaned.isEmpty ? stamp : String(cleaned.prefix(80)) + " " + stamp) + ".plist"
    }
    private func exportData(_ data: Data, name: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name); try data.write(to: url, options: .atomic)
        return url
    }
}
