import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'settings_screen.dart';
import 'activity_logs_screen.dart';
import '../widgets/cyber_love_fx.dart'; 
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../services/signals_service.dart';
import '../models/signals/battery_model.dart';
import '../models/signals/network_model.dart';
import '../models/signals/media_model.dart';
import '../models/permission_model.dart';
import '../models/log_model.dart';

// --- HARDCORE EKONOMİ ---
const int kDecryptCost = 60; 
const int kSingleRefreshCost = 5; 
const int kNudgeCost = 20;   
const int kPingReward = 25;  
const Duration kUnlockDuration = Duration(minutes: 30); 
const int kMediaUnlockCost = 50; 
const int kMoodUpdateReward = 10;

// --- RENK PALETİ ---
const Color kBgDark = Color(0xFF050505);
const Color kAccentRed = Color(0xFFFF2A6D);
const Color kAccentCyan = Color(0xFF05D9E8);
const Color kAccentPurple = Color(0xFFD230FF);
const Color kAccentOrange = Color(0xFFFF9E00);
const Color kSoulGold = Color(0xFFFFD700); 
const Color kCardBg = Color(0xFF141414);
const Color kTextGrey = Color(0xFF757575);

enum SignalType { battery, network, media, notifications, mood }

class DashboardActiveScreen extends StatefulWidget {
  const DashboardActiveScreen({super.key});

  @override
  State<DashboardActiveScreen> createState() => _DashboardActiveScreenState();
}

class _DashboardActiveScreenState extends State<DashboardActiveScreen> {
  final GlobalKey<CyberLoveFXState> _fxKey = GlobalKey<CyberLoveFXState>();
  final SignalsService _signalsService = SignalsService();
  final AuthService _authService = AuthService();
  
  StreamSubscription? _userSubscription;
  StreamSubscription? _partnerSubscription;

  // Yerel State
  int _myTrustPoints = 1000;
  String _myMood = "✨"; // KENDİ MOODUMUZ
  String _partnerName = "Loading...";
  String? _partnerUid;

  // Sinyaller
  BatteryModel? _batteryStatus;
  NetworkModel? _networkStatus;
  int _todayNotificationCount = 0;
  String? _partnerMood;
  DateTime? _partnerMoodTime;
  PermissionModel? _partnerPermissions;

  int? _partnerScore;
  DateTime? _partnerLastActive;

  bool _isLoadingData = false;
  DateTime? _mediaUnlockExpiry;

  // --- HARDCORE MOD ---
  DateTime? _globalUnlockExpiry; 
  bool get _areSignalsUnlocked => _globalUnlockExpiry != null && DateTime.now().isBefore(_globalUnlockExpiry!);

  @override
  void initState() {
    super.initState();
    _loadUnlockState();
    _fetchMyProfileAndPartner();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _partnerSubscription?.cancel();
    super.dispose();
  }

  // --- 1. PROFİL VE KENDİ MOODUMUZ ---
  Future<void> _fetchMyProfileAndPartner() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      _userSubscription = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data() as Map<String, dynamic>;
          setState(() {
            _myTrustPoints = data['trust_score'] ?? 1000;
            // DÜZELTME 1: Kendi mood'umuzu da çekiyoruz
            _myMood = data['current_mood'] ?? "✨";
            
            String? newPid = data['partner_uid'];
            if (newPid != null && newPid != _partnerUid) {
              _partnerUid = newPid;
              _listenToPartnerData(_partnerUid!);
              _loadSignalData();
              _loadMediaLockState();
            } else if (newPid == null) {
              _partnerName = "NO PARTNER";
            }
          });
        }
      });
    } catch (e) { print("Hata: $e"); }
  }

  // --- 2. TEKİL GÜNCELLEME (ONAY EKLENDİ) ---
  Future<void> _handleSignalRefresh(SignalType type) async {
    if (!_areSignalsUnlocked) {
      _unlockAllSignals();
      return;
    }

    if (_myTrustPoints < kSingleRefreshCost) {
      _showErrorSnackBar("Puan Yetersiz");
      return;
    }

    // DÜZELTME 3: Soru soruyoruz
    bool confirm = await _showConfirmationDialog(kSingleRefreshCost, "VERİYİ YENİLE?");
    if (!confirm) return;

    setState(() => _isLoadingData = true);
    
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _myTrustPoints -= kSingleRefreshCost);

      switch (type) {
        case SignalType.battery:
          final bat = await _signalsService.getBatteryStatus(_partnerUid!);
          setState(() => _batteryStatus = bat);
          break;
        case SignalType.network:
          final net = await _signalsService.getNetworkStatus(_partnerUid!);
          setState(() => _networkStatus = net);
          break;
        case SignalType.notifications:
          final notif = await _signalsService.getTodayNotificationCount(_partnerUid!);
          setState(() => _todayNotificationCount = notif);
          break;
        default: break;
      }
      _showSuccessSnackBar("Veri Yenilendi (-$kSingleRefreshCost TP)");
    } catch (e) {
      _showErrorSnackBar("Hata: $e");
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  // --- UI START ---
  @override
  Widget build(BuildContext context) {
    bool isCritical = _myTrustPoints < 500;
    Color statusColor = (_myTrustPoints < 500) ? kAccentRed : (_myTrustPoints >= 800) ? kSoulGold : kAccentPurple;
    String statusLabel = (_myTrustPoints < 500) ? "CRITICAL" : (_myTrustPoints >= 800) ? "SOUL SYNC" : "STABLE";

    return Scaffold(
      backgroundColor: kBgDark,
      body: Stack(
        children: [
          CyberLoveFX(key: _fxKey, child: Container()), 
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
              children: [
                // HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("CONNECTED TO", style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 10, letterSpacing: 2)),
                      Text(_partnerName, style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ]),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withOpacity(0.5))),
                      child: Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)).animate(onPlay: (c) => c.repeat(reverse: true)).fade(),
                        const SizedBox(width: 6),
                        Text("LIVE", style: GoogleFonts.montserrat(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold))
                      ]),
                    )
                  ],
                ),
                const SizedBox(height: 30),

                // KALP & SKOR
                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill), size: 220, color: statusColor)
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scale(begin: const Offset(1,1), end: const Offset(1.15, 1.15), duration: isCritical ? 300.ms : 1.5.seconds)
                              .shake(hz: isCritical ? 8 : 0), 
                          Text("$_myTrustPoints", style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 60, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)])),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(0.5))), child: Text(statusLabel, style: GoogleFonts.rajdhani(color: statusColor, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2))),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // MOOD KARTI (Partnerin Moodu)
                _buildMoodFullCard(),
                const SizedBox(height: 12),

                // DÜZELTME 1: KENDİ MOODUMUZU GÖSTEREN ALAN
                Center(
                  child: GestureDetector(
                    onTap: _showMoodSelectionSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.1))
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("MY VIBE: $_myMood", style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold), size: 14, color: kAccentCyan),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),

                // AKSİYON BUTONLARI (PING & NUDGE)
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildActionButton("PUSH STATUS", "+$kPingReward", kAccentCyan, () {
                         _signalsService.sendManualSignal();
                         _fxKey.currentState?.triggerLoveBurst();
                         _showSuccessSnackBar("STATUS PUSHED!");
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _buildActionButton("NUDGE", "-$kNudgeCost", kAccentRed, _sendNudge, isOutlined: true),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // KİLİT BAŞLIĞI
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Icon(PhosphorIcons.lockKey(PhosphorIconsStyle.fill), color: _areSignalsUnlocked ? kSoulGold : kTextGrey, size: 16),
                      const SizedBox(width: 8),
                      Text(_areSignalsUnlocked ? "SYSTEM DECRYPTED" : "ENCRYPTED SIGNALS", style: GoogleFonts.rajdhani(color: _areSignalsUnlocked ? kSoulGold : kTextGrey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ]),
                    if (_areSignalsUnlocked && _globalUnlockExpiry != null)
                      Text(_getTimeLeft(_globalUnlockExpiry!), style: GoogleFonts.montserrat(color: kSoulGold, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),

                // GRID ALANI
                if (_partnerUid == null)
                   const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Waiting for partner...", style: TextStyle(color: Colors.white))))
                else if (!_areSignalsUnlocked)
                   _buildLockedOverlay()
                else
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(), 
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      _buildDarkCard(
                        icon: PhosphorIcons.batteryCharging(PhosphorIconsStyle.regular),
                        title: "BATTERY",
                        value: (_batteryStatus == null) ? "--" : "${_batteryStatus!.level}%",
                        color: kAccentRed,
                        isPermitted: _partnerPermissions?.isBatteryPermitted ?? false,
                        onTap: () => _handleSignalRefresh(SignalType.battery), // TIKLAMA EKLENDİ
                      ),
                      _buildDarkCard(
                        icon: PhosphorIcons.wifiHigh(PhosphorIconsStyle.regular),
                        title: "NETWORK",
                        value: (_networkStatus == null) ? "--" : _networkStatus!.type,
                        color: kAccentCyan,
                        isPermitted: _partnerPermissions?.isNetworkPermitted ?? false,
                        onTap: () => _handleSignalRefresh(SignalType.network), // TIKLAMA EKLENDİ
                      ),
                      _buildMediaDarkCard(), 
                      _buildDarkCard(
                        icon: PhosphorIcons.bell(PhosphorIconsStyle.regular),
                        title: "NOTIFICATIONS",
                        value: "$_todayNotificationCount",
                        color: kAccentPurple,
                        isPermitted: _partnerPermissions?.isNotificationsPermitted ?? false,
                        onTap: () => _handleSignalRefresh(SignalType.notifications), // TIKLAMA EKLENDİ
                      ),
                    ],
                  ),

                const SizedBox(height: 30),
                _buildPartnerStatusFooter(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(statusColor),
    );
  }

  // --- LOGIC FUNCTIONS ---
  Future<void> _loadUnlockState() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString('global_signal_unlock');
    if (expiryStr != null) {
      final expiry = DateTime.parse(expiryStr);
      if (expiry.isAfter(DateTime.now())) {
        setState(() => _globalUnlockExpiry = expiry);
      }
    }
  }

  Future<void> _unlockAllSignals() async {
    if (_partnerUid == null) return;
    if (_myTrustPoints < kDecryptCost) {
      _showErrorSnackBar("INSUFFICIENT POINTS (Need $kDecryptCost)");
      return;
    }

    bool confirm = await _showConfirmationDialog(kDecryptCost, "DECRYPT ALL DATA?");
    if (!confirm) return;

    setState(() { _myTrustPoints -= kDecryptCost; });

    final newExpiry = DateTime.now().add(kUnlockDuration);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('global_signal_unlock', newExpiry.toIso8601String());

    setState(() { 
      _globalUnlockExpiry = newExpiry; 
      _isLoadingData = true; 
    });
    
    _showSuccessSnackBar("SYSTEM DECRYPTED. ACCESS GRANTED.");
    _fxKey.currentState?.triggerLoveBurst();
    _loadSignalData(); 
  }

  Future<void> _sendNudge() async {
    if (_partnerUid == null) return;
    if (_myTrustPoints < kNudgeCost) {
      _showErrorSnackBar("Yetersiz Puan!");
      return;
    }
    
    // DÜZELTME 2: Maliyet sorusu
    bool confirm = await _showConfirmationDialog(kNudgeCost, "DÜRTME GÖNDER?");
    if (!confirm) return;

    setState(() => _isLoadingData = true);
    try {
      await _signalsService.sendNudge(_partnerUid!);
      // DÜZELTME 2: 20 Puan düşüyoruz, kesin.
      setState(() => _myTrustPoints -= kNudgeCost); 
      _showSuccessSnackBar("DÜRTME GÖNDERİLDİ.");
    } catch (e) {
      _showErrorSnackBar("Hata: $e");
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  void _listenToPartnerData(String uid) {
    _partnerSubscription?.cancel();
    _partnerSubscription = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        final pData = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _partnerName = (pData['email'] as String).split('@')[0].toUpperCase();
          _partnerScore = pData['trust_score'] ?? 1000;
          if (pData['last_active'] != null) {
            _partnerLastActive = (pData['last_active'] as Timestamp).toDate();
          }
        });
      }
    });
  }

  Future<void> _loadSignalData() async {
    if (_partnerUid == null) return;
    try {
      final results = await Future.wait([
        _signalsService.getTodayNotificationCount(_partnerUid!), 
        _signalsService.getPartnerMood(_partnerUid!),
        _signalsService.getPartnerPermissions(_partnerUid!),
      ]);
      
      final bat = await _signalsService.getBatteryStatus(_partnerUid!);
      final net = await _signalsService.getNetworkStatus(_partnerUid!);

      if (mounted) {
        setState(() {
          if (bat != null) _batteryStatus = bat;
          if (net != null) _networkStatus = net;
          _todayNotificationCount = results[0] as int; 
          final moodData = results[1] as Map<String, dynamic>?;
          _partnerMood = moodData?['mood'];
          _partnerMoodTime = moodData?['timestamp'];
          _partnerPermissions = results[2] as PermissionModel?;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _loadMediaLockState() async {
    if (_partnerUid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString('media_unlock_$_partnerUid');
    if (expiryStr != null) {
      final expiry = DateTime.parse(expiryStr);
      if (expiry.isAfter(DateTime.now())) {
        setState(() { _mediaUnlockExpiry = expiry; });
      }
    }
  }

  Future<void> _unlockMedia() async {
    if (_partnerUid == null) return;
    if (_myTrustPoints < kMediaUnlockCost) {
      _showErrorSnackBar("Yetersiz Puan!");
      return;
    }
    bool confirm = await _showConfirmationDialog(kMediaUnlockCost, "Medya kilidini aç?");
    if (!confirm) return;

    setState(() { _myTrustPoints -= kMediaUnlockCost; });

    final newExpiry = DateTime.now().add(const Duration(minutes: 60));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('media_unlock_$_partnerUid', newExpiry.toIso8601String());

    setState(() { _mediaUnlockExpiry = newExpiry; });
    _showSuccessSnackBar("Medya Açıldı!");
    _fxKey.currentState?.triggerLoveBurst();
  }

  // --- WIDGET'LAR ---
  
  Widget _buildLockedOverlay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCardBg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(PhosphorIcons.lockKey(PhosphorIconsStyle.duotone), size: 48, color: kTextGrey),
          const SizedBox(height: 16),
          Text("DATA IS ENCRYPTED", style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text("Veriler gizli. Canlı sinyalleri 30 dakika görmek için şifreyi çöz.", textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 12)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _unlockAllSignals,
              style: ElevatedButton.styleFrom(backgroundColor: kAccentCyan.withOpacity(0.2), foregroundColor: kAccentCyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: kAccentCyan))),
              child: Text("ŞİFREYİ ÇÖZ (-$kDecryptCost TP)", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, String sub, Color color, VoidCallback onTap, {bool isOutlined = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: GoogleFonts.rajdhani(color: color, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
            Text(sub, style: GoogleFonts.montserrat(color: isOutlined ? color : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerStatusFooter() {
    Color pScoreColor = kAccentPurple;
    String pStatus = "UNKNOWN";
    if (_partnerScore != null) {
      if (_partnerScore! < 500) { pScoreColor = kAccentRed; pStatus = "CRITICAL"; }
      else if (_partnerScore! >= 800) { pScoreColor = kSoulGold; pStatus = "SOUL SYNC"; }
      else { pScoreColor = kAccentCyan; pStatus = "STABLE"; }
    }
    return Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: pScoreColor.withOpacity(0.3))),
      child: Column(children: [
          Text("PARTNER'S STATUS", style: GoogleFonts.rajdhani(color: kTextGrey, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill), color: pScoreColor, size: 28).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.1, 1.1)),
              const SizedBox(width: 16),
              Text(_partnerScore != null ? "$_partnerScore" : "--", style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: pScoreColor.withOpacity(0.2), borderRadius: BorderRadius.circular(6)), child: Text(pStatus, style: GoogleFonts.montserrat(color: pScoreColor, fontSize: 11, fontWeight: FontWeight.bold)))
          ]),
          const SizedBox(height: 8),
          if (_partnerLastActive != null) Text("Last seen: ${DateFormat('dd MMM - HH:mm').format(_partnerLastActive!)}", style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 11)),
      ]),
    );
  }

  Widget _buildMoodFullCard() {
    final timeAgo = _getTimeAgo(_partnerMoodTime); 
    String emoji = "✨";
    String moodText = "No Status";
    bool hasData = _partnerMood != null && _partnerMood!.isNotEmpty;

    if (hasData) {
      if (_partnerMood!.length > 2) {
        emoji = _partnerMood!.substring(0, 2).trim(); 
        moodText = _partnerMood!.substring(2).trim();
      } else {
        emoji = "✨";
        moodText = _partnerMood!;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("PARTNER'S VIBE", style: GoogleFonts.rajdhani(color: kTextGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(moodText, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                if(_partnerMoodTime != null)
                  Text(timeAgo, style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 10)),
              ],
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildDarkCard({required IconData icon, required String title, required String value, required Color color, required bool isPermitted, required VoidCallback onTap}) {
    Color effectiveColor = isPermitted ? color : kTextGrey;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: effectiveColor.withOpacity(isPermitted ? 0.3 : 0.1), width: 1.5), boxShadow: isPermitted ? [BoxShadow(color: effectiveColor.withOpacity(0.1), blurRadius: 10)] : []),
        child: Stack(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Icon(icon, color: effectiveColor, size: 28),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: GoogleFonts.rajdhani(color: kTextGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(isPermitted ? value : "LOCKED", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])
            ]),
            if(isPermitted) Align(alignment: Alignment.topRight, child: Icon(PhosphorIcons.arrowsClockwise(PhosphorIconsStyle.bold), color: kTextGrey.withOpacity(0.5), size: 18))
        ]),
      ),
    );
  }

  Widget _buildMediaDarkCard() {
    if (_partnerUid == null) return Container();
    bool isPermitted = _partnerPermissions?.isMediaPermitted ?? false;
    bool isUnlocked = _mediaUnlockExpiry != null && _mediaUnlockExpiry!.isAfter(DateTime.now());

    return StreamBuilder<MediaModel?>(
      stream: _signalsService.streamMediaStatus(_partnerUid!),
      builder: (context, snapshot) {
        final media = snapshot.data;
        bool isPlaying = media != null && media.isPlaying;
        Color accent = isPlaying ? kAccentOrange : kTextGrey;
        String statusText = "SILENT";
        if (media != null && DateTime.now().difference(media.timestamp).inMinutes > 30) { isPlaying = false; accent = kTextGrey; statusText = "IDLE"; }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: accent.withOpacity(isPlaying ? 0.6 : 0.1), width: isPlaying ? 2.0 : 1.5), boxShadow: isPlaying ? [BoxShadow(color: accent.withOpacity(0.1), blurRadius: 10)] : []),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Icon(PhosphorIcons.headphones(PhosphorIconsStyle.regular), color: accent, size: 28),
              if (!isPermitted) Text("NO ACCESS", style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 16, fontWeight: FontWeight.bold))
              else if (isUnlocked || _areSignalsUnlocked) 
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(media?.title ?? "Unknown", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(media?.artist ?? "-", style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 11), maxLines: 1),
                ])
              else if (isPlaying)
                GestureDetector(onTap: _unlockMedia, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: accent.withOpacity(0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: accent)), child: Text("UNLOCK (-$kMediaUnlockCost)", style: GoogleFonts.rajdhani(color: accent, fontSize: 11, fontWeight: FontWeight.bold))))
              else Text(statusText, style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 16, fontWeight: FontWeight.bold))
          ]),
        );
      },
    );
  }

  Widget _buildBottomNavBar(Color activeColor) {
    return Container(
      height: 80,
      decoration: BoxDecoration(color: kBgDark, border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _buildNavItem(PhosphorIcons.heart(PhosphorIconsStyle.fill), "Home", true, activeColor, () {}),
          _buildNavItem(PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.regular), "History", false, kTextGrey, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ActivityLogsScreen()))),
          _buildNavItem(PhosphorIcons.user(PhosphorIconsStyle.regular), "Settings", false, kTextGrey, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()))),
      ]),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 26).animate(target: isActive ? 1 : 0).scale(begin: const Offset(1,1), end: const Offset(1.2, 1.2)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.montserrat(color: color, fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal))
    ]));
  }

  void _showMoodSelectionSheet() { showModalBottomSheet(context: context, backgroundColor: kCardBg, builder: (BuildContext context) { return Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text("SET YOUR VIBE", style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 20), Wrap(spacing: 12.0, runSpacing: 12.0, children: ["😌 Chill", "🤯 Busy", "🚗 Driving", "😴 Sleepy", "❤️ In Love", "🤔 Focus", "🎉 Party", "🏋️ Gym"].map((mood) => ActionChip(label: Text(mood, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)), backgroundColor: Colors.white.withOpacity(0.1), side: BorderSide.none, onPressed: () => _updateMyMood(mood))).toList())])); }); }
  Future<void> _updateMyMood(String moodValue) async { Navigator.pop(context); setState(() => _isLoadingData = true); try { await _signalsService.updateMyMood(moodValue); setState(() { _myTrustPoints += kMoodUpdateReward; }); _fxKey.currentState?.triggerLoveBurst(); _showSuccessSnackBar("Mood Updated!"); } catch (_) {} finally { setState(() => _isLoadingData = false); } }
  Future<bool> _showConfirmationDialog(int cost, String text) async { return await showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: kCardBg, title: Text("CONFIRM", style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold)), content: Text("$text (-$cost TP)", style: GoogleFonts.montserrat(color: kTextGrey)), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text("CANCEL", style: GoogleFonts.montserrat(color: kTextGrey))), TextButton(onPressed: () => Navigator.pop(context, true), child: Text("CONFIRM", style: GoogleFonts.rajdhani(color: kAccentCyan, fontWeight: FontWeight.bold)))])) ?? false; }
  void _showErrorSnackBar(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: GoogleFonts.rajdhani(color: Colors.white)), backgroundColor: Colors.redAccent));
  void _showSuccessSnackBar(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: GoogleFonts.rajdhani(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: kSoulGold));
  String _getTimeLeft(DateTime expiry) { final diff = expiry.difference(DateTime.now()); return "${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}"; }
  String _getTimeAgo(DateTime? timestamp) { if (timestamp == null || timestamp.year < 2000) return "--"; final difference = DateTime.now().difference(timestamp); if (difference.inMinutes < 1) return "Now"; if (difference.inMinutes < 60) return "${difference.inMinutes}m"; if (difference.inHours < 24) return "${difference.inHours}h"; return "${difference.inDays}d"; }
}