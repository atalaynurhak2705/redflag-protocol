import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Senin ID'n (Master Data)
  static const String _googleClientId =
      "70654214962-arbptpbtitvaab9hlivgfkhndpqd0m4q.apps.googleusercontent.com";
      
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _googleInitFuture;

  // Senin yazdığın Initialize fonksiyonu (Master Logic)
  Future<void> _ensureGoogleSignInInitialized() {
    return _googleInitFuture ??= _googleSignIn.initialize(
     // clientId: _googleClientId,
     // serverClientId: _googleClientId,
    );
  }

  Future<User?> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInInitialized();

      // --- DÜZELTME BURADA: GÜVENLİ TEMİZLİK ---
      // Eski oturumu kapatmayı dener. Eğer zaten kapalıysa hata verir, 
      // biz o hatayı 'catch' ile yutup yola devam ederiz.
      try {
        await _googleSignIn.disconnect();
      } catch (_) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }
      // -----------------------------------------

      // Senin çalışan metodun (Master Logic)
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Firebase'e gir
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
      
    } catch (e) {
      debugPrint("Auth Service Hatası: $e");
      // Hata durumunda da temizlik yapmak iyidir
      try { await _googleSignIn.signOut(); } catch (_) {}
      rethrow;
    }
  }
  
  Future<void> signOut() async {
    try {
      await _ensureGoogleSignInInitialized();
      await _googleSignIn.disconnect();
    } catch (_) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }
}