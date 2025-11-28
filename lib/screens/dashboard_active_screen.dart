import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

import 'settings_screen.dart';
import 'activity_logs_screen.dart';

// --- SERVİS VE MODELLER ---
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../services/signals_service.dart';
import '../models/signals/battery_model.dart';
import '../models/signals/network_model.dart';
import '../models/signals/media_model.dart';
import '../models/signals/screen_time_model.dart';
// import '../models/signals/notification_model.dart';

// --- SABİT RENK PALETİ ---
const Color kBgDark = Color(0xFF121212);
const Color kAccentRed = Color(0xFFFF2000);
const Color kAccentOrange = Color(0xFFFF4500);
const Color kAccentCyan = Color(0xFF00E5FF); // İyi durum rengi
const Color kTextGrey = Color(0xFFB0BEC5);
const Color kCardBg = Color(0xFF1E1E1E);

// --- YAPILANDIRMA SABİTLERİ ---
const int kGenericUpdateCost = 10; // Standart güncelleme maliyeti
const Duration kGenericRateLimit = Duration(minutes: 30); // Standart bekleme süresi

// Sinyal Tipleri (Tüm sinyaller eklendi)
enum SignalType { battery, network, media, screenTime, notifications }

class DashboardActiveScreen extends StatefulWidget {
  final int trustPoints;
  final String partnerName;
  final String partnerUid;
  final Function(int) onDeductPoints;

  const DashboardActiveScreen({
    super.key,
    required this.trustPoints,
    required this.partnerName,
    required this.partnerUid,
    required this.onDeductPoints,
  });

  @override
  State<DashboardActiveScreen> createState() => _DashboardActiveScreenState();
}

class _DashboardActiveScreenState extends State<DashboardActiveScreen> with TickerProviderStateMixin {
  // Animasyon Kontrolcüleri
  late AnimationController _entranceController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _scoreAnimController;
  late Animation<int> _scoreAnimation;
  int _oldScore = 0;

  // --- VERİ YÖNETİMİ ---
  final SignalsService _signalsService = SignalsService();
  final AuthService _authService = AuthService();

  // Tüm sinyaller için durum değişkenleri
  BatteryModel? _batteryStatus;
  NetworkModel? _networkStatus;
  MediaModel? _mediaStatus;
  ScreenTimeModel? _yesterdayScreenTime;
  int _todayNotificationCount = 0;

  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _scoreAnimController.forward();
    _oldScore = widget.trustPoints;
    _loadInitialData();
  }

  // İlk açılışta TÜM verileri çek
  Future<void> _loadInitialData() async {
    setState(() => _isLoadingData = true);

    // Paralel olarak tüm verileri çekiyoruz
    final results = await Future.wait([
      _signalsService.getBatteryStatus(widget.partnerUid),
      _signalsService.getNetworkStatus(widget.partnerUid),
      _signalsService.getMediaStatus(widget.partnerUid),
      _signalsService.getYesterdayScreenTime(widget.partnerUid),
      _signalsService.getTodayNotificationCount(widget.partnerUid),
    ]);

    if (!mounted) return;
    setState(() {
      _batteryStatus = results[0] as BatteryModel?;
      _networkStatus = results[1] as NetworkModel?;
      _mediaStatus = results[2] as MediaModel?;
      _yesterdayScreenTime = results[3] as ScreenTimeModel?;
      _todayNotificationCount = results[4] as int;
      _isLoadingData = false;
    });
  }

  // Animasyon kurulumları
  void _setupAnimations() {
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _shimmerController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _oldScore = 0;
    _scoreAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _scoreAnimation = IntTween(begin: _oldScore, end: widget.trustPoints).animate(
        CurvedAnimation(parent: _scoreAnimController, curve: Curves.easeOutExpo)
    );
  }

  @override
  void didUpdateWidget(DashboardActiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trustPoints != widget.trustPoints) {
      _oldScore = oldWidget.trustPoints;
      _scoreAnimController.reset();
      _scoreAnimation = IntTween(begin: _oldScore, end: widget.trustPoints).animate(
          CurvedAnimation(parent: _scoreAnimController, curve: Curves.easeOutExpo)
      );
      _scoreAnimController.forward();
      _oldScore = widget.trustPoints;
    }
    if (oldWidget.partnerUid != widget.partnerUid) {
      _loadInitialData();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _scoreAnimController.dispose();
    super.dispose();
  }

  // --- ANA GÜNCELLEME MANTIĞI (Tüm Sinyaller İçin) ---
  Future<void> _handleSignalUpdate(SignalType type) async {
    int cost = kGenericUpdateCost;
    Duration rateLimit = kGenericRateLimit;
    DateTime? lastUpdated;

    // Hangi sinyalin güncelleneceğini ve son zamanını belirle
    switch (type) {
      case SignalType.battery:
        lastUpdated = _batteryStatus?.timestamp;
        break;
      case SignalType.network:
        lastUpdated = _networkStatus?.timestamp;
        break;
      case SignalType.media:
        lastUpdated = _mediaStatus?.timestamp;
        break;
      case SignalType.screenTime:
        // Ekran süresi günde bir güncellenir, rate limit farklı olabilir ama şimdilik standart tutalım.
        lastUpdated = _yesterdayScreenTime?.timestamp;
        break;
      case SignalType.notifications:
        // Bildirim sayısı genellikle otomatik güncellenir ama manuel buton koyacaksak:
        // lastUpdated bilgisi elimizde yok, şimdilik her zaman güncelletelim.
        lastUpdated = null; 
        break;
    }

    // Puan Kontrolü
    if (widget.trustPoints < cost) {
      _showErrorSnackBar("Yetersiz Puan! Güncelleme için $cost TP gerekiyor.");
      return;
    }

    // Rate Limit Kontrolü
    if (lastUpdated != null) {
      final timeSinceLastUpdate = DateTime.now().difference(lastUpdated);
      if (timeSinceLastUpdate < rateLimit) {
        final remainingTime = rateLimit - timeSinceLastUpdate;
        final remainingMinutes = remainingTime.inMinutes + 1;
        _showErrorSnackBar("Çok sık güncelleme! Lütfen $remainingMinutes dakika daha bekleyin.");
        return;
      }
    }

    // Onay
    bool confirm = await _showConfirmationDialog(cost);
    if (!confirm) return;

    // İşlem
    setState(() => _isLoadingData = true);
    widget.onDeductPoints(cost);

    try {
      switch (type) {
        case SignalType.battery:
          final newData = await _signalsService.getBatteryStatus(widget.partnerUid);
          setState(() => _batteryStatus = newData);
          break;
        case SignalType.network:
          final newData = await _signalsService.getNetworkStatus(widget.partnerUid);
          setState(() => _networkStatus = newData);
          break;
        case SignalType.media:
          final newData = await _signalsService.getMediaStatus(widget.partnerUid);
          setState(() => _mediaStatus = newData);
          break;
        case SignalType.screenTime:
          final newData = await _signalsService.getYesterdayScreenTime(widget.partnerUid);
          setState(() => _yesterdayScreenTime = newData);
          break;
        case SignalType.notifications:
          final newCount = await _signalsService.getTodayNotificationCount(widget.partnerUid);
          setState(() => _todayNotificationCount = newCount);
          break;
      }
      _showSuccessSnackBar("Veri başarıyla güncellendi! (-$cost TP)");
    } catch (e) {
      _showErrorSnackBar("Güncelleme başarısız: $e");
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  // --- YARDIMCI METOTLAR ---
  String _getTimeAgo(DateTime? timestamp) {
    if (timestamp == null) return "Veri Yok";
    // Eğer tarih 1970 başlarındaysa (boş timestamp) "Veri Yok" dön
    if (timestamp.year < 2000) return "Veri Yok";

    final difference = DateTime.now().difference(timestamp);
    if (difference.inDays > 0) return "${difference.inDays} gün önce";
    if (difference.inHours > 0) return "${difference.inHours} saat önce";
    if (difference.inMinutes > 0) return "${difference.inMinutes}dk önce";
    return "Az önce";
  }
  
  // Ekran süresini "Saat dk" formatına çevirir
  String _formatScreenTime(int totalMinutes) {
    if (totalMinutes == 0) return "--";
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) return "${hours}s ${minutes}dk";
    return "${minutes}dk";
  }

  Future<bool> _showConfirmationDialog(int cost) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: kCardBg,
            title: Text("Güncelleme Onayı", style: GoogleFonts.montserrat(color: Colors.white)),
            content: Text("Bu işlem için $cost Güven Puanı (TP) düşülecektir. Onaylıyor musunuz?", style: GoogleFonts.montserrat(color: kTextGrey)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text("İptal", style: GoogleFonts.montserrat(color: kTextGrey))),
              TextButton(onPressed: () => Navigator.pop(context, true), child: Text("Onayla (-$cost TP)", style: GoogleFonts.montserrat(color: kAccentCyan, fontWeight: FontWeight.bold))),
            ],
          ),
        ) ?? false;
  }

  void _showErrorSnackBar(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.white)), backgroundColor: kAccentRed));
  void _showSuccessSnackBar(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.black)), backgroundColor: kAccentCyan));
  void _signOut() async { await _authService.signOut(); if (!mounted) return; Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);}
  void _navigateToLogs() => Navigator.push(context, MaterialPageRoute(builder: (context) => const ActivityLogsScreen()));
  void _handleViewCriticalLogs() { widget.onDeductPoints(20); _navigateToLogs(); }

  @override
  Widget build(BuildContext context) {
    final currentTime = DateFormat('HH:mm').format(DateTime.now());
    
    // --- RENK MANTIĞI DÜZELTİLDİ ---
    Color mainStatusColor;
    if (widget.trustPoints >= 800) {
      mainStatusColor = kAccentCyan; // İyi (Yüksek Puan)
    } else if (widget.trustPoints >= 600) {
      mainStatusColor = kAccentOrange; // Orta (Uyarı)
    } else {
      mainStatusColor = kAccentRed; // Kötü (Kritik)
    }
    // --------------------------------

    return Scaffold(
      backgroundColor: kBgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildModernHeader(currentTime, mainStatusColor),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                children: [
                  // A) TRUST ORB
                  _buildAnimatedEntrance(
                    delay: 0.0, 
                    child: Column(
                      children: [
                        // Sadece puan düşükse veya orta seviyedeyse uyarı çipini göster
                        if (widget.trustPoints < 800) _buildPulsingStatusChip(mainStatusColor),
                        SizedBox(height: widget.trustPoints < 800 ? 24 : 0),
                        _buildCleanPulsingOrb(mainStatusColor)
                      ],
                    )
                  ),
                  const SizedBox(height: 40),

                  // B) DATA CARDS GRID (TÜM KARTLAR EKLENDİ)
                  _buildAnimatedEntrance(
                    delay: 0.2,
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      // --- TAŞMA HATASI ÇÖZÜMÜ: Oranı 1.0 (Kare) yaptık ---
                      childAspectRatio: 1.0, 
                      // ----------------------------------------------------
                      children: [
                        // 1. BATARYA
                        _buildInteractiveSignalCard(
                          type: SignalType.battery,
                          icon: Icons.battery_charging_full_rounded,
                          title: "Battery",
                          value: (_batteryStatus == null) ? "--" : "${_batteryStatus!.level}% (${_batteryStatus!.isCharging ? '⚡' : ''})",
                          timestamp: _batteryStatus?.timestamp,
                          mainColor: mainStatusColor,
                        ),
                        // 2. AĞ
                        _buildInteractiveSignalCard(
                          type: SignalType.network,
                          icon: Icons.wifi_rounded,
                          title: "Network",
                          value: (_networkStatus == null) ? "--" : _networkStatus!.type.toUpperCase(),
                          timestamp: _networkStatus?.timestamp,
                          mainColor: mainStatusColor,
                        ),
                        // 3. MEDYA (YENİ)
                        _buildInteractiveSignalCard(
                          type: SignalType.media,
                          icon: Icons.headset_rounded,
                          title: "Media Activity",
                          // Eğer medya çalıyorsa başlığı göster, yoksa "Inactive"
                          value: (_mediaStatus != null && _mediaStatus!.isPlaying) 
                              ? (_mediaStatus!.title ?? "Playing...") 
                              : "Inactive",
                          timestamp: _mediaStatus?.timestamp,
                          mainColor: mainStatusColor,
                        ),
                        // 4. EKRAN SÜRESİ (YENİ - Dünün Özeti)
                        _buildInteractiveSignalCard(
                          type: SignalType.screenTime,
                          icon: Icons.timer_rounded,
                          title: "Screen Time (Yesterday)",
                          value: _formatScreenTime(_yesterdayScreenTime?.totalMinutes ?? 0),
                          timestamp: _yesterdayScreenTime?.timestamp,
                          mainColor: mainStatusColor,
                        ),
                         // 5. BİLDİRİMLER (YENİ - Bugünün Sayısı)
                        _buildInteractiveSignalCard(
                          type: SignalType.notifications,
                          icon: Icons.notifications_rounded,
                          title: "Notifications (Today)",
                          value: "$_todayNotificationCount New",
                          // Bildirim sayısı için timestamp şimdilik yok, manuel gizledik.
                          timestamp: null, 
                          hideTimestamp: true,
                          mainColor: mainStatusColor,
                        ),
                         // 6. KONUM (MVP DIŞI - Statik Kart)
                        _buildModernDataCard(Icons.location_on_rounded, "Location History", "Disabled (MVP)", kTextGrey),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // C) CRITICAL LOGS BUTTON
                  _buildAnimatedEntrance(delay: 0.4, child: _buildModernShimmerButton(mainStatusColor)),
                  const SizedBox(height: 24),

                  // D) WARNING MESSAGE (Sadece puan düşükse göster)
                  if (widget.trustPoints < 800)
                  _buildAnimatedEntrance(delay: 0.6, child: _buildWarningMessage(mainStatusColor)),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- YARDIMCI WIDGET'LAR ---

  // YENİ: İnteraktif Sinyal Kartı
  Widget _buildInteractiveSignalCard({
    required SignalType type,
    required IconData icon,
    required String title,
    required String value,
    required DateTime? timestamp,
    required Color mainColor,
    bool hideTimestamp = false, // Zamanı gizlemek için opsiyon
  }) {
    final timeAgo = _getTimeAgo(timestamp);
    int cost = kGenericUpdateCost;

    return Container(
      padding: const EdgeInsets.all(12), // Padding biraz azaltıldı
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: mainColor.withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(color: mainColor.withOpacity(0.1), blurRadius: 15, spreadRadius: 1)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // İçeriği dikeyde yaymak için spaceBetween
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Üst: İkon ve Başlık
          Row(children: [Icon(icon, color: mainColor, size: 24), const SizedBox(width: 8), Expanded(child: Text(title, style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))]),
          
          // Orta: Değer ve Zaman
          _isLoadingData
              ? Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: mainColor, strokeWidth: 2)))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(value, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (!hideTimestamp) const SizedBox(height: 4),
                  if (!hideTimestamp) Text(timestamp == null ? "" : "Son: $timeAgo", style: GoogleFonts.montserrat(color: kTextGrey.withOpacity(0.6), fontSize: 10, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
                
          // Alt: GÜNCELLE Butonu
          SizedBox(width: double.infinity, height: 32, child: ElevatedButton(onPressed: _isLoadingData ? null : () => _handleSignalUpdate(type), style: ElevatedButton.styleFrom(backgroundColor: mainColor.withOpacity(0.2), foregroundColor: mainColor, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: mainColor.withOpacity(0.5))), padding: EdgeInsets.zero), child: _isLoadingData ? const SizedBox() : Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.refresh_rounded, size: 14, color: mainColor), const SizedBox(width: 4), Text("UPDATE (-$cost)", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800))]))),
        ],
      ),
    );
  }

  // Giriş Animasyonu
  Widget _buildAnimatedEntrance({required double delay, required Widget child}) { return FadeTransition(opacity: _entranceController, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _entranceController, curve: Interval(delay, 1.0, curve: Curves.easeOutQuad))), child: child)); }
  
  // Header (Renk dinamikleşti)
  Widget _buildModernHeader(String currentTime, Color mainColor) { return Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 24), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text("DASHBOARD", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.5, shadows: [Shadow(color: Colors.white.withOpacity(0.3), blurRadius: 10)])), IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())), icon: const Icon(Icons.settings_rounded, color: kTextGrey), tooltip: "Ayarlar"), IconButton(onPressed: _signOut, icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent), tooltip: "Çıkış Yap")]), const SizedBox(height: 4), Text("Partner: ${widget.partnerName}", style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 13, fontWeight: FontWeight.w500))]), _buildActiveIndicator(mainColor)])); }
  
  // Active Indicator (Renk dinamikleşti)
  Widget _buildActiveIndicator(Color mainColor) { return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: mainColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: mainColor.withOpacity(0.4))), child: Row(children: [AnimatedBuilder(animation: _pulseController, builder: (context, child) => Container(width: 8, height: 8, decoration: BoxDecoration(color: mainColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: mainColor, blurRadius: 8 * _pulseController.value, spreadRadius: 2 * _pulseController.value)]))), const SizedBox(width: 8), Text("ACTIVE", style: GoogleFonts.montserrat(color: mainColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))])); }
  
  // Pulsing Orb (Aynı)
  Widget _buildCleanPulsingOrb(Color color) { return AnimatedBuilder(animation: _pulseController, builder: (context, child) => Stack(alignment: Alignment.center, children: [Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.5 * _pulseController.value), blurRadius: 100, spreadRadius: 20)])), Container(width: 180, height: 180, decoration: BoxDecoration(shape: BoxShape.circle, color: kBgDark, border: Border.all(color: color.withOpacity(0.8), width: 2)), child: Stack(children: [Container(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.3), boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 25, spreadRadius: -5)])), Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shield_rounded, size: 36, color: color), const SizedBox(height: 8), AnimatedBuilder(animation: _scoreAnimController, builder: (context, child) => Text("${_scoreAnimation.value}", style: GoogleFonts.montserrat(color: color, fontSize: 56, fontWeight: FontWeight.w900, shadows: [Shadow(color: color.withOpacity(0.8), blurRadius: 15)])))]))]))])); }
  
  // Status Chip (Aynı)
  Widget _buildPulsingStatusChip(Color color) { return AnimatedBuilder(animation: _pulseController, builder: (context, child) => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(30), border: Border.all(color: color.withOpacity(0.6 + (0.4 * _pulseController.value))), boxShadow: [BoxShadow(color: color.withOpacity(0.3 * _pulseController.value), blurRadius: 15, spreadRadius: 2)]), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.warning_amber_rounded, color: color, size: 18), const SizedBox(width: 8), Text("STATUS: CRITICAL", style: GoogleFonts.montserrat(color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0))]))); }
  
  // Statik Kart (Sadece Konum için kaldı)
  Widget _buildModernDataCard(IconData icon, String title, String value, Color color, {bool isLive = false, int? cost, VoidCallback? onTap}) { return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: isLive ? color.withOpacity(0.5) : kTextGrey.withOpacity(0.1), width: 1.5), boxShadow: isLive ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 15, spreadRadius: 1)] : []), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: isLive ? color : kTextGrey, size: 26), if (cost != null) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: kAccentRed.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Text("-${cost} TP", style: GoogleFonts.montserrat(color: kAccentRed, fontSize: 14, fontWeight: FontWeight.w900)))]), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 12, fontWeight: FontWeight.w500)), const SizedBox(height: 6), Text(value, style: GoogleFonts.montserrat(color: isLive ? Colors.white : kTextGrey.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w700))])]))); }
  
  // Shimmer Button (Aynı)
  Widget _buildModernShimmerButton(Color color) { return GestureDetector(onTap: _handleViewCriticalLogs, child: AnimatedBuilder(animation: _pulseController, builder: (context, child) => Container(width: double.infinity, height: 64, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: color, boxShadow: [BoxShadow(color: color.withOpacity(0.5 + (0.2 * _pulseController.value)), blurRadius: 30, offset: const Offset(0, 8))]), child: Stack(children: [Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.warning_amber_rounded, color: Colors.black), const SizedBox(width: 12), Text("VIEW CRITICAL LOGS (-20 TP)", style: GoogleFonts.montserrat(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.0))])), Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: AnimatedBuilder(animation: _shimmerController, builder: (context, child) => FractionallySizedBox(widthFactor: 0.5, alignment: AlignmentGeometry.lerp(Alignment.centerLeft, Alignment.centerRight, _shimmerController.value)!, child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withOpacity(0.0), Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.0)], stops: const [0.0, 0.5, 1.0])))))))])),)); }
  
  // Warning Message (Aynı)
  Widget _buildWarningMessage(Color color) { return Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))), child: Row(children: [Icon(Icons.warning_amber_rounded, color: color, size: 20), const SizedBox(width: 12), Expanded(child: Text("Trust score critical. Partner activity requires attention.", style: GoogleFonts.montserrat(color: color, fontSize: 12, fontWeight: FontWeight.w500)))])); }
}