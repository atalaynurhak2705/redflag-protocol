import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Google ikonu için

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'verification_waiting_screen.dart';
import 'main_screen.dart'; // Google ile girişte direkt ana ekrana gitmek için

// Renkler
const Color kBgDark = Color(0xFF121212);
const Color kAccentCyan = Color(0xFF00E5FF);
const Color kTextGrey = Color(0xFFB0BEC5);
const Color kCardBg = Color(0xFF1E1E1E);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Servisler
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  // Form Kontrolcüleri
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  // --- E-POSTA İLE KAYIT İŞLEMİ ---
  Future<void> _handleEmailRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      User? user = await _authService.registerWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (user != null) {
        await _firestoreService.saveNewUser(user);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const VerificationWaitingScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _showErrorDialog(_mapFirebaseErrorToMessage(e.code));
    } catch (e) {
      _showErrorDialog("Kayıt hatası: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- YENİ: GOOGLE İLE KAYIT/GİRİŞ İŞLEMİ ---
  Future<void> _handleGoogleRegister() async {
    setState(() => _isLoading = true);
    try {
      // Google ile giriş yap (Bu aynı zamanda kayıt yerine de geçer)
      User? user = await _authService.signInWithGoogle();
      
      if (user != null) {
        // İlk kez giriş yapıyorsa veritabanına kaydetmeyi dene
        // (FirestoreService zaten var olan kullanıcıyı ezmeyecek şekilde ayarlı)
        await _firestoreService.saveNewUser(user);

        if (mounted) {
          // Google ile girişte e-posta doğrulamaya gerek yoktur,
          // direkt ana ekrana yönlendiriyoruz.
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      }
    } catch (e) {
      _showErrorDialog("Google kayıt hatası: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Hata Mesajları
  String _mapFirebaseErrorToMessage(String code) {
    switch (code) {
      case 'email-already-in-use': return "Bu e-posta adresi zaten kullanımda.";
      case 'invalid-email': return "Geçersiz bir e-posta adresi girdiniz.";
      case 'weak-password': return "Şifre çok zayıf. En az 6 karakter kullanın.";
      default: return "Kayıt başarısız. ($code)";
    }
  }

  void _showErrorDialog(String message) {
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: kCardBg, title: Text("Kayıt Hatası", style: GoogleFonts.montserrat(color: Colors.white)), content: Text(message, style: GoogleFonts.montserrat(color: kTextGrey)), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Tamam", style: GoogleFonts.montserrat(color: kAccentCyan)))]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Hesap Oluştur", style: GoogleFonts.montserrat(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text("Partnerinle bağlanmak için hemen başla.", style: GoogleFonts.montserrat(fontSize: 16, color: kTextGrey), textAlign: TextAlign.center),
                  const SizedBox(height: 40),

                  // E-posta ve Şifre Alanları
                  _buildTextField(controller: _emailController, label: "E-posta", icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (val) => (val == null || !val.contains('@')) ? 'Geçerli bir e-posta girin.' : null),
                  const SizedBox(height: 20),
                  _buildTextField(controller: _passwordController, label: "Şifre", icon: Icons.lock_outline, obscureText: _obscurePassword, toggleObscure: () => setState(() => _obscurePassword = !_obscurePassword), validator: (val) => (val == null || val.length < 6) ? 'Şifre en az 6 karakter olmalı.' : null),
                  const SizedBox(height: 20),
                  _buildTextField(controller: _confirmPasswordController, label: "Şifre Tekrar", icon: Icons.lock_outline, obscureText: true, validator: (val) => (val != _passwordController.text) ? 'Şifreler eşleşmiyor.' : null),
                  const SizedBox(height: 30),

                  // E-POSTA İLE KAYIT OL BUTONU
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleEmailRegister,
                      style: ElevatedButton.styleFrom(backgroundColor: kAccentCyan, foregroundColor: kBgDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                      child: _isLoading ? const CircularProgressIndicator(color: kBgDark) : Text("KAYIT OL", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- YENİ: VEYA AYIRAÇ ---
                  Row(children: [Expanded(child: Divider(color: kTextGrey.withOpacity(0.3))), Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text("VEYA", style: GoogleFonts.montserrat(color: kTextGrey, fontWeight: FontWeight.w500))), Expanded(child: Divider(color: kTextGrey.withOpacity(0.3)))]),
                  const SizedBox(height: 30),

                  // --- YENİ: GOOGLE İLE KAYIT OL BUTONU ---
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleRegister,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: kTextGrey.withOpacity(0.5)), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    icon: const FaIcon(FontAwesomeIcons.google, size: 20),
                    label: Text("Google ile Devam Et", style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // TextField Yardımcısı (Aynı)
  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool obscureText = false, TextInputType? keyboardType, String? Function(String?)? validator, VoidCallback? toggleObscure}) {
    return TextFormField(controller: controller, obscureText: obscureText, keyboardType: keyboardType, style: GoogleFonts.montserrat(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: GoogleFonts.montserrat(color: kTextGrey), prefixIcon: Icon(icon, color: kTextGrey), suffixIcon: toggleObscure != null ? IconButton(icon: Icon(obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: kTextGrey), onPressed: toggleObscure) : null, filled: true, fillColor: kCardBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kAccentCyan)), errorStyle: GoogleFonts.montserrat(color: Colors.redAccent)), validator: validator);
  }
}