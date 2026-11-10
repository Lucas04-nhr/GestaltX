import Foundation

enum DeviceFileAccess {
    static func acquire(_ target: String) throws -> Int64 {
        #if targetEnvironment(simulator)
        throw NSError(domain: "GestaltX.DeviceAccess", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: L("Device access is unavailable in the Simulator. Open a plist to explore GestaltX.")])
        #else
        let groups = GXEntitlementsReader.usableAppGroups()
        guard !groups.isEmpty else { throw failure("The signed app has no usable App Group. Enable its App Group capability and sign it again.") }
        var rejection: Int64 = -1
        for group in groups {
            var handle = worse_query(target, group, false, false)
            if handle == -4, let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
                try? FileManager.default.createDirectory(at: root.appendingPathComponent("Library/Caches"), withIntermediateDirectories: true)
                handle = worse_query(target, group, false, false)
            }
            if handle >= 0 { return handle }
            rejection = handle
        }
        throw failure(rejection == -1
                      ? "The signed app has no usable App Group. Enable its App Group capability and sign it again."
                      : "Device file access was denied. Check the OS version and App Group signing.")
        #endif
    }

    private static func failure(_ key: String) -> NSError {
        NSError(domain: "GestaltX.DeviceAccess", code: 1, userInfo: [NSLocalizedDescriptionKey: L(key)])
    }
}