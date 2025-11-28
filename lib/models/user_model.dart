import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  String? partnerUid;
  int trustScore; // Bu puan, sinyallere göre dinamik olarak hesaplanacak
  DateTime? createdAt;
  DateTime? pairedAt;

  UserModel({
    required this.uid,
    required this.email,
    this.partnerUid,
    this.trustScore = 1000,
    this.createdAt,
    this.pairedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      partnerUid: data['partner_uid'],
      trustScore: data['trust_score'] ?? 1000,
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      pairedAt: (data['paired_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    // ... (Aynı kalacak, sadece kayıt sırasında kullanılır)
    return {
      'email': email,
      'partner_uid': partnerUid,
      'trust_score': trustScore,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'paired_at': pairedAt != null ? Timestamp.fromDate(pairedAt!) : null,
    };
  }
}