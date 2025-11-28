import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart'; // UNUTMAYIN: flutter pub add uuid

import '../services/auth_service.dart';
// dashboard_active_screen.dart importuna gerek yok, main_screen.dart yeterli
import 'main_screen.dart';

// --- SABİT RENK PALETİ ---
const Color kBgDark = Color(0xFF121212);
const Color kAccentCyan = Color(0xFF00E5FF);
const Color kAccentRed = Color(0xFFFF2000); // Hata durumları için
const Color kTextGrey = Color(0xFFB0BEC5);
const Color kCardBg = Color(0xFF1E1E1E);

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  // TabController ile "Davet Et" ve "Katıl" arasında geçiş yapacak
  late TabController _tabController;

  String? _generatedCode; // Üretilen eşleşme kodunu tutar
  bool _isGeneratingCode = false; // Kod üretme animasyonu için
  String? _errorMessage; // Hata mesajlarını tutar

  final TextEditingController _joinCodeController = TextEditingController(); // Kodu girmek için
  bool _isJoiningCode = false; // Kod katılım animasyonu için

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  // Yardımcı Metot: Hata mesajını ayarlar
  void _setErrorMessage(String message) {
    setState(() {
      _errorMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: kAccentRed,
    ));
  }

  // #region HOST TARAFI: KOD ÜRETME
  Future<void> _generatePairingCode() async {
    if (user == null) {
      _setErrorMessage("Kullanıcı oturumu bulunamadı.");
      return;
    }
    setState(() {
      _isGeneratingCode = true;
      _errorMessage = null; // Önceki hataları temizle
    });

    try {
      // 1. Kullanıcının zaten bir partneri var mı kontrol et
      final userDoc = await _db.collection('users').doc(user!.uid).get();
      if (userDoc.exists && userDoc.data()?['partner_uid'] != null) {
        _setErrorMessage("Zaten bir partnerle eşleşmiş durumdasınız.");
        return;
      }

      // 2. Halihazırda oluşturulmuş ve aktif bir kodu var mı kontrol et
      final existingCodeQuery = await _db
          .collection('pairing_codes')
          .where('host_uid', isEqualTo: user!.uid)
          .where('is_used', isEqualTo: false)
          .where('expires_at', isGreaterThan: Timestamp.now())
          .get();

      if (existingCodeQuery.docs.isNotEmpty) {
        // Zaten aktif bir kodu varsa onu göster
        final existingCode = existingCodeQuery.docs.first.data();
        setState(() {
          _generatedCode = existingCode['code'];
        });
        _setErrorMessage("Zaten aktif bir kodunuz var. (${existingCode['code']})");
        return;
      }

      // 3. Benzersiz ve Kısa Süreli Kod Üretimi (8 haneli alfanümerik)
      String newCode = _uuid.v4().substring(0, 8).toUpperCase();

      // 4. Kodu Firebase'e yaz
      await _db.collection('pairing_codes').doc(newCode).set({
        'code': newCode,
        'host_uid': user!.uid,
        'created_at': FieldValue.serverTimestamp(),
        'expires_at': Timestamp.fromMillisecondsSinceEpoch(
            DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch), // 5 dakika geçerli
        'is_used': false,
      });

      setState(() {
        _generatedCode = newCode;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: kBgDark,
        content: Text("Eşleşme kodu oluşturuldu: $newCode", style: const TextStyle(color: kAccentCyan)),
      ));

    } catch (e) {
      // Hata ayıklama için konsola yaz
      print("KOD OLUŞTURMA HATASI: $e");
      _setErrorMessage("Kod oluşturulurken bir hata oluştu: ${e.toString()}");
    } finally {
      setState(() {
        _isGeneratingCode = false;
      });
    }
  }
  // #endregion

  // #region JOINER TARAFI: KOD İLE KATILMA (GÜVENLİ TRANSACTION VERSİYONU)
  Future<void> _joinPairingCode() async {
    final String enteredCode = _joinCodeController.text.trim().toUpperCase();

    if (user == null) {
      _setErrorMessage("Kullanıcı oturumu bulunamadı.");
      return;
    }
    // Basit validasyon
    if (enteredCode.isEmpty || enteredCode.length < 6) {
      _setErrorMessage("Lütfen geçerli bir kod girin.");
      return;
    }

    setState(() {
      _isJoiningCode = true;
      _errorMessage = null;
    });

    try {
      // 1. Kodu Firestore'da ara (Ön kontrol)
      final codeDocSnapshot = await _db.collection('pairing_codes').doc(enteredCode).get();

      if (!codeDocSnapshot.exists) {
        throw Exception("Geçersiz kod.");
      }

      final codeData = codeDocSnapshot.data()!;
      final String hostUid = codeData['host_uid'];
      final Timestamp expiresAt = codeData['expires_at'];
      final bool isUsed = codeData['is_used'];

      // 2. Kodun geçerliliğini kontrol et (Ön kontroller)
      if (isUsed) throw Exception("Bu kod daha önce kullanılmış.");
      if (Timestamp.now().compareTo(expiresAt) > 0) throw Exception("Bu kodun süresi dolmuş.");
      if (hostUid == user!.uid) throw Exception("Kendi kodunuzla eşleşemezsiniz.");

      // ==============================================================================
      // 🔥 KRİTİK BÖLÜM: ATOMİK TRANSACTION BAŞLIYOR 🔥
      // Bu blok içindeki her şey ya hep birlikte başarılı olur, ya da hiçbiri olmaz.
      // ==============================================================================
      await _db.runTransaction((transaction) async {
        // Referansları al
        DocumentReference hostUserRef = _db.collection('users').doc(hostUid);
        DocumentReference joinerUserRef = _db.collection('users').doc(user!.uid);
        DocumentReference pairingCodeRef = _db.collection('pairing_codes').doc(enteredCode);

        // (Opsiyonel ama Ekstra Güvenlik): Transaction içinde dokümanların hala var olduğunu teyit et.
        // Transaction içinde bir "get" (okuma) işlemi yapmak, o dokümanı kilitler.
        DocumentSnapshot hostSnapshot = await transaction.get(hostUserRef);
        if (!hostSnapshot.exists) {
          throw Exception("Kodun sahibi olan kullanıcı bulunamadı. İşlem iptal edildi.");
        }

        // a) Host (davet eden) kullanıcının partner_uid alanını güncelle
        transaction.update(hostUserRef, {
          'partner_uid': user!.uid,
          'paired_at': FieldValue.serverTimestamp(),
        });

        // b) Joiner (katılan - mevcut) kullanıcının partner_uid alanını güncelle
        transaction.update(joinerUserRef, {
          'partner_uid': hostUid,
          'paired_at': FieldValue.serverTimestamp(),
        });

        // c) Kodu kullanılmış olarak işaretle
        transaction.update(pairingCodeRef, {
          'is_used': true,
          'used_by': user!.uid,
          'used_at': FieldValue.serverTimestamp(),
        });

        // Transaction bloğunun sonuna gelindiğinde, Firebase tüm bu güncellemeleri
        // tek bir atomik paket olarak sunucuya gönderir.
      });
      // ==============================================================================
      // 🔥 TRANSACTION BAŞARIYLA TAMAMLANDI 🔥
      // ==============================================================================

      // 4. Başarılı Eşleşme Sonrası Yönlendirme
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("✅ Eşleşme güvenli bir şekilde tamamlandı! Yönlendiriliyorsunuz...", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ));

      // Ana ekrana dön (Orası zaten partneri algılayıp Active Dashboard'a yönlendirecek)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );

    } catch (e) {
      // Transaction içinde veya ön kontrollerde bir hata olursa buraya düşer.
      // Hata mesajını kullanıcıya göster.
      // Eğer hata "Exception:" kelimesiyle başlıyorsa, temizleyip gösterelim.
      String errorMessage = e.toString();
      if (errorMessage.startsWith("Exception: ")) {
        errorMessage = errorMessage.substring(11);
      }
      _setErrorMessage(errorMessage);

    } finally {
      setState(() {
        _isJoiningCode = false;
        _joinCodeController.clear();
      });
    }
  }
  // #endregion

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "PARTNER EŞLEŞTİRME",
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kAccentCyan,
          labelColor: kAccentCyan,
          unselectedLabelColor: kTextGrey,
          labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "DAVET ET"),
            Tab(text: "KATIL"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInviteTab(),
          _buildJoinTab(),
        ],
      ),
    );
  }

  // --- SEKME 1: DAVET ET (Host) ---
  Widget _buildInviteTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_rounded, size: 80, color: kAccentCyan),
          const SizedBox(height: 24),
          Text(
            "Partnerini Davet Et",
            style: GoogleFonts.montserrat(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            "Aşağıdaki kodu partnerinle paylaş. Kod 5 dakika boyunca geçerlidir.",
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 14),
          ),
          const SizedBox(height: 40),

          // Kod Gösterge Alanı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kAccentCyan.withOpacity(0.5), width: 2),
            ),
            child: _isGeneratingCode
                ? CircularProgressIndicator(color: kAccentCyan)
                : SelectableText(
                    _generatedCode ?? "KOD ÜRETİLMEDİ",
                    style: GoogleFonts.montserrat(
                      color: kAccentCyan,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4.0,
                    ),
                  ),
          ),
          const SizedBox(height: 40),

          // Kod Üret Butonu
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isGeneratingCode ? null : _generatePairingCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentCyan,
                foregroundColor: kBgDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isGeneratingCode
                  ? const CircularProgressIndicator(color: kBgDark)
                  : Text(
                      _generatedCode == null ? "KOD OLUŞTUR" : "YENİ KOD OLUŞTUR",
                      style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SEKME 2: KATIL (Joiner) ---
  Widget _buildJoinTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_rounded, size: 80, color: kAccentCyan),
          const SizedBox(height: 24),
          Text(
            "Bir Davete Katıl",
            style: GoogleFonts.montserrat(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            "Partnerinin paylaştığı 8 haneli kodu aşağıya gir.",
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(color: kTextGrey, fontSize: 14),
          ),
          const SizedBox(height: 40),

          // Kod Giriş Alanı
          TextField(
            controller: _joinCodeController,
            style: GoogleFonts.montserrat(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4.0),
            textAlign: TextAlign.center,
            maxLength: 8,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: "A1B2C3D4",
              hintStyle: TextStyle(color: kTextGrey.withOpacity(0.3)),
              counterText: "", // Karakter sayacını gizle
              filled: true,
              fillColor: kCardBg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kTextGrey.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kAccentCyan, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Eşleş Butonu
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isJoiningCode ? null : _joinPairingCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentCyan,
                foregroundColor: kBgDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isJoiningCode
                  ? const CircularProgressIndicator(color: kBgDark)
                  : Text(
                      "EŞLEŞMEYİ TAMAMLA",
                      style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}