import 'package:flutter/material.dart';

class AppTheme {
  // Couleurs Pulse
  static const Color primary   = Color(0xFF1D9E75);
  static const Color secondary = Color(0xFFEF9F27);
  static const Color background = Color(0xFFF8F9FA);
  static const Color white     = Color(0xFFFFFFFF);
  static const Color textDark  = Color(0xFF1A1A2E);
  static const Color textGray  = Color(0xFF6B7280);
  static const Color error     = Color(0xFFE24B4A);

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      background: background,
    ),
    scaffoldBackgroundColor: background,
    fontFamily: 'SF Pro Display',

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: white,
      foregroundColor: textDark,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textDark,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),

    // Boutons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Champs de texte
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 14,
      ),
    ),
  );
}