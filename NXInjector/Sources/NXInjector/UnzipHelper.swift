import Foundation
import ZIPFoundation

struct FileResult {
    let path: String
    let success: Bool
    let error: String?
}

final class UnzipHelper {
    static func inject(zipURL: URL, into containerURL: URL) async throws -> [FileResult] {
        let fm = FileManager.default
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: tempDir) }

        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try fm.unzipItem(at: zipURL, to: tempDir)

        let targetPaths = [
            "Documents/Engine/Common",
            "Documents/Engine/EngineResource/Media",
            "Documents/Data/Application"
        ]

        for rel in targetPaths {
            let dir = containerURL.appendingPathComponent(rel)
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }

        var results: [FileResult] = []

        let enumerator = fm.enumerator(at: tempDir, includingPropertiesForKeys: [.isRegularFileKey])
        while let itemURL = enumerator?.nextObject() as? URL {
            guard let values = try? itemURL.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else { continue }

            let relative = itemURL.path.replacingOccurrences(of: tempDir.path + "/", with: "")
            var matched = false

            for rel in targetPaths {
                let destDir = containerURL.appendingPathComponent(rel)
                let destFile = destDir.appendingPathComponent(itemURL.lastPathComponent)
                do {
                    if fm.fileExists(atPath: destFile.path) {
                        try fm.removeItem(at: destFile)
                    }
                    try fm.copyItem(at: itemURL, to: destFile)
                    results.append(FileResult(path: rel + "/" + itemURL.lastPathComponent, success: true, error: nil))
                    matched = true
                    break
                } catch {
                    results.append(FileResult(path: rel + "/" + itemURL.lastPathComponent, success: false, error: error.localizedDescription))
                }
                _ = matched
            }

            if !matched {
                let destFile = containerURL.appendingPathComponent(relative)
                let destDir = destFile.deletingLastPathComponent()
                do {
                    if !fm.fileExists(atPath: destDir.path) {
                        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
                    }
                    if fm.fileExists(atPath: destFile.path) {
                        try fm.removeItem(at: destFile)
                    }
                    try fm.copyItem(at: itemURL, to: destFile)
                    results.append(FileResult(path: relative, success: true, error: nil))
                } catch {
                    results.append(FileResult(path: relative, success: false, error: error.localizedDescription))
                }
            }
        }

        return results
    }
}
