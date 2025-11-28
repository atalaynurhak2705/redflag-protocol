import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Firestore kontrolü için bu import gerekli
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/theme_constants.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  // Firestore instance'ı eklendi
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.accentOrange : AppColors.successGreen,
      ),
    );
  }

  // --- DÜZELTİLMİŞ: Email Giriş Fonksiyonu ---
  Future<void> _handleLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        _showSnackbar('Lütfen tüm alanları doldurun.', isError: true);
        return;
      }

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;

      if (user != null) {
        // 🔥 KRİTİK DÜZELTME: Önce kullanıcının verisi var mı kontrol et
        // Eğer doküman zaten varsa, saveNewUser'ı ÇAĞIRMA.
        DocumentSnapshot userDoc = await _db.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          // Sadece doküman hiç yoksa oluştur (İlk kayıt durumu)
          await _firestoreService.saveNewUser(user);
        }
        // Doküman varsa dokunmuyoruz, böylece partner_uid korunuyor.

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = "Giriş başarısız.";
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = "Hatalı e-posta veya şifre.";
      }
      _showSnackbar(msg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- DÜZELTİLMİŞ: Google Giriş Fonksiyonu ---
  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final User? user = await _authService.signInWithGoogle();

      if (user != null) {
        // 🔥 KRİTİK DÜZELTME: Google için de aynısını yapıyoruz.
        // Önce kullanıcının verisi var mı kontrol et.
        DocumentSnapshot userDoc = await _db.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          // Sadece doküman hiç yoksa oluştur
          await _firestoreService.saveNewUser(user);
        }
        // Doküman varsa dokunmuyoruz.

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Google girişi başarısız.', isError: true);
      debugPrint("Google Sign In Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // ----------------------------------

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Başlık
                Text(
                  "Login here",
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Welcome back you've been missed!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 50),

                // Input Alanları (Flutter Icons ile)
                _buildModernInput(
                  controller: _emailController,
                  hint: "Email",
                  icon: Icons.email_outlined, // Flutter ikonu
                ),
                const SizedBox(height: 20),
                _buildModernInput(
                  controller: _passwordController,
                  hint: "Password",
                  icon: Icons.lock_outline, // Flutter ikonu
                  isPassword: true,
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      _showSnackbar("Şifre sıfırlama yakında!", isError: false);
                    },
                    child: Text(
                      "Forgot your password?",
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Ana Giriş Butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: AppStyles.primaryButtonStyle,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text("Sign in"),
                  ),
                ),
                const SizedBox(height: 40),

                Text(
                  "Or continue with",
                  style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 20),

                // Sosyal Medya Butonları (Google için yerleşik ikonu kullandık)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Google Butonu (Aktif)
                    _buildSocialButton(
                      icon: Icons.g_mobiledata, // Google'ın yerleşik ikonu
                      onTap: _isLoading ? null : _handleGoogleSignIn,
                    ),
                    const SizedBox(width: 20),
                    // Apple (Pasif)
                    _buildSocialButton(icon: Icons.apple, onTap: null),
                    const SizedBox(width: 20),
                    // Facebook (Pasif)
                    _buildSocialButton(icon: Icons.facebook, onTap: null),
                  ],
                ),
                 const SizedBox(height: 40),

                 Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Not a member? ", style: TextStyle(color: AppColors.textGrey)),
                    GestureDetector(
                      onTap: () => _showSnackbar("Kayıt ekranı yakında!", isError: false),
                      child: Text("Register now", style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                    )
                  ],
                 )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- YARDIMCI WIDGET'LAR (SVG GEREKTİRMEYEN) ---

  // Modern Input Alanı (Flutter'ın Kendi İkonlarıyla)
  Widget _buildModernInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon, // IconData alacak
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: TextStyle(color: AppColors.textWhite),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surfaceDark,
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textGrey),
        prefixIcon: Icon(icon, color: AppColors.textGrey, size: 24), // Doğrudan Icon kullanıyoruz
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: OutlineInputBorder(
          borderRadius: AppStyles.defaultRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppStyles.defaultRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppStyles.defaultRadius,
          borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
      ),
    );
  }

  // Sosyal Medya Butonu (Flutter'ın Kendi İkonlarıyla)
  Widget _buildSocialButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: AppStyles.defaultRadius,
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Icon(icon, color: AppColors.textWhite, size: 28), // Doğrudan Icon kullanıyoruz
      ),
    );
  }
}