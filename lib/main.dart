import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:telephony/telephony.dart';
import 'package:flutter/foundation.dart'; // kIsWeb kontrolü için
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';
import 'settings_screen.dart';
import 'navigation_screen.dart';
import 'bluetooth_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AkilliBastonApp());
}

class AkilliBastonApp extends StatelessWidget {
  const AkilliBastonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Akıllı Baston',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        primarySwatch: Colors.orange,
      ),
      home: const SelectionScreen(),
    );
  }
}

// Ortak Acil Durum Gönderme Fonksiyonu
Future<void> sendEmergencySMSGlobal(FlutterTts flutterTts) async {
  final prefs = await SharedPreferences.getInstance();
  String? num1 = prefs.getString('emergencyNumber');
  String? num2 = prefs.getString('emergencyNumber2');
  String? num3 = prefs.getString('emergencyNumber3');
  List<String> numbers = [];
  if (num1 != null && num1.trim().isNotEmpty) numbers.add(num1.trim());
  if (num2 != null && num2.trim().isNotEmpty) numbers.add(num2.trim());
  if (num3 != null && num3.trim().isNotEmpty) numbers.add(num3.trim());

  String? userName = prefs.getString('userName');
  bool allowGpsAccess = prefs.getBool('allowGpsAccess') ?? false;

  if (numbers.isEmpty) {
    await flutterTts.speak(
      "Acil durum numarası ayarlanmamış. Lütfen ayarlardan numara ekleyin.",
    );
    debugPrint("HATA: Acil durum numarası bulunamadı!");
    return;
  }

  String displayName = (userName != null && userName.trim().isNotEmpty)
      ? userName
      : "Akıllı Baston kullanıcısı";
  String message =
      "ACİL DURUM! $displayName isimli yakınınız akıllı baston üzerinden panik sinyali gönderdi.";

  if (allowGpsAccess) {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        flutterTts.speak("Konum izni reddedildi.");
      }
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      flutterTts.speak("GPS aranıyor, konumunuz bulunuyor...");
      Position position = await Geolocator.getCurrentPosition();
      message +=
          " Konum: https://maps.google.com/?q=${position.latitude},${position.longitude}";
    }
  } else {
    flutterTts.speak(
      "Konum paylaşımı kapalı olduğu için sadece uyarı mesajı gönderiliyor.",
    );
  }

  if (kIsWeb) {
    debugPrint("TEST MODU (WEB) SMS İÇERİĞİ: $message");
    flutterTts.speak(
      "Tarayıcı test modunda olduğumuz için SMS telefona atılmış gibi simüle edildi.",
    );
  } else if (Platform.isAndroid) {
    var smsStatus = await Permission.sms.status;
    if (!smsStatus.isGranted) {
      smsStatus = await Permission.sms.request();
    }

    if (smsStatus.isGranted) {
      try {
        for (String num in numbers) {
          Telephony.instance.sendSms(to: num, message: message);
        }
        debugPrint("SMS Gerçekten Gönderildi: $message");
        flutterTts.speak(
          "Acil durum mesajınız ${numbers.length} kişiye başarıyla gönderildi.",
        );
      } catch (e) {
        debugPrint("SMS Hatası: $e");
        flutterTts.speak("Mesaj gönderilirken bir hata oluştu.");
      }
    } else {
      flutterTts.speak("SMS izni verilmediği için mesaj gönderilemiyor.");
      debugPrint("HATA: SMS izni reddedildi.");
    }
  } else {
    flutterTts.speak(
      "SMS gönderme özelliği sadece Android cihazlarda desteklenmektedir.",
    );
    debugPrint("TEST MODU (iOS/Masaüstü) SMS İÇERİĞİ: $message");
  }
}

// BAŞLANGIÇ SEÇİM EKRANI
class SelectionScreen extends StatefulWidget {
  const SelectionScreen({super.key});

  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  FlutterTts flutterTts = FlutterTts();
  bool _isLooping = true;

  @override
  void initState() {
    super.initState();
    _startAnnouncingLoop();
  }

  Future<void> _startAnnouncingLoop() async {
    await flutterTts.setLanguage("tr-TR");
    await flutterTts.awaitSpeakCompletion(true);

    while (_isLooping) {
      if (!mounted) return;
      await flutterTts.speak(
        "Akıllı baston uygulamasına hoş geldiniz. Sesli komutla mı ilerlemek istersiniz yoksa uygulama ile mi devam edeceksiniz? Sesli komut ile devam etmek istiyorsanız üstteki, uygulama ile devam etmek istiyorsanız alttaki butona dokunun.",
      );

      if (_isLooping) {
        await Future.delayed(
          const Duration(seconds: 4),
        ); // Cümle tamamen bitince 4 sn bekle
      }
    }
  }

  @override
  void dispose() {
    _isLooping = false;
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                _isLooping = false;
                await flutterTts.stop();
                await Future.delayed(const Duration(milliseconds: 300)); // TTS motorunun durma işlemini tamamlaması için bekle
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VoiceAssistantScreen(),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                color: Colors.blueAccent,
                child: const Center(
                  child: Text(
                    "SESLİ KOMUTLA\nDEVAM ET",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                _isLooping = false;
                await flutterTts.stop();
                await Future.delayed(const Duration(milliseconds: 300));
                flutterTts.speak("Uygulama modu seçildi.");
                if (!context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DashboardScreen(),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                color: Colors.orange,
                child: const Center(
                  child: Text(
                    "UYGULAMA İLE\nDEVAM ET",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// SESLİ ASİSTAN EKRANI
class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  FlutterTts flutterTts = FlutterTts();
  stt.SpeechToText speech = stt.SpeechToText();
  bool isListening = false;
  String spokenText = "";
  bool _awaitingPhoneNumber = false;
  int _updatingContactIndex = 0;
  bool _inSettingsMenu = false; // Ayarlar alt menüsü durumu
  bool _isProcessingCommand =
      false; // Aynı komutun üst üste tetiklenmesini önleyen bayrak

  final BluetoothHandler _bleHandler = BluetoothHandler();

  @override
  void initState() {
    super.initState();
    _initVoiceAssistant();
  }

  Future<void> _initVoiceAssistant() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }

    await flutterTts.stop();
    await Future.delayed(const Duration(milliseconds: 300)); // TTS tampon belleğinin temizlenmesi için kritik bekleme
    await flutterTts.setLanguage("tr-TR");

    // Görme engelli birey için açılış anonsunu mikrofon motorunu beklemeden HEMEN okutuyoruz!
    await flutterTts.speak(
      "Sesli asistan ekranındasınız. "
      "Komut vermek için ekranın herhangi bir yerine dokunun. "
      "Bana 'bağlan', 'acil durum', 'navigasyon' veya 'ayarlar' diyebilirsiniz.",
    );

    // Arka planda mikrofon motorunu initialize ediyoruz (Anonsu kesinlikle engellemez)
    _initSpeechToText();
  }

  Future<bool> _initSpeechToText() async {
    try {
      return await speech.initialize(
        debugLogging: true,
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            if (mounted && isListening) {
              setState(() => isListening = false);
              if (spokenText.isNotEmpty && !_isProcessingCommand) {
                _evaluateCommand();
              }
            }
          }
        },
        onError: (val) {
          debugPrint("Speech Error: ${val.errorMsg}");
          if (mounted) setState(() => isListening = false);
        },
      ).timeout(const Duration(seconds: 3), onTimeout: () => false);
    } catch (e) {
      debugPrint("Speech Init Hatası: $e");
      return false;
    }
  }

  void _startListening() async {
    if (isListening || _isProcessingCommand) return;
    await flutterTts.stop();

    await flutterTts.speak("Dinliyorum");
    // "Dinliyorum" kelimesinin bitmesi ve mikrofonla çakışmaması için bekleme
    await Future.delayed(const Duration(milliseconds: 600));

    if (!speech.isAvailable) {
      bool available = await _initSpeechToText();
      if (!available) {
        await flutterTts.speak(
          "Telefonunuzun Google ses tanıma servisi şu an yanıt vermiyor veya kapalı. Lütfen telefon ayarlarından Google Asistan'ın açık olduğundan emin olun.",
        );
        return;
      }
    }

    if (mounted) {
      setState(() {
        isListening = true;
        spokenText = "";
      });
    }

    try {
      speech.listen(
        onResult: (val) {
          if (!context.mounted) return;
          setState(() {
            spokenText = val.recognizedWords.toLowerCase();
          });
          // Eğer Android motoru cümlenin bittiğini (finalResult) bildirdiyse hemen komutu işlet!
          if (val.finalResult && spokenText.isNotEmpty && !_isProcessingCommand) {
            setState(() => isListening = false);
            speech.stop();
            _evaluateCommand();
          }
        },
        localeId: "tr_TR",
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint("Speech listen hatası: $e");
      if (mounted) setState(() => isListening = false);
      await flutterTts.speak(
        "Mikrofonda bir sorun oluştu, lütfen tekrar dokunun.",
      );
    }
  }

  String _formatNumberForTTS(String number) {
    String clean = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.startsWith('+90') && clean.length == 13) {
      return "+90, ${clean.substring(3, 6)}, ${clean.substring(6, 9)}, ${clean.substring(9, 11)}, ${clean.substring(11, 13)}";
    } else if (clean.startsWith('90') && clean.length == 12) {
      return "90, ${clean.substring(2, 5)}, ${clean.substring(5, 8)}, ${clean.substring(8, 10)}, ${clean.substring(10, 12)}";
    } else if (clean.startsWith('0') && clean.length == 11) {
      return "0, ${clean.substring(1, 4)}, ${clean.substring(4, 7)}, ${clean.substring(7, 9)}, ${clean.substring(9, 11)}";
    } else if (clean.length == 10) {
      return "${clean.substring(0, 3)}, ${clean.substring(3, 6)}, ${clean.substring(6, 8)}, ${clean.substring(8, 10)}";
    }
    return clean.split('').join(', ');
  }

  String _convertWordsToDigits(String text) {
    String s = text.toLowerCase();
    s = s
        .replaceAll("sıfır", " sıfır ")
        .replaceAll("bir", " bir ")
        .replaceAll("iki", " iki ")
        .replaceAll("üç", " üç ")
        .replaceAll("dört", " dört ")
        .replaceAll("beş", " beş ")
        .replaceAll("altı", " altı ")
        .replaceAll("yedi", " yedi ")
        .replaceAll("sekiz", " sekiz ")
        .replaceAll("dokuz", " dokuz ")
        .replaceAll("on", " on ")
        .replaceAll("yirmi", " yirmi ")
        .replaceAll("otuz", " otuz ")
        .replaceAll("kırk", " kırk ")
        .replaceAll("elli", " elli ")
        .replaceAll("altmış", " altmış ")
        .replaceAll("yetmiş", " yetmiş ")
        .replaceAll("seksen", " seksen ")
        .replaceAll("doksan", " doksan ")
        .replaceAll("yüz", " yüz ")
        .replaceAll("bin", " bin ");

    List<String> words = s
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    Map<String, int> ones = {
      "sıfır": 0,
      "bir": 1,
      "iki": 2,
      "üç": 3,
      "dört": 4,
      "beş": 5,
      "altı": 6,
      "yedi": 7,
      "sekiz": 8,
      "dokuz": 9,
    };
    Map<String, int> tens = {
      "on": 10,
      "yirmi": 20,
      "otuz": 30,
      "kırk": 40,
      "elli": 50,
      "altmış": 60,
      "yetmiş": 70,
      "seksen": 80,
      "doksan": 90,
    };

    String resultDigits = "";
    int currentBlockValue = 0;
    bool hasTens = false;
    bool hasOnes = false;
    bool hasHundreds = false;

    void commitCurrentBlock() {
      if (hasHundreds || hasTens || hasOnes) {
        resultDigits += currentBlockValue.toString();
        currentBlockValue = 0;
        hasTens = false;
        hasOnes = false;
        hasHundreds = false;
      }
    }

    for (int i = 0; i < words.length; i++) {
      String w = words[i];

      if (w == "sıfır") {
        commitCurrentBlock();
        resultDigits += "0";
      } else if (w == "yüz") {
        if (hasHundreds || hasTens || hasOnes) {
          if (hasTens || hasOnes) {
            commitCurrentBlock();
            currentBlockValue = 100;
            hasHundreds = true;
          } else {
            currentBlockValue = currentBlockValue * 100;
            hasHundreds = true;
          }
        } else {
          currentBlockValue = 100;
          hasHundreds = true;
        }
      } else if (w == "bin") {
        if (currentBlockValue == 0) currentBlockValue = 1;
        currentBlockValue = currentBlockValue * 1000;
        hasHundreds = true;
      } else if (tens.containsKey(w)) {
        if (hasTens || hasOnes) {
          commitCurrentBlock();
        }
        currentBlockValue += tens[w]!;
        hasTens = true;
      } else if (ones.containsKey(w)) {
        if (hasOnes) {
          commitCurrentBlock();
        }
        if (!hasHundreds &&
            !hasTens &&
            i + 1 < words.length &&
            (words[i + 1] == "yüz" || words[i + 1] == "bin")) {
          currentBlockValue += ones[w]!;
        } else {
          currentBlockValue += ones[w]!;
          hasOnes = true;
        }
      } else {
        String digits = w.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isNotEmpty) {
          commitCurrentBlock();
          resultDigits += digits;
        }
      }
    }
    commitCurrentBlock();

    return resultDigits;
  }

  Future<void> _evaluateCommand() async {
    if (spokenText.isEmpty || _isProcessingCommand) return;
    _isProcessingCommand = true;
    try {
      await _processCurrentCommand();
    } finally {
      if (mounted) {
        setState(() {
          spokenText =
              ""; // İşlem bittiğinde ekrandaki ve hafızadaki metni tamamen sıfırla
        });
      }
      // Asistan sustuktan sonra olası yankıları/gecikmeli mikrofon algılamalarını
      // engellemek için kilidi açmadan önce yarım saniye bekliyoruz!
      await Future.delayed(const Duration(milliseconds: 500));
      _isProcessingCommand = false;
    }
  }

  Future<void> _processCurrentCommand() async {
    if (spokenText.isEmpty) return;

    if (_awaitingPhoneNumber) {
      String digitsOnly = _convertWordsToDigits(spokenText);
      if (digitsOnly.length >= 10) {
        if (digitsOnly.length > 10 && digitsOnly.startsWith('90')) {
          digitsOnly = '+90${digitsOnly.substring(2)}';
        } else if (digitsOnly.startsWith('0')) {
          digitsOnly = '+90${digitsOnly.substring(1)}';
        } else {
          digitsOnly = '+90$digitsOnly';
        }

        final prefs = await SharedPreferences.getInstance();

        String readableNumber = _formatNumberForTTS(digitsOnly);
        String? num1 = prefs.getString('emergencyNumber');
        String? num2 = prefs.getString('emergencyNumber2');
        String? num3 = prefs.getString('emergencyNumber3');

        if (num1 == digitsOnly || num2 == digitsOnly || num3 == digitsOnly) {
          await flutterTts.speak(
            "Bu telefon numarası zaten acil durum listesinde kayıtlı.",
          );
        } else if (num1 == null || num1.isEmpty) {
          await prefs.setString('emergencyNumber', digitsOnly);
          await flutterTts.speak(
            "Birinci acil durum numarası $readableNumber olarak başarıyla kaydedildi.",
          );
        } else if (num2 == null || num2.isEmpty) {
          await prefs.setString('emergencyNumber2', digitsOnly);
          await flutterTts.speak(
            "İkinci acil durum numarası $readableNumber olarak başarıyla kaydedildi.",
          );
        } else if (num3 == null || num3.isEmpty) {
          await prefs.setString('emergencyNumber3', digitsOnly);
          await flutterTts.speak(
            "Üçüncü acil durum numarası $readableNumber olarak başarıyla kaydedildi.",
          );
        } else {
          // Kapasite doluyken hata vermek yerine sınav demosunun hızlı ve akıcı olması için doğrudan 1. numarayı güncelliyoruz!
          await prefs.setString('emergencyNumber', digitsOnly);
          await flutterTts.speak(
            "Acil durum listesi doluydu, bu yüzden birinci acil durum numarası $readableNumber olarak güncellendi.",
          );
        }
        _awaitingPhoneNumber = false;
        _updatingContactIndex = 0;
      } else {
        await flutterTts.speak(
          "Söylediğiniz numara eksik veya anlaşılamadı. Lütfen ekrana dokunup numarayı tekrar söyleyin.",
        );
      }
      return;
    }

    // 1. Ayarlar / Alt Menü Komutları (Her an erişilebilir!)
    if (spokenText.contains("ana menü") ||
        spokenText.contains("geri") ||
        spokenText.contains("ana menu")) {
      _inSettingsMenu = false;
      await flutterTts.speak(
        "Ana menüye dönüldü. Bana 'bağlan', 'acil durum', 'navigasyon' veya 'ayarlar' diyebilirsiniz.",
      );
    } else if (spokenText.contains("düşük") ||
        spokenText.contains("dusuk") ||
        (spokenText.contains("titreşim") && spokenText.contains("az"))) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('vibrationLevel', 1.0);
      _bleHandler.sendCommand("VIB:1");
      await flutterTts.speak(
        "Titreşim seviyesi bastonda düşük olarak ayarlandı.",
      );
    } else if (spokenText.contains("orta") ||
        (spokenText.contains("titreşim") && spokenText.contains("normal"))) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('vibrationLevel', 2.0);
      _bleHandler.sendCommand("VIB:2");
      await flutterTts.speak(
        "Titreşim seviyesi bastonda orta olarak ayarlandı.",
      );
    } else if (spokenText.contains("yüksek") ||
        spokenText.contains("yuksek") ||
        (spokenText.contains("titreşim") && spokenText.contains("çok"))) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('vibrationLevel', 3.0);
      _bleHandler.sendCommand("VIB:3");
      await flutterTts.speak(
        "Titreşim seviyesi bastonda yüksek olarak ayarlandı.",
      );
    } else if (spokenText == "titreşim" || spokenText == "titresim") {
      await flutterTts.speak(
        "Titreşim seviyesini ne yapmak istersiniz? Lütfen ekrana dokunup düşük, orta veya yüksek deyin.",
      );
    } else if (spokenText.contains("numaraları sil") ||
        spokenText.contains("kişileri sil")) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('emergencyNumber', '');
      await prefs.setString('emergencyNumber2', '');
      await prefs.setString('emergencyNumber3', '');
      await flutterTts.speak("Tüm acil durum numaraları başarıyla silindi.");
    } else if (spokenText.contains("kaydet") ||
        spokenText.contains("numara") ||
        spokenText.contains("kişi") ||
        spokenText.contains("kisi") ||
        spokenText.contains("ekle")) {
      _awaitingPhoneNumber = true;
      _updatingContactIndex = 0;
      await flutterTts.speak(
        "Lütfen kaydetmek istediğiniz telefon numarasının rakamlarını, ekrana dokunduktan sonra tek tek okuyun.",
      );
    } else if (spokenText.contains("konumu aç") ||
        spokenText.contains("konum aç") ||
        spokenText.contains("konumu ac") ||
        spokenText.contains("konum ac")) {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('allowGpsAccess', true);
        await flutterTts.speak("Konum paylaşımı başarıyla açıldı.");
      } else {
        await flutterTts.speak(
          "Telefondan konum izni verilmediği için açılamadı.",
        );
      }
    } else if (spokenText.contains("konumu kapat") ||
        spokenText.contains("konum kapat") ||
        spokenText.contains("konumu kapa") ||
        spokenText.contains("konum kapa")) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('allowGpsAccess', false);
      await flutterTts.speak("Konum paylaşımı başarıyla kapatıldı.");
    } else if (spokenText.contains("manuel") || spokenText.contains("ekran")) {
      await flutterTts.speak("Görsel ayarlar ekranı açılıyor...");
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsScreen()),
      );

      // 2. Ana Menü & Navigasyon Komutları (Her an erişilebilir!)
    } else if (spokenText.contains("ayar")) {
      _inSettingsMenu = true;
      await flutterTts.speak(
        "Ayarlar menüsündesiniz. Ne yapmak istersiniz? Bana 'titreşim düşük', 'titreşim orta', 'titreşim yüksek', 'kaydet', 'konumu aç', 'konumu kapat' veya 'ana menü' diyebilirsiniz.",
      );
    } else if (spokenText.contains("bağlantıyı kes") ||
        spokenText.contains("bağlantı kes") ||
        spokenText.contains("bastonu kes")) {
      _bleHandler.disconnect();
      await flutterTts.speak("Baston bağlantısı kesildi.");
    } else if (spokenText.contains("bağlan") || spokenText.contains("baglan")) {
      await flutterTts.speak("Baston aranıyor...");
      _bleHandler.connectToBaston((status) {
        if (status == "ACIL") {
          sendEmergencySMSGlobal(flutterTts);
        }
      });
    } else if (spokenText.contains("acil") || spokenText.contains("yardım")) {
      await flutterTts.speak("Acil durum işlemi başlatılıyor...");
      sendEmergencySMSGlobal(flutterTts);
    } else if (spokenText.contains("navigasyon") ||
        spokenText.contains("git") ||
        spokenText.contains("yol")) {
      await flutterTts.speak("Navigasyon menüsü açılıyor...");
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NavigationScreen()),
      );
    } else if (spokenText.contains("çık") ||
        spokenText.contains("kapat") ||
        spokenText.contains("uygulama")) {
      await flutterTts.speak("Uygulama moduna geçiliyor.");
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      if (_inSettingsMenu) {
        await flutterTts.speak(
          "Söylediğiniz komut anlaşılamadı. Ayarlar menüsündesiniz. Bana 'titreşim düşük', 'titreşim orta', 'titreşim yüksek', 'kaydet', 'konumu aç', 'konumu kapat', 'manuel ayarlar' veya 'ana menü' diyebilirsiniz.",
        );
      } else {
        await flutterTts.speak(
          "Söylediğiniz komut anlaşılamadı. Ana menüdesiniz. Lütfen bağlan, acil durum, navigasyon veya ayarlar diyiniz.",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Sesli Asistan"),
        backgroundColor: Colors.amber,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await flutterTts.stop();
            if (!context.mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SelectionScreen()),
            );
          },
        ),
      ),
      body: InkWell(
        onTap: () {
          if (!isListening) _startListening();
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isListening ? Icons.mic : Icons.mic_none,
                size: 150,
                color: isListening ? Colors.red : Colors.grey,
              ),
              const SizedBox(height: 30),
              Text(
                isListening ? "Dinliyorum..." : "Konuşmak İçin Dokunun",
                style: const TextStyle(color: Colors.white, fontSize: 30),
              ),
              const SizedBox(height: 20),
              Text(
                spokenText,
                style: const TextStyle(color: Colors.orange, fontSize: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ANA KONTROL EKRANI (MANUEL MOD)
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  FlutterTts flutterTts = FlutterTts();
  final BluetoothHandler _bleHandler = BluetoothHandler();
  String _bleStatus = "BAĞLAN (V24)";

  @override
  void initState() {
    super.initState();
    _announcePage();
  }

  Future<void> _announcePage() async {
    await flutterTts.stop();
    await flutterTts.setLanguage("tr-TR");
    await flutterTts.speak(
      "Uygulama ekranı. İşlem yapmak için ekrandaki butonlara dokunabilirsiniz.",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Akıllı Baston',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.amber,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await flutterTts.stop();
            await Future.delayed(const Duration(milliseconds: 300));
            if (!context.mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SelectionScreen()),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await flutterTts.stop();
                  if (_bleStatus == "BASTONA\nBAĞLAN" ||
                      _bleStatus == "BAĞLAN" ||
                      _bleStatus == "BAĞLAN (V4)" ||
                      _bleStatus == "Bağlantı Kesildi") {
                    setState(() => _bleStatus = "Aranıyor...");
                    flutterTts.speak("Bastona bağlanma işlemi başlatılıyor");

                    _bleHandler.connectToBaston((status) {
                      if (status == "ACIL") {
                        sendEmergencySMSGlobal(flutterTts);
                        return;
                      }
                      if (mounted) {
                        setState(() {
                          if (!status.contains("UYARI")) {
                            _bleStatus = status;
                          }
                        });
                      }
                      debugPrint("BLE BİLGİSİ: $status");
                    });
                  } else {
                    _bleHandler.disconnect();
                    setState(() => _bleStatus = "BAĞLAN");
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_bleStatus == "Aranıyor..." ||
                        _bleStatus == "Bağlanılıyor...")
                      const Padding(
                        padding: EdgeInsets.only(right: 15),
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    Text(
                      _bleStatus == "BAĞLANDI" ? "BAĞLANTIYI KES" : _bleStatus,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await flutterTts.stop();
                  debugPrint("Navigasyon butonuna basıldı");
                  flutterTts.speak("Navigasyon menüsü açılıyor");
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NavigationScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'NAVİGASYON',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await flutterTts.stop();
                  debugPrint("Acil durum butonuna basıldı");
                  flutterTts.speak("Acil durum işlemi başlatılıyor...");
                  sendEmergencySMSGlobal(flutterTts);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'ACİL DURUM\nGÖNDER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await flutterTts.stop();
                  debugPrint("Ayarlar butonuna basıldı");
                  flutterTts.speak("Ayarlar menüsü açılıyor");
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'AYARLAR &\nREHBER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            // ─── MOTOR TEST BUTONLARI (sadece bağlıyken görünür) ───
            if (_bleStatus == "BAĞLANDI") ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await flutterTts.speak("Sağ motor test ediliyor.");
                        for (int i = 0; i < 3; i++) {
                          _bleHandler.sendCommand("SAG\n");
                          await Future.delayed(const Duration(milliseconds: 400));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: const Text(
                        '▶ SAĞ\nTEST',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await flutterTts.speak("Sol motor test ediliyor.");
                        for (int i = 0; i < 3; i++) {
                          _bleHandler.sendCommand("SOL\n");
                          await Future.delayed(const Duration(milliseconds: 400));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: const Text(
                        '◀ SOL\nTEST',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),

          ],
        ),
      ),
    );
  }
}
