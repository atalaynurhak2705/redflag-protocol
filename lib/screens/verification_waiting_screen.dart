import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import 'dashboard_active_screen.dart';
import 'login_screen.dart';

// --- RENK PALETİ ---
const Color kBgDark = Color(0xFF050505);
const Color kCardBg = Color(0xFF141414);
const Color kAccentCyan = Color(0xFF05D9E8);
const Color kTextGrey = Color(0xFF757575);

class VerificationWaitingScreen extends StatefulWidget {
  const VerificationWaitingScreen({super.key});

  @override
  State<VerificationWaitingScreen> createState() => _VerificationWaitingScreenState();
}

class _VerificationWaitingScreenState extends State<VerificationWaitingScreen> {
  final AuthService _authService = AuthService();
  Timer? _timer;
  bool _isEmailVerified = false;
  bool _canResendEmail = false;
  int _resendCountdown = 30;

  @override
  void initState() {
    super.initState();
    _isEmailVerified = _authService.isEmailVerified();

    if (!_isEmailVerified) {
      _sendVerificationEmail();
      // Her 3 saniyede bir kontrol et
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkEmailVerified());
      _startResendTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    // Kullanıcı durumunu yenile (Firebase'den güncel veriyi çek)
    await _authService.reloadUser();
    
    setState(() {
      _isEmailVerified = _authService.isEmailVerified();
    });

    if (_isEmailVerified) {
      _timer?.cancel();
      if (mounted) {
        // Doğrulama tamam, Dashboard'a git
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardActiveScreen()),
        );
      }
    }
  }

  Future<void> _sendVerificationEmail() async {
    try {
      await _authService.sendVerificationEmail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification email sent!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  void _startResendTimer() {
    setState(() {
      _canResendEmail = false;
      _resendCountdown = 30;
    });
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        if (mounted) setState(() => _resendCountdown--);
      } else {
        if (mounted) setState(() => _canResendEmail = true);
        timer.cancel();
      }
    });
  }

  void _handleResend() {
    if (_canResendEmail) {
      _sendVerificationEmail();
      _startResendTimer();
    }
  }

  void _signOut() async {
    _timer?.cancel();
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_unread_outlined, size: 80, color: kAccentCyan),
              const SizedBox(height: 30),
              
              Text(
                "VERIFY YOUR EMAIL",
                style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                "We have sent a verification link to your email address. Please verify to access the protocol.",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 14, height: 1.5),
              ),
              
              const SizedBox(height: 40),
              
              // Resend Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _canResendEmail ? _handleResend : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kCardBg,
                    side: BorderSide(color: _canResendEmail ? kAccentCyan : Colors.white10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _canResendEmail ? "RESEND EMAIL" : "WAIT ${_resendCountdown}s",
                    style: GoogleFonts.rajdhani(
                      color: _canResendEmail ? kAccentCyan : kTextGrey,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Logout Button
              TextButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.arrow_back, color: kTextGrey, size: 18),
                label: Text(
                  "Return to Login",
                  style: GoogleFonts.montserrat(color: kTextGrey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}