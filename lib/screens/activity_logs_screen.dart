import 'package:flutter/material.dart';

class ActivityLogsScreen extends StatelessWidget {
  const ActivityLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("KRİTİK LOGLAR", style: TextStyle(color: Colors.white, fontFamily: 'Courier')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: Text(
          "Log Geçmişi (Yapım Aşamasında)",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ),
    );
  }
}