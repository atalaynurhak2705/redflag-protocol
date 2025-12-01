class NetworkModel {
  final String type; // 'wifi', 'mobile', 'none'
  final DateTime timestamp;

  NetworkModel({
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      // ÖNEMLİ: UTC'ye çevir
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  factory NetworkModel.fromMap(Map<String, dynamic> map) {
    return NetworkModel(
      type: map['type'] ?? 'none',
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}