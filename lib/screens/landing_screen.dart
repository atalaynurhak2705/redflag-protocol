import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'login_screen.dart';
import 'register_screen.dart';

// --- SABİT RENK PALETİ (Global Standart - V5.0) ---
const Color kBgDark = Color(0xFF050505);
const Color kCardBg = Color(0xFF141414);
const Color kAccentRed = Color(0xFFFF2A6D);
const Color kAccentCyan = Color(0xFF05D9E8);
const Color kTextGrey = Color(0xFF757575);

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Giriş Animasyonları
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      body: Stack(
        children: [
          // 1. ARKA PLAN EFEKTLERİ (Silik Neon Glow - DÜZELTİLDİ)
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kAccentRed.withOpacity(0.05), // Çok hafif zemin rengi
                boxShadow: [
                  BoxShadow(
                    color: kAccentRed.withOpacity(0.2), // Parlama rengi
                    blurRadius: 100, // Bulanıklık yarıçapı burada olmalı
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          
          // 2. İÇERİK
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end, 
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(), 

                  // LOGO VE BAŞLIK
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Zincir ikonu
                          Icon(
                            PhosphorIcons.linkBreak(PhosphorIconsStyle.bold), 
                            size: 64,
                            color: kAccentRed,
                          ),
                          const SizedBox(height: 24),
                          
                          // Ana Başlık
                          Text(
                            "RED FLAG",
                            style: GoogleFonts.rajdhani(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              height: 0.9,
                              shadows: [
                                Shadow(
                                  color: kAccentRed.withOpacity(0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                          ),
                          
                          // Alt Başlık
                          Text(
                            "PROTOCOL v5.0",
                            style: GoogleFonts.rajdhani(
                              color: kAccentCyan,
                              fontSize: 18,
                              letterSpacing: 4.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Çizgi
                          Container(
                            width: 60,
                            height: 4,
                            color: kAccentRed,
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Açıklama Metni
                          Text(
                            "Securely monitor device status, trust scores, and digital presence. Keep the connection alive.",
                            style: GoogleFonts.montserrat(
                              color: kTextGrey,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const Spacer(), 

                  // BUTONLAR
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        // REGISTER BUTONU
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RegisterScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccentRed,
                              foregroundColor: Colors.white,
                              elevation: 10,
                              shadowColor: kAccentRed.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "INITIATE PROTOCOL",
                                  style: GoogleFonts.rajdhani(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),

                        // LOGIN BUTONU
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              "ACCESS TERMINAL",
                              style: GoogleFonts.rajdhani(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
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
}