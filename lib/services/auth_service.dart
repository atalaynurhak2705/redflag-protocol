import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Mevcut kullanıcıyı getir
  User? get currentUser => _auth.currentUser;

  // --- GOOGLE İLE GİRİŞ (ESKİ, ÇALIŞAN YÖNTEM) ---
  Future<User?> signInWithGoogle() async {
    try {
      // Temizlik denemesi
      try { await _googleSignIn.disconnect(); } catch (_) {}
      try { await _googleSignIn.signOut(); } catch (_) {}

      // ESKİ YÖNTEM: signIn() kullanılıyor
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        debugPrint("Google girişi iptal edildi.");
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      debugPrint("Google ile giriş başarılı: ${userCredential.user?.email}");
      return userCredential.user;

    } catch (e) {
      debugPrint("Auth Service Hatası: $e");
      try { await _googleSignIn.signOut(); } catch (_) {}
      rethrow;
    }
  }
  
  // Çıkış Yapma Metodu
  Future<void> signOut() async {
    try { await _googleSignIn.disconnect(); } catch (_) { await _googleSignIn.signOut(); }
    await _auth.signOut();
  }

  // --- E-POSTA METOTLARI (Bunlar aynı kalıyor, sorun yok) ---
  Future<User?> registerWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      if (user != null && !user.emailVerified) { await sendVerificationEmail(); }
      return user;
    } catch (e) { debugPrint("E-posta kayıt hatası: $e"); rethrow; }
  }

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } catch (e) { debugPrint("E-posta giriş hatası: $e"); rethrow; }
  }

  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
      debugPrint("✅ Doğrulama e-postası gönderildi: ${user.email}");
    }
  }

  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      final refreshedUser = _auth.currentUser;
      return refreshedUser?.emailVerified ?? false;
    }
    return false;
  }
}