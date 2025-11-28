import 'package:cloud_firestore/cloud_firestore.dart';

class NetworkModel {
  final String type; // "wifi", "mobile", "none"
  final String? ssid; // Wi-Fi adı (opsiyonel, izin gerekebilir)
  final DateTime timestamp;

  NetworkModel({
    required this.type,
    this.ssid,
    required this.timestamp,
  });

  factory NetworkModel.fromMap(Map<String, dynamic> data) {
    return NetworkModel(
      type: data['type'] ?? 'unknown',
      ssid: data['ssid'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'ssid': ssid,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}