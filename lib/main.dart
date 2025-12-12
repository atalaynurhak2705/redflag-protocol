import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

// Firebase Ayarları
import 'firebase_options.dart'; 

// Ekranlar
import 'screens/landing_screen.dart'; // <-- YENİ: Giriş Kapısı
import 'screens/main_screen.dart';    // <-- V5.0: Zincir Kontrol Merkezi
// import 'screens/login_screen.dart'; // Artık direkt buraya gitmiyoruz

// Servisler
import 'services/background_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(dynamic notification) {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Status bar şeffaflığı (Modern Görünüm)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Eğer oturum açıksa servisi başlat
  if (FirebaseAuth.instance.currentUser != null) {
    BackgroundService().startService();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RedFlag Protocol',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050505),
        primaryColor: const Color(0xFF05D9E8),
        useMaterial3: true,
        textTheme: GoogleFonts.montserratTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// --- AUTH GATE (GİRİŞ KONTROLÜ) ---
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Bekleme (Splash)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF050505),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF05D9E8))),
          );
        }

        // 2. Giriş Yapılmış -> MAIN SCREEN (Zincir Kontrolü)
        if (snapshot.hasData) {
          BackgroundService().startService();
          // V5.0 KURALI: Direkt Dashboard değil, MainScreen açılır.
          // MainScreen partner kontrolü yapar: Yoksa Zincir, Varsa Dashboard.
          return const MainScreen(); 
        }

        // 3. Giriş Yapılmamış -> LANDING PAGE (Karşılama Ekranı)
        // Kullanıcı buradan Login veya Register'a gider.
        return const LandingScreen();
      },
    );
  }
}