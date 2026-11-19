import Foundation
import UIKit

final class HWIDManager {
    static let shared = HWIDManager()

    private let storageKey = "nx_hwid_stored"

    var hwid: String {
        if let stored = UserDefaults.standard.string(forKey: storageKey) {
            return stored
        }
        let generated = derive()
        UserDefaults.standard.set(generated, forKey: storageKey)
        return generated
    }

    private func derive() -> String {
        let vendor = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        return vendor
    }

    func writeHWIDFile() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let file = docs.appendingPathComponent("hwid.txt")
        try? hwid.write(to: file, atomically: true, encoding: .utf8)
    }
}
