import SwiftUI

@main
struct YapayZekaApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @AppStorage("didSetupKeys") private var didSetupKeys = false

    var body: some View {
        TabView {
            ChatView()
                .tabItem { Label("Sohbet", systemImage: "bubble.left.and.bubble.right") }
            ImageGenView()
                .tabItem { Label("Fotoğraf", systemImage: "photo") }
            VideoGenView()
                .tabItem { Label("Video", systemImage: "film") }
            FileGenView()
                .tabItem { Label("Dosya", systemImage: "doc.text") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Ayarlar", systemImage: "gear") }
        }
        .sheet(isPresented: .constant(!didSetupKeys && !KeyStore.hasAnyKey)) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        Button("Tamam") { didSetupKeys = true }
                    }
            }
        }
    }
}
