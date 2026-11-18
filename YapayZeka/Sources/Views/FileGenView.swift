import SwiftUI

struct FileGenView: View {
    @State private var request = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var file: ClaudeService.GeneratedFile?
    @State private var savedURL: URL?
    @State private var savedFiles: [URL] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Hangi dosyayı oluşturayım?") {
                    TextField("Ör. 10 öğrencilik not tablosu (CSV) ya da kişisel web sayfası (HTML)",
                              text: $request, axis: .vertical)
                        .lineLimit(3...6)
                    Button {
                        Task { await generate() }
                    } label: {
                        HStack {
                            if isLoading { ProgressView() }
                            Text(isLoading ? "Hazırlanıyor…" : "Dosya oluştur")
                        }
                    }
                    .disabled(request.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                if let file, let savedURL {
                    Section("Oluşturulan: \(file.filename)") {
                        ScrollView {
                            Text(file.content)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 300)
                        ShareLink(item: savedURL) { Label("Paylaş / Kaydet", systemImage: "square.and.arrow.up") }
                    }
                }
                Section("Kaydedilen dosyalar") {
                    if savedFiles.isEmpty {
                        Text("Henüz dosya yok").foregroundStyle(.secondary)
                    }
                    ForEach(savedFiles, id: \.self) { url in
                        ShareLink(item: url) {
                            Label(url.lastPathComponent, systemImage: url.pathExtension == "mp4" ? "film" : "doc")
                        }
                    }
                    .onDelete { idx in
                        idx.forEach { try? FileManager.default.removeItem(at: savedFiles[$0]) }
                        refresh()
                    }
                }
            }
            .navigationTitle("Dosya Oluştur")
            .onAppear(perform: refresh)
        }
    }

    private func generate() async {
        isLoading = true; error = nil
        defer { isLoading = false }
        do {
            let f = try await ClaudeService.generateFile(description: request)
            file = f
            savedURL = try FileStore.save(f.content, filename: f.filename)
            refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func refresh() {
        savedFiles = ((try? FileManager.default.contentsOfDirectory(
            at: FileStore.directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
}
