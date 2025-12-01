class PermissionModel {
  // Hangi izinlerin verildiğini tutan boolean bayraklar
  final bool isMediaPermitted;
  final bool isNotificationsPermitted;
  // YENİ EKLENENLER:
  final bool isBatteryPermitted;
  final bool isNetworkPermitted;
  
  // Ne zaman güncellendiği (UTC)
  final DateTime timestamp;

  PermissionModel({
    this.isMediaPermitted = false,
    this.isNotificationsPermitted = false,
    // Varsayılan olarak hepsi kapalı başlar
    this.isBatteryPermitted = false, 
    this.isNetworkPermitted = false,
    required this.timestamp,
  });

  // Firestore'a yazmak için Map'e çevir
  Map<String, dynamic> toMap() {
    return {
      'isMediaPermitted': isMediaPermitted,
      'isNotificationsPermitted': isNotificationsPermitted,
      // YENİ ALANLAR:
      'isBatteryPermitted': isBatteryPermitted,
      'isNetworkPermitted': isNetworkPermitted,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  // Firestore'dan okumak için Map'ten nesneye çevir
  factory PermissionModel.fromMap(Map<String, dynamic> map) {
    return PermissionModel(
      isMediaPermitted: map['isMediaPermitted'] ?? false,
      isNotificationsPermitted: map['isNotificationsPermitted'] ?? false,
      // YENİ ALANLAR:
      isBatteryPermitted: map['isBatteryPermitted'] ?? false,
      isNetworkPermitted: map['isNetworkPermitted'] ?? false,
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}