# 🦯 Akıllı Baston Mobil Uygulaması

Bu proje, görme engelli bireyler için geliştirdiğimiz akıllı bastona eşlik eden yardımcı mobil uygulamadır. İki kişilik bir ekip çalışması (öğrenci projesi) olarak hayata geçirilmiştir.

---

## 🎯 Projenin Amacı
Baston donanımına destek olarak; görme engelli kullanıcının sesli komutlarla telefonunu yönetebilmesini, bastonla Bluetooth üzerinden bağlantı kurabilmesini ve acil durumlarda yakınlarına hızlıca konum gönderebilmesini sağlamaktır.

---

## 📱 Uygulamanın Özellikleri
* **Bluetooth ile Baston Bağlantısı:** Baston üzerindeki modüle bağlanarak cihazla iletişim kurar.
* **Sesli Komut ve Sesli Yanıt:** Görme engellilerin rahat kullanabilmesi için ses tanıma ve sesli geri bildirim (okuma) özellikleri içerir.
* **Acil Durum SMS ve Konum:** İhtiyaç anında önceden kaydedilen acil durum numarasına telefonun GPS konumunu SMS olarak gönderir.
* **Erişilebilir Ekran:** Görme yetisi kısıtlı kullanıcılar için sade, siyah temalı ve dokunmatik geri bildirimli arayüz.
* **Ayarlar Ekranı:** Acil durum numaralarını ve kullanıcı bilgilerini kaydetme alanı.

---

## 🛠️ Kullanılan Teknolojiler
* **Geliştirme:** Flutter & Dart
* **Hazır Paketler (Kütüphaneler):**
  * `speech_to_text` (Ses Tanıma)
  * `flutter_tts` (Sesli Okuma)
  * `geolocator` (GPS Konum)
  * `telephony` (SMS Gönderme)
  * `flutter_bluetooth_serial` (Bluetooth İletişimi)
  * `shared_preferences` (Numaraları Hafızada Tutma)

---

## 🚀 Çalıştırma
Flutter yüklü bir bilgisayarda:
```bash
git clone https://github.com/nisanurportakal/Ak-ll-_Baston_App.git
cd Ak-ll-_Baston_App
flutter pub get
flutter run
```
*Hazır çalışan kurulum dosyasını doğrudan telefonunuza yüklemek için [Releases](../../releases) sayfasından `.apk` dosyasını indirebilirsiniz.*
