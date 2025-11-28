import 'package:flutter/material.dart';

// --- RENK PALETİ (UI Kit'ten Analiz Edildi) ---
class AppColors {
  // Ana Renkler
  static const Color primaryBlue = Color(0xFF00E5FF); // Parlak Cyan/Turkuaz
  static const Color accentOrange = Color(0xFFFF3D00); // Uyarı/Vurgu Kırmızı-Turuncu

  // Zemin Renkleri
  static const Color backgroundDark = Color(0xFF121212); // Ana arka plan (Çok koyu gri)
  static const Color surfaceDark = Color(0xFF1E1E1E); // <<< BU SATIR EKSİKMİŞ, EKLENDİ
  
  // Metin Renkleri
  static const Color textWhite = Color(0xFFFFFFFF); // Başlıklar
  static const Color textGrey = Color(0xFFB0BEC5); // Alt başlıklar, placeholderlar
  
  // Diğer
  static const Color successGreen = Color(0xFF00C853); // İlerde lazım olur
}

// --- ORTAK STİLLER ---
class AppStyles {
  // Yuvarlatılmış Köşeler (Buton ve Kartlar için standart)
  static BorderRadius defaultRadius = BorderRadius.circular(14.0);

  // Input Alanı Dekorasyonu (UI Kit'teki gibi)
  static InputDecoration inputDecoration(String hintText, IconData icon) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.surfaceDark,
      prefixIcon: Icon(icon, color: AppColors.textGrey),
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.textGrey),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: defaultRadius,
        borderSide: BorderSide.none, // Kenarlık yok
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: defaultRadius,
        borderSide: BorderSide(color: AppColors.surfaceDark.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: defaultRadius,
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
      ),
    );
  }

  // Ana Buton Stili (Mavi)
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primaryBlue,
    foregroundColor: Colors.black, // Yazı rengi koyu olsun ki okunsun
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: defaultRadius),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    elevation: 0, // Gölge yok, düz tasarım
  );

  // İkincil Buton Stili (Koyu)
  static ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.surfaceDark,
    foregroundColor: AppColors.textWhite,
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: defaultRadius,
      side: BorderSide(color: AppColors.textGrey.withOpacity(0.2)), // Hafif kenarlık
    ),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    elevation: 0,
  );
}