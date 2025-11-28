import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'pairing_screen.dart';
import 'dashboard_active_screen.dart';

// --- SABİT RENK PALETİ ---
const Color kBgDark = Color(0xFF121212);
const Color kAccentCyan = Color(0xFF00E5FF);
const Color kTextGrey = Color(0xFF4A5568);
// -----------------------

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Animasyon Kontrolcüleri
  late AnimationController _entranceController; // Sayfa giriş animasyonu
  late AnimationController _chainController; // Zincir ikonunun hareketi
  late AnimationController _shimmerController; // Buton parlama efekti

  @override
  void initState() {
    super.initState();
    // Giriş Animasyonu (Aşağıdan yukarı belirme)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    // Zincir Hareketi (Sürekli tekrar eden)
    _chainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Buton Parlaması (Sürekli tekrar eden)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _chainController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _signOut() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const LoginScreen();

    return Scaffold(
      backgroundColor: kBgDark,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('users').doc(user!.uid).snapshots(),
        builder: (context, snapshot) {
          // Hata ve Yüklenme Durumları
          if (snapshot.hasError) return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: kAccentCyan));
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text('Veri yok.', style: TextStyle(color: Colors.white)));

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          // --- DEĞİŞİKLİK BURADA: partner_uid'yi alıyoruz ---
          final String? partnerId = data?['partner_uid'];
          final int score = data?['trust_score'] ?? 1000;

          // Partner Kontrolü
          if (partnerId == null || partnerId.isEmpty) {
            // Partner YOKSA -> Boş Ekran
            return _buildEmptyStateExact();
          } else {
            // Partner VARSA -> Aktif Ekran
            // --- DEĞİŞİKLİK BURADA: partnerUid parametresi eklendi ---
            return DashboardActiveScreen(
              trustPoints: score,
              partnerName: "Partner", // Şimdilik sabit isim
              partnerUid: partnerId, // Firestore'dan gelen gerçek ID
              onDeductPoints: (amount) { print("TEST: $amount puan düşüldü."); },
            );
          }
        },
      ),
    );
  }

  // --- BOŞ DURUM EKRANI (Empty State) ---
  Widget _buildEmptyStateExact() {
    return SafeArea(
      child: Column(
        children: [
          // 1. Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      "DASHBOARD",
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: kTextGrey, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text("OFFLINE", style: TextStyle(color: kTextGrey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _signOut,
                  icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
                ),
              ],
            ),
          ),

          // 2. Ana İçerik (Giriş Animasyonlu)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Giriş animasyonu (Opacity ve Slide)
                  FadeTransition(
                    opacity: _entranceController,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
                        CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
                      ),
                      child: Column(
                        children: [
                          // Hareketli Kırık Zincir İkonu
                          CustomPaint(
                            size: const Size(100, 100),
                            painter: BrokenChainAnimPainter(color: kAccentCyan, animation: _chainController),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "NO CONNECTION YET",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Pair with a partner to begin monitoring.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: kTextGrey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Add Partner Button (Giriş animasyonlu ve parlayan)
                  FadeTransition(
                    opacity: _entranceController,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
                        CurvedAnimation(parent: _entranceController, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)),
                      ),
                      child: _buildShimmerButton(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Parlayan Buton
  Widget _buildShimmerButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const PairingScreen()));
      },
      child: Stack(
        children: [
          // Buton Zemini
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: kAccentCyan,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: kAccentCyan.withOpacity(0.6), blurRadius: 30, spreadRadius: 0),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_add_alt_1, color: Colors.black),
                const SizedBox(width: 12),
                const Text(
                  "ADD PARTNER",
                  style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
              ],
            ),
          ),
          // Parlama Efekti
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, child) {
                  return FractionallySizedBox(
                    widthFactor: 0.5,
                    alignment: AlignmentGeometry.lerp(
                      Alignment.centerLeft,
                      Alignment.centerRight,
                      _shimmerController.value,
                    )!,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0.0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- ÇİZİM SINIFI (Hareketli Kırık Zincir) ---
class BrokenChainAnimPainter extends CustomPainter {
  final Color color;
  final Animation<double> animation;

  BrokenChainAnimPainter({required this.color, required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Sol Halka (Sola sağa hareket eder)
    final leftMove = math.sin(animation.value * math.pi * 2) * 3;
    canvas.save();
    canvas.translate(leftMove, 0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(8, 30, 30, 40), const Radius.circular(15)),
      paint,
    );
    canvas.restore();

    // Sağ Halka (Ters yöne hareket eder)
    final rightMove = -math.sin(animation.value * math.pi * 2) * 3;
    canvas.save();
    canvas.translate(rightMove, 0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(62, 30, 30, 40), const Radius.circular(15)),
      paint,
    );
    canvas.restore();

    // Ortadaki Kesik Çizgiler (Yanıp söner)
    final dashPaint = Paint()
      ..color = color.withOpacity(0.2 + (0.4 * (0.5 + 0.5 * math.sin(animation.value * math.pi * 4))))
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    _drawDashedLine(canvas, const Offset(40, 50), const Offset(45, 50), dashPaint);
    _drawDashedLine(canvas, const Offset(55, 50), const Offset(60, 50), dashPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double dashWidth = 2;
    const double dashSpace = 3;
    double distance = (end - start).distance;
    double currentDistance = 0;
    while (currentDistance < distance) {
      canvas.drawLine(
        start + (end - start) * (currentDistance / distance),
        start + (end - start) * ((currentDistance + dashWidth) / distance),
        paint,
      );
      currentDistance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant BrokenChainAnimPainter oldDelegate) => true;
}