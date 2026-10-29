import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'bluetooth_handler.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  FlutterTts flutterTts = FlutterTts();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _phoneController2 = TextEditingController();
  final TextEditingController _phoneController3 = TextEditingController();

  double _vibrationLevel = 2.0;
  bool _allowGpsAccess = false;

  final phoneMaskFormatter = MaskTextInputFormatter(
    mask: '+90 (###) ### ## ##', 
    filter: { "#": RegExp(r'[0-9]') },
    type: MaskAutoCompletionType.lazy
  );

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _announcePage();
  }

  Future<void> _announcePage() async {
    await flutterTts.setLanguage("tr-TR");
    await flutterTts.speak("Ayarlar ekranı. Buradan adınızı, acil durum numaranızı, titreşim düzeyini ve konum erişim iznini ayarlayabilirsiniz.");
  }

  // Hafızadan mevcut bilgileri yükle
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('userName') ?? '';
      _phoneController.text = prefs.getString('emergencyNumber') ?? '';
      _phoneController2.text = prefs.getString('emergencyNumber2') ?? '';
      _phoneController3.text = prefs.getString('emergencyNumber3') ?? '';
      _vibrationLevel = prefs.getDouble('vibrationLevel') ?? 2.0;
      _allowGpsAccess = prefs.getBool('allowGpsAccess') ?? false;
    });
  }

  // Bilgileri hafızaya kaydet
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', _nameController.text);
    await prefs.setString('emergencyNumber', _phoneController.text);
    await prefs.setString('emergencyNumber2', _phoneController2.text);
    await prefs.setString('emergencyNumber3', _phoneController3.text);
    await prefs.setDouble('vibrationLevel', _vibrationLevel);
    await prefs.setBool('allowGpsAccess', _allowGpsAccess);
    
    await flutterTts.stop();
    await flutterTts.speak("Bilgiler başarıyla kaydedildi!");

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bilgiler başarıyla kaydedildi!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context); // Kaydettikten sonra ana ekrana dön
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil & Ayarlar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Kullanıcı Bilgileri",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: const InputDecoration(
                labelText: "Kullanıcı Adı ve Soyadı",
                labelStyle: TextStyle(color: Colors.orange),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [phoneMaskFormatter],
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: const InputDecoration(
                labelText: "1. Acil Durum Numarası",
                hintText: "+90 (555) 123 45 67",
                hintStyle: TextStyle(color: Colors.grey),
                labelStyle: TextStyle(color: Colors.orange),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _phoneController2,
              keyboardType: TextInputType.phone,
              inputFormatters: [phoneMaskFormatter],
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: const InputDecoration(
                labelText: "2. Acil Durum Numarası",
                hintText: "+90 (555) 123 45 67",
                hintStyle: TextStyle(color: Colors.grey),
                labelStyle: TextStyle(color: Colors.orange),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _phoneController3,
              keyboardType: TextInputType.phone,
              inputFormatters: [phoneMaskFormatter],
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: const InputDecoration(
                labelText: "3. Acil Durum Numarası",
                hintText: "+90 (555) 123 45 67",
                hintStyle: TextStyle(color: Colors.grey),
                labelStyle: TextStyle(color: Colors.orange),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Cihaz Ayarları",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text("Titreşim Düzeyi", style: TextStyle(color: Colors.orange, fontSize: 18)),
            Slider(
              value: _vibrationLevel,
              min: 1.0,
              max: 3.0,
              divisions: 2,
              activeColor: Colors.orange,
              inactiveColor: Colors.grey,
              label: _vibrationLevel == 1.0 ? "Düşük" : _vibrationLevel == 2.0 ? "Orta" : "Yüksek",
              onChanged: (val) {
                setState(() => _vibrationLevel = val);
                String cmd = val == 1.0 ? "VIB:1" : val == 2.0 ? "VIB:2" : "VIB:3";
                BluetoothHandler().sendCommand(cmd);
                flutterTts.stop();
                flutterTts.speak(val == 1.0 ? "Düşük Titreşim" : val == 2.0 ? "Orta Titreşim" : "Yüksek Titreşim");
              },
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text("Acil Durum Kişileri Konumuma Erişebilsin", style: TextStyle(color: Colors.white, fontSize: 18)),
              activeTrackColor: Colors.orange,
              activeThumbColor: Colors.white,
              value: _allowGpsAccess,
              onChanged: (val) async {
                if (val) {
                  // İzin iste
                  LocationPermission perm = await Geolocator.checkPermission();
                  if (perm == LocationPermission.denied) {
                    perm = await Geolocator.requestPermission();
                  }
                  
                  if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
                    setState(() => _allowGpsAccess = true);
                    await flutterTts.stop();
                    await flutterTts.speak("GPS Erişimi Aktif");
                  } else {
                    setState(() => _allowGpsAccess = false);
                    await flutterTts.stop();
                    await flutterTts.speak("Konum izni reddedildiği için açılamadı.");
                  }
                } else {
                  setState(() => _allowGpsAccess = false);
                  await flutterTts.stop();
                  await flutterTts.speak("GPS Erişimi Kapalı");
                }
              },
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text(
                  'KAYDET',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
