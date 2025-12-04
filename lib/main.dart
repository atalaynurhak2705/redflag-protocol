import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  // Global error handler - AssetManifest.json hatasını sessizce yakala
  FlutterError.onError = (FlutterErrorDetails details) {
    // AssetManifest.json hatasını sessizce geç
    if (details.exception.toString().contains('AssetManifest.json') ||
        details.exception.toString().contains('Unable to load asset')) {
      // Sessizce geç, terminalde gösterme
      return;
    }
    // Diğer hataları normal şekilde göster
    FlutterError.presentError(details);
  };

  // Platform-specific error handler (Android/iOS)
  PlatformDispatcher.instance.onError = (error, stack) {
    // AssetManifest.json hatasını sessizce geç
    if (error.toString().contains('AssetManifest.json') ||
        error.toString().contains('Unable to load asset')) {
      return true; // Hatayı yakaladık, devam et
    }
    // Diğer hataları göster
    return false;
  };

  // 1. Flutter motorunu hazırlıyoruz
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Firebase'i başlatıyoruz (Platforma göre otomatik ayar)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Uygulamayı çalıştırıyoruz
  runApp(const RedFlagApp());
}

class RedFlagApp extends StatelessWidget {
  const RedFlagApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RedFlag Protocol',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      // Şimdilik direkt Login ekranını açıyoruz
      home: const LoginScreen(),
    );
  }
}