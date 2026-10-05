import Foundation

/// Session files stay local. No cookies, browsing history database or credentials are collected.
enum BrowserRecovery {
    static let bundleIDs = ["com.google.Chrome", "company.thebrowser.dia"]
    static func root(bundleID: String, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL? {
        switch bundleID {
        case "com.google.Chrome": return home.appendingPathComponent("Library/Application Support/Google/Chrome")
        case "company.thebrowser.dia": return home.appendingPathComponent("Library/Application Support/Dia/User Data")
        default: return nil
        }
    }
    static func sessionFiles(at root: URL) throws -> [URL] {
        let fm = FileManager.default
        let profiles = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            .filter { url in
                let info = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                return (url.lastPathComponent == "Default" || url.lastPathComponent.hasPrefix("Profile "))
                    && info?.isDirectory == true && info?.isSymbolicLink != true
            }
        var files: [URL] = []
        for profile in profiles {
            let directory = profile.appendingPathComponent("Sessions")
            guard fm.fileExists(atPath: directory.path),
                  (try directory.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true else { continue }
            for file in try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]) {
                let name = file.lastPathComponent
                guard name.hasPrefix("Session_") || name.hasPrefix("Tabs_") else { continue }
                let info = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard info.isRegularFile == true, info.isSymbolicLink != true, let size = info.fileSize,
                      size >= 8, size <= 16 * 1_048_576 else { continue }
                let reader = try FileHandle(forReadingFrom: file)
                let magic = try reader.read(upToCount: 4); try reader.close()
                if magic == Data("SNSS".utf8) { files.append(file) }
            }
        }
        guard files.contains(where: { $0.lastPathComponent.hasPrefix("Session_") }) else {
            throw NSError(domain: "LiteGauge.BrowserRecovery", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "未找到可读取的普通浏览器会话，恢复重启已暂缓。"])
        }
        return files.sorted { $0.path < $1.path }
    }
    static func backup(bundleID: String, store: CareStore = CareStore()) throws -> URL {
        guard let root = root(bundleID: bundleID) else { throw NSError(domain: "LiteGauge.BrowserRecovery", code: 2) }
        return try backup(root: root, destination: store.directory.appendingPathComponent("browser-recovery/\(bundleID)"))
    }
    static func backup(root: URL, destination: URL) throws -> URL {
        let files = try sessionFiles(at: root)
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: destination.path)
        let folder = destination.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        do {
            for file in files {
                let profile = file.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
                let target = folder.appendingPathComponent("\(profile)/Sessions/\(file.lastPathComponent)")
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                try fm.copyItem(at: file, to: target)
                try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
            }
            // Keep the newest two recovery snapshots for this browser, including this one.
            let previous = try fm.contentsOfDirectory(at: destination, includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey])
                .filter { $0.lastPathComponent != folder.lastPathComponent && UUID(uuidString: $0.lastPathComponent) != nil
                    && (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
                .sorted { ((try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast)
                    > ((try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast) }
            for old in previous.dropFirst() { try fm.removeItem(at: old) }
            return folder
        } catch { try? fm.removeItem(at: folder); throw error }
    }
}
