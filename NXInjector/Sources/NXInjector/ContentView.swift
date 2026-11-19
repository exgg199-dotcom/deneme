import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var state = AppState()

    var body: some View {
        ZStack {
            NCLBackdrop()

            if state.isActivated {
                MainView(state: state)
                    .transition(.opacity)
            } else {
                GateView(state: state)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: state.isActivated)
        .preferredColorScheme(.dark)
        .onAppear { HWIDManager.shared.writeHWIDFile() }
    }
}

final class AppState: ObservableObject {
    @Published var isActivated: Bool = true
    @Published var licenseKey: String = ""
    @Published var activationStatus: String = ""
    @Published var isActivating: Bool = false
    @Published var selectedZipURL: URL? = nil
    @Published var isPickerPresented: Bool = false
    @Published var isInjecting: Bool = false
    @Published var logLines: [LogLine] = []
    @Published var showShareSheet: Bool = false

    let hwid = HWIDManager.shared.hwid

    struct LogLine: Identifiable {
        let id = UUID()
        let text: String
        let kind: Kind
        enum Kind { case info, success, failure }
    }

    func log(_ text: String, kind: LogLine.Kind = .info) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logLines.append(LogLine(text: "[\(ts)] \(text)", kind: kind))
    }
}

struct NCLBackdrop: View {
    var body: some View {
        ZStack {
            if let img = UIImage(named: "bg-texture") {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            } else {
                Color(red: 0.04, green: 0.04, blue: 0.07).ignoresSafeArea()
            }
            Color.black.opacity(0.45).ignoresSafeArea()
        }
    }
}

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
            )
    }
}

struct PrimarySilverButton: ButtonStyle {
    var active: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(active
                          ? LinearGradient(colors: [Color(white: 0.28), Color(white: 0.18)], startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [Color(white: 0.14), Color(white: 0.10)], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color.white.opacity(active ? 0.18 : 0.07), lineWidth: 0.8)
                    )
            )
            .foregroundColor(active ? .white : Color(white: 0.45))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AccentButton: ButtonStyle {
    var color: Color = Color(red: 0.55, green: 0.1, blue: 0.85)
    var active: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(active ? color.opacity(0.85) : Color(white: 0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(active ? color.opacity(0.5) : Color.clear, lineWidth: 0.8)
                    )
            )
            .foregroundColor(active ? .white : Color(white: 0.4))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GateView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("NX Injector")
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Blockman GO Mod Loader")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(white: 0.55))
                }
                .padding(.top, 48)

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("THÔNG TIN LICENSE", systemImage: "key.fill")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(white: 0.5))

                        hwidRow

                        TextField("NCL-XXXXX-XXXXX-XXXXX", text: $state.licenseKey)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.6)
                            )
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)

                        Button(action: performActivation) {
                            HStack {
                                if state.isActivating {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.shield")
                                }
                                Text(state.isActivating ? "Đang kiểm tra..." : "XÁC THỰC KEY")
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            }
                        }
                        .buttonStyle(PrimarySilverButton(active: !state.licenseKey.isEmpty && !state.isActivating))
                        .disabled(state.licenseKey.isEmpty || state.isActivating)

                        if !state.activationStatus.isEmpty {
                            Text(state.activationStatus)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }

                Text("Key Free tại: NX Community")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(white: 0.3))
                    .padding(.bottom, 20)
            }
            .padding(.horizontal)
        }
    }

    private var hwidRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("HWID (trong game: MISC → My HWID)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(white: 0.4))
                Text(state.hwid)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(white: 0.8))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = state.hwid
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.6))
            }
            Button {
                state.showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.6))
            }
            .sheet(isPresented: $state.showShareSheet) {
                ShareSheet(activityItems: [state.hwid])
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.25))
        .cornerRadius(8)
    }

    private func performActivation() {
        guard !state.licenseKey.isEmpty else { return }
        state.isActivating = true
        state.activationStatus = ""

        Task {
            do {
                let resp = try await LicenseClient.shared.activate(hwid: state.hwid, key: state.licenseKey)
                await MainActor.run {
                    if resp.ok {
                        state.isActivated = true
                    } else {
                        state.activationStatus = resp.message
                    }
                    state.isActivating = false
                }
            } catch {
                await MainActor.run {
                    state.activationStatus = "Key không hợp lệ hoặc lỗi kết nối."
                    state.isActivating = false
                }
            }
        }
    }
}

struct MainView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerBar

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("INJECT MENU", icon: "square.and.arrow.down.on.square")

                        modStatusRow

                        Button {
                            state.isPickerPresented = true
                        } label: {
                            HStack {
                                Image(systemName: "folder.badge.plus")
                                Text(state.selectedZipURL?.lastPathComponent ?? "Chọn file .zip mod")
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .font(.system(size: 13, design: .monospaced))
                            }
                        }
                        .buttonStyle(PrimarySilverButton())
                        .sheet(isPresented: $state.isPickerPresented) {
                            DocumentPicker(selectedURL: $state.selectedZipURL)
                        }

                        Button(action: performInjection) {
                            HStack {
                                if state.isInjecting {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.down.app.fill")
                                }
                                Text(state.isInjecting ? "Đang inject..." : "INJECT MOD")
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            }
                        }
                        .buttonStyle(AccentButton(active: canInject))
                        .disabled(!canInject)

                        Text("Sau khi inject, tắt hoàn toàn và khởi động lại Blockman GO.")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(white: 0.4))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            sectionLabel("STATUS LOG", icon: "terminal")
                            Spacer()
                            if !state.logLines.isEmpty {
                                Button("Xóa") { state.logLines = [] }
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color(white: 0.4))
                            }
                        }

                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(state.logLines) { line in
                                        Text(line.text)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(logColor(line.kind))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .id(line.id)
                                    }
                                }
                                .padding(8)
                            }
                            .frame(minHeight: 100, maxHeight: 180)
                            .background(Color.black.opacity(0.35))
                            .cornerRadius(8)
                            .onChange(of: state.logLines.count) { count in
                                if let last = state.logLines.last { proxy.scrollTo(last.id) }
                            }
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("NX Injector")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("Blockman GO Mod Loader")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(white: 0.45))
            }
            Spacer()
            Button {
                state.isActivated = false
            } label: {
                Image(systemName: "key")
                    .foregroundColor(Color(white: 0.4))
                    .font(.system(size: 16))
            }
        }
        .padding(.top, 16)
    }

    private var modStatusRow: some View {
        HStack {
            Circle()
                .fill(state.selectedZipURL != nil ? Color.green : Color(white: 0.3))
                .frame(width: 7, height: 7)
            Text(state.selectedZipURL != nil ? "Mod đã sẵn sàng: \(state.selectedZipURL!.lastPathComponent)" : "Chưa có mod file")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(state.selectedZipURL != nil ? Color(white: 0.75) : Color(white: 0.4))
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(Color(white: 0.45))
    }

    private var canInject: Bool {
        state.selectedZipURL != nil && !state.isInjecting
    }

    private func logColor(_ kind: AppState.LogLine.Kind) -> Color {
        switch kind {
        case .success: return Color(red: 0.3, green: 0.9, blue: 0.5)
        case .failure: return Color(red: 1.0, green: 0.35, blue: 0.35)
        case .info: return Color(white: 0.55)
        }
    }

    private func performInjection() {
        guard let zipURL = state.selectedZipURL else { return }
        state.isInjecting = true
        state.log("Đang tìm container Blockman GO...")

        Task {
            do {
                let results = try await Injector.shared.installPicked(url: zipURL)
                await MainActor.run {
                    for r in results {
                        state.log(r.success ? "OK  \(r.path)" : "ERR \(r.path): \(r.error ?? "")",
                                  kind: r.success ? .success : .failure)
                    }
                    let ok = results.filter { $0.success }.count
                    state.log("Xong — \(ok)/\(results.count) files. Khởi động lại Blockman GO.", kind: .success)
                    state.isInjecting = false
                }
            } catch {
                await MainActor.run {
                    state.log("FAIL: \(error.localizedDescription)", kind: .failure)
                    state.isInjecting = false
                }
            }
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.zip], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.selectedURL = urls.first
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
