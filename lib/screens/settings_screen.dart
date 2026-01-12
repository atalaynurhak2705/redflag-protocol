import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../services/auth_service.dart';
import '../services/signals_service.dart';
import '../services/background_service.dart'; // <--- İŞTE EKSİK OLAN BU SATIRDI
import '../models/permission_model.dart';
import 'landing_screen.dart'; // Çıkışta Landing Page'e gitmek için

// --- V5.0 RENK PALETİ ---
const Color kBgDark = Color(0xFF050505);
const Color kCardBg = Color(0xFF141414);
const Color kAccentCyan = Color(0xFF05D9E8);
const Color kAccentRed = Color(0xFFFF2A6D);
const Color kTextGrey = Color(0xFF757575);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final SignalsService _signalsService = SignalsService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  bool _isLoading = true;
  
  // İzin Durumları
  bool _shareBattery = true;
  bool _shareNetwork = true;
  bool _shareMedia = true;
  bool _shareNotifs = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    if (_currentUser == null) return;
    try {
      final perms = await _signalsService.getPartnerPermissions(_currentUser!.uid);
      if (perms != null) {
        setState(() {
          _shareBattery = perms.isBatteryPermitted;
          _shareNetwork = perms.isNetworkPermitted;
          _shareMedia = perms.isMediaPermitted;
          _shareNotifs = perms.isNotificationsPermitted;
        });
      }
    } catch (e) {
      print("Ayarlar yüklenirken hata: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePermissions() async {
    if (_currentUser == null) return;
    
    final newPerms = PermissionModel(
      isBatteryPermitted: _shareBattery,
      isNetworkPermitted: _shareNetwork,
      isMediaPermitted: _shareMedia,
      isNotificationsPermitted: _shareNotifs,
    );
    
    _signalsService.updatePermissions(newPerms).catchError((e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Kaydedilemedi: $e"), backgroundColor: kAccentRed)
         );
       }
    });
  }

  // --- GÜVENLİ ÇIKIŞ FONKSİYONU ---
  void _signOut() async {
    // 1. Önce Arka Plan Servisini Durdur
    // (Artık import edildiği için hata vermeyecek)
    BackgroundService().stopService();
    
    // 2. Sayfadan Ayrıl (Landing Page'e git)
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LandingScreen()),
      (route) => false,
    );
    
    // 3. EN SON Auth'u Kapat
    // Böylece "Permission Denied" hatası almazsın çünkü sayfa kapanmış olur.
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgDark,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "SETTINGS",
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kAccentCyan))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildSectionHeader("PRIVACY & SHARING"),
                const SizedBox(height: 16),
                _buildSwitchTile("Share Battery Status", PhosphorIcons.batteryCharging(PhosphorIconsStyle.regular), _shareBattery, (val) { setState(() => _shareBattery = val); _savePermissions(); }),
                _buildSwitchTile("Share Network Info", PhosphorIcons.wifiHigh(PhosphorIconsStyle.regular), _shareNetwork, (val) { setState(() => _shareNetwork = val); _savePermissions(); }),
                _buildSwitchTile("Share Media Activity", PhosphorIcons.headphones(PhosphorIconsStyle.regular), _shareMedia, (val) { setState(() => _shareMedia = val); _savePermissions(); }),
                _buildSwitchTile("Share Notifications", PhosphorIcons.bell(PhosphorIconsStyle.regular), _shareNotifs, (val) { setState(() => _shareNotifs = val); _savePermissions(); }),

                const SizedBox(height: 40),
                _buildSectionHeader("ACCOUNT"),
                const SizedBox(height: 16),
                
                // User ID Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05))
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        child: Icon(PhosphorIcons.user(PhosphorIconsStyle.regular), color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("USER ID", style: GoogleFonts.rajdhani(color: kTextGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                            SelectableText(_currentUser?.uid ?? "Unknown", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Icon(PhosphorIcons.copy(PhosphorIconsStyle.regular), color: kTextGrey, size: 18),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Sign Out Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _signOut,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentRed.withOpacity(0.1),
                      foregroundColor: kAccentRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: kAccentRed, width: 1),
                      ),
                    ),
                    icon: Icon(PhosphorIcons.signOut(PhosphorIconsStyle.bold)),
                    label: Text(
                      "DISCONNECT SYSTEM",
                      style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    "RedFlag Protocol v5.0",
                    style: GoogleFonts.rajdhani(color: kTextGrey.withOpacity(0.5), fontSize: 10, letterSpacing: 2),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.rajdhani(
        color: kAccentCyan,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildSwitchTile(String title, IconData icon, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: kTextGrey, size: 22),
              const SizedBox(width: 16),
              Text(title, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: kCardBg, 
            activeTrackColor: kAccentCyan, 
            inactiveThumbColor: kTextGrey,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
          ),
        ],
      ),
    );
  }
}