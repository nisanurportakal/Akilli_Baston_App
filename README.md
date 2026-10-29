# 🦯 Akıllı Baston Mobil Uygulaması
> **Görme Engelli Bireyler İçin Erişilebilir Mobil Asistan ve Güvenlik Sistemi**

Bu proje, görme engelli bireylerin günlük yaşamda daha güvenli ve bağımsız hareket edebilmelerini sağlamak amacıyla geliştirilen akıllı baston projesinin mobil ayağını oluşturmaktadır. İki kişilik bir ekip çalışması kapsamında hayata geçirilmiş olup; akıllı baston donanımı ile mobil cihaz arasında köprü kurarak kullanıcıya sesli rehberlik, navigasyon ve güvenlik desteği sunar.

---

## 🌟 Öne Çıkan Özellikler

* 🎙️ **Sesli Asistan & Ses Tanıma:** Görme engelli kullanıcıların ekrana ihtiyaç duymadan cihazı yönetebilmesi için ses tanıma (*Speech-to-Text*) ve metin seslendirme (*Text-to-Speech*) altyapısı.
* 📡 **Bluetooth Donanım Entegrasyonu:** Akıllı baston üzerindeki modülle kablosuz iletişim kurarak anlık durum takibi ve veri senkronizasyonu sağlayan Bluetooth bağlantısı.
* 🚨 **Acil Durum & GPS Konum Bildirimi:** Tehlike anında tek bir komutla kullanıcının anlık coğrafi konumunu önceden belirlenen acil durum kişilerine SMS ile otomatik ileten güvenlik sistemi.
* 👁️ **Erişilebilir Kullanıcı Deneyimi:** Az gören veya görme engelli kullanıcılar için özel olarak optimize edilmiş yüksek kontrastlı, sade ve dokunmatik geri bildirimli arayüz mimarisi.
* ⚙️ **Kişiselleştirilmiş Ayarlar:** Acil durum numaralarını ve kullanıcı tercihlerini cihaz hafızasında güvenle saklayan yönetim modülü.

---

## 🛠️ Kullanılan Teknolojiler ve Kütüphaneler

* **Geliştirme Platformu:** Flutter & Dart
* **Ses & Asistan Altyapısı:** `speech_to_text`, `flutter_tts`, `audio_session`
* **Donanım İletişimi:** `flutter_bluetooth_serial`, `flutter_blue_plus`
* **Konum & Harita:** `geolocator`, `geocoding`
* **Güvenlik & SMS:** `telephony`, `permission_handler`
* **Yerel Depolama:** `shared_preferences`

---

## 🚀 Kurulum ve Çalıştırma

Projeyi yerel ortamınızda çalıştırmak için:

```bash
# 1. Depoyu klonlayın
git clone https://github.com/nisanurportakal/Ak-ll-_Baston_App.git

# 2. Proje dizinine gidin
cd Ak-ll-_Baston_App

# 3. Bağımlılıkları yükleyin
flutter pub get

# 4. Uygulamayı başlatın
flutter run
```

---

## 📱 Hazır Kurulum Dosyası (APK)
Uygulamayı derleme yapmadan doğrudan Android cihazınızda test etmek için [Releases](../../releases) sayfasından güncel `.apk` kurulum dosyasını indirebilirsiniz.
