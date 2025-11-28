import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveNewUser(User user) async {
    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'trust_score': 1000,
      'partner_uid': null,
      'signals_enabled': false,
    }, SetOptions(merge: true));
  }
}