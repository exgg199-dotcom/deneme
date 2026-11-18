import SwiftUI
import Photos

struct ImageGenView: View {
    @State private var prompt = ""
    @State private var size = "1024x1024"
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var error: String?
    @State private var info: String?

    private let sizes = [("Kare", "1024x1024"), ("Dikey", "1024x1536"), ("Yatay", "1536x1024")]

    var body: some View {
        NavigationStack {
            Form {
                Section("Ne çizilsin?") {
                    TextField("Ör. gün batımında İstanbul Boğazı, yağlı boya", text: $prompt, axis: .vertical)
                        .lineLimit(3...6)
                    Picker("Boyut", selection: $size) {
                        ForEach(sizes, id: \.1) { Text($0.0).tag($0.1) }
                    }
                    .pickerStyle(.segmented)
                    Button {
                        Task { await generate() }
                    } label: {
                        HStack {
                            if isLoading { ProgressView() }
                            Text(isLoading ? "Oluşturuluyor…" : "Fotoğraf oluştur")
                        }
                    }
                    .disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                if let image {
                    Section("Sonuç") {
                        Image(uiImage: image).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Button("Galeriye kaydet") { saveToPhotos(image) }
                        ShareLink(item: Image(uiImage: image), preview: SharePreview("Fotoğraf", image: Image(uiImage: image)))
                        if let info { Text(info).font(.footnote).foregroundStyle(.secondary) }
                    }
                }
            }
            .navigationTitle("Fotoğraf Oluştur")
        }
    }

    private func generate() async {
        isLoading = true; error = nil; info = nil
        defer { isLoading = false }
        do {
            image = try await OpenAIService.generateImage(prompt: prompt, size: size)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func saveToPhotos(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in info = "Galeri izni verilmedi." }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { ok, _ in
                Task { @MainActor in info = ok ? "Galeriye kaydedildi ✅" : "Kaydedilemedi." }
            }
        }
    }
}
