import 'package:flutter/material.dart';

class AppTheme {
  // --- MASTER PALETTE ---
  
  // Dark Mode Tokens
  static const Color darkBg = Color(0xFF05070B);
  static const Color darkCard = Color(0xFF0B0F16);
  static const Color darkCardElevated = Color(0xFF0F1622);
  static const Color darkBorder = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const Color darkText = Color(0xFFEAF2FF);
  static const Color darkTextSecondary = Color(0xFF9FB1C5);
  static const Color darkInput = Color(0xFF0A0E15);
  // Shadow: 0 12 40 rgba(0,0,0,0.55)

  // Light Mode Tokens
  static const Color lightBg = Color(0xFFF6F8FB);
  static const Color lightScaffoldBackgroundColor = lightBg; // Added for completeness
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurfaceColor = lightCard;

  static const Color lightBorder = Color(0x1F0F172A); // rgba(15,23,42,0.12)
  static const Color lightText = Color(0xFF0B1220);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightInput = Color(0xFFF1F5F9);
  // Shadow: 0 10 30 rgba(15,23,42,0.08)

  // Accent Palette (Shared)
  static const Color accentBlue = Color(0xFF2D5BFF);
  static const Color accentPurple = Color(0xFF8B2CFF);
  static const Color accentGreen = Color(0xFF00A030);
  static const Color accentOrange = Color(0xFFFF6A00);
  static const Color accentYellow = Color(0xFFF0B000);
  static const Color accentCyan = Color(0xFF00E5FF);

  // Aliases for Neon Theme
  static const Color neonBlue = accentBlue;
  static const Color neonGreen = accentGreen;
  static const Color neonPurple = accentPurple;
  static const Color neonOrange = accentOrange;

  static const Color primaryColor = accentBlue; // Default Primary

  // Compatibility Getters
  static const Color scaffoldBackgroundColor = darkBg;
  static const Color surfaceColor = darkCard;
  static const Color errorColor = accentOrange; // Mapping error to orange/red
  static const Color successColor = accentGreen;
  static const Color warningColor = accentYellow;


  // --- THEMES ---

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentPurple,
        surface: darkCard,
        background: darkBg,
        error: accentOrange, // Using Orange for error/warning based on palette availability or default red
        onPrimary: Colors.white,
        onSurface: darkText,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: darkText, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        displayMedium: TextStyle(color: darkText, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        bodyLarge: TextStyle(color: darkText, fontFamily: 'Inter'),
        bodyMedium: TextStyle(color: darkTextSecondary, fontFamily: 'Inter'),
        labelLarge: TextStyle(color: darkText, fontFamily: 'Inter', fontWeight: FontWeight.w600),
      ),
      cardTheme: CardTheme(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), 
            side: const BorderSide(color: darkBorder)
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInput,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor),
        ),
        hintStyle: const TextStyle(color: darkTextSecondary),
        labelStyle: const TextStyle(color: darkTextSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          minimumSize: const Size(double.infinity, 54),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, fontFamily: 'Inter'),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: darkText, fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
        iconTheme: IconThemeData(color: darkText),
      ),
    );
  }

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentPurple,
        surface: lightCard,
        background: lightBg,
        error: accentOrange,
        onPrimary: Colors.white,
        onSurface: lightText,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: lightText, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        displayMedium: TextStyle(color: lightText, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        bodyLarge: TextStyle(color: lightText, fontFamily: 'Inter'),
        bodyMedium: TextStyle(color: lightTextSecondary, fontFamily: 'Inter'),
        labelLarge: TextStyle(color: lightText, fontFamily: 'Inter', fontWeight: FontWeight.w600),
      ),
      cardTheme: CardTheme(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), 
            side: const BorderSide(color: lightBorder)
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightInput,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor),
        ),
        hintStyle: const TextStyle(color: lightTextSecondary),
        labelStyle: const TextStyle(color: lightTextSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          minimumSize: const Size(double.infinity, 54),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, fontFamily: 'Inter'),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: lightText, fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
        iconTheme: IconThemeData(color: lightText),
      ),
    );
  }
}
