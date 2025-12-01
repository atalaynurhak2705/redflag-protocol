import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/signals/battery_model.dart';
import '../models/signals/network_model.dart';
import '../models/signals/media_model.dart';
import '../models/signals/screen_time_model.dart';
import '../models/permission_model.dart';

class SignalsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  CollectionReference _getDeviceStatusRef(String userId) {
    return _db.collection('users').doc(userId).collection('device_status');
  }

  // ===========================================================================
  // --- A) VERİ YAZMA METOTLARI ---
  // ===========================================================================
  
  // Kendi Modunu Güncelle
  Future<void> updateMyMood(String moodValue) async {
    if (_currentUserId == null) return;
    try {
      await _db.collection('users').doc(_currentUserId).update({
        'current_mood': moodValue,
        'last_mood_update': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      print("Mod güncelleme hatası: $e");
      throw e;
    }
  }

  // İzin Durumunu Güncelle (Simülasyon için)
 // lib/services/signals_service.dart içinde

  // İzin Durumunu Güncelle (Simülasyon için)
  Future<void> updatePermissions(PermissionModel permissions) async {
    if (_currentUserId == null) return;
    try {
      // --- AJAN LOG 1: YAZMA İŞLEMİ ---
      print("📝 SİNYAL SERVİSİ: İzinler yazılıyor...");
      print("   - Hedef Kullanıcı ID: $_currentUserId");
      print("   - Yazılacak Veri (Map): ${permissions.toMap()}");
      // ----------------------------------

      await _db
          .collection('users')
          .doc(_currentUserId)
          .collection('permissions')
          .doc('status')
          .set(permissions.toMap());
          
      print("✅ SİNYAL SERVİSİ: İzinler başarıyla yazıldı.");
    } catch (e) {
      print("❌ SİNYAL SERVİSİ: İzin yazma hatası: $e");
      throw e;
    }
  }

  // Diğer sinyal yazma metotları
  Future<void> updateBatteryStatus(BatteryModel battery) async {
    if (_currentUserId == null) return;
    await _getDeviceStatusRef(_currentUserId!).doc('battery').set(battery.toMap());
  }
  Future<void> updateNetworkStatus(NetworkModel network) async {
    if (_currentUserId == null) return;
    await _getDeviceStatusRef(_currentUserId!).doc('network').set(network.toMap());
  }
  Future<void> updateMediaStatus(MediaModel media) async {
    if (_currentUserId == null) return;
    await _getDeviceStatusRef(_currentUserId!).doc('media').set(media.toMap());
  }
  // (ScreenTime yazma metodu MVP'de kullanılmıyor ama durabilir)
  Future<void> updateScreenTime(ScreenTimeModel screenTime) async {
    if (_currentUserId == null) return;
    String docId = screenTime.date.toIso8601String().split('T')[0];
    await _db.collection('users').doc(_currentUserId!).collection('screen_time_history').doc(docId).set(screenTime.toMap());
  }

  // ===========================================================================
  // --- B) VERİ OKUMA METOTLARI (GET) ---
  // ===========================================================================
  
  // Kendi İzin Durumumu Çek (Ayarlar Ekranı İçin)
  Future<PermissionModel?> getMyPermissions() async {
     if (_currentUserId == null) return null;
    try {
      DocumentSnapshot doc = await _db
          .collection('users')
          .doc(_currentUserId)
          .collection('permissions')
          .doc('status')
          .get();

      if (doc.exists && doc.data() != null) {
        return PermissionModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      print("Kendi izin durumumu çekme hatası: $e");
    }
    return PermissionModel(timestamp: DateTime.now().toUtc()); 
  }

  // Partnerin Modunu Çek
  Future<Map<String, dynamic>?> getPartnerMood(String partnerId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(partnerId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['current_mood'] == null) return null;
        return {
          'mood': data['current_mood'],
          'timestamp': data['last_mood_update'] != null 
              ? DateTime.parse(data['last_mood_update']) 
              : null,
        };
      }
    } catch (e) { print("Mod çekme hatası: $e"); }
    return null;
  }

  // Partnerin İzin Durumunu Çek
  // lib/services/signals_service.dart içinde

  // Partnerin İzin Durumunu Çek
  Future<PermissionModel?> getPartnerPermissions(String partnerId) async {
    try {
      // --- AJAN LOG 2: OKUMA İŞLEMİ ---
      print("🔍 SİNYAL SERVİSİ: Partner izinleri okunuyor...");
      print("   - Hedef Partner ID: $partnerId");
      // ----------------------------------

      DocumentSnapshot doc = await _db
          .collection('users')
          .doc(partnerId)
          .collection('permissions')
          .doc('status')
          .get();

      if (doc.exists && doc.data() != null) {
        print("✅ SİNYAL SERVİSİ: Doküman bulundu. Ham veri: ${doc.data()}");
        return PermissionModel.fromMap(doc.data() as Map<String, dynamic>);
      } else {
        print("⚠️ SİNYAL SERVİSİ: Doküman bulunamadı veya boş! (Varsayılan false dönecek)");
      }
    } catch (e) {
      print("❌ SİNYAL SERVİSİ: İzin okuma hatası: $e");
    }
    // Eğer veri yoksa, varsayılan olarak izinler kapalı döner
    return PermissionModel(timestamp: DateTime.now().toUtc()); 
  }

  // --- ARANAN BATARYA METODU BURADA ---
  Future<BatteryModel?> getBatteryStatus(String partnerId) async {
    try {
      DocumentSnapshot doc = await _getDeviceStatusRef(partnerId).doc('battery').get();
      if (doc.exists && doc.data() != null) return BatteryModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) { print("Batarya hata: $e"); }
    return null;
  }
  // ------------------------------------

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
    try {
      String yesterdayDocId = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T')[0];
      DocumentSnapshot doc = await _db.collection('users').doc(partnerId).collection('screen_time_history').doc(yesterdayDocId).get();
      if (doc.exists && doc.data() != null) return ScreenTimeModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) { print("Ekran süresi hata: $e"); }
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
}