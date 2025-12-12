import 'package:cloud_firestore/cloud_firestore.dart';

enum LogType { info, warning, success, danger }

class LogModel {
  final String id;
  final String title;
  final String description;
  final int pointChange;
  final LogType type;
  final DateTime timestamp;
  final String actorUid;

  LogModel({
    required this.id,
    required this.title,
    required this.description,
    required this.pointChange,
    required this.type,
    required this.timestamp,
    required this.actorUid,
  });

  factory LogModel.fromMap(String id, Map<String, dynamic> map) {
    // Log tipini string'den enum'a çevir
    LogType parseType(String? typeStr) {
      switch (typeStr) {
        case 'warning': return LogType.warning;
        case 'success': return LogType.success;
        case 'danger': return LogType.danger;
        default: return LogType.info;
      }
    }

    return LogModel(
      id: id,
      title: map['title'] ?? 'Unknown Activity',
      description: map['description'] ?? '',
      pointChange: map['point_change'] ?? 0,
      type: parseType(map['type']),
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
      actorUid: map['actor_uid'] ?? '',
    );
  }
}