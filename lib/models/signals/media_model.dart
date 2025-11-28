import 'package:cloud_firestore/cloud_firestore.dart';

class MediaModel {
  final bool isPlaying; // Çalıyor mu?
  final String? title; // Medya başlığı (opsiyonel)
  final String? artist; // Sanatçı (opsiyonel)
  final String? packageName; // Hangi uygulama çalıyor? (örn: com.spotify.music)
  final DateTime timestamp;

  MediaModel({
    required this.isPlaying,
    this.title,
    this.artist,
    this.packageName,
    required this.timestamp,
  });

  factory MediaModel.fromMap(Map<String, dynamic> data) {
    return MediaModel(
      isPlaying: data['is_playing'] ?? false,
      title: data['title'],
      artist: data['artist'],
      packageName: data['package_name'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'is_playing': isPlaying,
      'title': title,
      'artist': artist,
      'package_name': packageName,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}