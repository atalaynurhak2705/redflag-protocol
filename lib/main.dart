import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase kütüphanesi
import 'firebase_options.dart'; // Az önce oluşan ayar dosyası
import 'screens/login_screen.dart';

Future<void> main() async {
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