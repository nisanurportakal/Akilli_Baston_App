# 🦯 IoT Tabanlı ve Mobil Entegreli Akıllı Baston Sistemi

Görme engelli bireylerin günlük yaşamlarını kolaylaştırmak, sosyal hayata aktif katılımlarını desteklemek ve bağımsız hareket kabiliyetlerini artırmak amacıyla iki kişilik bir ekip çalışması kapsamında geliştirilmiş **donanım-yazılım entegreli kapsamlı bir IoT ve mobil erişilebilirlik projesidir.**

---

## 🌟 Proje Mimarisi ve Temel Bileşenler

Proje iki ana bileşenin gerçek zamanlı entegrasyonuyla çalışır:

```
┌────────────────────────────────┐         Bluetooth (BLE)         ┌─────────────────────────────────┐
│     AKILLI BASTON DONANIMI     │ ◄─────────────────────────────► │    FLUTTER MOBİL ASİSTANI       │
│  - Ultrasonik Engel Sensörleri │                                 │  - Türkçe Sesli Komut & Asistan │
│  - Titreşim / Sesli Uyarılar   │                                 │  - GPS Konum & Acil Durum SMS   │
│  - Mikrodenetleyici (IoT)      │                                 │  - Sesli Navigasyon & Arayüz    │
└────────────────────────────────┘                                 └─────────────────────────────────┘
```

---

## 🛠️ Donanım (IoT) Yetenekleri
* **Ultrasonik Engel Tespiti:** Kullanıcının yürüyüş hattındaki engelleri farklı mesafelerden gerçek zamanlı algılama.
* **Titreşimli ve Sesli Geri Bildirim:** Engel mesafesine göre kademeli haptik titreşim ve sesli uyarı mekanizması.
* **Mikrodenetleyici & BLE İletişimi:** Sensör verilerini anlık olarak işleyip mobil uygulamaya aktaran düşük enerji tüketimli kablosuz haberleşme altyapısı.

---

## 📱 Mobil Uygulama (Flutter) Yetenekleri
* **Kesintisiz Bluetooth Bağlantısı:** Baston donanımıyla otomatik ve kararlı veri senkronizasyonu (`flutter_bluetooth_serial`, `flutter_blue_plus`).
* **Türkçe Sesli Asistan:** Kullanıcının ekrana bakmasına gerek kalmadan sesli komutlarla kontrol sağlayabileceği, sesle telefon numarası algılayıp kaydedebilen asistan mimarisi (`speech_to_text`, `flutter_tts`).
* **Acil Durum & GPS Konum Paylaşımı:** Tehlike anında kullanıcının güncel coğrafi koordinatlarını acil durum kişilerine SMS ile anında ileten güvenlik sistemi (`geolocator`, `telephony`).
* **Sesli Navigasyon Desteği:** Kullanıcıyı yönlendiren erişilebilir rota ve harita takibi ekranı.
* **Yüksek Kontrastlı Erişilebilir Arayüz:** Görme yetisi kısıtlı kullanıcılar düşünülerek tasarlanmış siyah tabanlı, yüksek kontrastlı ve dokunmatik geri bildirimli tasarım.

---

## 💻 Kullanılan Teknolojiler & Kütüphaneler

| Alan | Teknoloji / Kütüphane | Kullanım Amacı |
| :--- | :--- | :--- |
| **Mobil Çatı** | Flutter (Dart) | Çapraz platform yüksek performanslı mobil mimari |
| **Haberleşme** | `flutter_bluetooth_serial`, `flutter_blue_plus` | Akıllı baston IoT donanımı ile kablosuz iletişim |
| **Ses & Asistan** | `speech_to_text`, `flutter_tts`, `audio_session` | Ses algılama ve sesli geri bildirim (TTS) |
| **Konum & Harita**| `geolocator`, `geocoding`, `flutter_map` | GPS koordinat tespiti ve rota yönetimi |
| **Güvenlik & İletişim** | `telephony`, `permission_handler`, `url_launcher` | Acil durum SMS gönderimi ve arama başlatma |
| **Veri Depolama** | `shared_preferences` | Ayarlar ve acil durum kişilerinin yerel hafızada tutulması |

---

## 🚀 Kurulum ve Çalıştırma

### Mobil Uygulamayı Başlatma:
```bash
# 1. Depoyu klonlayın
git clone https://github.com/nisanurportakal/Ak-ll-_Baston_App.git

# 2. Proje dizinine gidin
cd Ak-ll-_Baston_App

# 3. Bağımlılıkları yükleyin
flutter pub get

# 4. Uygulamayı çalıştırın
flutter run
```

### 📱 Hazır Kurulum (APK):
Uygulamanın hazır derlenmiş kurulum dosyasını doğrudan cihazınıza yüklemek için deponun [Releases](../../releases) bölümünden güncel `.apk` dosyasını indirebilirsiniz.
