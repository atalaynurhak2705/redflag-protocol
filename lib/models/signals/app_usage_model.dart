

import 'package:cloud_firestore/cloud_firestore.dart';

class AppUsageInfo {
  final String packageName; // Uygulamanın paket adı
  final String appName; // Uygulamanın görünen adı
  final int usageMinutes; // Kullanım süresi (dakika)

  AppUsageInfo({
    required this.packageName,
    required this.appName,
    required this.usageMinutes,
  });

  factory AppUsageInfo.fromMap(Map<String, dynamic> data) {
    return AppUsageInfo(
      packageName: data['package_name'] ?? '',
      appName: data['app_name'] ?? '',
      usageMinutes: data['usage_minutes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'package_name': packageName,
      'app_name': appName,
      'usage_minutes': usageMinutes,
    };
  }
}

// Ana model, uygulama listesini tutar
class AppUsageModel {
  final List<AppUsageInfo> apps;
  final DateTime date; // Hangi güne ait olduğu
  final DateTime timestamp;

  AppUsageModel({
    required this.apps,
    required this.date,
    required this.timestamp,
  });

  factory AppUsageModel.fromMap(Map<String, dynamic> data) {
    return AppUsageModel(
      apps: (data['apps'] as List<dynamic>?)
              ?.map((e) => AppUsageInfo.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'apps': apps.map((e) => e.toMap()).toList(),
      'date': Timestamp.fromDate(date),
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}