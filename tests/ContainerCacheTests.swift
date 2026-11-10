import Foundation
import Darwin

@main struct ContainerCacheTests {
    static func main() throws {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: root) }
        let container = root.appendingPathComponent(UUID().uuidString)
        for path in ContainerCache.directories + ["Documents", "Library/Preferences"] {
            try files.createDirectory(at: container.appendingPathComponent(path), withIntermediateDirectories: true)
        }
        let bundleID = "com.example.cachetest"
        let identifier = Array(bundleID.utf8)
        guard setxattr(container.path, "com.apple.containermanager.identifier", identifier, identifier.count, 0, 0) == 0 else {
            fatalError("Cannot create container identifier fixture")
        }
        let document = container.appendingPathComponent("Documents/save.db")
        let preferences = container.appendingPathComponent("Library/Preferences/login.plist")
        try Data("keep".utf8).write(to: document)
        try Data("keep".utf8).write(to: preferences)
        for directory in ContainerCache.directories {
            try Data(repeating: 1, count: 100).write(to: container.appendingPathComponent(directory + "/file"))
        }
        let nested = container.appendingPathComponent("Library/Caches/nested")
        try files.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 50).write(to: nested.appendingPathComponent("file"))
        let link = nested.appendingPathComponent("escape")
        try files.createSymbolicLink(at: link, withDestinationURL: container.appendingPathComponent("Documents"))
        let hardlink = container.appendingPathComponent("tmp/hardlink")
        guard Darwin.link(document.path, hardlink.path) == 0 else { fatalError("Cannot create hardlink fixture") }
        let fifo = container.appendingPathComponent("tmp/fifo")
        guard mkfifo(fifo.path, 0o600) == 0 else { fatalError("Cannot create FIFO fixture") }
        let rootAttributes = try ContainerCache.directories.map {
            try files.attributesOfItem(atPath: container.appendingPathComponent($0).path)
        }
        let entry = try ContainerCache.inspect(at: container, bundleID: bundleID)
        precondition(entry.totalBytes == 350, "Count all three cache roots without following links")
        let result = try ContainerCache.clean(entry, ownBundleID: "com.example.gestaltx")
        precondition(result.bytes == 350 && result.issues == 0 && result.skipped == 3)
        let savedDocument = try Data(contentsOf: document)
        let savedPreferences = try Data(contentsOf: preferences)
        precondition(savedDocument == Data("keep".utf8))
        precondition(savedPreferences == Data("keep".utf8))
        precondition(files.fileExists(atPath: link.path) && files.fileExists(atPath: hardlink.path))
        for (index, directory) in ContainerCache.directories.enumerated() {
            let attributes = try files.attributesOfItem(atPath: container.appendingPathComponent(directory).path)
            precondition(attributes[.systemFileNumber] as? NSNumber == rootAttributes[index][.systemFileNumber] as? NSNumber)
            precondition(attributes[.posixPermissions] as? NSNumber == rootAttributes[index][.posixPermissions] as? NSNumber)
        }
        let remaining = try ContainerCache.inspect(at: container, bundleID: bundleID)
        precondition(remaining.totalBytes == 0)
        let changed = ContainerCacheEntry(containerURL: container, bundleID: "com.example.changed", bytes: [100], issues: 0)
        do { _ = try ContainerCache.clean(changed, ownBundleID: "self"); fatalError("Accepted changed identity") } catch {}
        do { _ = try ContainerCache.clean(entry, ownBundleID: bundleID); fatalError("Accepted own container") } catch {}
        try files.removeItem(at: container.appendingPathComponent("Library/Caches"))
        try files.createSymbolicLink(at: container.appendingPathComponent("Library/Caches"), withDestinationURL: container.appendingPathComponent("Documents"))
        let blocked = try ContainerCache.inspect(at: container, bundleID: bundleID)
        precondition(blocked.totalBytes == 0 && blocked.issues == 1)
        _ = try ContainerCache.clean(entry, ownBundleID: "self")
        precondition(files.fileExists(atPath: document.path))
        let containerLink = root.appendingPathComponent(UUID().uuidString)
        try files.createSymbolicLink(at: containerLink, withDestinationURL: container)
        do { _ = try ContainerCache.openContainer(containerLink); fatalError("Accepted linked container") } catch {}
        print("PASS: cache totals, root inode/permission retention, preserved documents/preferences, symlinks, hardlinks, FIFOs, identity and self protection.")
    }
}