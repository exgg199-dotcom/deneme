import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var licenseKey: String = ""
    @State private var activationStatus: String = ""
    @State private var isActivated: Bool = LicenseClient.shared.isActivated
    @State private var selectedZipURL: URL? = nil
    @State private var isPickerPresented: Bool = false
    @State private var isInjecting: Bool = false
    @State private var isActivating: Bool = false
    @State private var logLines: [String] = []
    @State private var showShareSheet: Bool = false
    @State private var shareItems: [Any] = []

    private let hwid = HWIDManager.shared.hwid

    var body: some View {
        ZStack {
            backgroundLayer

            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    hwidSection
                    licenseSection
                    zipSection
                    injectSection
                    logSection
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isPickerPresented) {
            DocumentPicker(selectedURL: $selectedZipURL)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .onAppear {
            HWIDManager.shared.writeHWIDFile()
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.07)
            Canvas { context, size in
                for x in stride(from: 0, to: size.width, by: 3) {
                    for y in stride(from: 0, to: size.height, by: 3) {
                        let v = sin(x * 0.25 + 1.3) * cos(y * 0.25 + 0.7)
                        if v > 0.6 {
                            context.fill(
                                Path(CGRect(x: x, y: y, width: 1.5, height: 1.5)),
                                with: .color(Color.white.opacity(0.018))
                            )
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("NX Injector")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text("Blockman GO Resource Mod")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(red: 0.4, green: 0.6, blue: 1.0))
            Text("TrollStore only · Stock iOS · No jailbreak")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding(.top, 16)
    }

    private var hwidSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Device ID", systemImage: "cpu")
                .font(.caption)
                .foregroundColor(.gray)

            HStack(spacing: 10) {
                Text(hwid)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {
                    UIPasteboard.general.string = hwid
                    logAppend("HWID copied")
                } label: {
                    Image(systemName: "doc.on.doc").foregroundColor(.blue)
                }

                Button {
                    shareItems = [hwid]
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up").foregroundColor(.blue)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
        .cardStyle()
    }

    private var licenseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("License", systemImage: "key")
                .font(.caption)
                .foregroundColor(.gray)

            TextField("NX-XXXXX-XXXXX-XXXXX", text: $licenseKey)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .padding(10)
                .background(Color.white.opacity(0.07))
                .cornerRadius(8)
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)

            Button(action: performActivation) {
                HStack {
                    if isActivating {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: isActivated ? "checkmark.seal.fill" : "lock.open")
                    }
                    Text(isActivated ? "Activated" : "Activate")
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(isActivated ? Color.green.opacity(0.7) : Color.blue.opacity(0.7))
                .cornerRadius(10)
                .foregroundColor(.white)
                .font(Font.body.weight(.semibold))
            }
            .disabled(isActivating || licenseKey.isEmpty)

            if !activationStatus.isEmpty {
                Text(activationStatus)
                    .font(.caption)
                    .foregroundColor(isActivated ? .green : .red)
            }
        }
        .cardStyle()
    }

    private var zipSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Mod Package", systemImage: "archivebox")
                .font(.caption)
                .foregroundColor(.gray)

            Button {
                isPickerPresented = true
            } label: {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text(selectedZipURL?.lastPathComponent ?? "Pick mod .zip (e.g. common_1.zip)")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
                .foregroundColor(selectedZipURL == nil ? .gray : .white)
            }
        }
        .cardStyle()
    }

    private var injectSection: some View {
        VStack(spacing: 8) {
            Button(action: performInjection) {
                HStack {
                    if isInjecting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.down.app.fill")
                    }
                    Text(isInjecting ? "Injecting..." : "Inject")
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(canInject ? Color(red: 0.55, green: 0.1, blue: 0.85) : Color.gray.opacity(0.3))
                .cornerRadius(12)
                .foregroundColor(.white)
                .font(Font.headline.weight(.bold))
            }
            .disabled(!canInject)

            Text("After injecting, fully close and relaunch Blockman GO.")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }

    private var canInject: Bool {
        isActivated && selectedZipURL != nil && !isInjecting
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Log", systemImage: "terminal")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                if !logLines.isEmpty {
                    Button("Clear") { logLines = [] }
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(logLines.indices, id: \.self) { idx in
                            Text(logLines[idx])
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(lineColor(logLines[idx]))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(idx)
                        }
                    }
                    .padding(8)
                }
                .frame(minHeight: 120, maxHeight: 200)
                .background(Color.black.opacity(0.4))
                .cornerRadius(8)
                .onChange(of: logLines.count) { count in
                    if count > 0 { proxy.scrollTo(count - 1) }
                }
            }
        }
        .cardStyle()
    }

    private func lineColor(_ line: String) -> Color {
        if line.contains("FAIL") || line.contains("error") { return .red }
        if line.contains("OK") || line.contains("Done") || line.contains("activated") { return .green }
        return .gray
    }

    private func logAppend(_ line: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logLines.append("[\(ts)] \(line)")
    }

    private func performActivation() {
        guard !licenseKey.isEmpty else { return }
        isActivating = true
        activationStatus = ""

        Task {
            do {
                let resp = try await LicenseClient.shared.activate(hwid: hwid, key: licenseKey)
                await MainActor.run {
                    isActivated = resp.ok
                    activationStatus = resp.message
                    logAppend(resp.ok ? "License activated: \(resp.message)" : "FAIL: \(resp.message)")
                    isActivating = false
                }
            } catch {
                await MainActor.run {
                    activationStatus = error.localizedDescription
                    logAppend("FAIL activation: \(error.localizedDescription)")
                    isActivating = false
                }
            }
        }
    }

    private func performInjection() {
        guard let zipURL = selectedZipURL, isActivated else { return }
        isInjecting = true
        logAppend("Resolving Blockman GO container...")

        Task {
            do {
                let results = try await Injector.shared.installPicked(url: zipURL)
                await MainActor.run {
                    for r in results {
                        logAppend(r.success ? "OK \(r.path)" : "FAIL \(r.path): \(r.error ?? "")")
                    }
                    let ok = results.filter { $0.success }.count
                    logAppend("Done — \(ok)/\(results.count) files. Fully close and relaunch Blockman GO.")
                    isInjecting = false
                }
            } catch {
                await MainActor.run {
                    logAppend("FAIL: \(error.localizedDescription)")
                    isInjecting = false
                }
            }
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        self.padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
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
