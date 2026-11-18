import SwiftUI
import AVKit
import Photos

struct VideoGenView: View {
    @State private var prompt = ""
    @State private var seconds = "4"
    @State private var size = "720x1280"
    @State private var videoURL: URL?
    @State private var player: AVPlayer?
    @State private var isLoading = false
    @State private var progress = 0
    @State private var statusText = ""
    @State private var error: String?
    @State private var info: String?
    @State private var task: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section("Nasıl bir video?") {
                    TextField("Ör. karlı ormanda koşan bir tilki, sinematik", text: $prompt, axis: .vertical)
                        .lineLimit(3...6)
                    Picker("Süre", selection: $seconds) {
                        Text("4 sn").tag("4"); Text("8 sn").tag("8"); Text("12 sn").tag("12")
                    }
                    .pickerStyle(.segmented)
                    Picker("Yön", selection: $size) {
                        Text("Dikey").tag("720x1280"); Text("Yatay").tag("1280x720")
                    }
                    .pickerStyle(.segmented)
                    if isLoading {
                        VStack(alignment: .leading) {
                            ProgressView(value: Double(progress), total: 100)
                            Text(statusText).font(.footnote).foregroundStyle(.secondary)
                        }
                        Button("İptal", role: .destructive) { task?.cancel() }
                    } else {
                        Button("Video oluştur") { start() }
                            .disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Text("Video oluşturmak birkaç dakika sürebilir. En fazla 100 MB.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                if let player, let videoURL {
                    Section("Sonuç") {
                        VideoPlayer(player: player)
                            .frame(height: 400)
                            .onAppear { player.play() }
                        Text("Boyut: \(fileSize(videoURL))").font(.footnote)
                        Button("Galeriye kaydet") { saveToPhotos(videoURL) }
                        ShareLink(item: videoURL) { Label("Paylaş", systemImage: "square.and.arrow.up") }
                        if let info { Text(info).font(.footnote).foregroundStyle(.secondary) }
                    }
                }
            }
            .navigationTitle("Video Oluştur")
        }
    }

    private func start() {
        isLoading = true; error = nil; info = nil; progress = 0; statusText = "Sıraya alındı…"
        task = Task {
            do {
                let url = try await OpenAIService.generateVideo(prompt: prompt, seconds: seconds, size: size) { p, status in
                    progress = p
                    statusText = switch status {
                    case "queued": "Sırada bekliyor…"
                    case "in_progress": "Oluşturuluyor… %\(p)"
                    case "downloading": "İndiriliyor…"
                    default: status
                    }
                }
                videoURL = url
                player = AVPlayer(url: url)
            } catch is CancellationError {
                error = "İptal edildi."
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func fileSize(_ url: URL) -> String {
        let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func saveToPhotos(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in info = "Galeri izni verilmedi." }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { ok, _ in
                Task { @MainActor in info = ok ? "Galeriye kaydedildi ✅" : "Kaydedilemedi." }
            }
        }
    }
}
