import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import 'dashboard_active_screen.dart';

// --- RENK PALETİ ---
const Color kBgDark = Color(0xFF050505);
const Color kCardBg = Color(0xFF141414);
const Color kAccentCyan = Color(0xFF05D9E8);
const Color kTextGrey = Color(0xFF757575);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // 1. Kayıt Ol
      User? user = await _authService.signUpWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (user != null) {
        // 2. Kullanıcı verisini Firestore'a yaz (Sadece trust_score)
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'uid': user.uid,
          // <--- DÜZELTİLDİ: 'points' kaldırıldı.
          'trust_score': 1000, 
          'created_at': FieldValue.serverTimestamp(),
          'last_active': FieldValue.serverTimestamp(),
          'partner_uid': null, 
        });

        if (mounted) {
          // 3. Dashboard'a git (PARAMETRESİZ)
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const DashboardActiveScreen()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _showErrorDialog(e.message ?? "Registration failed.");
    } catch (e) {
      _showErrorDialog("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: kCardBg, title: Text("Error", style: GoogleFonts.montserrat(color: Colors.white)), content: Text(message, style: GoogleFonts.montserrat(color: kTextGrey)), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text("OK", style: GoogleFonts.montserrat(color: kAccentCyan)))]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
                  Text("Create Account", style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text("Join the protocol.", style: GoogleFonts.montserrat(fontSize: 16, color: kTextGrey), textAlign: TextAlign.center),
                  const SizedBox(height: 48),

                  _buildTextField(controller: _emailController, label: "Email", icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (val) => (val == null || !val.contains('@')) ? 'Invalid email' : null),
                  const SizedBox(height: 20),
                  _buildTextField(controller: _passwordController, label: "Password", icon: Icons.lock_outline, obscureText: _obscurePassword, toggleObscure: () => setState(() => _obscurePassword = !_obscurePassword), validator: (val) => (val == null || val.length < 6) ? 'Min 6 characters' : null),
                  const SizedBox(height: 20),
                  _buildTextField(controller: _confirmPasswordController, label: "Confirm Password", icon: Icons.lock_outline, obscureText: true, validator: (val) => (val != _passwordController.text) ? 'Passwords do not match' : null),
                  
                  const SizedBox(height: 32),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(backgroundColor: kAccentCyan, foregroundColor: kBgDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: _isLoading ? const CircularProgressIndicator(color: kBgDark) : Text("SIGN UP", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold)),
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

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool obscureText = false, TextInputType? keyboardType, String? Function(String?)? validator, VoidCallback? toggleObscure}) {
    return TextFormField(controller: controller, obscureText: obscureText, keyboardType: keyboardType, style: GoogleFonts.montserrat(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: GoogleFonts.montserrat(color: kTextGrey), prefixIcon: Icon(icon, color: kTextGrey), suffixIcon: toggleObscure != null ? IconButton(icon: Icon(obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: kTextGrey), onPressed: toggleObscure) : null, filled: true, fillColor: kCardBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kAccentCyan)), errorStyle: GoogleFonts.montserrat(color: Colors.redAccent)), validator: validator);
  }
}