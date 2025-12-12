import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart'; // İkon paketi

import '../services/signals_service.dart';
import '../models/log_model.dart';

// --- DASHBOARD İLE AYNI RENK PALETİ ---
const Color kBgDark = Color(0xFF050505);
const Color kCardBg = Color(0xFF141414);
const Color kAccentCyan = Color(0xFF05D9E8);
const Color kAccentRed = Color(0xFFFF2A6D);
const Color kAccentPurple = Color(0xFFD230FF);
const Color kAccentOrange = Color(0xFFFF9E00);
const Color kTextGrey = Color(0xFF757575);

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({Key? key}) : super(key: key);

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final SignalsService _signalsService = SignalsService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) return const Scaffold(body: Center(child: Text("Error: No User")));

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgDark,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "SECURITY LOGS",
          style: GoogleFonts.rajdhani(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
        leading: IconButton(
          icon: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.bold), color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.white.withOpacity(0.1), height: 1.0),
        ),
      ),
      body: StreamBuilder<List<LogModel>>(
        stream: _signalsService.streamLogs(_currentUserId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kAccentCyan));
          }
          
          if (snapshot.hasError) {
            return Center(child: Text("Veri hatası: ${snapshot.error}", style: const TextStyle(color: kAccentRed)));
          }

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.light), size: 64, color: kTextGrey.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text("No Activity Recorded", style: GoogleFonts.montserrat(color: kTextGrey, letterSpacing: 1.5)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              return _buildLogTile(logs[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildLogTile(LogModel log) {
    Color statusColor;
    IconData statusIcon;

    switch (log.type) {
      case LogType.success:
        statusColor = const Color(0xFF00C853);
        statusIcon = PhosphorIcons.checkCircle(PhosphorIconsStyle.regular);
        break;
      case LogType.warning:
        statusColor = kAccentOrange;
        statusIcon = PhosphorIcons.warning(PhosphorIconsStyle.regular);
        break;
      case LogType.danger:
        statusColor = kAccentRed;
        statusIcon = PhosphorIcons.warningOctagon(PhosphorIconsStyle.regular);
        break;
      default:
        statusColor = kAccentCyan;
        statusIcon = PhosphorIcons.info(PhosphorIconsStyle.regular);
    }

    if (log.title.toUpperCase().contains("MEDIA")) {
      statusIcon = PhosphorIcons.headphones(PhosphorIconsStyle.regular);
    } else if (log.title.toUpperCase().contains("BATTERY")) {
      statusIcon = PhosphorIcons.batteryCharging(PhosphorIconsStyle.regular);
    } else if (log.title.toUpperCase().contains("SIGNAL") || log.title.toUpperCase().contains("PING")) {
      statusIcon = PhosphorIcons.broadcast(PhosphorIconsStyle.regular);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        log.title.toUpperCase(),
                        style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(DateFormat('HH:mm').format(log.timestamp), style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(log.description, style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}