import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/signals/battery_model.dart';
import '../models/signals/network_model.dart';
import '../models/signals/media_model.dart';
import '../models/signals/screen_time_model.dart';
// Bildirim modeli için import (Henüz oluşturmadıysak hata verebilir,
// oluşturduysan aktif et, yoksa şimdilik map kullanacağız)
// import '../models/signals/notification_model.dart'; 

class SignalsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  CollectionReference _getDeviceStatusRef(String userId) {
    return _db.collection('users').doc(userId).collection('device_status');
  }

  // ===========================================================================
  // --- A) VERİ YAZMA METOTLARI (Cihazdan Buluta) ---
  // ===========================================================================
  Future<void> updateBatteryStatus(BatteryModel battery) async {
    if (_currentUserId == null) return;
    await _getDeviceStatusRef(_currentUserId!).doc('battery').set(battery.toMap());
  }

  Future<void> updateNetworkStatus(NetworkModel network) async {
    if (_currentUserId == null) return;
    await _getDeviceStatusRef(_currentUserId!).doc('network').set(network.toMap());
  }

  // ... Diğer yazma metotları (Medya, Ekran Süresi vb.) buraya gelecek ...

  // ===========================================================================
  // --- B) VERİ OKUMA METOTLARI (Buluttan Cihaza - Dashboard İçin) ---
  // ===========================================================================

  // 1. BATARYA (Get)
  Future<BatteryModel?> getBatteryStatus(String partnerId) async {
    try {
      DocumentSnapshot doc = await _getDeviceStatusRef(partnerId).doc('battery').get();
      if (doc.exists && doc.data() != null) {
        return BatteryModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) { print("Batarya hata: $e"); }
    return null;
  }

  // 2. AĞ (Get)
  Future<NetworkModel?> getNetworkStatus(String partnerId) async {
    try {
      DocumentSnapshot doc = await _getDeviceStatusRef(partnerId).doc('network').get();
      if (doc.exists && doc.data() != null) {
        return NetworkModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) { print("Ağ hata: $e"); }
    return null;
  }

  // --- YENİ EKLENENLER (Şimdilik boş dönecekler ama yapı hazır) ---

  // 3. MEDYA (Get)
  Future<MediaModel?> getMediaStatus(String partnerId) async {
    try {
      DocumentSnapshot doc = await _getDeviceStatusRef(partnerId).doc('media').get();
      if (doc.exists && doc.data() != null) {
        return MediaModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) { print("Medya hata: $e"); }
    return null;
  }

  // 4. EKRAN SÜRESİ (Get - Dünün Özeti)
  Future<ScreenTimeModel?> getYesterdayScreenTime(String partnerId) async {
    try {
      // Dünün tarihini bul (Örn: 2023-10-26)
      String yesterdayDocId = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T')[0];
      
      DocumentSnapshot doc = await _db
          .collection('users')
          .doc(partnerId)
          .collection('screen_time_history')
          .doc(yesterdayDocId)
          .get();
          
      if (doc.exists && doc.data() != null) {
        return ScreenTimeModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) { print("Ekran süresi hata: $e"); }
    return null;
  }

  // 5. BİLDİRİMLER (Get - Günlük Özet Sayısı)
  Future<int> getTodayNotificationCount(String partnerId) async {
    try {
      // Bugünün başlangıcı ve bitişi
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      // Bugün gelen bildirimleri say
      QuerySnapshot query = await _db
          .collection('users')
          .doc(partnerId)
          .collection('notifications')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
          .get();
          
      return query.docs.length;
    } catch (e) { print("Bildirim sayma hata: $e"); }
    return 0; // Hata varsa veya bildirim yoksa 0 dön
  }
}