import Foundation

/// Claude (Anthropic Messages API) istemcisi: sohbet, soru-cevap, kod ve dosya üretimi.
/// Swift için resmi SDK olmadığından doğrudan HTTP kullanılır.
struct ClaudeService {
    static let model = "claude-opus-5-5"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    static let systemPrompt = """
    Sen Türkçe konuşan, yardımsever bir yapay zeka asistanısın. Kullanıcı hangi dilde \
    yazarsa o dilde cevap ver. Soruları net ve doğru cevapla. Kod istenirse çalışan, \
    açıklamalı kod yaz ve kodu dil etiketiyle ``` blokları içine koy.
    """

    struct ChatTurn: Codable {
        let role: String   // "user" ya da "assistant"
        let content: String
    }

    private static func makeRequest(body: [String: Any]) throws -> URLRequest {
        guard let key = KeyStore.get(.anthropic) else {
            throw AppError("Anthropic API anahtarı yok. Ayarlar sekmesinden ekleyin.")
        }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 600
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        // Güvenlik sınıflandırıcısı bir isteği reddederse sunucu otomatik olarak yedek modele geçer.
        req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    private static func apiErrorMessage(_ data: Data, status: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = json["error"] as? [String: Any],
           let msg = err["message"] as? String {
            return "Claude hatası (\(status)): \(msg)"
        }
        return "Claude hatası (HTTP \(status))"
    }

    /// Cevabı parça parça (streaming) üretir.
    static func streamChat(history: [ChatTurn]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let body: [String: Any] = [
                        "model": model,
                        "max_tokens": 64000,
                        "stream": true,
                        "system": systemPrompt,
                        "fallbacks": "default",
                        "thinking": ["type": "adaptive"],
                        "output_config": ["effort": "medium"],
                        "messages": history.map { ["role": $0.role, "content": $0.content] },
                    ]
                    let req = try makeRequest(body: body)
                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    if status != 200 {
                        var data = Data()
                        for try await b in bytes { data.append(b) }
                        throw AppError(apiErrorMessage(data, status: status))
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        guard let data = payload.data(using: .utf8),
                              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let type = event["type"] as? String
                        else { continue }
                        switch type {
                        case "content_block_delta":
                            if let delta = event["delta"] as? [String: Any],
                               delta["type"] as? String == "text_delta",
                               let text = delta["text"] as? String {
                                continuation.yield(text)
                            }
                        case "message_delta":
                            if let delta = event["delta"] as? [String: Any],
                               delta["stop_reason"] as? String == "refusal" {
                                continuation.yield("\n\n⚠️ Bu istek güvenlik nedeniyle yanıtlanamadı.")
                            } else if let delta = event["delta"] as? [String: Any],
                                      delta["stop_reason"] as? String == "max_tokens" {
                                continuation.yield("\n\n⚠️ Cevap uzunluk sınırına ulaştı.")
                            }
                        case "error":
                            let msg = (event["error"] as? [String: Any])?["message"] as? String
                            throw AppError("Claude hatası: \(msg ?? "bilinmiyor")")
                        default:
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    struct GeneratedFile: Codable {
        let filename: String
        let content: String
    }

    /// İstenen dosyayı (txt, md, csv, json, html, py, swift ...) yapılandırılmış çıktı olarak üretir.
    static func generateFile(description: String) async throws -> GeneratedFile {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "filename": [
                    "type": "string",
                    "description": "Uzantısıyla birlikte dosya adı, ör. rapor.md, veriler.csv, index.html",
                ],
                "content": ["type": "string", "description": "Dosyanın tam içeriği"],
            ],
            "required": ["filename", "content"],
            "additionalProperties": false,
        ]
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 64000,
            "stream": true,
            "fallbacks": "default",
            "system": """
            Kullanıcının tarif ettiği dosyayı oluştur. Uygun bir dosya adı ve uzantı seç \
            (metin tabanlı biçimler: txt, md, csv, json, html, css, js, py, swift, xml vb.). \
            İçerik eksiksiz ve doğrudan kullanılabilir olsun.
            """,
            "output_config": [
                "effort": "medium",
                "format": ["type": "json_schema", "schema": schema],
            ],
            "messages": [["role": "user", "content": description]],
        ]
        let req = try makeRequest(body: body)
        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            var data = Data()
            for try await b in bytes { data.append(b) }
            throw AppError(apiErrorMessage(data, status: status))
        }
        var text = ""
        var stopReason: String?
        for try await line in bytes.lines {
            guard line.hasPrefix("data:"),
                  let data = line.dropFirst(5).trimmingCharacters(in: .whitespaces).data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            if event["type"] as? String == "content_block_delta",
               let delta = event["delta"] as? [String: Any],
               delta["type"] as? String == "text_delta",
               let t = delta["text"] as? String {
                text += t
            } else if event["type"] as? String == "message_delta",
                      let delta = event["delta"] as? [String: Any] {
                stopReason = delta["stop_reason"] as? String
            } else if event["type"] as? String == "error" {
                throw AppError("Claude hatası: \(((event["error"] as? [String: Any])?["message"] as? String) ?? "bilinmiyor")")
            }
        }
        if stopReason == "refusal" { throw AppError("Bu istek güvenlik nedeniyle yanıtlanamadı.") }
        if stopReason == "max_tokens" { throw AppError("Dosya çok uzun, sınır aşıldı. Daha kısa bir dosya isteyin.") }
        guard let data = text.data(using: .utf8),
              let file = try? JSONDecoder().decode(GeneratedFile.self, from: data)
        else { throw AppError("Dosya çıktısı okunamadı.") }
        return file
    }
}
