import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'dashboard_active_screen.dart';

// --- RENK PALETİ ---
const Color kBgDark = Color(0xFF050505);
const Color kCardBg = Color(0xFF141414);
const Color kAccentCyan = Color(0xFF05D9E8);
const Color kTextGrey = Color(0xFF757575);

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _idController = TextEditingController();
  bool _isLoading = false;

  Future<void> _linkPartner() async {
    final String partnerId = _idController.text.trim();
    if (partnerId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Partner ID'sini veritabanına kaydet
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'partner_uid': partnerId
        });

        if (!mounted) return;

        // 2. Dashboard'a git (PARAMETRESİZ - DÜZELTİLEN KISIM)
        // Artık Dashboard veriyi kendi çektiği için parametre göndermiyoruz.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DashboardActiveScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.bold), color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("LINK PARTNER", style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.link(PhosphorIconsStyle.regular), size: 80, color: kAccentCyan),
            const SizedBox(height: 30),
            Text(
              "ENTER PARTNER ID",
              style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "Paste the User ID shared by your partner to establish a secure connection.",
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 14),
            ),
            const SizedBox(height: 40),
            
            // Input Alanı
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _idController,
                style: GoogleFonts.montserrat(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Partner User ID",
                  hintStyle: TextStyle(color: kTextGrey.withOpacity(0.5)),
                  border: InputBorder.none,
                  icon: Icon(PhosphorIcons.user(PhosphorIconsStyle.regular), color: kTextGrey),
                ),
              ),
            ),
            
            const SizedBox(height: 30),

            // Bağlan Butonu
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _linkPartner,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentCyan,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.black) 
                  : Text("ESTABLISH CONNECTION", style: GoogleFonts.rajdhani(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}