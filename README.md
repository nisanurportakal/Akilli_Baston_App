# Akıllı Baston Mobil Uygulaması 🦯📱

Görme engelli bireylerin günlük yaşamlarını kolaylaştırmak ve bağımsız hareket edebilmelerini sağlamak amacıyla geliştirilmiş Flutter tabanlı mobil uygulama.

## 🌟 Temel Özellikler
- **Bluetooth Bağlantısı:** Akıllı baston donanımı ile gerçek zamanlı kablosuz BLE iletişimi.
- **Sesli Asistan & Ses Tanıma:** Türkçe sesli komut algılama, sesli geri bildirim (TTS) ve sesle telefon numarası kaydetme.
- **Acil Durum & GPS Konum Paylaşımı:** Tehlike veya düşme anında güncel GPS koordinatlarını SMS yoluyla acil durum kişilerine otomatik iletme.
- **Navigasyon Ekranı:** Sesli rehberlik ile rota takibi.
- **Özelleştirilebilir Ayarlar:** Acil durum kişileri ve ses/bağlantı parametreleri yönetimi.

## 🛠️ Kullanılan Teknolojiler & Kütüphaneler
- **Flutter & Dart**
- **Bluetooth:** `flutter_bluetooth_serial`, `flutter_blue_plus`
- **Konum:** `geolocator`, `geocoding`
- **Ses & Konuşma:** `speech_to_text`, `flutter_tts`, `audio_session`
- **İletişim & İzinler:** `telephony`, `permission_handler`, `url_launcher`
- **Yerel Depolama:** `shared_preferences`

## 🚀 Kurulum ve Çalıştırma
Projeyi çalıştırmak için Flutter SDK yüklü olmalıdır:

```bash
# 1. Depoyu klonlayın
git clone https://github.com/nisanurportakal/Ak-ll-_Baston_App.git

# 2. Proje dizinine gidin
cd Ak-ll-_Baston_App

# 3. Paketleri indirin
flutter pub get

# 4. Uygulamayı başlatın
flutter run
```
