import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:battery_plus/battery_plus.dart'; // Gerçek batarya paketi

import '../models/signals/battery_model.dart';
import '../models/permission_model.dart';

class BackgroundService {
  // Singleton pattern (Uygulamada tek bir örneği olsun)
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Battery _battery = Battery(); // Batarya sensörüne erişim nesnesi
  
  Timer? _timer; // Periyodik işlem için zamanlayıcı

  // --- SERVİSİ BAŞLAT ---
  // Genellikle MainScreen açıldığında çağrılır.
  void startService() {
    // Eğer zaten çalışıyorsa önce durdur, üst üste binmesin.
    stopService();

    print("🤖 Arka Plan Servisi: Başlatılıyor...");

    // İlk çalıştırmada hemen bir veri gönderelim.
    _updateRealBatteryData();

    // Sonrasında her 5 dakikada bir tekrar etsin.
    // (Gerçek hayatta bu süre 15-30 dk olabilir, test için 5 dk iyi)
    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _updateRealBatteryData();
    });
  }

  // --- SERVİSİ DURDUR ---
  // Çıkış yapıldığında çağrılır.
  void stopService() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
      print("🤖 Arka Plan Servisi: Durduruldu.");
    }
  }

  // --- ANA İŞLEM: GERÇEK BATARYA VERİSİNİ GÜNCELLE ---
  Future<void> _updateRealBatteryData() async {
    final user = _auth.currentUser;
    // 1. KONTROL: Kullanıcı giriş yapmış mı?
    if (user == null) {
        print("🤖 Arka Plan Uyarısı: Kullanıcı yok, veri gönderilemedi.");
        stopService(); // Kullanıcı yoksa servisi durdur.
        return;
    }

    // 2. KONTROL: Kullanıcı batarya paylaşımına İZİN VERMİŞ Mİ?
    // Bu çok önemli. Kendi veritabanımıza bakıp izni kontrol ediyoruz.
    bool isAllowed = await _checkIfBatteryShareAllowed(user.uid);
    if (!isAllowed) {
      print("🤖 Arka Plan Bilgisi: Batarya paylaşım izni KAPALI. Veri gönderilmedi.");
      return; // İzin yoksa işlem yapma.
    }

    try {
      print("🔋 Sensör: Gerçek batarya verisi okunuyor...");
      
      // --- GERÇEK SENSÖR VERİLERİ OKUNUYOR ---
      final int level = await _battery.batteryLevel;
      final BatteryState state = await _battery.batteryState;
      // Şarj oluyor mu? (Tam doluysa veya fişe takılıysa evet)
      bool isCharging = state == BatteryState.charging || state == BatteryState.full;

      // Modeli oluştur (UTC Zaman damgasıyla)
      BatteryModel batteryData = BatteryModel(
        level: level,
        isCharging: isCharging,
        timestamp: DateTime.now().toUtc(),
      );

      // Firestore'a yaz
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('device_status')
          .doc('battery')
          .set(batteryData.toMap());

      print("✅ Arka Plan Başarısı: Gerçek batarya verisi güncellendi (%$level, Şarj: $isCharging)");

    } catch (e) {
      print("❌ Arka Plan Hatası (Batarya): $e");
    }
  }

  // Yardımcı Metot: İzin kontrolü
  Future<bool> _checkIfBatteryShareAllowed(String uid) async {
    try {
      DocumentSnapshot doc = await _db
          .collection('users')
          .doc(uid)
          .collection('permissions')
          .doc('status')
          .get();

      if (doc.exists && doc.data() != null) {
        final perms = PermissionModel.fromMap(doc.data() as Map<String, dynamic>);
        return perms.isBatteryPermitted;
      }
    } catch (e) {
        print("İzin kontrol hatası: $e");
    }
    return false; // Veri yoksa veya hata varsa izin yok say.
  }
}