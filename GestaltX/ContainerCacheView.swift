import SwiftUI
import Combine

private struct CacheScanSnapshot: Sendable {
    var entries: [ContainerCacheEntry] = []
    var failures = 0
}

private enum CacheDeviceWorker {
    static let root = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application")

    static func scan(maximumInode: UInt64, progress: @escaping @Sendable (Double) -> Void) throws -> CacheScanSnapshot {
        #if targetEnvironment(simulator)
        throw NSError(domain: "GestaltX.ContainerCache", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: L("Container scanning requires a supported physical device.")])
        #else
        guard !GXEntitlementsReader.usableAppGroups().isEmpty else {
            throw NSError(domain: "GestaltX.ContainerCache", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: L("The signed app has no usable App Group. Enable its App Group capability and sign it again.")])
        }
        let paths: [String]
        if let children = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil), !children.isEmpty {
            paths = children.filter { UUID(uuidString: $0.lastPathComponent) != nil }.map(\.path)
        } else {
            guard let discovered = GXContainerPaths(maximumInode, { inode in
                progress(Double(inode) / Double(maximumInode) * 0.8)
                return !Task.isCancelled
            }) else {
                try Task.checkCancellation()
                throw NSError(domain: "GestaltX.ContainerCache", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: L("Container discovery failed. Check device access and try again.")])
            }
            paths = discovered
        }
        let ownBundleID = Bundle.main.bundleIdentifier ?? ""
        var snapshot = CacheScanSnapshot()
        for (index, path) in paths.enumerated() {
            try Task.checkCancellation()
            progress(0.8 + Double(index) / Double(max(1, paths.count)) * 0.2)
            let url = URL(fileURLWithPath: path)
            guard url.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL else { continue }
            do {
                let handle = try DeviceFileAccess.acquire(path)
                defer { worse_query_release(handle) }
                let descriptor = try ContainerCache.openContainer(url)
                let bundleID: String
                do { bundleID = try ContainerCache.identifier(at: descriptor) } catch { close(descriptor); throw error }
                close(descriptor)
                guard !ContainerCache.isProtected(bundleID, ownBundleID: ownBundleID) else { continue }
                let entry = try ContainerCache.inspect(at: url, bundleID: bundleID)
                if entry.totalBytes > 0 || entry.issues > 0 { snapshot.entries.append(entry) }
                snapshot.failures += entry.issues
            } catch { snapshot.failures += 1 }
        }
        try Task.checkCancellation()
        snapshot.entries.sort {
            $0.totalBytes == $1.totalBytes ? $0.bundleID < $1.bundleID : $0.totalBytes > $1.totalBytes
        }
        return snapshot
        #endif
    }

    static func clean(_ entries: [ContainerCacheEntry]) -> (CacheScanSnapshot, CacheOperationResult) {
        var snapshot = CacheScanSnapshot()
        var total = CacheOperationResult()
        for entry in entries {
            do {
                let handle = try DeviceFileAccess.acquire(entry.containerURL.path)
                defer { worse_query_release(handle) }
                let result = try ContainerCache.clean(entry, ownBundleID: Bundle.main.bundleIdentifier ?? "")
                total.bytes += result.bytes
                total.issues += result.issues
                total.skipped += result.skipped
                let remaining = try ContainerCache.inspect(at: entry.containerURL, bundleID: entry.bundleID)
                if remaining.totalBytes > 0 || remaining.issues > 0 || result.skipped > 0 { snapshot.entries.append(remaining) }
            } catch {
                total.issues += 1
                snapshot.entries.append(entry)
            }
        }
        return (snapshot, total)
    }
}

@MainActor
private final class ContainerCacheModel: ObservableObject {
    @Published var entries: [ContainerCacheEntry] = []
    @Published var isBusy = false
    @Published var isScanning = false
    @Published var progress = 0.0
    @Published var scanFailures = 0
    @Published var message: String?
    private var scanTask: Task<CacheScanSnapshot, Error>?

    func cancelScan() { scanTask?.cancel() }

    func scan(maximumInode: UInt64) {
        guard !isBusy else { return }
        isBusy = true
        isScanning = true
        progress = 0
        let worker = Task.detached(priority: .userInitiated) { [weak self] in
            try CacheDeviceWorker.scan(maximumInode: maximumInode) { [weak self] value in
                DispatchQueue.main.async { self?.progress = value }
            }
        }
        scanTask = worker
        Task {
            defer { isBusy = false; isScanning = false; scanTask = nil }
            do {
                let snapshot = try await worker.value
                entries = snapshot.entries
                scanFailures = snapshot.failures
            } catch is CancellationError {} catch { message = error.localizedDescription }
        }
    }

    func clean(_ targets: [ContainerCacheEntry]) {
        guard !isBusy, !targets.isEmpty else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            let (snapshot, result) = await Task.detached(priority: .userInitiated) { CacheDeviceWorker.clean(targets) }.value
            let identifiers = Set(targets.map(\.id))
            entries.removeAll { identifiers.contains($0.id) }
            entries.append(contentsOf: snapshot.entries)
            entries.sort { $0.totalBytes > $1.totalBytes }
            let defaults = UserDefaults.standard
            let previous = defaults.double(forKey: "GestaltX.cacheDeletedBytes")
            defaults.set(previous + Double(result.bytes), forKey: "GestaltX.cacheDeletedBytes")
            message = String(format: L("Deleted file data: %@. Errors: %lld. Skipped links or special files: %lld."),
                             Self.format(result.bytes), Int64(result.issues), Int64(result.skipped))
        }
    }

    static func format(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
}

struct ContainerCacheView: View {
    @StateObject private var model = ContainerCacheModel()
    @State private var search = ""
    @State private var includeSystem = false
    @State private var selected: Set<String> = []
    @State private var pending: [ContainerCacheEntry] = []
    @State private var asksCleaning = false
    @AppStorage("GestaltX.cacheMaximumInode") private var maximumInode = 15
    @AppStorage("GestaltX.cacheDeletedBytes") private var history = 0.0

    private var visible: [ContainerCacheEntry] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.entries.filter {
            (includeSystem || !$0.bundleID.hasPrefix("com.apple.") || $0.bundleID == "com.apple.mobilesafari") &&
            (query.isEmpty || $0.bundleID.localizedCaseInsensitiveContains(query))
        }
    }
    private var targets: [ContainerCacheEntry] { visible.filter { selected.contains($0.id) && $0.totalBytes > 0 } }

    var body: some View {
        List {
            Section {
                LabeledContent(L("Estimated Cache Data"), value: ContainerCacheModel.format(visible.reduce(0) { $0 + $1.totalBytes }))
                if history > 0 { LabeledContent(L("Total Deleted File Data"), value: ContainerCacheModel.format(Int64(min(history, Double(Int64.max - 1024))))) }
                Toggle(L("Include System Containers"), isOn: $includeSystem)
                    .disabled(model.isBusy)
                Stepper(value: $maximumInode, in: 1...30) {
                    LabeledContent(L("Inode Scan Limit"), value: String(format: L("%lld million"), Int64(maximumInode)))
                }.disabled(model.isBusy)
                HStack {
                    Button { selected = []; model.scan(maximumInode: UInt64(max(1, min(30, maximumInode))) * 1_000_000) } label: {
                        Label(L("Scan Caches"), systemImage: "arrow.clockwise")
                    }.disabled(model.isBusy)
                    Spacer()
                    Button(role: .destructive) { confirm(targets) } label: {
                        Label(L("Clean Selected"), systemImage: "trash")
                    }.disabled(model.isBusy || targets.isEmpty)
                }.buttonStyle(.borderless)
            }
            if model.isBusy {
                Section {
                    if model.isScanning {
                        ProgressView(L("Scanning Containers"), value: model.progress)
                        Button { model.cancelScan() } label: { Label(L("Cancel"), systemImage: "xmark") }
                    } else { ProgressView(L("Cleaning Caches")) }
                }
            }
            if model.scanFailures > 0 {
                Section {
                    Label(String(format: L("Incomplete scan: %lld access or read errors."), Int64(model.scanFailures)), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                if visible.isEmpty {
                    Text(L("No Cache Results")).foregroundStyle(.secondary)
                }
                ForEach(visible) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: Binding(get: { selected.contains(entry.id) }, set: { enabled in
                            if enabled { selected.insert(entry.id) } else { selected.remove(entry.id) }
                        })) {
                            Text(entry.bundleID).font(.subheadline).textSelection(.enabled)
                        }.disabled(model.isBusy || entry.totalBytes == 0)
                        HStack {
                            Text(ContainerCacheModel.format(entry.totalBytes)).font(.headline)
                            Spacer()
                            Button(role: .destructive) { confirm([entry]) } label: {
                                Image(systemName: "trash").accessibilityLabel(L("Clean Caches"))
                            }.buttonStyle(.borderless).disabled(model.isBusy || entry.totalBytes == 0)
                        }
                        ForEach(Array(ContainerCache.directories.enumerated()), id: \.offset) { index, directory in
                            LabeledContent(directory, value: ContainerCacheModel.format(entry.bytes[index]))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if entry.issues > 0 { Text(L("Some cache paths could not be read.")).font(.caption).foregroundStyle(.orange) }
                    }.padding(.vertical, 4)
                }
            } header: {
                HStack {
                    Text(L("Container Caches"))
                    Spacer()
                    let selectable = Set(visible.filter { $0.totalBytes > 0 }.map(\.id))
                    Button(L(!selectable.isEmpty && selectable.isSubset(of: selected) ? "Deselect All" : "Select All")) {
                        if selectable.isSubset(of: selected) { selected.subtract(selectable) } else { selected.formUnion(selectable) }
                    }.disabled(model.isBusy || selectable.isEmpty)
                }
            }
        }
        .navigationTitle(L("Container Cache Cleaner"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: L("Search Bundle ID"))
        .alert(L("Clean Caches?"), isPresented: $asksCleaning) {
            Button(L("Cancel"), role: .cancel) { pending = [] }
            Button(L("Clean Caches"), role: .destructive) { let targets = pending; pending = []; model.clean(targets) }
        } message: {
            Text(String(format: L("Clean cache data in %lld containers (estimated %@)? Only Library/Caches, tmp and WebKit CacheStorage are targeted. Close the selected apps first. Cached offline content may be lost; apps may need to download data or sign in again. This cannot be undone."),
                        Int64(pending.count), ContainerCacheModel.format(pending.reduce(0) { $0 + $1.totalBytes })))
        }
        .alert(L("Container Cache Cleaner"), isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button(L("OK"), role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
        .onDisappear { model.cancelScan() }
    }

    private func confirm(_ entries: [ContainerCacheEntry]) {
        guard !model.isBusy else { return }
        pending = entries
        asksCleaning = true
    }
}