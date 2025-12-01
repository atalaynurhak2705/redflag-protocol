import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

import 'settings_screen.dart';
import 'activity_logs_screen.dart';

// --- SERVİS VE MODELLER ---
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../services/firestore_service.dart';
import '../services/signals_service.dart';
import '../models/signals/battery_model.dart';
import '../models/signals/network_model.dart';
import '../models/signals/media_model.dart';
// import '../models/signals/screen_time_model.dart'; // KALDIRILDI
import '../models/permission_model.dart';

// --- SABİT RENK PALETİ ---
const Color kBgDark = Color(0xFF121212);
const Color kAccentRed = Color(0xFFFF2000);
const Color kAccentOrange = Color(0xFFFF4500);
const Color kAccentCyan = Color(0xFF00E5FF);
const Color kTextGrey = Color(0xFFB0BEC5);
const Color kCardBg = Color(0xFF1E1E1E);

// --- YAPILANDIRMA SABİTLERİ ---
const int kGenericUpdateCost = 10;
const Duration kGenericRateLimit = Duration(minutes: 30);
const int kMoodUpdateReward = 10;

// Sinyal Tipleri (screenTime kaldırıldı)
enum SignalType { battery, network, media, notifications, mood }

class DashboardActiveScreen extends StatefulWidget {
  final int trustPoints;
  final String partnerName;
  final String partnerUid;
  final Function(int) onDeductPoints;
  final Function(int) onAddPoints;

  const DashboardActiveScreen({
    super.key,
    required this.trustPoints,
    required this.partnerName,
    required this.partnerUid,
    required this.onDeductPoints,
    required this.onAddPoints,
  });

  @override
  State<DashboardActiveScreen> createState() => _DashboardActiveScreenState();
}

class _DashboardActiveScreenState extends State<DashboardActiveScreen> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _scoreAnimController;
  late Animation<int> _scoreAnimation;
  int _oldScore = 0;

  final SignalsService _signalsService = SignalsService();
  final AuthService _authService = AuthService();

  // Sinyal durum değişkenleri
  BatteryModel? _batteryStatus;
  NetworkModel? _networkStatus;
  MediaModel? _mediaStatus;
  int _todayNotificationCount = 0;
  
  String? _partnerMood;
  DateTime? _partnerMoodTime;
  PermissionModel? _partnerPermissions;

  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _scoreAnimController.forward();
    _oldScore = widget.trustPoints;
    _loadInitialData();
  }

  // --- VERİ YÜKLEME METODU (Aynı zamanda Yenileme için kullanılacak) ---
  Future<void> _loadInitialData() async {
    // Eğer zaten yükleniyorsa tekrar başlatma
    if (_isLoadingData) return;

    setState(() => _isLoadingData = true);

    print("--- DASHBOARD VERİ YÜKLEME BAŞLADI (Tazeleniyor) ---");

    try {
      final results = await Future.wait([
        _signalsService.getTodayNotificationCount(widget.partnerUid), // 0
        _signalsService.getPartnerMood(widget.partnerUid), // 1
        _signalsService.getPartnerPermissions(widget.partnerUid), // 2
      ]);

      if (!mounted) return;
      setState(() {
        // Paralı verileri sıfırlamıyoruz ki eski halleri görünsün, 
        // kullanıcı güncelleyince yenileri gelsin.
        // _batteryStatus = null; _networkStatus = null; _mediaStatus = null;
        
        _todayNotificationCount = results[0] as int; 
        
        final moodData = results[1] as Map<String, dynamic>?;
        _partnerMood = moodData?['mood'];
        _partnerMoodTime = moodData?['timestamp'];

        // İzin durumunu ata
        _partnerPermissions = results[2] as PermissionModel?;

        print("✅ Dashboard: Veriler ve İzinler Tazelendi.");
      });
    } catch (e) {
      print("❌ Veri yenileme hatası: $e");
      if (mounted) _showErrorSnackBar("Veriler yenilenemedi.");
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  void _setupAnimations() {
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _shimmerController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _oldScore = 0;
    _scoreAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _scoreAnimation = IntTween(begin: _oldScore, end: widget.trustPoints).animate(CurvedAnimation(parent: _scoreAnimController, curve: Curves.easeOutExpo));
  }

  @override
  void didUpdateWidget(DashboardActiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trustPoints != widget.trustPoints) {
      _oldScore = oldWidget.trustPoints;
      _scoreAnimController.reset();
      _scoreAnimation = IntTween(begin: _oldScore, end: widget.trustPoints).animate(CurvedAnimation(parent: _scoreAnimController, curve: Curves.easeOutExpo));
      _scoreAnimController.forward();
      _oldScore = widget.trustPoints;
    }
    if (oldWidget.partnerUid != widget.partnerUid) { _loadInitialData(); }
  }

  @override
  void dispose() { _entranceController.dispose(); _pulseController.dispose(); _shimmerController.dispose(); _scoreAnimController.dispose(); super.dispose(); }

  // --- GÜNCELLEME MANTIĞI ---
  Future<void> _handleSignalUpdate(SignalType type) async {
    if (type == SignalType.mood) { _showMoodSelectionSheet(); return; }

    // YENİ: Tüm sinyaller için izin kontrolü (Ekstra güvenlik)
    bool isPermitted = false;
    switch (type) {
      case SignalType.battery: isPermitted = _partnerPermissions?.isBatteryPermitted ?? false; break;
      case SignalType.network: isPermitted = _partnerPermissions?.isNetworkPermitted ?? false; break;
      case SignalType.media: isPermitted = _partnerPermissions?.isMediaPermitted ?? false; break;
      case SignalType.notifications: isPermitted = _partnerPermissions?.isNotificationsPermitted ?? false; break;
      default: isPermitted = true; break;
    }

    if (!isPermitted) {
       _showErrorSnackBar("Partner bu veri paylaşımına rıza göstermemiş.");
       return;
    }

    int cost = kGenericUpdateCost;
    Duration rateLimit = kGenericRateLimit;
    DateTime? lastUpdated;

    switch (type) {
      case SignalType.battery: lastUpdated = _batteryStatus?.timestamp; break;
      case SignalType.network: lastUpdated = _networkStatus?.timestamp; break;
      case SignalType.media: lastUpdated = _mediaStatus?.timestamp; break;
      case SignalType.notifications: lastUpdated = null; break;
      default: return;
    }

    if (widget.trustPoints < cost) { _showErrorSnackBar("Yetersiz Puan! Güncelleme için $cost TP gerekiyor."); return; }

    if (lastUpdated != null) {
      final timeSinceLastUpdate = DateTime.now().difference(lastUpdated);
      if (timeSinceLastUpdate < rateLimit) {
        final remainingTime = rateLimit - timeSinceLastUpdate;
        final remainingMinutes = remainingTime.inMinutes + 1;
        _showErrorSnackBar("Çok sık güncelleme! Lütfen $remainingMinutes dakika daha bekleyin.");
        return;
      }
    }

    bool confirm = await _showConfirmationDialog(cost);
    if (!confirm) return;

    setState(() => _isLoadingData = true);
    widget.onDeductPoints(cost);

    try {
      switch (type) {
        case SignalType.battery: final newData = await _signalsService.getBatteryStatus(widget.partnerUid); setState(() => _batteryStatus = newData); break;
        case SignalType.network: final newData = await _signalsService.getNetworkStatus(widget.partnerUid); setState(() => _networkStatus = newData); break;
        case SignalType.media: final newData = await _signalsService.getMediaStatus(widget.partnerUid); setState(() => _mediaStatus = newData); break;
        case SignalType.notifications: final newCount = await _signalsService.getTodayNotificationCount(widget.partnerUid); setState(() => _todayNotificationCount = newCount); break;
        default: break;
      }
      _showSuccessSnackBar("Veri başarıyla güncellendi! (-$cost TP)");
    } catch (e) {
      _showErrorSnackBar("Güncelleme başarısız: $e");
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  // ... (Mod Seçim ve Yardımcı Metotlar aynı) ...
  void _showMoodSelectionSheet() { showModalBottomSheet(context: context, backgroundColor: kCardBg, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25.0))), builder: (BuildContext context) { final moods = ["😌 Rahatlıyorum", "🤯 Çok Yoğunum", "🚗 Yoldayım", "😴 Uykulu", "❤️ Seni Düşünüyorum", "🤔 Odaklandım", "🎉 Eğleniyorum", "🏋️ Spordayım"]; return Container(padding: const EdgeInsets.all(24.0), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Anlık Modunu Seç", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text("Partnerine durumunu bildir ve +$kMoodUpdateReward TP kazan!", style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 14)), const SizedBox(height: 24), Wrap(spacing: 12.0, runSpacing: 12.0, children: moods.map((mood) => _buildMoodChip(mood)).toList()), const SizedBox(height: 24)])); }); }
  Widget _buildMoodChip(String moodLabel) { return ActionChip(label: Text(moodLabel, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600)), backgroundColor: kBgDark, side: BorderSide(color: kAccentCyan.withOpacity(0.5)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), onPressed: () => _updateMyMood(moodLabel)); }
  Future<void> _updateMyMood(String moodValue) async { Navigator.pop(context); setState(() => _isLoadingData = true); try { await _signalsService.updateMyMood(moodValue); widget.onAddPoints(kMoodUpdateReward); _showSuccessSnackBar("Modun güncellendi! (+ $kMoodUpdateReward TP)"); } catch (e) { _showErrorSnackBar("Mod güncellenemedi: $e"); } finally { setState(() => _isLoadingData = false); } }
  String _getTimeAgo(DateTime? timestamp) { if (timestamp == null || timestamp.year < 2000) return "Veri Yok"; final difference = DateTime.now().difference(timestamp); if (difference.inDays > 0) return "${difference.inDays} gün önce"; if (difference.inHours > 0) return "${difference.inHours} saat önce"; if (difference.inMinutes > 0) return "${difference.inMinutes}dk önce"; return "Az önce"; }
  Future<bool> _showConfirmationDialog(int cost) async { return await showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: kCardBg, title: Text("Güncelleme Onayı", style: GoogleFonts.montserrat(color: Colors.white)), content: Text("Bu işlem için $cost Güven Puanı (TP) düşülecektir. Onaylıyor musunuz?", style: GoogleFonts.montserrat(color: kTextGrey)), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text("İptal", style: GoogleFonts.montserrat(color: kTextGrey))), TextButton(onPressed: () => Navigator.pop(context, true), child: Text("Onayla (-$cost TP)", style: GoogleFonts.montserrat(color: kAccentCyan, fontWeight: FontWeight.bold)))])) ?? false; }
  void _showErrorSnackBar(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.white)), backgroundColor: kAccentRed));
  void _showSuccessSnackBar(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.black)), backgroundColor: kAccentCyan));
  void _signOut() async { await _authService.signOut(); if (!mounted) return; Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);}
  void _navigateToLogs() => Navigator.push(context, MaterialPageRoute(builder: (context) => const ActivityLogsScreen()));
  void _handleViewCriticalLogs() { widget.onDeductPoints(20); _navigateToLogs(); }

  @override
  Widget build(BuildContext context) {
    final currentTime = DateFormat('HH:mm').format(DateTime.now());
    Color mainStatusColor = widget.trustPoints >= 800 ? kAccentCyan : (widget.trustPoints >= 600 ? kAccentOrange : kAccentRed);

    return Scaffold(
      backgroundColor: kBgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildModernHeader(currentTime, mainStatusColor),
            Expanded(
              // YENİ: ÇEK-YENİLE WIDGET'I EKLENDİ
              child: RefreshIndicator(
                onRefresh: _loadInitialData, // Çekilince bu metodu çalıştır
                color: kBgDark,
                backgroundColor: kAccentCyan,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  children: [
                    _buildAnimatedEntrance(delay: 0.0, child: Column(children: [if (widget.trustPoints < 800) _buildPulsingStatusChip(mainStatusColor), SizedBox(height: widget.trustPoints < 800 ? 24 : 0), _buildCleanPulsingOrb(mainStatusColor)])),
                    const SizedBox(height: 30),
                    _buildAnimatedEntrance(delay: 0.1, child: _buildMoodSignalCard(mainStatusColor)),
                    const SizedBox(height: 30),
                    _buildAnimatedEntrance(
                      delay: 0.2,
                      child: GridView.count(
                        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.0,
                        children: [
                          // İzin kontrollü kartlar
                          _buildInteractiveSignalCard(
  type: SignalType.battery,
  icon: Icons.battery_charging_full_rounded,
  title: "Battery",
  // DÜZELTME BURADA:
  value: (_batteryStatus == null) ? "--" : "${_batteryStatus!.level}%${_batteryStatus!.isCharging ? ' (⚡)' : ''}",
  timestamp: _batteryStatus?.timestamp,
  mainColor: mainStatusColor,
  isPermitted: _partnerPermissions?.isBatteryPermitted ?? false
),
                          _buildInteractiveSignalCard(type: SignalType.network, icon: Icons.wifi_rounded, title: "Network", value: (_networkStatus == null) ? "--" : _networkStatus!.type.toUpperCase(), timestamp: _networkStatus?.timestamp, mainColor: mainStatusColor, isPermitted: _partnerPermissions?.isNetworkPermitted ?? false),
                          _buildInteractiveSignalCard(type: SignalType.media, icon: Icons.headset_rounded, title: "Media Activity", value: (_mediaStatus != null && _mediaStatus!.isPlaying) ? (_mediaStatus!.title ?? "Playing...") : "Inactive", timestamp: _mediaStatus?.timestamp, mainColor: mainStatusColor, isPermitted: _partnerPermissions?.isMediaPermitted ?? false),
                          _buildInteractiveSignalCard(type: SignalType.notifications, icon: Icons.notifications_rounded, title: "Notifications (Today)", value: "$_todayNotificationCount New", timestamp: null, hideTimestamp: true, mainColor: mainStatusColor, isPermitted: _partnerPermissions?.isNotificationsPermitted ?? false),
                          _buildModernDataCard(Icons.location_on_rounded, "Location History", "Disabled (MVP)", kTextGrey),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40), _buildAnimatedEntrance(delay: 0.4, child: _buildModernShimmerButton(mainStatusColor)), const SizedBox(height: 24),
                    if (widget.trustPoints < 800) _buildAnimatedEntrance(delay: 0.6, child: _buildWarningMessage(mainStatusColor)),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (Yardımcı Widget'lar aynı) ...
  Widget _buildMoodSignalCard(Color mainColor) { final timeAgo = _getTimeAgo(_partnerMoodTime); return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: mainColor.withOpacity(0.5), width: 1.5), boxShadow: [BoxShadow(color: mainColor.withOpacity(0.1), blurRadius: 15, spreadRadius: 1)]), child: Column(children: [Row(children: [Icon(Icons.face_rounded, color: mainColor, size: 24), const SizedBox(width: 8), Text("Partner's Current Mood", style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 12, fontWeight: FontWeight.w600))]), const SizedBox(height: 16), _isLoadingData ? Center(child: CircularProgressIndicator(color: mainColor)) : Column(children: [Text(_partnerMood ?? "Henüz bir mod seçmedi", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center), if (_partnerMoodTime != null) const SizedBox(height: 8), if (_partnerMoodTime != null) Text("Son güncelleme: $timeAgo", style: GoogleFonts.montserrat(color: kTextGrey.withOpacity(0.6), fontSize: 12, fontStyle: FontStyle.italic))]), const SizedBox(height: 20), SizedBox(width: double.infinity, height: 44, child: ElevatedButton.icon(onPressed: _isLoadingData ? null : () => _handleSignalUpdate(SignalType.mood), style: ElevatedButton.styleFrom(backgroundColor: kAccentCyan, foregroundColor: kBgDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.add_reaction_rounded), label: Text("KENDİ MODUNU PAYLAŞ (+${kMoodUpdateReward} TP)", style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w800))))])); }
  Widget _buildInteractiveSignalCard({required SignalType type, required IconData icon, required String title, required String value, required DateTime? timestamp, required Color mainColor, bool hideTimestamp = false, bool isPermitted = true}) { final timeAgo = _getTimeAgo(timestamp); int cost = kGenericUpdateCost; final effectiveColor = isPermitted ? mainColor : kTextGrey; return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: effectiveColor.withOpacity(isPermitted ? 0.5 : 0.2), width: 1.5), boxShadow: isPermitted ? [BoxShadow(color: mainColor.withOpacity(0.1), blurRadius: 15, spreadRadius: 1)] : []), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(icon, color: effectiveColor, size: 24), const SizedBox(width: 8), Expanded(child: Text(title, style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))]), _isLoadingData ? Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: effectiveColor, strokeWidth: 2))) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isPermitted ? value : "İzin Verilmedi", style: GoogleFonts.montserrat(color: isPermitted ? Colors.white : kTextGrey, fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis), if (!hideTimestamp && isPermitted) const SizedBox(height: 4), if (!hideTimestamp && isPermitted) Text(timestamp == null ? "" : "Son: $timeAgo", style: GoogleFonts.montserrat(color: kTextGrey.withOpacity(0.6), fontSize: 10, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis)]), SizedBox(width: double.infinity, height: 32, child: ElevatedButton(onPressed: (isPermitted && !_isLoadingData) ? () => _handleSignalUpdate(type) : null, style: ElevatedButton.styleFrom(backgroundColor: effectiveColor.withOpacity(isPermitted ? 0.2 : 0.1), foregroundColor: effectiveColor, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: effectiveColor.withOpacity(0.5))), padding: EdgeInsets.zero, disabledBackgroundColor: kCardBg.withOpacity(0.5), disabledForegroundColor: kTextGrey.withOpacity(0.5)), child: _isLoadingData ? const SizedBox() : Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isPermitted ? Icons.refresh_rounded : Icons.block_rounded, size: 14, color: isPermitted ? effectiveColor : kTextGrey), const SizedBox(width: 4), Text(isPermitted ? "UPDATE (-$cost)" : "ERİŞİM YOK", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800))])))])); }
  Widget _buildAnimatedEntrance({required double delay, required Widget child}) { return FadeTransition(opacity: _entranceController, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _entranceController, curve: Interval(delay, 1.0, curve: Curves.easeOutQuad))), child: child)); }
  Widget _buildModernHeader(String currentTime, Color mainColor) { return Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 24), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text("DASHBOARD", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.5, shadows: [Shadow(color: Colors.white.withOpacity(0.3), blurRadius: 10)])), IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())), icon: const Icon(Icons.settings_rounded, color: kTextGrey), tooltip: "Ayarlar"), IconButton(onPressed: _signOut, icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent), tooltip: "Çıkış Yap")]), const SizedBox(height: 4), Text("Partner: ${widget.partnerName}", style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 13, fontWeight: FontWeight.w500))]), _buildActiveIndicator(mainColor)])); }
  Widget _buildActiveIndicator(Color mainColor) { return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: mainColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: mainColor.withOpacity(0.4))), child: Row(children: [AnimatedBuilder(animation: _pulseController, builder: (context, child) => Container(width: 8, height: 8, decoration: BoxDecoration(color: mainColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: mainColor, blurRadius: 8 * _pulseController.value, spreadRadius: 2 * _pulseController.value)]))), const SizedBox(width: 8), Text("ACTIVE", style: GoogleFonts.montserrat(color: mainColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))])); }
  Widget _buildCleanPulsingOrb(Color color) { return AnimatedBuilder(animation: _pulseController, builder: (context, child) => Stack(alignment: Alignment.center, children: [Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.5 * _pulseController.value), blurRadius: 100, spreadRadius: 20)])), Container(width: 180, height: 180, decoration: BoxDecoration(shape: BoxShape.circle, color: kBgDark, border: Border.all(color: color.withOpacity(0.8), width: 2)), child: Stack(children: [Container(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.3), boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 25, spreadRadius: -5)])), Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shield_rounded, size: 36, color: color), const SizedBox(height: 8), AnimatedBuilder(animation: _scoreAnimController, builder: (context, child) => Text("${_scoreAnimation.value}", style: GoogleFonts.montserrat(color: color, fontSize: 56, fontWeight: FontWeight.w900, shadows: [Shadow(color: color.withOpacity(0.8), blurRadius: 15)])))]))]))])); }
  Widget _buildPulsingStatusChip(Color color) { return AnimatedBuilder(animation: _pulseController, builder: (context, child) => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(30), border: Border.all(color: color.withOpacity(0.6 + (0.4 * _pulseController.value))), boxShadow: [BoxShadow(color: color.withOpacity(0.3 * _pulseController.value), blurRadius: 15, spreadRadius: 2)]), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.warning_amber_rounded, color: color, size: 18), const SizedBox(width: 8), Text("STATUS: CRITICAL", style: GoogleFonts.montserrat(color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0))]))); }
  Widget _buildModernDataCard(IconData icon, String title, String value, Color color, {bool isLive = false, int? cost, VoidCallback? onTap}) { return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: isLive ? color.withOpacity(0.5) : kTextGrey.withOpacity(0.1), width: 1.5), boxShadow: isLive ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 15, spreadRadius: 1)] : []), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: isLive ? color : kTextGrey, size: 26), if (cost != null) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: kAccentRed.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Text("-${cost} TP", style: GoogleFonts.montserrat(color: kAccentRed, fontSize: 14, fontWeight: FontWeight.w900)))]), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 12, fontWeight: FontWeight.w500)), const SizedBox(height: 6), Text(value, style: GoogleFonts.montserrat(color: isLive ? Colors.white : kTextGrey.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w700))])]))); }
  Widget _buildModernShimmerButton(Color color) { return GestureDetector(onTap: _handleViewCriticalLogs, child: AnimatedBuilder(animation: _pulseController, builder: (context, child) => Container(width: double.infinity, height: 64, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: color, boxShadow: [BoxShadow(color: color.withOpacity(0.5 + (0.2 * _pulseController.value)), blurRadius: 30, offset: const Offset(0, 8))]), child: Stack(children: [Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.warning_amber_rounded, color: Colors.black), const SizedBox(width: 12), Text("VIEW CRITICAL LOGS (-20 TP)", style: GoogleFonts.montserrat(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.0))])), Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: AnimatedBuilder(animation: _shimmerController, builder: (context, child) => FractionallySizedBox(widthFactor: 0.5, alignment: AlignmentGeometry.lerp(Alignment.centerLeft, Alignment.centerRight, _shimmerController.value)!, child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withOpacity(0.0), Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.0)], stops: const [0.0, 0.5, 1.0])))))))])),)); }
  Widget _buildWarningMessage(Color color) { return Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))), child: Row(children: [Icon(Icons.warning_amber_rounded, color: color, size: 20), const SizedBox(width: 12), Expanded(child: Text("Trust score critical. Partner activity requires attention.", style: GoogleFonts.montserrat(color: color, fontSize: 12, fontWeight: FontWeight.w500)))])); }
}