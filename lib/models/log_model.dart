import 'package:cloud_firestore/cloud_firestore.dart';

// Log Türleri
enum LogType {
  info,       // Genel bilgi (Mavi)
  warning,    // Uyarı (Turuncu)
  danger,     // Kritik/Kırmızı Bayrak (Kırmızı)
  success     // Başarım/Puan Kazanma (Yeşil)
}

class LogModel {
  final String id;
  final String title;       // Başlık (Örn: "Batarya Güncellendi")
  final String description; // Detay (Örn: "Partnerin şarj durumu sorgulandı.")
  final int pointChange;    // Puan etkisi (Örn: -10)
  final LogType type;       // Türü
  final DateTime timestamp; // Zamanı

  LogModel({
    required this.id,
    required this.title,
    required this.description,
    required this.pointChange,
    required this.type,
    required this.timestamp,
  });

  // Firestore'dan okuma
  factory LogModel.fromMap(String id, Map<String, dynamic> map) {
    return LogModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      pointChange: map['point_change'] ?? 0,
      type: _stringToType(map['type']),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Firestore'a yazma
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'point_change': pointChange,
      'type': type.toString().split('.').last,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  // Enum dönüşüm yardımcıları
  static LogType _stringToType(String? type) {
    switch (type) {
      case 'danger': return LogType.danger;
      case 'warning': return LogType.warning;
      case 'success': return LogType.success;
      default: return LogType.info;
    }
  }
}