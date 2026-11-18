import Foundation
import UIKit

/// Fotoğraf (gpt-image-1) ve video (Sora 2) üretimi için OpenAI istemcisi.
struct OpenAIService {
    static let imageModel = "gpt-image-1"
    static let videoModel = "sora-2"
    /// İndirilen videonun izin verilen en büyük boyutu: 100 MB.
    static let maxVideoBytes: Int64 = 100 * 1024 * 1024

    private static let base = URL(string: "https://api.openai.com/v1")!

    private static func apiKey() throws -> String {
        guard let key = KeyStore.get(.openai) else {
            throw AppError("OpenAI API anahtarı yok. Ayarlar sekmesinden ekleyin.")
        }
        return key
    }

    private static func check(_ data: Data, _ response: URLResponse) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = json["error"] as? [String: Any],
               let msg = err["message"] as? String {
                throw AppError("OpenAI hatası (\(status)): \(msg)")
            }
            throw AppError("OpenAI hatası (HTTP \(status))")
        }
    }

    // MARK: - Fotoğraf

    static func generateImage(prompt: String, size: String) async throws -> UIImage {
        var req = URLRequest(url: base.appendingPathComponent("images/generations"))
        req.httpMethod = "POST"
        req.timeoutInterval = 300
        req.setValue("Bearer \(try apiKey())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": imageModel,
            "prompt": prompt,
            "size": size,
            "n": 1,
        ])
        let (data, response) = try await URLSession.shared.data(for: req)
        try check(data, response)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let first = (json["data"] as? [[String: Any]])?.first,
              let b64 = first["b64_json"] as? String,
              let imgData = Data(base64Encoded: b64),
              let image = UIImage(data: imgData)
        else { throw AppError("Fotoğraf verisi okunamadı.") }
        return image
    }

    // MARK: - Video

    struct VideoJob: Decodable {
        let id: String
        let status: String
        let progress: Int?
        let error: VideoError?
        struct VideoError: Decodable { let message: String? }
    }

    /// Video işini başlatır, bitene kadar bekler, indirir ve 100 MB sınırını uygular.
    static func generateVideo(
        prompt: String,
        seconds: String,
        size: String,
        onProgress: @escaping @MainActor (Int, String) -> Void
    ) async throws -> URL {
        let key = try apiKey()

        // 1) İşi oluştur (multipart/form-data)
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        for (name, value) in ["model": videoModel, "prompt": prompt, "seconds": seconds, "size": size] {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var createReq = URLRequest(url: base.appendingPathComponent("videos"))
        createReq.httpMethod = "POST"
        createReq.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        createReq.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        createReq.httpBody = body
        let (cData, cResp) = try await URLSession.shared.data(for: createReq)
        try check(cData, cResp)
        var job = try JSONDecoder().decode(VideoJob.self, from: cData)

        // 2) Tamamlanana kadar durumu sorgula
        while job.status != "completed" {
            if job.status == "failed" {
                throw AppError("Video oluşturulamadı: \(job.error?.message ?? "bilinmeyen hata")")
            }
            await onProgress(job.progress ?? 0, job.status)
            try await Task.sleep(nanoseconds: 5_000_000_000)
            var pollReq = URLRequest(url: base.appendingPathComponent("videos/\(job.id)"))
            pollReq.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            let (pData, pResp) = try await URLSession.shared.data(for: pollReq)
            try check(pData, pResp)
            job = try JSONDecoder().decode(VideoJob.self, from: pData)
        }
        await onProgress(100, "downloading")

        // 3) MP4'ü indir
        var dlReq = URLRequest(url: base.appendingPathComponent("videos/\(job.id)/content"))
        dlReq.timeoutInterval = 600
        dlReq.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let (tempURL, dlResp) = try await URLSession.shared.download(for: dlReq)
        let status = (dlResp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw AppError("Video indirilemedi (HTTP \(status)).") }

        // 4) 100 MB sınırı
        let size = (try FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        if size > maxVideoBytes {
            try? FileManager.default.removeItem(at: tempURL)
            throw AppError("Video \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) — 100 MB sınırını aşıyor. Daha kısa süre veya küçük çözünürlük seçin.")
        }

        let dest = FileStore.directory.appendingPathComponent("video-\(job.id).mp4")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }
}

/// Uygulamanın oluşturduğu dosyaların saklandığı klasör (Dosyalar uygulamasında görünür).
enum FileStore {
    static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func save(_ content: String, filename: String) throws -> URL {
        let safe = filename
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "..", with: ".")
        let url = directory.appendingPathComponent(safe.isEmpty ? "dosya.txt" : safe)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
