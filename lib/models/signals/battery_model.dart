class BatteryModel {
  final int level;
  final bool isCharging;
  final DateTime timestamp;

  BatteryModel({
    required this.level,
    required this.isCharging,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'level': level,
      'isCharging': isCharging,
      // ÖNEMLİ: Kaydederken UTC'ye çeviriyoruz
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  factory BatteryModel.fromMap(Map<String, dynamic> map) {
    return BatteryModel(
      level: map['level'] ?? 0,
      isCharging: map['isCharging'] ?? false,
      // DateTime.parse() ISO8601 (UTC 'Z' harfli) stringleri otomatik tanır
      // ve yerel saate çevirerek DateTime objesi oluşturur. Bu doğru davranıştır.
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}