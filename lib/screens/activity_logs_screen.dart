import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/signals_service.dart';
import '../models/log_model.dart';

// --- RENK PALETİ ---
const Color kBgDark = Color(0xFF121212);
const Color kCardBg = Color(0xFF1E1E1E);
const Color kAccentCyan = Color(0xFF00E5FF);
const Color kAccentRed = Color(0xFFFF2000);
const Color kAccentGreen = Colors.greenAccent;
const Color kTextGrey = Color(0xFFB0BEC5);

class ActivityLogsScreen extends StatelessWidget {
  const ActivityLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final SignalsService signalsService = SignalsService();

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "SYSTEM LOGS",
          style: GoogleFonts.courierPrime( // Hacker/Terminal fontu
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.white.withOpacity(0.1), height: 1.0),
        ),
      ),
      body: user == null 
          ? const Center(child: Text("User not found"))
          : StreamBuilder<List<LogModel>>(
              // Servisteki streamLogs metodunu kullanıyoruz
              stream: signalsService.streamLogs(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: kAccentRed)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kAccentCyan));
                }
                
                final logs = snapshot.data ?? [];

                if (logs.isEmpty) {
                  return _buildEmptyLogs();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _buildLogCard(log);
                  },
                );
              },
            ),
    );
  }

  // --- BOŞ DURUM ---
  Widget _buildEmptyLogs() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 80, color: kTextGrey.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            "NO ACTIVITY DETECTED",
            style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 16, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }

  // --- LOG KARTI TASARIMI ---
  Widget _buildLogCard(LogModel log) {
    // Log tipine göre renk ve ikon belirle
    Color itemColor;
    IconData itemIcon;
    String sign = "";

    switch (log.type) {
      case LogType.danger: // Kritik (Kırmızı)
        itemColor = kAccentRed;
        itemIcon = Icons.warning_amber_rounded;
        sign = ""; // Puan zaten eksi gelir
        break;
      case LogType.warning: // Harcama (Turuncu/Sarı)
        itemColor = Colors.orangeAccent;
        itemIcon = Icons.remove_circle_outline;
        sign = "";
        break;
      case LogType.success: // Kazanım (Yeşil)
        itemColor = kAccentGreen;
        itemIcon = Icons.add_circle_outline;
        sign = "+";
        break;
      case LogType.info: // Bilgi (Mavi/Gri)
      default:
        itemColor = kAccentCyan;
        itemIcon = Icons.info_outline;
        sign = "";
    }

    // Tarih formatı (Örn: 14:30)
    final timeStr = DateFormat('HH:mm').format(log.timestamp);
    final dateStr = DateFormat('MMM d').format(log.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: itemColor, width: 4)), // Sol tarafta renkli çizgi
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Zaman
          Column(
            children: [
              Text(timeStr, style: GoogleFonts.courierPrime(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(dateStr, style: GoogleFonts.courierPrime(color: kTextGrey, fontSize: 10)),
            ],
          ),
          const SizedBox(width: 16),
          
          // 2. İçerik
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.title, 
                  style: GoogleFonts.montserrat(color: itemColor, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  log.description, 
                  style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 12),
                ),
              ],
            ),
          ),

          // 3. Puan Değişimi
          if (log.pointChange != 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: itemColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: itemColor.withOpacity(0.3)),
              ),
              child: Text(
                "$sign${log.pointChange} TP",
                style: GoogleFonts.courierPrime(color: itemColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}