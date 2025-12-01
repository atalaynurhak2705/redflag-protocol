import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/signals_service.dart';
import '../models/signals/battery_model.dart';
import '../models/permission_model.dart';

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

  // Simülasyon için yerel durum değişkenleri (Varsayılan false)
  bool _simMediaPermission = false;
  bool _simNotifPermission = false;
  bool _simBatteryPermission = false;
  bool _simNetworkPermission = false;

  // YENİ: Veriler yükleniyor mu?
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Ekran açılır açılmaz mevcut izinleri yükle
    _loadCurrentPermissions();
  }

  // --- YENİ: MEVCUT İZİNLERİ YÜKLE ---
  Future<void> _loadCurrentPermissions() async {
    // Yükleme başlıyor
    if (mounted) setState(() => _isLoading = true);
    
    try {
      // Servisten kendi izinlerimizi çekiyoruz
      final permissions = await _signalsService.getMyPermissions();
      
      if (permissions != null && mounted) {
        setState(() {
          // Veritabanından gelen değerleri yerel değişkenlere ata
          _simMediaPermission = permissions.isMediaPermitted;
          _simNotifPermission = permissions.isNotificationsPermitted;
          _simBatteryPermission = permissions.isBatteryPermitted;
          _simNetworkPermission = permissions.isNetworkPermitted;
        });
        print("✅ Ayarlar: Mevcut izinler yüklendi.");
      } else {
         print("⚠️ Ayarlar: İzin verisi bulunamadı, varsayılanlar kullanılacak.");
      }
    } catch (e) {
      print("❌ İzin yükleme hatası: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("İzinler yüklenemedi: $e"), backgroundColor: kAccentRed));
      }
    } finally {
      // Yükleme bitti
      if (mounted) setState(() => _isLoading = false);
    }
  }


  // --- İZİN DURUMUNU GÜNCELLE (Yazma) ---
  Future<void> _updateSimulatedPermissions() async {
    if (user == null) return;
    // setState(() => _isLoading = true); // Güncellerken ekranı kilitlemeye gerek yok, daha akıcı olur.
    try {
      final permissions = PermissionModel(
        isMediaPermitted: _simMediaPermission,
        isNotificationsPermitted: _simNotifPermission,
        isBatteryPermitted: _simBatteryPermission,
        isNetworkPermitted: _simNetworkPermission,
        timestamp: DateTime.now().toUtc(),
      );
      
      await _signalsService.updatePermissions(permissions);
      print("✅ Ayarlar: İzinler güncellendi.");

    } catch (e) {
      print("❌ Ayarlar: Güncelleme hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("❌ Güncelleme hatası: $e"),
        backgroundColor: kAccentRed,
      ));
      // Hata olursa, switch'i eski haline döndürmek için tekrar yükle
      _loadCurrentPermissions(); 
    } 
  }

  // --- TEST METODU 1: VERİ YAZMA (Aynı) ---
  Future<void> _writeTestBatteryData() async {
    if (user == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Önce giriş yapmalısınız."))); return; }
    try {
      final testBattery = BatteryModel(level: 85, isCharging: true, timestamp: DateTime.now().toUtc());
      await _signalsService.updateBatteryStatus(testBattery);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Test verisi (Batarya %85) yazıldı!"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Hata: $e"), backgroundColor: kAccentRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("AYARLAR (TEST MODU)", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      // YENİ: Eğer yükleniyorsa dönen çark göster
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: kAccentCyan))
        : ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            Text("Sinyal Servisi Test Paneli", textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: kAccentCyan, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text("Aşağıdaki butonlarla veri yazma ve okuma işlemlerini test edebilirsiniz.", textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 14)),
            const SizedBox(height: 40),
            ElevatedButton.icon(onPressed: _writeTestBatteryData, style: ElevatedButton.styleFrom(backgroundColor: kAccentCyan, foregroundColor: kBgDark, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.battery_charging_full_rounded), label: Text("TEST VERİSİ YAZ (Batarya %85)", style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800))),
            const SizedBox(height: 24),
            Text("Not: Veriler UTC (Evrensel Saat) olarak kaydedilir.", textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 12, fontStyle: FontStyle.italic)),
            
            const SizedBox(height: 40),
            Divider(color: kTextGrey.withOpacity(0.3)),
            const SizedBox(height: 20),
            
            Text("İzin Simülasyonu (Rıza Yönetimi)", textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Partnerin hangi verilerini paylaşmaya rıza gösterdiğini simüle et.", textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 12)),
            const SizedBox(height: 20),

            // --- İZİN ANAHTARLARI ---
            _buildPermissionSwitch("Batarya Durumu Paylaşımı", Icons.battery_std_rounded, _simBatteryPermission, (val) { setState(() => _simBatteryPermission = val); _updateSimulatedPermissions(); }),
            const SizedBox(height: 12),
            _buildPermissionSwitch("Ağ Bağlantısı Paylaşımı", Icons.wifi_rounded, _simNetworkPermission, (val) { setState(() => _simNetworkPermission = val); _updateSimulatedPermissions(); }),
            const SizedBox(height: 12),
            _buildPermissionSwitch("Medya Aktivitesi Paylaşımı", Icons.headset_rounded, _simMediaPermission, (val) { setState(() => _simMediaPermission = val); _updateSimulatedPermissions(); }),
            const SizedBox(height: 12),
            _buildPermissionSwitch("Bildirim Sayısı Paylaşımı", Icons.notifications_rounded, _simNotifPermission, (val) { setState(() => _simNotifPermission = val); _updateSimulatedPermissions(); }),
            
            const SizedBox(height: 40),
          ],
        ),
    );
  }

  // Yardımcı Switch Widget'ı
  Widget _buildPermissionSwitch(String title, IconData icon, bool value, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kAccentCyan.withOpacity(value ? 0.5 : 0.1))),
      child: SwitchListTile(title: Text(title, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)), secondary: Icon(icon, color: value ? kAccentCyan : kTextGrey), value: value, onChanged: onChanged, activeColor: kAccentCyan, inactiveTrackColor: kBgDark, dense: true),
    );
  }
}