import SwiftUI

struct SettingsView: View {
    @State private var anthropicKey = KeyStore.get(.anthropic) ?? ""
    @State private var openaiKey = KeyStore.get(.openai) ?? ""
    @State private var saved = false

    var body: some View {
        Form {
            Section {
                SecureField("sk-ant-…", text: $anthropicKey)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            } header: {
                Text("Anthropic (Claude) API anahtarı")
            } footer: {
                Text("Sohbet, soru-cevap, kod ve dosya için. console.anthropic.com adresinden alınır.")
            }
            Section {
                SecureField("sk-…", text: $openaiKey)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            } header: {
                Text("OpenAI API anahtarı")
            } footer: {
                Text("Fotoğraf ve video üretimi için. platform.openai.com adresinden alınır.")
            }
            Section {
                Button("Kaydet") {
                    KeyStore.set(anthropicKey, for: .anthropic)
                    KeyStore.set(openaiKey, for: .openai)
                    saved = true
                }
                if saved { Text("Kaydedildi ✅").foregroundStyle(.green) }
            } footer: {
                Text("Anahtarlar yalnızca bu cihazın Keychain'inde saklanır. Kullanım ücretleri ilgili hesaplara yansır.")
            }
        }
        .navigationTitle("Ayarlar")
    }
}
