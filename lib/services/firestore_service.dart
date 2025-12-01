import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- KRİTİK DÜZELTME BURADA ---
  Future<void> saveNewUser(User user) async {
    try {
      DocumentReference userDocRef = _db.collection('users').doc(user.uid);

      // 1. Önce bu doküman var mı diye kontrol et!
      DocumentSnapshot docSnapshot = await userDocRef.get();

      if (docSnapshot.exists) {
        // 2. EĞER VARSA: Hiçbir şey yapma. 
        // Kullanıcı zaten kayıtlıdır, sadece giriş yapmıştır.
        // Var olan verileri (partner, puan vb.) ezmemeliyiz.
        print("ℹ️ Kullanıcı zaten Firestore'da mevcut. Veri yazma işlemi atlandı.");
        return;
      }

      // 3. EĞER YOKSA: Yeni kullanıcı verilerini oluştur ve kaydet.
      print("🆕 Yeni kullanıcı Firestore'a kaydediliyor...");
      
      UserModel newUser = UserModel(
        uid: user.uid,
        email: user.email ?? "",
        createdAt: DateTime.now().toUtc(),
        trustScore: 1000, // Varsayılan başlangıç puanı
        partnerUid: null, // Başlangıçta partner yok
      );

      // İlk oluşturma sırasında varsayılan izinleri de ekleyelim
      await userDocRef.set(newUser.toMap());
      
      // İzinler alt koleksiyonunu varsayılan (kapalı) olarak oluştur
      await userDocRef.collection('permissions').doc('status').set({
        'isBatteryPermitted': false,
        'isNetworkPermitted': false,
        'isMediaPermitted': false,
        'isNotificationsPermitted': false,
        'lastUpdated': DateTime.now().toUtc().toIso8601String(),
      });

    } catch (e) {
      print("❌ Firestore yeni kullanıcı kaydetme hatası: $e");
      throw e;
    }
  }

  // ... (Diğer metotlar: getUserData, pairUsersWithCode vb. aynı kalacak) ...
   Future<UserModel?> getUserData(String uid) async { try { DocumentSnapshot doc = await _db.collection('users').doc(uid).get(); if (doc.exists) { return UserModel.fromMap(doc.data() as Map<String, dynamic>); } return null; } catch (e) { print("Veri çekme hatası: $e"); return null; } }
   Future<String?> pairUsersWithCode(String currentUserId, String codeInput) async { try { QuerySnapshot query = await _db.collection('users').where('pairing_code', isEqualTo: codeInput).limit(1).get(); if (query.docs.isEmpty) { return "Girdiğiniz koda ait kullanıcı bulunamadı."; } DocumentSnapshot partnerDoc = query.docs.first; String partnerId = partnerDoc.id; if (partnerId == currentUserId) { return "Kendinizle eşleşemezsiniz."; } Map<String, dynamic>? partnerData = partnerDoc.data() as Map<String, dynamic>?; if (partnerData != null && partnerData['partner_uid'] != null) { return "Bu kullanıcı zaten başka biriyle eşleşmiş."; } WriteBatch batch = _db.batch(); DocumentReference currentUserRef = _db.collection('users').doc(currentUserId); DocumentReference partnerUserRef = _db.collection('users').doc(partnerId); batch.update(currentUserRef, {'partner_uid': partnerId, 'pairing_code': FieldValue.delete()}); batch.update(partnerUserRef, {'partner_uid': currentUserId, 'pairing_code': FieldValue.delete()}); await batch.commit(); return null; } catch (e) { return "Eşleşme hatası: $e"; } }
   Future<String?> generatePairingCode(String uid) async { try { String code = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString(); await _db.collection('users').doc(uid).update({'pairing_code': code}); return code; } catch (e) { return null; } }
   Future<void> deductTrustPoints(String uid, int amount) async { try { await _db.collection('users').doc(uid).update({'trust_score': FieldValue.increment(-amount)}); } catch (e) { print("Puan düşme hatası: $e"); } }
   Future<void> addTrustPoints(String uid, int amount) async { try { await _db.collection('users').doc(uid).update({'trust_score': FieldValue.increment(amount)}); } catch (e) { print("Puan ekleme hatası: $e"); } }

}