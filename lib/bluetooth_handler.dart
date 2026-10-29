import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

class BluetoothHandler {
  static final BluetoothHandler _instance = BluetoothHandler._internal();
  factory BluetoothHandler() => _instance;
  BluetoothHandler._internal();

  ble.BluetoothDevice? connectedBleDevice;
  classic.BluetoothConnection? connectedClassicDevice;
  ble.BluetoothCharacteristic? _bleWriteChar; // Cache — her komutta servis taranmaz
  final FlutterTts flutterTts = FlutterTts();

  final String targetDeviceName = "AKILLI_BASTON";

  Future<void> connectToBaston(Function(String) onStatusUpdate) async {
    if (kIsWeb) {
      onStatusUpdate("TEST MODU: Web tarayıcısında Bluetooth simüle ediliyor.");
      await flutterTts.speak("Tarayıcıda Bluetooth testi simüle ediliyor.");
      return;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();

        if (statuses[Permission.bluetoothScan]!.isPermanentlyDenied ||
            statuses[Permission.bluetoothConnect]!.isPermanentlyDenied ||
            statuses[Permission.location]!.isPermanentlyDenied) {
          onStatusUpdate("BAĞLAN");
          await flutterTts.speak("Bluetooth veya Konum izinleri kalıcı olarak reddedilmiş. Ayarlar açılıyor.");
          await openAppSettings();
          return;
        } else if (statuses[Permission.bluetoothScan]!.isDenied ||
            statuses[Permission.bluetoothConnect]!.isDenied ||
            statuses[Permission.location]!.isDenied) {
          onStatusUpdate("BAĞLAN");
          await flutterTts.speak("Bluetooth ve Konum izinleri verilmediği için bastona bağlanılamıyor.");
          return;
        }
      }

      onStatusUpdate("Aranıyor...");
      await flutterTts.speak("Akıllı baston aranıyor, lütfen bekleyin.");

      // =================================================================
      // 1. KLASİK BLUETOOTH (SPP) BAĞLANTI DENEMESİ (EŞLEŞMİŞ CİHAZLAR)
      // =================================================================
      try {
        debugPrint("=== KLASİK BLUETOOTH (SPP) EŞLEŞMİŞ CİHAZLAR KONTROL EDILIYOR ===");
        List<classic.BluetoothDevice> bondedDevices = await classic.FlutterBluetoothSerial.instance.getBondedDevices();
        
        debugPrint(">>> Toplam Eşleşmiş Cihaz Sayısı: ${bondedDevices.length}");
        
        classic.BluetoothDevice? targetDevice;

        // Önce tümünü logla (filtre olmadan)
        for (classic.BluetoothDevice device in bondedDevices) {
          debugPrint(">>> EŞLEŞMİŞ: name='${device.name}', address='${device.address}'");
        }

        // Sadece bastonumuzu ara — genel isimler (BT, HC vb.) yanlış cihazlara bağlanıyor!
        for (classic.BluetoothDevice device in bondedDevices) {
          String rawName = device.name ?? "";
          String upperName = rawName.toUpperCase();
          
          // SADECE "akilli" veya "baston" içeren isimleri kabul et
          bool isBaston = upperName.contains("AKILLI") ||
              upperName.contains("BASTON") ||
              rawName.toLowerCase().contains("akilli") ||
              rawName.toLowerCase().contains("baston");

          if (isBaston) {
            debugPrint(">>> BASTON BULUNDU: '${device.name}' -> ${device.address}");
            targetDevice = device;
            break;
          }
        }

        // Eğer isimle bulunamadıysa, sadece 1 cihaz varsa onu dene
        if (targetDevice == null && bondedDevices.length == 1) {
          targetDevice = bondedDevices.first;
          debugPrint(">>> Tek cihaz var, onu deniyoruz: '${targetDevice.name}' -> ${targetDevice.address}");
        }

        if (targetDevice != null) {
          debugPrint(">>> BAĞLANILIYOR: '${targetDevice.name}' (${targetDevice.address})");
          onStatusUpdate("Bağlanılıyor (${targetDevice.name})...");

          try {
            classic.BluetoothConnection connection = await classic.BluetoothConnection
                .toAddress(targetDevice.address)
                .timeout(const Duration(seconds: 12));
            connectedClassicDevice = connection;
            
            debugPrint(">>> KLASİK BLUETOOTH BAĞLANTISI BAŞARILI! (${targetDevice.name})");
            onStatusUpdate("BAĞLANDI");
            await flutterTts.speak("Akıllı bastona başarıyla bağlandınız. Sensörler aktif.");

            final prefs = await SharedPreferences.getInstance();
            double vib = prefs.getDouble('vibrationLevel') ?? 2.0;
            String vibCmd = vib == 1.0 ? "VIB:1" : vib == 2.0 ? "VIB:2" : "VIB:3";
            sendCommand(vibCmd);

            connection.input!.listen((Uint8List data) {
              String sensorData = ascii.decode(data);
              debugPrint(">>> SPP SENSÖR: $sensorData");
              if (sensorData.contains("ENGEL")) {
                flutterTts.speak("Dikkat, baş hizasında engel var.");
                onStatusUpdate("UYARI: ENGEL");
              } else if (sensorData.contains("CUKUR")) {
                flutterTts.speak("Dikkat, zeminde çukur veya merdiven boşluğu var.");
                onStatusUpdate("UYARI: ÇUKUR");
              } else if (sensorData.contains("ACIL") || sensorData.contains("DUSME_ALGILANDI")) {
                onStatusUpdate("ACIL");
              }
            }).onDone(() {
              debugPrint(">>> SPP Bağlantısı koptu.");
              connectedClassicDevice = null;
              onStatusUpdate("BAĞLAN");
              flutterTts.speak("Baston bağlantısı kesildi.");
            });

            return; // Başarılı! BLE taramasına geçme.
          } catch (connErr) {
            debugPrint(">>> Klasik SPP toAddress HATASI (${targetDevice.name}): $connErr");
          }
        } else {
          debugPrint(">>> HİÇBİR EŞLEŞMİŞ BASTON BULUNAMADI! (${bondedDevices.length} cihaz var)");
        }
      } catch (sppErr) {
        debugPrint(">>> KLASİK SPP GENEL HATASI: $sppErr");
      }

      // Klasik Bluetooth adaptörünün dinlenmesi ve çakışma (socket not created) önlemi
      debugPrint("Klasik SPP denemeleri bitti, BLE taraması için 1.5 saniye bekleniyor...");
      await Future.delayed(const Duration(milliseconds: 1500));

      // =================================================================
      // 2. BLE (LOW ENERGY) TARAMA DENEMESİ (YEDEK / İKİNCİ YÖNTEM)
      // =================================================================
      debugPrint("BLE taraması başlatılıyor...");
      bool isConnecting = false;

      var subscription = ble.FlutterBluePlus.onScanResults.listen((results) async {
        for (ble.ScanResult r in results) {
          String pName = r.device.platformName.toUpperCase();
          String aName = r.device.advName.toUpperCase();
          String rawP = r.device.platformName;
          String rawA = r.device.advName;
          
          // Sadece isimli cihazları logla
          if (pName.isNotEmpty || aName.isNotEmpty) {
            debugPrint("TARANAN BLE CİHAZI: platformName='$pName', advName='$aName', address='${r.device.remoteId}'");
          }

          // SADECE "akilli" veya "baston" içeren BLE cihazları kabul et
          bool isBaston = pName.contains("AKILLI") ||
              pName.contains("BASTON") ||
              rawP.toLowerCase().contains("akilli") ||
              rawP.toLowerCase().contains("baston") ||
              aName.contains("AKILLI") ||
              aName.contains("BASTON") ||
              rawA.toLowerCase().contains("akilli") ||
              rawA.toLowerCase().contains("baston");

          if (isBaston && !isConnecting) {
            isConnecting = true;
            await ble.FlutterBluePlus.stopScan();

            String foundName = pName.isNotEmpty ? pName : aName;
            debugPrint("BLE Baston bulundu ($foundName), bağlanılıyor...");
            onStatusUpdate("Bağlanılıyor ($foundName)...");
            await flutterTts.speak("Baston bulundu, bağlantı kuruluyor.");

            try {
              await r.device.connect(timeout: const Duration(seconds: 12), license: ble.License.free);
              connectedBleDevice = r.device;

              debugPrint("BLE BAĞLANTISI BAŞARILI! ($foundName)");
              onStatusUpdate("BAĞLANDI");

              // Servisleri BİR KEZ keşfet ve write karakteristiğini cache'e al
              await _discoverAndCacheCharacteristics(r.device, onStatusUpdate);

              await flutterTts.speak("Akıllı bastona bağlandınız. Sensörler aktif.");

              final prefs = await SharedPreferences.getInstance();
              double vib = prefs.getDouble('vibrationLevel') ?? 2.0;
              String vibCmd = vib == 1.0 ? "VIB:1" : vib == 2.0 ? "VIB:2" : "VIB:3";
              sendCommand(vibCmd);
            } catch (e) {
              isConnecting = false;
              debugPrint("BLE connect hatası: $e");
              onStatusUpdate("BAĞLAN");
              await flutterTts.speak("Bastona bağlanılamadı. Lütfen tekrar deneyin.");
            }
            break;
          }
        }
      });

      await ble.FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      for (int i = 15; i > 0; i--) {
        if (isConnecting || connectedClassicDevice != null || connectedBleDevice != null) break;
        onStatusUpdate("Aranıyor... ($i sn)");
        if (i % 5 == 0) {
          await flutterTts.speak("$i saniye kaldı");
        }
        await Future.delayed(const Duration(seconds: 1));
      }

      await subscription.cancel();

      if (!isConnecting && connectedBleDevice == null && connectedClassicDevice == null) {
        onStatusUpdate("BAĞLAN");
        await flutterTts.speak("Baston bulunamadı. Lütfen bastonun açık olduğundan emin olup tekrar bağlanmayı deneyin.");
      }

    } catch (e) {
      debugPrint("Genel Bağlantı Hatası: $e");
      onStatusUpdate("Hata: Bağlantı kurulamadı.");
      await flutterTts.stop();
      await Future.delayed(const Duration(milliseconds: 300));
      await flutterTts.speak("Bağlantı hatası oluştu. Lütfen Bluetooth'u kontrol edin.");
    }
  }

  /// Servisleri bir kez keşfeder: write char cache'e alınır, notify char dinlemeye başlar
  Future<void> _discoverAndCacheCharacteristics(ble.BluetoothDevice device, Function(String) onSensorAlert) async {
    try {
      List<ble.BluetoothService> services = await device.discoverServices();
      debugPrint(">>> BLE Servis sayısı: ${services.length}");

      for (ble.BluetoothService service in services) {
        for (ble.BluetoothCharacteristic char in service.characteristics) {
          // Write karakteristiğini cache'e al (ilk bulunan)
          if ((char.properties.write || char.properties.writeWithoutResponse) && _bleWriteChar == null) {
            _bleWriteChar = char;
            debugPrint(">>> BLE Write Char cache'lendi: ${char.uuid}");
          }

          // Notify karakteristiğini dinlemeye başla
          if (char.properties.notify) {
            try {
              await char.setNotifyValue(true);
              char.lastValueStream.listen((value) {
                if (value.isEmpty) return;
                String sensorData = String.fromCharCodes(value);
                debugPrint(">>> BLE SENSÖR: $sensorData");
                if (sensorData.contains("ENGEL")) {
                  flutterTts.speak("Dikkat, baş hizasında engel var.");
                  onSensorAlert("UYARI: ENGEL");
                } else if (sensorData.contains("CUKUR")) {
                  flutterTts.speak("Dikkat, zeminde çukur var.");
                  onSensorAlert("UYARI: ÇUKUR");
                } else if (sensorData.contains("ACIL") || sensorData.contains("DUSME")) {
                  onSensorAlert("ACIL");
                }
              });
            } catch (e) {
              debugPrint(">>> Notify ayarlama hatası: $e");
            }
          }
        }
      }
    } catch (e) {
      debugPrint(">>> discoverServices hatası: $e");
    }
  }

  Future<void> sendCommand(String command) async {
    // 1. Klasik SPP
    if (connectedClassicDevice != null) {
      try {
        connectedClassicDevice!.output.add(ascii.encode(command));
        await connectedClassicDevice!.output.allSent;
        debugPrint(">>> SPP Komut: $command");
        return;
      } catch (e) {
        debugPrint(">>> SPP gönderme hatası: $e");
      }
    }

    // 2. BLE — cache'lenmiş write char üzerinden ANINDA gönder
    if (connectedBleDevice != null && _bleWriteChar != null) {
      try {
        // writeWithoutResponse daha hızlı, navigasyon için idealdir
        bool useWR = _bleWriteChar!.properties.writeWithoutResponse;
        await _bleWriteChar!.write(
          command.codeUnits,
          withoutResponse: useWR,
        );
        debugPrint(">>> BLE Komut (${useWR ? 'WR' : 'W'}): $command");
        return;
      } catch (e) {
        debugPrint(">>> BLE gönderme hatası: $e — char yeniden aranıyor");
        _bleWriteChar = null; // Cache bozuldu, sonraki connect'te yenilenecek
      }
    }

    debugPrint(">>> UYARI: Bağlı cihaz yok veya write char bulunamadı!");
  }

  Future<void> disconnect() async {
    _bleWriteChar = null;
    if (connectedClassicDevice != null) {
      await connectedClassicDevice!.finish();
      connectedClassicDevice = null;
      await flutterTts.speak("Baston ile bağlantı kesildi.");
    }
    if (connectedBleDevice != null) {
      await connectedBleDevice!.disconnect();
      connectedBleDevice = null;
      await flutterTts.speak("Baston ile bağlantı kesildi.");
    }
  }
}
