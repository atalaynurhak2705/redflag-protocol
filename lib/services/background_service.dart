import 'dart:async';
import 'dart:ui';
import 'dart:isolate';

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
@pragma('vm:entry-point')
void onNotificationData(NotificationEvent event) {
  print("🔔 Isolate Tetiklendi: ${event.packageName}");
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
    'com.spotify.music', 
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
      var hasPerm = await NotificationsListener.hasPermission;
      if (hasPerm != true) {
        print("⚠️ SİSTEM İZNİ YOK: Notification Access gerekli!");
        return;
      }

      await NotificationsListener.initialize(callbackHandle: onNotificationData);
      
      _port = ReceivePort();
      IsolateNameServer.removePortNameMapping("notifications_send_port"); 
      IsolateNameServer.registerPortWithName(_port!.sendPort, "notifications_send_port");

      _port!.listen((message) {
        if (message is NotificationEvent) {
          _processNotificationEvent(message);
        }
      });

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
    final String body = event.text ?? "";

    // 1. Filtreleme: Sistem bildirimlerini ve boş başlıkları ele
    if (pkg.contains("android.system") || 
        pkg.contains("com.android.systemui") || 
        pkg.contains("com.google.android.gms") ||
        title.isEmpty) return;

    PermissionModel? perms = await _getMyPermissions(user.uid);

    // 2. MEDYA KONTROLÜ
    if (_musicApps.contains(pkg)) {
      bool isMediaAllowed = perms?.isMediaPermitted ?? true;
      if (isMediaAllowed) {
        final mediaData = MediaModel(
          isPlaying: true, 
          packageName: pkg,
          title: title,
          artist: body,
          timestamp: DateTime.now().toUtc(),
        );
        await _db.collection('users').doc(user.uid).collection('device_status').doc('media').set(mediaData.toMap());
        print("✅ MEDYA GÜNCELLENDİ: $title");
      }
      return; // Medya olarak işlendiyse bildirim sayacına ekleme
    }

    // 3. GENEL BİLDİRİM SAYACI (Eskiden yorum satırı olan kısım)
    bool isNotifAllowed = perms?.isNotificationsPermitted ?? true;
    if (isNotifAllowed) {
      try {
        await _db.collection('users').doc(user.uid).collection('notifications').add({
          'package_name': pkg,
          'timestamp': FieldValue.serverTimestamp(), // Dashboard buradan "bugünküleri" sayıyor
          'category': _categorizeApp(pkg),
        });
        print("✅ BİLDİRİM KAYDEDİLDİ: $pkg");
      } catch (e) {
        print("❌ Bildirim yazma hatası: $e");
      }
    }
  }

  String _categorizeApp(String packageName) {
    if (packageName.contains("whatsapp")) return "Message";
    if (packageName.contains("instagram") || packageName.contains("facebook")) return "Social";
    return "Other";
  }

  Future<void> _updateAllSensors() async {
    final user = _auth.currentUser;
    if (user == null) { stopService(); return; }
    
    PermissionModel? perms = await _getMyPermissions(user.uid);
    
    if (perms?.isBatteryPermitted ?? true) {
       await _processBattery(user.uid);
    }
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