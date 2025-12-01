class MediaModel {
  final bool isPlaying;
  final String? title;
  final String? artist;
  final String? packageName; // Hangi uygulama (örn: com.spotify.music)
  final DateTime timestamp;

  MediaModel({
    required this.isPlaying,
    this.title,
    this.artist,
    this.packageName,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'isPlaying': isPlaying,
      'title': title,
      'artist': artist,
      'packageName': packageName,
      // ÖNEMLİ: UTC'ye çevir
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  factory MediaModel.fromMap(Map<String, dynamic> map) {
    return MediaModel(
      isPlaying: map['isPlaying'] ?? false,
      title: map['title'],
      artist: map['artist'],
      packageName: map['packageName'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}