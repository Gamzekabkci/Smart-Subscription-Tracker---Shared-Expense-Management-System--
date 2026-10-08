import 'package:flutter/material.dart';

class AppThemes {
  // --- AÇIK TEMA (Light Mode) ---
  static final ThemeData lightTheme = ThemeData.light().copyWith(
    scaffoldBackgroundColor: const Color(0xFFF4F6F9), // Çok açık, modern gri-mavi bir arka plan
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF4CAF50), // Neon yeşilin açık temadaki yumuşak hali
      surface: Colors.white, // Kartlar bembeyaz ve temiz duracak
      secondary: Color(0xFFE0E5EC),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF4F6F9),
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black87), // AppBar ikonları koyu renk
    ),
    textTheme: ThemeData.light().textTheme.apply(
      fontFamily: 'Roboto',
      bodyColor: const Color(0xFF2C3E50), // Yazılar tam siyah değil, şık bir koyu lacivert/gri
      displayColor: const Color(0xFF2C3E50),
    ),
  );

  // --- KOYU TEMA (Dark Mode - Senin Orijinal Tasarımın) ---
  static final ThemeData darkTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: const Color(0xFF10121D), // Derin charcoal
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF8CFF32), // Neon Yeşil
      surface: Color(0xFF1C1E2D), // Kartlar/Giriş alanları
      secondary: Color(0xFF1C1E2D),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF10121D),
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    textTheme: ThemeData.dark().textTheme.apply(
      fontFamily: 'Roboto',
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
  );
}