import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../services/auth_service.dart';
import 'main_screen.dart';
import 'register_screen.dart';

// Renk Paleti
const Color kBgDark = Color(0xFF121212);
const Color kAccentCyan = Color(0xFF00E5FF);
const Color kTextGrey = Color(0xFFB0BEC5);
const Color kCardBg = Color(0xFF1E1E1E);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  // --- E-POSTA GİRİŞ İŞLEMİ ---
  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      User? user = await _authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (user != null && mounted) {
        _navigateToMain();
      }
    } on FirebaseAuthException catch (e) {
      _showErrorDialog(_mapFirebaseErrorToMessage(e.code));
    } catch (e) {
      _showErrorDialog("Login error: $e"); // İngilizce
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- GOOGLE GİRİŞ İŞLEMİ ---
  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      User? user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        _navigateToMain();
      }
    } catch (e) {
      _showErrorDialog("Google login error: $e"); // İngilizce
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToMain() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  // Hata Mesajları (İngilizce)
  String _mapFirebaseErrorToMessage(String code) {
    switch (code) {
      case 'user-not-found': return "No user found for this email.";
      case 'wrong-password': return "Wrong password. Please try again.";
      case 'invalid-email': return "Invalid email format.";
      case 'user-disabled': return "This account has been disabled.";
      default: return "Login failed. ($code)";
    }
  }

  void _showErrorDialog(String message) {
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: kCardBg, title: Text("Login Error", style: GoogleFonts.montserrat(color: Colors.white)), content: Text(message, style: GoogleFonts.montserrat(color: kTextGrey)), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text("OK", style: GoogleFonts.montserrat(color: kAccentCyan)))]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
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
                  // Logo ve Başlık
                  Icon(Icons.lock_outline_rounded, size: 80, color: kAccentCyan),
                  const SizedBox(height: 24),
                  // İngilizce Başlıklar
                  Text("Welcome Back!", style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text("Sign in to connect with your partner.", style: GoogleFonts.montserrat(fontSize: 16, color: kTextGrey), textAlign: TextAlign.center),
                  const SizedBox(height: 48),

                  // E-posta ve Şifre Alanları (İngilizce Label ve Hatalar)
                  _buildTextField(controller: _emailController, label: "Email", icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (val) => (val == null || !val.contains('@')) ? 'Please enter a valid email.' : null),
                  const SizedBox(height: 20),
                  _buildTextField(controller: _passwordController, label: "Password", icon: Icons.lock_outline, obscureText: _obscurePassword, toggleObscure: () => setState(() => _obscurePassword = !_obscurePassword), validator: (val) => (val == null || val.isEmpty) ? 'Please enter your password.' : null),
                  const SizedBox(height: 24),

                  // GİRİŞ YAP BUTONU (İngilizce)
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleEmailLogin,
                      style: ElevatedButton.styleFrom(backgroundColor: kAccentCyan, foregroundColor: kBgDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                      child: _isLoading ? const CircularProgressIndicator(color: kBgDark) : Text("LOG IN", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // VEYA AYIRAÇ (İngilizce)
                  Row(children: [Expanded(child: Divider(color: kTextGrey.withOpacity(0.3))), Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text("OR", style: GoogleFonts.montserrat(color: kTextGrey, fontWeight: FontWeight.w500))), Expanded(child: Divider(color: kTextGrey.withOpacity(0.3)))]),
                  const SizedBox(height: 24),

                  // GOOGLE GİRİŞ BUTONU (İngilizce)
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleLogin,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: kTextGrey.withOpacity(0.5)), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    icon: const FaIcon(FontAwesomeIcons.google, size: 20),
                    label: Text("Continue with Google", style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 48),

                  // KAYIT OL YÖNLENDİRMESİ (İngilizce)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 16),
                        children: [
                          const TextSpan(text: "Don't have an account? "),
                          TextSpan(text: "Sign Up", style: TextStyle(color: kAccentCyan, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
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