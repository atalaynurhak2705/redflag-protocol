import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final DateTime createdAt;
  final int trustScore;
  final String? partnerUid;
  final String? pairingCode;

  UserModel({
    required this.uid,
    required this.email,
    required this.createdAt,
    this.trustScore = 1000,
    this.partnerUid,
    this.pairingCode,
  });

  // ==================================================
  // --- İŞTE EKSİK OLAN KRİTİK PARÇA: fromMap ---
  // ==================================================
  // Firestore'dan gelen Map verisini alıp UserModel objesine çevirir.
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      // Firestore Timestamp'ini güvenli bir şekilde Dart DateTime'a çevir
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now().toUtc(),
      // Sayısal değerleri güvenli bir şekilde int'e çevir
      trustScore: data['trust_score']?.toInt() ?? 1000,
      partnerUid: data['partner_uid'],
      pairingCode: data['pairing_code'],
    );
  }

  // ==================================================
  // --- toMap METODU (Veri Yazmak İçin) ---
  // ==================================================
  // UserModel objesini Firestore'a kaydedilebilecek bir Map'e çevirir.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      // DateTime'ı Firestore'un anlayacağı Timestamp formatına çevir
      'createdAt': Timestamp.fromDate(createdAt),
      'trust_score': trustScore,
      'partner_uid': partnerUid,
      'pairing_code': pairingCode,
    };
  }
}