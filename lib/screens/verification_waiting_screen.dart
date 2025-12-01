import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import 'main_screen.dart';

// Renk Paleti
const Color kBgDark = Color(0xFF121212);
const Color kAccentCyan = Color(0xFF00E5FF);
const Color kTextGrey = Color(0xFFB0BEC5);
const Color kCardBg = Color(0xFF1E1E1E);

class VerificationWaitingScreen extends StatefulWidget {
  const VerificationWaitingScreen({super.key});

  @override
  State<VerificationWaitingScreen> createState() => _VerificationWaitingScreenState();
}

class _VerificationWaitingScreenState extends State<VerificationWaitingScreen> {
  final AuthService _authService = AuthService();
  final User? user = FirebaseAuth.instance.currentUser;
  
  Timer? _checkTimer;
  Timer? _resendTimer;
  
  bool _isVerified = false;
  bool _canResendEmail = false;
  int _resendCountdown = 60; // 60 saniye bekleme süresi

  @override
  void initState() {
    super.initState();
    
    // 1. Otomatik Kontrolü Başlat: Her 3 saniyede bir onayladı mı diye bak.
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkVerificationStatus());
    
    // 2. Tekrar Gönder Sayacını Başlat
    _startResendTimer();
  }

  @override
  void dispose() {
    // Ekrandan çıkarken timer'ları durdurmak çok önemlidir.
    _checkTimer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  // Düzenli olarak çalışan onay kontrol fonksiyonu
  Future<void> _checkVerificationStatus() async {
    // Servise sor: Doğrulandı mı?
    bool isVerified = await _authService.isEmailVerified();
    
    if (isVerified) {
      // ONAYLANMIŞ!
      _checkTimer?.cancel(); // Artık kontrole gerek yok
      if (mounted) {
        setState(() => _isVerified = true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ E-posta doğrulandı! Yönlendiriliyorsunuz...", style: GoogleFonts.montserrat()),
            backgroundColor: Colors.green,
          ),
        );
        
        // Kısa bir süre sonra ana ekrana yönlendir
        Future.delayed(const Duration(seconds: 2), () {
           Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        });
      }
    }
  }

  // "Tekrar Gönder" butonu için geri sayım
  void _startResendTimer() {
    setState(() {
      _canResendEmail = false;
      _resendCountdown = 60;
    });
    
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
          } else {
            _canResendEmail = true;
            timer.cancel();
          }
        });
      }
    });
  }

  // E-postayı tekrar gönderme işlemi
  Future<void> _handleResendEmail() async {
    try {
      await _authService.sendVerificationEmail();
      _startResendTimer(); // Sayacı tekrar başlat
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Doğrulama e-postası tekrar gönderildi.", style: GoogleFonts.montserrat()), backgroundColor: kAccentCyan));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e", style: GoogleFonts.montserrat()), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("E-posta Doğrulama", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false, // Geri butonunu gizle
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: kCardBg,
                shape: BoxShape.circle,
                border: Border.all(color: kAccentCyan.withOpacity(0.3), width: 2),
              ),
              child: Icon(_isVerified ? Icons.mark_email_read_rounded : Icons.mark_email_unread_rounded, size: 80, color: kAccentCyan),
            ),
            const SizedBox(height: 30),
            Text(
              _isVerified ? "Doğrulama Başarılı!" : "Lütfen E-postanızı Kontrol Edin",
              style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 14),
                children: [
                  TextSpan(text: user?.email, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  const TextSpan(text: " adresine bir doğrulama bağlantısı gönderdik.\nHesabınızı aktif hale getirmek için lütfen o bağlantıya tıklayın."),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            // Otomatik kontrol ediliyor bilgisi
            if (!_isVerified)
             Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kAccentCyan.withOpacity(0.5))),
                 const SizedBox(width: 12),
                 Text("Onay bekleniyor...", style: GoogleFonts.montserrat(color: kTextGrey, fontStyle: FontStyle.italic)),
               ],
             ),
             const SizedBox(height: 40),

            // Tekrar Gönder Butonu
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_canResendEmail && !_isVerified) ? _handleResendEmail : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCardBg,
                  foregroundColor: kAccentCyan,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: kAccentCyan.withOpacity(_canResendEmail ? 0.5 : 0.1))),
                  disabledBackgroundColor: kCardBg.withOpacity(0.5),
                  disabledForegroundColor: kTextGrey,
                ),
                icon: const Icon(Icons.send_rounded),
                label: Text(_canResendEmail ? "E-postayı Tekrar Gönder" : "Tekrar gönder (${_resendCountdown}s)", style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
              ),
            ),
            
            const SizedBox(height: 24),
            // Çıkış Yap / Farklı Hesap Butonu
            TextButton(
              onPressed: () {
                 _authService.signOut();
                 Navigator.pop(context); // Login ekranına dön
              },
               child: Text("Farklı bir hesapla giriş yap", style: GoogleFonts.montserrat(color: kTextGrey)),
            )
          ],
        ),
      ),
    );
  }
}