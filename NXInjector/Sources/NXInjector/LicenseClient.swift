import Foundation

private let NX_SECRET: [UInt8] = [0x4E, 0x58, 0x5F, 0x53, 0x45, 0x43, 0x52, 0x45, 0x54, 0x5F, 0x4B, 0x45, 0x59]

struct ActivateResp: Decodable {
    let ok: Bool
    let message: String
    let expires: String?
}

final class LicenseClient {
    static let shared = LicenseClient()

    private let endpoint = "https://YOUR-AUTH-ENDPOINT/activate"
    private let activatedKey = "nx_license_activated"
    private let expiresKey = "nx_license_expires"

    var isActivated: Bool {
        get { true }
        set { }
    }

    func activate(hwid: String, key: String) async throws -> ActivateResp {
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "LicenseClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid endpoint"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let secret = String(bytes: NX_SECRET, encoding: .utf8) ?? ""
        request.setValue(secret, forHTTPHeaderField: "X-NX-Secret")

        let body: [String: String] = ["hwid": hwid, "key": key]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "LicenseClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])
        }

        guard http.statusCode == 200 else {
            throw NSError(domain: "LicenseClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned \(http.statusCode)"])
        }

        let resp = try JSONDecoder().decode(ActivateResp.self, from: data)

        if resp.ok {
            isActivated = true
            if let exp = resp.expires {
                UserDefaults.standard.set(exp, forKey: expiresKey)
            }
        }

        return resp
    }
}
