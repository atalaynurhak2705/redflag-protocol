import 'package:cloud_firestore/cloud_firestore.dart';

class ScreenTimeModel {
  final int totalMinutes; // Günlük toplam ekran süresi (dakika cinsinden)
  final DateTime date; // Hangi güne ait olduğu (Örn: 2023-10-27)
  final DateTime timestamp; // Verinin son güncellenme zamanı

  ScreenTimeModel({
    required this.totalMinutes,
    required this.date,
    required this.timestamp,
  });

  factory ScreenTimeModel.fromMap(Map<String, dynamic> data) {
    return ScreenTimeModel(
      totalMinutes: data['total_minutes'] ?? 0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total_minutes': totalMinutes,
      'date': Timestamp.fromDate(date), // Sadece tarih kısmı önemli
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}