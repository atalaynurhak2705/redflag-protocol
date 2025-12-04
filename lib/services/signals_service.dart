import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Sensör Paketleri
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/signals/battery_model.dart';
import '../models/signals/network_model.dart';
import '../models/signals/media_model.dart';
import '../models/signals/screen_time_model.dart';
import '../models/permission_model.dart';
import '../models/log_model.dart';

class SignalsService {
  static final SignalsService _instance = SignalsService._internal();
  factory SignalsService() => _instance;
  SignalsService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  
  // --- SABİTLER (SECURITY CONFIG) ---
  static const int MANUAL_SIGNAL_REWARD = 15;
  static const int RATE_LIMIT_MINUTES = 30; // 30 Dakika bekleme kuralı

  Timer? _timer;
  bool _isServiceRunning = false;

  String? get _currentUserId => _auth.currentUser?.uid;

  CollectionReference _getDeviceStatusRef(String userId) {
    return _db.collection('users').doc(userId).collection('device_status');
  }

  // ===========================================================================
  // --- YENİ EKLENEN: MANUEL SİNYAL GÖNDERME (TRANSACTION & SECURITY) ---
  // ===========================================================================

  /// Kullanıcının kendi sinyalini manuel olarak partnerine "Push" etmesi.
  /// Puan kazandırır (+15) ve veriyi günceller.
  /// Transaction kullanır: Hata olursa puan verilmez.
  Future<void> sendManualSignal() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Oturum açmış kullanıcı bulunamadı.");

    final userRef = _db.collection('users').doc(user.uid);

    // 1. Sensör Verilerini Taze Çek
    final int batteryLevel = await _battery.batteryLevel;
    // YENİ: Batarya durumunu (Şarj oluyor mu?) kontrol et
    final BatteryState batteryState = await _battery.batteryState;
    final bool isCharging = batteryState == BatteryState.charging || batteryState == BatteryState.full;
    
    // Ağ Durumunu Çek
    final ConnectivityResult connectivityResult = await _connectivity.checkConnectivity();
    String networkStatus = 'Unknown';
    if (connectivityResult == ConnectivityResult.wifi) {
      networkStatus = 'WiFi';
    } else if (connectivityResult == ConnectivityResult.mobile) {
      networkStatus = 'Mobile';
    } else if (connectivityResult == ConnectivityResult.none) {
      networkStatus = 'Offline';
    }

    // 2. Transaction Başlat (Veri Bütünlüğü İçin)
    await _db.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);

      if (!userSnapshot.exists) {
        throw Exception("Kullanıcı profili bulunamadı.");
      }

      final data = userSnapshot.data() as Map<String, dynamic>;

      // --- SECURITY: Rate Limiting Kontrolü ---
      if (data.containsKey('last_manual_signal') && data['last_manual_signal'] != null) {
        Timestamp lastSignal = data['last_manual_signal'];
        DateTime lastSignalDate = lastSignal.toDate();
        final difference = DateTime.now().difference(lastSignalDate).inMinutes;

        if (difference < RATE_LIMIT_MINUTES) {
          throw Exception("Sinyal göndermek için ${RATE_LIMIT_MINUTES - difference} dakika beklemelisiniz.");
        }
      }

      // 3. Puan Hesapla
      final int currentPoints = data['points'] ?? 0;
      final int newPoints = currentPoints + MANUAL_SIGNAL_REWARD;

      // 4. Update İşlemleri (Atomik)
      // Kullanıcı ana dokümanını güncelle (Puan ve Zamanlar)
      transaction.update(userRef, {
        'last_active': FieldValue.serverTimestamp(),
        'last_manual_signal': FieldValue.serverTimestamp(), // Rate limit sayacı sıfırlanır
        'points': newPoints, // Ödül
      });

      // Cihaz durumunu güncelle
      final batteryRef = _getDeviceStatusRef(user.uid).doc('battery');
      final networkRef = _getDeviceStatusRef(user.uid).doc('network');

      // Batarya verisini yaz
      transaction.set(batteryRef, {
        'level': batteryLevel,
        'status': 'unknown', 
        'timestamp': FieldValue.serverTimestamp(),
        'isCharging': isCharging // ARTIK GERÇEK VERİ GİDİYOR (true/false)
      }, SetOptions(merge: true));

      // Ağ verisini yaz
      transaction.set(networkRef, {
        'status': networkStatus,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 5. Loglama (Activity Logs) - Transaction parçası olarak
      final logRef = _db.collection('users').doc(user.uid).collection('activity_logs').doc();
      transaction.set(logRef, {
        'title': 'Manuel Sinyal',
        'description': 'Partnerine anlık veri gönderildi. +$MANUAL_SIGNAL_REWARD TP',
        'point_change': MANUAL_SIGNAL_REWARD,
        'type': 'MANUAL_PUSH',
        'timestamp': FieldValue.serverTimestamp(),
        'actor_uid': user.uid,
        'metadata': {
          'battery': batteryLevel,
          'isCharging': isCharging,
          'network': networkStatus
        }
      });
    });
  }

  // ===========================================================================
  // --- MEVCUT VERİ OKUMA METOTLARI (GET) ---
  // ===========================================================================
  
  Future<PermissionModel?> getMyPermissions() async {
     if (_currentUserId == null) return null;
     return _getMyPermissions(_currentUserId!);
  }

  Future<PermissionModel?> _getMyPermissions(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).collection('permissions').doc('status').get();
      if (doc.exists && doc.data() != null) return PermissionModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (_) {}
    return PermissionModel(timestamp: DateTime.now().toUtc());
  }

  Future<Map<String, dynamic>?> getPartnerMood(String partnerId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(partnerId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['current_mood'] == null) return null;
        return {'mood': data['current_mood'], 'timestamp': data['last_mood_update'] != null ? DateTime.parse(data['last_mood_update']) : null};
      }
    } catch (e) { print("Mod çekme hatası: $e"); }
    return null;
  }

  Future<PermissionModel?> getPartnerPermissions(String partnerId) async {
    return await _getMyPermissions(partnerId);
  }

  Future<BatteryModel?> getBatteryStatus(String partnerId) async {
    try {
      DocumentSnapshot doc = await _getDeviceStatusRef(partnerId).doc('battery').get();
      if (doc.exists && doc.data() != null) return BatteryModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) { print("Batarya hata: $e"); }
    return null;
  }

  Future<NetworkModel?> getNetworkStatus(String partnerId) async {
    try {
      DocumentSnapshot doc = await _getDeviceStatusRef(partnerId).doc('network').get();
      if (doc.exists && doc.data() != null) return NetworkModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) { print("Ağ hata: $e"); }
    return null;
  }

  Future<MediaModel?> getMediaStatus(String partnerId) async {
    try {
      DocumentSnapshot doc = await _getDeviceStatusRef(partnerId).doc('media').get();
      if (doc.exists && doc.data() != null) return MediaModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) { print("Medya hata: $e"); }
    return null;
  }

  Future<ScreenTimeModel?> getYesterdayScreenTime(String partnerId) async {
    return null; 
  }

  Future<int> getTodayNotificationCount(String partnerId) async {
    try {
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));
      QuerySnapshot query = await _db.collection('users').doc(partnerId).collection('notifications').where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay)).where('timestamp', isLessThan: Timestamp.fromDate(endOfDay)).get();
      return query.docs.length;
    } catch (e) { print("Bildirim sayma hata: $e"); }
    return 0;
  }

  // ===========================================================================
  // --- MEVCUT VERİ YAZMA METOTLARI ---
  // ===========================================================================

  Future<void> updateMyMood(String moodValue) async {
    if (_currentUserId == null) return;
    try {
      await _db.collection('users').doc(_currentUserId).update({
        'current_mood': moodValue,
        'last_mood_update': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) { print("Mod güncelleme hatası: $e"); throw e; }
  }

  Future<void> updatePermissions(PermissionModel permissions) async {
    if (_currentUserId == null) return;
    try {
      await _db.collection('users').doc(_currentUserId).collection('permissions').doc('status').set(permissions.toMap());
    } catch (e) { print("İzin güncelleme hatası: $e"); throw e; }
  }

  // Manuel Batarya Güncelleme (Ayarlar Testi İçin)
  Future<void> updateBatteryStatus(BatteryModel battery) async {
    if (_currentUserId == null) return;
    await _getDeviceStatusRef(_currentUserId!).doc('battery').set(battery.toMap());
  }

  // --- LOGLAMA ---
  Future<void> addLog({
    required String userId, 
    required String title, 
    required String description, 
    required int pointChange, 
    required LogType type
  }) async {
    if (_currentUserId == null) {
      print("⚠️ Log hatası: Kullanıcı giriş yapmamış (_currentUserId null)");
      throw Exception("Kullanıcı giriş yapmamış. Log yazılamıyor.");
    }

    try {
      print("📝 Log yazılıyor: $title - $description (userId: $userId, actor: $_currentUserId)");
      
      await _db.collection('users').doc(userId).collection('activity_logs').add({
        'title': title,
        'description': description,
        'point_change': pointChange,
        'type': type.toString().split('.').last,
        'timestamp': FieldValue.serverTimestamp(),
        'actor_uid': _currentUserId, 
      });
      
      print("✅ Log başarıyla yazıldı!");
    } catch (e) {
      print("❌ Log hatası: $e");
      rethrow;
    }
  }

  Stream<List<LogModel>> streamLogs(String userId) {
    return _db.collection('users').doc(userId).collection('activity_logs').orderBy('timestamp', descending: true).limit(50).snapshots().map((s) => s.docs.map((d) => LogModel.fromMap(d.id, d.data())).toList());
  }
}