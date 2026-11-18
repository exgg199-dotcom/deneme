import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: String
    var text: String
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var input = ""
    @Published var isSending = false
    @Published var error: String?
    private var task: Task<Void, Never>?

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        input = ""
        error = nil
        messages.append(ChatMessage(role: "user", text: text))
        let history = messages.map { ClaudeService.ChatTurn(role: $0.role, content: $0.text) }
        messages.append(ChatMessage(role: "assistant", text: ""))
        let index = messages.count - 1
        isSending = true

        task = Task {
            do {
                for try await chunk in ClaudeService.streamChat(history: history) {
                    messages[index].text += chunk
                }
            } catch {
                if !Task.isCancelled { self.error = error.localizedDescription }
            }
            if messages[index].text.isEmpty {
                // Boş cevabı ve onu doğuran kullanıcı mesajını geri al, kullanıcı tekrar deneyebilsin.
                messages.remove(at: index)
                if let last = messages.last, last.role == "user" {
                    input = last.text
                    messages.removeLast()
                }
            }
            isSending = false
        }
    }

    func stop() { task?.cancel() }
    func clear() { stop(); messages.removeAll(); error = nil }
}

struct ChatView: View {
    @StateObject private var vm = ChatViewModel()
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if vm.messages.isEmpty {
                                EmptyChatHint()
                            }
                            ForEach(vm.messages) { msg in
                                MessageBubble(message: msg).id(msg.id)
                            }
                            if let error = vm.error {
                                Text(error).foregroundStyle(.red).font(.footnote)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: vm.messages.last?.text) { _, _ in
                        if let id = vm.messages.last?.id { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
                Divider()
                HStack(alignment: .bottom) {
                    TextField("Bir şey sor ya da kod iste…", text: $vm.input, axis: .vertical)
                        .lineLimit(1...6)
                        .textFieldStyle(.roundedBorder)
                        .focused($focused)
                    if vm.isSending {
                        Button { vm.stop() } label: {
                            Image(systemName: "stop.circle.fill").font(.title)
                        }
                    } else {
                        Button { vm.send() } label: {
                            Image(systemName: "arrow.up.circle.fill").font(.title)
                        }
                        .disabled(vm.input.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding()
            }
            .navigationTitle("Sohbet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button { vm.clear() } label: { Image(systemName: "trash") }
                    .disabled(vm.messages.isEmpty)
            }
        }
    }
}

private struct EmptyChatHint: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Merhaba! 👋").font(.title2.bold())
            Text("Soru sorabilir, kod yazdırabilir, metin hazırlatabilirsin.")
            Text("Örnek: “Swift ile bir hesap makinesi fonksiyonu yaz”")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
    }
}

/// Mesajı düz metin ve ``` kod bloklarına ayırarak gösterir.
struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        let isUser = message.role == "user"
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 8) {
                if message.text.isEmpty {
                    ProgressView()
                } else {
                    ForEach(Array(Segment.parse(message.text).enumerated()), id: \.offset) { _, seg in
                        switch seg {
                        case .text(let t):
                            Text(.init(t)).textSelection(.enabled)
                        case .code(let lang, let code):
                            CodeBlock(language: lang, code: code)
                        }
                    }
                }
            }
            .padding(12)
            .background(isUser ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            if !isUser { Spacer(minLength: 0) }
        }
    }
}

enum Segment {
    case text(String)
    case code(String, String)

    static func parse(_ s: String) -> [Segment] {
        var result: [Segment] = []
        let parts = s.components(separatedBy: "```")
        for (i, part) in parts.enumerated() {
            if i % 2 == 0 {
                let t = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { result.append(.text(t)) }
            } else {
                var lines = part.components(separatedBy: "\n")
                let lang = lines.isEmpty ? "" : lines.removeFirst().trimmingCharacters(in: .whitespaces)
                result.append(.code(lang, lines.joined(separator: "\n").trimmingCharacters(in: .newlines)))
            }
        }
        return result
    }
}

struct CodeBlock: View {
    let language: String
    let code: String
    @State private var copied = false
    @State private var savedURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.isEmpty ? "kod" : language).font(.caption.bold())
                Spacer()
                Button(copied ? "Kopyalandı" : "Kopyala") {
                    UIPasteboard.general.string = code
                    copied = true
                }
                .font(.caption)
                if let url = savedURL {
                    ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }.font(.caption)
                } else {
                    Button("Dosya yap") {
                        savedURL = try? FileStore.save(code, filename: "kod-\(Int(Date().timeIntervalSince1970)).\(Self.ext(language))")
                    }
                    .font(.caption)
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.85))
            .foregroundStyle(.white)
            ScrollView(.horizontal) {
                Text(code)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
            }
            .background(Color.black.opacity(0.75))
            .foregroundStyle(.green)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    static func ext(_ lang: String) -> String {
        let map = ["python": "py", "swift": "swift", "javascript": "js", "js": "js", "typescript": "ts",
                   "html": "html", "css": "css", "json": "json", "java": "java", "kotlin": "kt",
                   "c": "c", "cpp": "cpp", "c++": "cpp", "csharp": "cs", "go": "go", "rust": "rs",
                   "bash": "sh", "sh": "sh", "sql": "sql", "php": "php", "ruby": "rb", "markdown": "md"]
        return map[lang.lowercased()] ?? "txt"
    }
}
