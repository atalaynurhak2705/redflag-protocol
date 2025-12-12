import 'package:cloud_firestore/cloud_firestore.dart';

class PermissionModel {
  // 'final' kelimeleri kaldırıldı, artık değiştirilebilirler.
  bool isBatteryPermitted;
  bool isNetworkPermitted;
  bool isMediaPermitted;
  bool isNotificationsPermitted;
  DateTime? timestamp;

  PermissionModel({
    this.isBatteryPermitted = false,
    this.isNetworkPermitted = false,
    this.isMediaPermitted = false,
    this.isNotificationsPermitted = false,
    this.timestamp,
  });

  // Firestore'dan gelen veriyi modele çevir
  factory PermissionModel.fromMap(Map<String, dynamic> map) {
    return PermissionModel(
      isBatteryPermitted: map['isBatteryPermitted'] ?? false,
      isNetworkPermitted: map['isNetworkPermitted'] ?? false,
      isMediaPermitted: map['isMediaPermitted'] ?? false,
      isNotificationsPermitted: map['isNotificationsPermitted'] ?? false,
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  // Modeli Firestore'a yazılacak formata çevir
  Map<String, dynamic> toMap() {
    return {
      'isBatteryPermitted': isBatteryPermitted,
      'isNetworkPermitted': isNetworkPermitted,
      'isMediaPermitted': isMediaPermitted,
      'isNotificationsPermitted': isNotificationsPermitted,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
    };
  }
}