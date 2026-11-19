import Foundation
import ZIPFoundation

struct InjectionResult {
    let path: String
    let success: Bool
    let error: String?
}

final class Injector {
    static let shared = Injector()

    private let targetBundle = "com.sandboxol.blockmango"

    private let relativePaths = [
        "Documents/Engine/Common",
        "Documents/Engine/EngineResource/Media",
        "Documents/Data/Application"
    ]

    func installPicked(url: URL) async throws -> [InjectionResult] {
        let containerRoot = try ContainerManager.shared.resolveDataContainer(bundleID: targetBundle)
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: url, to: tempDir)

        return try await writeFiles(tempDir: tempDir, root: containerRoot)
    }

    private func writeFiles(tempDir: URL, root: URL) async throws -> [InjectionResult] {
        let fm = FileManager.default

        for rel in relativePaths {
            let dir = root.appendingPathComponent(rel)
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }

        var results: [InjectionResult] = []

        guard let enumerator = fm.enumerator(at: tempDir, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return results
        }

        while let itemURL = enumerator.nextObject() as? URL {
            guard let values = try? itemURL.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else { continue }

            let relative = String(itemURL.path.dropFirst(tempDir.path.count + 1))

            var placed = false
            for rel in relativePaths {
                let destDir = root.appendingPathComponent(rel)
                let dest = destDir.appendingPathComponent(itemURL.lastPathComponent)
                do {
                    if fm.fileExists(atPath: dest.path) {
                        try fm.removeItem(at: dest)
                    }
                    try fm.copyItem(at: itemURL, to: dest)
                    results.append(InjectionResult(path: rel + "/" + itemURL.lastPathComponent, success: true, error: nil))
                    placed = true
                    break
                } catch {
                    results.append(InjectionResult(path: rel + "/" + itemURL.lastPathComponent, success: false, error: error.localizedDescription))
                    placed = true
                    break
                }
            }

            if !placed {
                let dest = root.appendingPathComponent(relative)
                let destDir = dest.deletingLastPathComponent()
                do {
                    if !fm.fileExists(atPath: destDir.path) {
                        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
                    }
                    if fm.fileExists(atPath: dest.path) {
                        try fm.removeItem(at: dest)
                    }
                    try fm.copyItem(at: itemURL, to: dest)
                    results.append(InjectionResult(path: relative, success: true, error: nil))
                } catch {
                    results.append(InjectionResult(path: relative, success: false, error: error.localizedDescription))
                }
            }
        }

        return results
    }
}
