# Yapay Zeka — iOS Uygulaması

SwiftUI ile yazılmış, hepsi bir arada yapay zeka uygulaması (iOS 17+).

| Sekme | Ne yapar | Kullanılan model |
|---|---|---|
| 💬 Sohbet | Soru-cevap, kod yazma (kod bloklarını kopyala / dosya yap) | Claude Opus 5.5 (`claude-opus-5-5`) |
| 🖼️ Fotoğraf | Yazıdan fotoğraf üretir, galeriye kaydeder | OpenAI `gpt-image-1` |
| 🎬 Video | Yazıdan 4/8/12 sn video üretir, **en fazla 100 MB** | OpenAI `sora-2` |
| 📄 Dosya | İstediğin dosyayı oluşturur (txt, md, csv, json, html, py…) | Claude Opus 5.5 |
| ⚙️ Ayarlar | API anahtarları (Keychain'de saklanır) | — |

## Kurulum (Mac + Xcode 15 veya üstü gerekir)

1. XcodeGen kur: `brew install xcodegen`
2. Projeyi oluştur:
   ```bash
   cd YapayZeka
   xcodegen generate
   open YapayZeka.xcodeproj
   ```
3. Xcode'da **Signing & Capabilities** → kendi Apple hesabını (Team) seç.
4. iPhone'u bağla ya da simülatör seç → ▶️ Çalıştır.
5. Uygulamada **Ayarlar** sekmesine anahtarlarını gir:
   - Claude: <https://console.anthropic.com> → API Keys
   - OpenAI: <https://platform.openai.com/api-keys> (video için Sora erişimi gerekir)

## Notlar

- Kullanım ücretlidir; ücretler kendi Anthropic / OpenAI hesaplarına yansır. Video üretimi en pahalısıdır.
- Video 100 MB'ı aşarsa silinir ve hata gösterilir (720p, 12 sn'lik videolar normalde bu sınırın çok altındadır).
- Oluşturulan dosyalar uygulamanın Belgeler klasörüne kaydedilir ve **Dosyalar** uygulamasında görünür.
- Anahtarlar uygulamanın içinde saklandığı için bu yapı kişisel kullanım içindir. App Store'a
  yayınlayacaksan anahtarları kendi sunucunda tutup istekleri oradan geçirmelisin.

## Dosya yapısı

```
YapayZeka/
├── project.yml              # XcodeGen proje tanımı
└── Sources/
    ├── App/YapayZekaApp.swift
    ├── Services/
    │   ├── ClaudeService.swift   # Claude: streaming sohbet + yapılandırılmış dosya çıktısı
    │   ├── OpenAIService.swift   # Fotoğraf + video (100 MB sınırı) + dosya kaydetme
    │   └── KeyStore.swift        # Keychain
    └── Views/                    # Sohbet, Fotoğraf, Video, Dosya, Ayarlar ekranları
```
