import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'main.dart'; 
import 'bluetooth_handler.dart';

class NavigationStep {
  final double lat;
  final double lon;
  final String modifier;
  final String instruction;
  bool announced = false;

  NavigationStep({required this.lat, required this.lon, required this.modifier, required this.instruction});
}

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  FlutterTts flutterTts = FlutterTts();
  stt.SpeechToText speech = stt.SpeechToText();
  bool isListening = false;
  final TextEditingController _searchController = TextEditingController();

  List<NavigationStep> _steps = [];
  int _currentStepIndex = 0;
  bool _isNavigating = false;
  StreamSubscription<Position>? _positionSubscription;
  String _navigationStatusText = "";

  @override
  void initState() {
    super.initState();
    _announcePage();
  }

  @override
  void dispose() {
    flutterTts.stop();
    _positionSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _announcePage() async {
    await flutterTts.stop();
    await flutterTts.setLanguage("tr-TR");
    await flutterTts.speak("Navigasyon ekranındasınız. Gitmek istediğiniz yeri aramak için mikrofona basın veya arama çubuğuna yazın. Akıllı baston üzerinden adım adım titreşimli yol tarifi otomatik olarak başlatılacaktır.");
  }

  void _startListening() async {
    await flutterTts.stop();
    bool available = await speech.initialize(
      onStatus: (val) => debugPrint('onStatus: $val'),
      onError: (val) => debugPrint('onError: $val'),
    );
    if (available) {
      setState(() => isListening = true);
      await flutterTts.speak("Dinliyorum, nereye gitmek istiyorsunuz?");
      
      speech.listen(
        onResult: (val) {
          setState(() {
            _searchController.text = val.recognizedWords;
          });
          if (val.hasConfidenceRating && val.confidence > 0) {
            setState(() => isListening = false);
            speech.stop();
            _findAndStartNavigation(val.recognizedWords);
          }
        },
        localeId: 'tr_TR',
        listenFor: const Duration(seconds: 10),
      );
    } else {
      await flutterTts.speak("Mikrofon başlatılamadı. Lütfen mikrofon izinlerini kontrol edin.");
    }
  }

  Future<void> _findAndStartNavigation(String destination) async {
    if (destination.isEmpty) return;
    
    await flutterTts.stop();
    await flutterTts.speak("En yakın $destination aranıyor, lütfen bekleyin.");

    try {
      // 1. Kullanıcının anlık GPS konumunu al
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      // 2. Android Geocoder ile kullanıcının bulunduğu ilçeyi/şehri öğren (Örn: "Tire")
      List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      String currentLocality = "";
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        currentLocality = "${p.subAdministrativeArea ?? p.locality ?? ''}".trim();
      }
      
      // 3. Hedef kelimesini ilçe ile birleştir (Örn: "Migros Tire")
      String searchQuery = destination;
      if (currentLocality.isNotEmpty && !destination.toLowerCase().contains(currentLocality.toLowerCase())) {
        searchQuery = "$destination $currentLocality";
      }
      debugPrint("Nominatim Sorgusu: $searchQuery");

      // 4. Nominatim API'den şubeleri çek
      final searchUrl = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(searchQuery)}&format=json&addressdetails=1&accept-language=tr');
      final response = await http.get(searchUrl, headers: {'User-Agent': 'AkilliBastonApp/1.0'});
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        
        if (data.isNotEmpty) {
          // 5. Gelen sonuçlar arasında kullanıcının GPS konumuna en yakın olanı bul
          Map<String, dynamic>? bestFeature;
          double minDistance = double.infinity;
          
          for (var item in data) {
            double lat = double.tryParse(item['lat'].toString()) ?? 0.0;
            double lon = double.tryParse(item['lon'].toString()) ?? 0.0;
            if (lat != 0.0 && lon != 0.0) {
              double dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lon);
              if (dist < minDistance) {
                minDistance = dist;
                bestFeature = item;
              }
            }
          }
          
          if (bestFeature != null) {
            final destLat = double.tryParse(bestFeature['lat'].toString()) ?? 0.0;
            final destLon = double.tryParse(bestFeature['lon'].toString()) ?? 0.0;
            final exactName = bestFeature['name'] ?? bestFeature['display_name'] ?? destination;
            
            await flutterTts.speak("Bulunduğunuz konuma ${(minDistance).toInt()} metre mesafedeki en yakın $exactName bulundu. Akıllı baston ile adım adım titreşimli yol tarifi başlatılıyor.");
            
            // OSRM API'den rota adımlarını çek
            await _fetchOsrmRouteAndStart(pos.latitude, pos.longitude, destLat, destLon, exactName);
            return;
          }
        }
      }
      
      await _fallbackToGoogleDirect(destination);
    } catch (e) {
      debugPrint("Harita Hatası: $e");
      await _fallbackToGoogleDirect(destination);
    }
  }

  Future<void> _fetchOsrmRouteAndStart(double startLat, double startLon, double destLat, double destLon, String destName) async {
    final osrmUrl = Uri.parse('https://router.project-osrm.org/route/v1/foot/$startLon,$startLat;$destLon,$destLat?steps=true&geometries=geojson&overview=full');
    try {
      final response = await http.get(osrmUrl, headers: {'User-Agent': 'AkilliBastonApp/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final legs = routes[0]['legs'] as List;
          if (legs.isNotEmpty) {
            final stepsData = legs[0]['steps'] as List;
            List<NavigationStep> parsedSteps = [];

            for (var s in stepsData) {
              final maneuver = s['maneuver'];
              final location = maneuver['location'] as List;
              final modifier = maneuver['modifier']?.toString() ?? "";
              final type = maneuver['type']?.toString() ?? "";
              final name = s['name']?.toString() ?? "";

              String instruction = "";
              if (type == "turn") {
                if (modifier.contains("right")) {
                  instruction = "Sağa dönün, $name yönünde ilerleyin.";
                } else if (modifier.contains("left")) {
                  instruction = "Sola dönün, $name yönünde ilerleyin.";
                } else {
                  instruction = "$name yönünde düz ilerleyin.";
                }
              } else if (type == "arrive") {
                instruction = "Hedefinize ulaştınız.";
              } else {
                instruction = "$name boyunca ilerleyin.";
              }

              parsedSteps.add(NavigationStep(
                lat: double.tryParse(location[1].toString()) ?? 0.0,
                lon: double.tryParse(location[0].toString()) ?? 0.0,
                modifier: modifier.toLowerCase(),
                instruction: instruction,
              ));
            }

            // Rota adımlarını kaydet ve GPS takibini başlat (arka planda titreşim için)
            setState(() {
              _steps = parsedSteps;
              _currentStepIndex = 0;
              _isNavigating = true;
              _navigationStatusText =
                  "Google Maps açılıyor...\nBaston titreşim takibi aktif.\n${parsedSteps.length} dönüş noktası yüklendi.";
            });

            // GPS takibini HEMEN başlat (Google Maps açılmadan önce)
            _startLocationTracking();

            // Google Maps'i aç — kullanıcı sesli yönlendirmeyi oradan alır
            // Bizim GPS takibimiz arka planda dönüş noktalarını izler ve motoru titretir
            await flutterTts.speak(
              "Rota hazır. ${parsedSteps.length} dönüş noktası yüklendi. "
              "Google Haritalar açılıyor. Dönüşlerde baston titreyecek."
            );

            final intentUrl = Uri.parse(
              'google.navigation:q=$destLat,$destLon&mode=w'
            );
            final webUrl = Uri.parse(
              'https://www.google.com/maps/dir/?api=1'
              '&destination=$destLat,$destLon'
              '&travelmode=walking&dir_action=navigate'
            );
            try {
              bool launched = await launchUrl(intentUrl, mode: LaunchMode.externalNonBrowserApplication);
              if (!launched) await launchUrl(webUrl, mode: LaunchMode.externalApplication);
            } catch (_) {
              await launchUrl(webUrl, mode: LaunchMode.externalApplication);
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("OSRM Hatası: $e");
    }

    // OSRM başarısız — sadece Google Maps aç (titreşim olmadan)
    await _fallbackToGoogleDirect(destName);
  }

  // Titreşim komutunu [count] kez gönder (güçlü haptic feedback)
  Future<void> _sendRepeatedVibration(String command, int count) async {
    for (int i = 0; i < count; i++) {
      BluetoothHandler().sendCommand(command);
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  void _startLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 2),
    ).listen((Position currentPos) async {
      if (!_isNavigating || _steps.isEmpty || _currentStepIndex >= _steps.length) return;

      NavigationStep nextStep = _steps[_currentStepIndex];
      double distanceToTurn = Geolocator.distanceBetween(currentPos.latitude, currentPos.longitude, nextStep.lat, nextStep.lon);

      setState(() {
        _navigationStatusText = "Sıradaki: ${nextStep.instruction}\nKalan Mesafe: ${distanceToTurn.toInt()} metre";
      });

      // 30 metre uyarısı — dönüş öncesi hafif hazırlık titreşimi
      if (distanceToTurn <= 30.0 && distanceToTurn > 15.0 && !nextStep.announced) {
        if (nextStep.modifier.contains("right")) {
          BluetoothHandler().sendCommand("SAG_UYARI\n");
        } else if (nextStep.modifier.contains("left")) {
          BluetoothHandler().sendCommand("SOL_UYARI\n");
        }
      }

      // Eğer dönüş noktasına 15 metre veya daha yaklaştıysak ana titreşim + ses komutu!
      if (distanceToTurn <= 15.0 && !nextStep.announced) {
        nextStep.announced = true;

        if (nextStep.modifier.contains("right")) {
          await _sendRepeatedVibration("SAG\n", 3);
          await flutterTts.speak("Dikkat! Sağa dönün. ${nextStep.instruction}");
        } else if (nextStep.modifier.contains("left")) {
          await _sendRepeatedVibration("SOL\n", 3);
          await flutterTts.speak("Dikkat! Sola dönün. ${nextStep.instruction}");
        } else {
          BluetoothHandler().sendCommand("DUZ\n");
          await flutterTts.speak(nextStep.instruction);
        }

        // Bir sonraki adıma geç
        _currentStepIndex++;
        if (_currentStepIndex >= _steps.length) {
          await flutterTts.speak("Hedefinize ulaştınız. Akıllı baston navigasyonu tamamlandı.");
          BluetoothHandler().sendCommand("HEDEF\n");
          setState(() {
            _isNavigating = false;
            _navigationStatusText = "Hedefe Ulaşıldı!";
          });
          _positionSubscription?.cancel();
        }
      }
    });
  }

  Future<void> _fallbackToGoogleDirect(String destination) async {
    // Google Maps'e yönlendirme KALDIRILDI — titreşim motorları için navigasyon
    // uygulama içinde kalmalı. Kullanıcıya tekrar denemesini söyle.
    setState(() {
      _isNavigating = false;
      _navigationStatusText = "";
    });
    await flutterTts.speak(
      "$destination için rota bulunamadı. Lütfen daha spesifik bir yer adı deneyin. "
      "Örneğin şehir adıyla birlikte söyleyin."
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Akıllı Baston Navigasyon', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () async {
            await flutterTts.stop();
            if (!context.mounted) return;
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SelectionScreen()));
          },
        ),
      ),
      body: _isNavigating 
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.navigation, size: 120, color: Colors.blue),
                  const SizedBox(height: 30),
                  Text(
                    _navigationStatusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 50),
                  ElevatedButton(
                    onPressed: () {
                      _positionSubscription?.cancel();
                      setState(() {
                        _isNavigating = false;
                        _navigationStatusText = "";
                      });
                      flutterTts.speak("Navigasyon durduruldu.");
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("NAVİGASYONU BİTİR", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
          )
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    "Nereye Gitmek İstiyorsunuz?",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  
                  // SESLİ ARAMA BUTONU
                  GestureDetector(
                    onTap: _startListening,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      decoration: BoxDecoration(
                        color: isListening ? Colors.red : Colors.green,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            isListening ? Icons.mic : Icons.mic_none,
                            size: 80,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isListening ? "Dinleniyor..." : "SESLİ ARAMA",
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // YAZILI ARAMA KUTUSU
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 20),
                      decoration: InputDecoration(
                        hintText: "Veya buraya yazın...",
                        prefixIcon: const Icon(Icons.search, size: 30),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send, color: Colors.blue, size: 35),
                          onPressed: () => _findAndStartNavigation(_searchController.text),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                      onSubmitted: (val) => _findAndStartNavigation(val),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  const Text(
                    "Not: Hiçbir Başla butonuna basmanıza gerek kalmadan navigasyon otomatik başlatılacaktır.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
