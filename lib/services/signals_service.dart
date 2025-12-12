import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/signals/battery_model.dart';
import '../models/signals/network_model.dart';
import '../models/signals/media_model.dart';
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

  static const int MANUAL_SIGNAL_REWARD = 15;
  static const int RATE_LIMIT_MINUTES = 30;

  String? get _currentUserId => _auth.currentUser?.uid;

  CollectionReference _getDeviceStatusRef(String userId) {
    return _db.collection('users').doc(userId).collection('device_status');
  }

  // --- 1. MANUEL SİNYAL GÖNDERME ---
  Future<void> sendManualSignal() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Oturum açmış kullanıcı bulunamadı.");
    
    final userRef = _db.collection('users').doc(user.uid);
    final int batteryLevel = await _battery.batteryLevel;
    final BatteryState batteryState = await _battery.batteryState;
    final bool isCharging = batteryState == BatteryState.charging || batteryState == BatteryState.full;
    
    final ConnectivityResult connectivityResult = await _connectivity.checkConnectivity();
    String networkStatus = 'Unknown';
    if (connectivityResult == ConnectivityResult.wifi) networkStatus = 'WiFi';
    else if (connectivityResult == ConnectivityResult.mobile) networkStatus = 'Mobile';
    else if (connectivityResult == ConnectivityResult.none) networkStatus = 'Offline';

    await _db.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) throw Exception("Kullanıcı profili bulunamadı.");
      
      final data = userSnapshot.data() as Map<String, dynamic>;

      if (data.containsKey('last_manual_signal') && data['last_manual_signal'] != null) {
        Timestamp lastSignal = data['last_manual_signal'];
        final difference = DateTime.now().difference(lastSignal.toDate()).inMinutes;
        if (difference < RATE_LIMIT_MINUTES) {
          throw Exception("Sinyal göndermek için ${RATE_LIMIT_MINUTES - difference} dakika beklemelisiniz.");
        }
      }

      transaction.update(userRef, {
        'last_active': FieldValue.serverTimestamp(),
        'last_manual_signal': FieldValue.serverTimestamp(),
        // <--- DÜZELTİLDİ: 'points' yerine 'trust_score' güncelleniyor
        'trust_score': (data['trust_score'] ?? 1000) + MANUAL_SIGNAL_REWARD,
      });

      final batteryRef = _getDeviceStatusRef(user.uid).doc('battery');
      transaction.set(batteryRef, {
        'level': batteryLevel, 
        'isCharging': isCharging, 
        'timestamp': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));

      final networkRef = _getDeviceStatusRef(user.uid).doc('network');
      transaction.set(networkRef, {
        'status': networkStatus, 
        'timestamp': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));
      
      final logRef = _db.collection('users').doc(user.uid).collection('activity_logs').doc();
      transaction.set(logRef, {
        'title': 'MANUEL SİNYAL',
        'description': 'Partnerine anlık veri gönderildi. +$MANUAL_SIGNAL_REWARD TP',
        'point_change': MANUAL_SIGNAL_REWARD,
        'type': 'success',
        'timestamp': FieldValue.serverTimestamp(),
        'actor_uid': user.uid,
      });
    });
  }

  // --- VERİ OKUMA VE DİNLEME ---
  Stream<MediaModel?> streamMediaStatus(String partnerId) {
    return _getDeviceStatusRef(partnerId).doc('media').snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return MediaModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }
  
  Stream<List<LogModel>> streamLogs(String userId) {
    return _db.collection('users').doc(userId).collection('activity_logs')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LogModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<BatteryModel?> getBatteryStatus(String partnerId) async {
    try {
      DocumentSnapshot doc = await _getDeviceStatusRef(partnerId).doc('battery').get();
      if (doc.exists && doc.data() != null) return BatteryModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (_) {}
    return null;
  }

  Future<NetworkModel?> getNetworkStatus(String partnerId) async {
    try {
      DocumentSnapshot doc = await _getDeviceStatusRef(partnerId).doc('network').get();
      if (doc.exists && doc.data() != null) return NetworkModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (_) {}
    return null;
  }

  Future<MediaModel?> getMediaStatus(String partnerId) async {
    try {
      DocumentSnapshot doc = await _getDeviceStatusRef(partnerId).doc('media').get();
      if (doc.exists && doc.data() != null) return MediaModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (_) {}
    return null;
  }

  Future<int> getTodayNotificationCount(String partnerId) async {
    try {
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));
      AggregateQuerySnapshot query = await _db.collection('users').doc(partnerId).collection('notifications')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
          .count().get();
      return query.count;
    } catch (_) {}
    return 0;
  }

  Future<Map<String, dynamic>?> getPartnerMood(String partnerId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(partnerId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['current_mood'] != null) {
          return {'mood': data['current_mood'], 'timestamp': data['last_mood_update'] != null ? DateTime.parse(data['last_mood_update']) : null};
        }
      }
    } catch (_) {}
    return null;
  }

  Future<PermissionModel?> getPartnerPermissions(String partnerId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(partnerId).collection('permissions').doc('status').get();
      if (doc.exists && doc.data() != null) {
        return PermissionModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (_) {}
    
    return PermissionModel(
      timestamp: DateTime.now(),
      isBatteryPermitted: false,
      isNetworkPermitted: false,
      isMediaPermitted: false,
      isNotificationsPermitted: false,
    );
  }

  Future<void> updatePermissions(PermissionModel permissions) async {
    if (_currentUserId == null) return;
    Map<String, dynamic> data = permissions.toMap();
    data['timestamp'] = FieldValue.serverTimestamp();
    await _db.collection('users').doc(_currentUserId).collection('permissions').doc('status').set(data);
  }
  
  Future<PermissionModel?> getMyPermissions() async {
    if (_currentUserId == null) return null;
    return getPartnerPermissions(_currentUserId!);
  }

  Future<void> updateMyMood(String moodValue) async {
    if (_currentUserId == null) return;
    await _db.collection('users').doc(_currentUserId).update({
      'current_mood': moodValue,
      'last_mood_update': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> addLog({
    required String userId, 
    required String title, 
    required String description, 
    int pointChange = 0, 
    LogType type = LogType.info
  }) async {
    if (_currentUserId == null) return;
    try {
      await _db.collection('users').doc(userId).collection('activity_logs').add({
        'title': title,
        'description': description,
        'point_change': pointChange,
        'type': type.toString().split('.').last,
        'timestamp': FieldValue.serverTimestamp(),
        'actor_uid': _currentUserId, 
      });
    } catch (_) {}
  }
}