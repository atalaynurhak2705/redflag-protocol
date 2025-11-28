import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/signals_service.dart';
import '../models/signals/battery_model.dart';

// --- SABİT RENK PALETİ ---
const Color kBgDark = Color(0xFF121212);
const Color kAccentCyan = Color(0xFF00E5FF);
const Color kAccentRed = Color(0xFFFF2000);
const Color kTextGrey = Color(0xFFB0BEC5);
const Color kCardBg = Color(0xFF1E1E1E);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SignalsService _signalsService = SignalsService();
  final User? user = FirebaseAuth.instance.currentUser;

  // StreamSubscription ARTIK YOK, çünkü canlı dinlemiyoruz.

  // --- TEST METODU 1: VERİ YAZMA (Aynı kalıyor) ---
  Future<void> _writeTestBatteryData() async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Önce giriş yapmalısınız.")));
      return;
    }

    try {
      // Sahte bir batarya verisi oluştur
      final testBattery = BatteryModel(
        level: 85, // %85 şarj
        isCharging: true, // Şarj oluyor
        timestamp: DateTime.now(),
      );

      // Servisi kullanarak Firestore'a yaz
      await _signalsService.updateBatteryStatus(testBattery);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("✅ Test verisi (Batarya %85) başarıyla yazıldı!"),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("❌ Hata: $e"),
        backgroundColor: kAccentRed,
      ));
    }
  }

  // --- TEST METODU 2: TEK SEFERLİK VERİ OKUMA (YENİLANDİ) ---
  // Artık stream dinlemiyor, bir kere çekip konsola yazıyor.
  Future<void> _readTestBatteryDataOnce() async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Önce giriş yapmalısınız.")));
      return;
    }

    print("--- BATARYA VERİSİ ÇEKİLİYOR (TEK SEFERLİK) ---");
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("📡 Veri çekiliyor... Konsolu kontrol edin."),
      backgroundColor: kAccentCyan,
    ));

    try {
      // YENİ METOT KULLANILIYOR: getBatteryStatus
      final batteryData = await _signalsService.getBatteryStatus(user!.uid);

      if (batteryData != null) {
        print("🔥 GÜNCEL VERİ ALINDI:");
        print("   - Seviye: %${batteryData.level}");
        print("   - Şarj Durumu: ${batteryData.isCharging ? 'Şarj Oluyor ⚡' : 'Şarj Olmuyor'}");
        print("   - Zaman: ${batteryData.timestamp}");
      } else {
        print("⚠️ Veri yok veya okunamadı.");
      }
    } catch (e) {
      print("❌ Okuma hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "AYARLAR (TEST MODU)",
          style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Sinyal Servisi Test Paneli",
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(color: kAccentCyan, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              "Aşağıdaki butonlarla veri yazma ve okuma işlemlerini test edebilirsiniz.",
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 14),
            ),
            const SizedBox(height: 40),

            // --- TEST BUTONU 1 ---
            ElevatedButton.icon(
              onPressed: _writeTestBatteryData,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentCyan,
                foregroundColor: kBgDark,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.battery_charging_full_rounded),
              label: Text(
                "TEST VERİSİ YAZ (Batarya %85)",
                style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 24),

            // --- TEST BUTONU 2 (GÜNCELLENDİ) ---
            ElevatedButton.icon(
              // Yeni metoda bağlandı
              onPressed: _readTestBatteryDataOnce,
              style: ElevatedButton.styleFrom(
                backgroundColor: kCardBg,
                foregroundColor: kAccentCyan,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: kAccentCyan, width: 2),
                ),
              ),
              icon: const Icon(Icons.radar_rounded),
              label: Text(
                "SON VERİYİ OKU (Konsola Yaz)", // Metin değişti
                style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
             const SizedBox(height: 24),
             Text(
              "Not: Artık canlı akış yok. 'Son Veriyi Oku' butonuna her bastığınızda o anki güncel veri veritabanından çekilir.",
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}