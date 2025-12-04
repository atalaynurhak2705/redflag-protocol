import 'dart:async';
import 'dart:ui';
import 'dart:isolate';

// Paket ismini doğru import ediyoruz
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/signals/battery_model.dart';
import '../models/signals/network_model.dart';
import '../models/signals/media_model.dart';
import '../models/permission_model.dart';

// --- TOP-LEVEL CALLBACK ---
// --- TOP-LEVEL CALLBACK (DÜZELTİLDİ) ---
@pragma('vm:entry-point')
void onNotificationData(NotificationEvent event) {
  print("🔔 Isolate Tetiklendi: ${event.packageName}");
  
  // EKSİK OLAN KÖPRÜ KODU BURASI:
  // Arka plandan ana uygulamaya veriyi fırlatıyoruz.
  final SendPort? send = IsolateNameServer.lookupPortByName("notifications_send_port");
  if (send != null) {
    send.send(event);
  } else {
    print("❌ HATA: Ana uygulamaya giden port kapalı!");
  }
}

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  
  Timer? _timer;
  ReceivePort? _port;
  bool _isServiceRunning = false;

  // --- MÜZİK UYGULAMALARI LİSTESİ ---
  final List<String> _musicApps = [
    'com.spotify.music', // Spotify
    'com.google.android.apps.youtube.music',
    'com.apple.android.music',
    'deezer.android.app',
    'com.soundcloud.android',
    'com.google.android.youtube',
    'com.android.chrome', 
  ];

  void startService() {
    if (_isServiceRunning) return;
    _isServiceRunning = true;
    print("🤖 BackgroundService: Başlatıldı.");

    _updateAllSensors();
    _timer = Timer.periodic(const Duration(minutes: 15), (timer) {
      _updateAllSensors();
    });

    _startNotificationListener();
  }

  void stopService() {
    _timer?.cancel();
    _port?.close();
    _isServiceRunning = false;
    print("🛑 BackgroundService: Durduruldu.");
  }

  Future<void> _startNotificationListener() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // DÜZELTME 1: Sınıf adı 'NotificationsListener' olarak güncellendi
      var hasPerm = await NotificationsListener.hasPermission;
      if (hasPerm != true) {
        print("⚠️ SİSTEM İZNİ YOK: Kullanıcı Ayarlardan 'Notification Access' vermemiş!");
        return;
      }

      // DÜZELTME 2: 'NotificationsListener' kullanıldı
      await NotificationsListener.initialize(callbackHandle: onNotificationData);
      
      // Port Kurulumu (Veriyi yakalamak için şart)
      _port = ReceivePort();
      // 'notifications_send_port' ismi plugin.dart içindeki SEND_PORT_NAME ile aynı olmalı
      IsolateNameServer.removePortNameMapping("notifications_send_port"); 
      IsolateNameServer.registerPortWithName(_port!.sendPort, "notifications_send_port");

      // Portu Dinle
      _port!.listen((message) {
        // Gelen mesaj NotificationEvent tipindedir
        if (message is NotificationEvent) {
          _processNotificationEvent(message);
        } else {
          print("❓ Bilinmeyen veri tipi: $message");
        }
      });

      // DÜZELTME 3: Servisi Başlat
      await NotificationsListener.startService();
      print("👂 KULAK AÇIK: Dinlemeye başladı...");

    } catch (e) {
      print("❌ Servis Başlatma Hatası: $e");
    }
  }

  Future<void> _processNotificationEvent(NotificationEvent event) async {
    if (!_isServiceRunning) return;
    final user = _auth.currentUser;
    if (user == null) return;

    final String pkg = event.packageName ?? "unknown";
    final String title = event.title ?? "";
    final String body = event.text ?? ""; // Şarkıcı adı genelde buradadır

    print("🔥 DEBUG: Bildirim Geldi -> $pkg | $title");

    PermissionModel? perms = await _getMyPermissions(user.uid);
    bool isMediaAllowed = perms?.isMediaPermitted ?? true; 

    // --- MEDYA KONTROLÜ ---
    if (_musicApps.contains(pkg)) {
      print("🔥 DEBUG: Müzik Uygulaması Tespit Edildi! ($pkg)");
      
      if (!isMediaAllowed) {
        print("⛔ Medya izni veritabanında kapalı.");
        return;
      }

      if (title.isEmpty || title.contains("Android System")) return;

      final mediaData = MediaModel(
        isPlaying: true, 
        packageName: pkg,
        title: title,
        artist: body,
        timestamp: DateTime.now().toUtc(),
      );

      print("📝 FIRESTORE YAZILIYOR: ${mediaData.toMap()}");

      await _db.collection('users').doc(user.uid).collection('device_status').doc('media').set(mediaData.toMap());
      print("✅ MEDYA YAZILDI!");
      return;
    }

    // --- DİĞER BİLDİRİMLER (Şimdilik pasif) ---
    /*
    if (pkg.contains("android.system") || pkg.contains("com.google.android.gms")) return;
    try {
      final notificationData = {
        'package_name': pkg,
        'title': title,
        'timestamp': FieldValue.serverTimestamp(),
        'is_read': false,
        'category': _categorizeApp(pkg),
      };
      // await _db.collection('users').doc(user.uid).collection('notifications').add(notificationData);
    } catch (e) {
      print("❌ Hata: $e");
    }
    */
  }

  String _categorizeApp(String packageName) {
    if (packageName.contains("whatsapp")) return "Message";
    return "Other";
  }

  Future<void> _updateAllSensors() async {
    final user = _auth.currentUser;
    if (user == null) { stopService(); return; }
    
    PermissionModel? perms = await _getMyPermissions(user.uid);
    // İzin null ise varsayılan olarak devam et (Test için)
    
    // Batarya
    if (perms?.isBatteryPermitted ?? true) {
       await _processBattery(user.uid);
    }
    // Ağ
    if (perms?.isNetworkPermitted ?? true) {
       await _processNetwork(user.uid);
    }
  }

  Future<void> _processBattery(String uid) async {
    try {
      final int level = await _battery.batteryLevel;
      final BatteryState state = await _battery.batteryState;
      bool isCharging = (state == BatteryState.charging || state == BatteryState.full);
      final data = BatteryModel(level: level, isCharging: isCharging, timestamp: DateTime.now().toUtc());
      await _db.collection('users').doc(uid).collection('device_status').doc('battery').set(data.toMap());
    } catch (_) {}
  }

  Future<void> _processNetwork(String uid) async {
    try {
      final ConnectivityResult result = await _connectivity.checkConnectivity();
      String type = "Unknown";
      if (result == ConnectivityResult.wifi) type = "WI-FI";
      else if (result == ConnectivityResult.mobile) type = "MOBILE DATA";
      else type = "OFFLINE";
      final data = NetworkModel(type: type, timestamp: DateTime.now().toUtc());
      await _db.collection('users').doc(uid).collection('device_status').doc('network').set(data.toMap());
    } catch (_) {}
  }

  Future<PermissionModel?> _getMyPermissions(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).collection('permissions').doc('status').get();
      if (doc.exists && doc.data() != null) {
        return PermissionModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }
}