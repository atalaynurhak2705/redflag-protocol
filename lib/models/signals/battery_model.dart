import 'package:cloud_firestore/cloud_firestore.dart';

class BatteryModel {
  final int level; // Şarj yüzdesi (0-100)
  final bool isCharging; // Şarj oluyor mu?
  final DateTime timestamp; // Verinin alındığı zaman

  BatteryModel({
    required this.level,
    required this.isCharging,
    required this.timestamp,
  });

  // Firestore'dan okuma
  factory BatteryModel.fromMap(Map<String, dynamic> data) {
    return BatteryModel(
      level: data['level'] ?? 0,
      isCharging: data['is_charging'] ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Firestore'a yazma
  Map<String, dynamic> toMap() {
    return {
      'level': level,
      'is_charging': isCharging,
      'timestamp': FieldValue.serverTimestamp(), // Sunucu zamanı
    };
  }
}