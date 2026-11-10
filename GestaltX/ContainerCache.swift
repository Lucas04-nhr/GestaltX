import Foundation
import Darwin

struct ContainerCacheEntry: Identifiable, Sendable {
    let containerURL: URL
    let bundleID: String
    let bytes: [Int64]
    let issues: Int
    var id: String { containerURL.lastPathComponent }
    var totalBytes: Int64 { bytes.reduce(0, +) }
}

struct CacheOperationResult: Sendable {
    var bytes: Int64 = 0
    var issues = 0
    var skipped = 0
}

enum ContainerCache {
    static let directories = ["Library/Caches", "tmp", "Library/WebKit/WebsiteData/CacheStorage"]
    static let protectedBundleIDs: Set<String> = [
        "com.apple.springboard", "com.apple.PosterBoard", "com.apple.Preferences", "com.jbdotparty.Erosion"
    ]

    static func isProtected(_ bundleID: String, ownBundleID: String) -> Bool {
        bundleID.isEmpty || bundleID == ownBundleID || protectedBundleIDs.contains(bundleID)
    }

    static func identifier(at descriptor: Int32) throws -> String {
        var buffer = [UInt8](repeating: 0, count: 1024)
        let count = fgetxattr(descriptor, "com.apple.containermanager.identifier", &buffer, buffer.count, 0, 0)
        guard count > 0, count < buffer.count,
              let value = String(bytes: buffer.prefix(count).prefix(while: { $0 != 0 }), encoding: .utf8),
              !value.isEmpty else { throw failure("The container identifier could not be read.") }
        return value
    }

    static func inspect(at url: URL, bundleID: String) throws -> ContainerCacheEntry {
        let descriptor = try openContainer(url)
        defer { close(descriptor) }
        var results: [CacheOperationResult] = []
        for directory in directories { results.append(walkRoot(descriptor, path: directory, deleting: false)) }
        return ContainerCacheEntry(containerURL: url, bundleID: bundleID, bytes: results.map(\.bytes),
                                   issues: results.reduce(0) { $0 + $1.issues })
    }

    static func clean(_ entry: ContainerCacheEntry, ownBundleID: String) throws -> CacheOperationResult {
        guard !isProtected(entry.bundleID, ownBundleID: ownBundleID) else {
            throw failure("This container is protected and cannot be cleaned.")
        }
        let descriptor = try openContainer(entry.containerURL)
        defer { close(descriptor) }
        guard try identifier(at: descriptor) == entry.bundleID else {
            throw failure("The container changed since scanning. Scan again before cleaning.")
        }
        var result = CacheOperationResult()
        for directory in directories {
            let part = walkRoot(descriptor, path: directory, deleting: true)
            result.bytes += part.bytes
            result.issues += part.issues
            result.skipped += part.skipped
        }
        return result
    }

    static func openContainer(_ url: URL) throws -> Int32 {
        guard url.isFileURL, UUID(uuidString: url.lastPathComponent) != nil else {
            throw failure("Invalid application container path.")
        }
        let descriptor = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw failure("The application container could not be opened.") }
        return descriptor
    }

    private static func failure(_ key: String) -> NSError {
        NSError(domain: "GestaltX.ContainerCache", code: 1, userInfo: [NSLocalizedDescriptionKey: L(key)])
    }

    private static func walkRoot(_ container: Int32, path: String, deleting: Bool) -> CacheOperationResult {
        var descriptor = dup(container)
        guard descriptor >= 0 else { return CacheOperationResult(issues: 1) }
        for component in path.split(separator: "/") {
            let next = openat(descriptor, String(component), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            let code = errno
            close(descriptor)
            guard next >= 0 else {
                return code == ENOENT ? CacheOperationResult() : CacheOperationResult(issues: 1)
            }
            descriptor = next
        }
        defer { close(descriptor) }
        var info = stat()
        guard fstat(descriptor, &info) == 0 else { return CacheOperationResult(issues: 1) }
        return walk(descriptor, device: info.st_dev, deleting: deleting, depth: 0)
    }

    private static func walk(_ descriptor: Int32, device: dev_t, deleting: Bool, depth: Int) -> CacheOperationResult {
        guard depth < 64 else { return CacheOperationResult(issues: 1) }
        let copy = dup(descriptor)
        guard copy >= 0 else { return CacheOperationResult(issues: 1) }
        guard let stream = fdopendir(copy) else { close(copy); return CacheOperationResult(issues: 1) }
        defer { closedir(stream) }
        var result = CacheOperationResult()
        while true {
            if Task.isCancelled { result.issues += 1; break }
            errno = 0
            guard let entry = readdir(stream) else {
                if errno != 0 { result.issues += 1 }
                break
            }
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen) + 1) { String(cString: $0) }
            }
            guard name != ".", name != "..", !name.contains("/") else { continue }
            var info = stat()
            guard fstatat(descriptor, name, &info, AT_SYMLINK_NOFOLLOW) == 0 else { result.issues += 1; continue }
            guard info.st_dev == device else { result.skipped += 1; continue }
            switch info.st_mode & S_IFMT {
            case S_IFREG:
                guard info.st_nlink == 1 else { result.skipped += 1; continue }
                if !deleting || unlinkat(descriptor, name, 0) == 0 {
                    result.bytes += max(0, info.st_size)
                } else { result.issues += 1 }
            case S_IFDIR:
                let child = openat(descriptor, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard child >= 0 else { result.issues += 1; continue }
                var opened = stat()
                guard fstat(child, &opened) == 0, opened.st_ino == info.st_ino, opened.st_dev == device else {
                    close(child); result.issues += 1; continue
                }
                let part = walk(child, device: device, deleting: deleting, depth: depth + 1)
                close(child)
                result.bytes += part.bytes
                result.issues += part.issues
                result.skipped += part.skipped
                if deleting {
                    var current = stat()
                    if fstatat(descriptor, name, &current, AT_SYMLINK_NOFOLLOW) == 0,
                       current.st_ino == info.st_ino, current.st_dev == device {
                        if unlinkat(descriptor, name, AT_REMOVEDIR) != 0, part.skipped == 0 { result.issues += 1 }
                    } else { result.issues += 1 }
                }
            default:
                result.skipped += 1
            }
        }
        return result
    }
}