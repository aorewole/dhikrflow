import 'package:flutter/material.dart';

/// Calm, accessible, modern design system for Dhikr Counter.
///
/// Designed to evoke a peaceful digital tasbih experience without visual noise.
class AppTheme {
  // Brand color palette
  static const Color primaryGreen = Color(0xFF1E3A2F); // Deep Sage / Forest
  static const Color accentGold = Color(0xFFD4AF37); // Subtle gold
  static const Color softTeal = Color(0xFF2C5E50);
  static const Color warmSand = Color(0xFFF7F5F0); // Light background
  static const Color slateDark = Color(0xFF121816); // Dark background
  static const Color cardDark = Color(0xFF1A2320); // Dark card
  static const Color cardLight = Colors.white; // Light card
  static const Color textMutedLight = Color(0xFF6E7A75);
  static const Color textMutedDark = Color(0xFF9EABA6);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: warmSand,
      colorScheme: ColorScheme.light(
        primary: primaryGreen,
        secondary: softTeal,
        tertiary: accentGold,
        surface: cardLight,
        onPrimary: Colors.white,
        onSurface: const Color(0xFF1B2321),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: warmSand,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFF1B2321),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: Color(0xFF1B2321)),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E2D9), width: 1),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.w300,
          letterSpacing: -1.0,
          color: Color(0xFF1B2321),
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: Color(0xFF1B2321),
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1B2321),
        ),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF2C3834)),
        bodyMedium: TextStyle(fontSize: 14, color: textMutedLight),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: slateDark,
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFF4E8E76),
        secondary: accentGold,
        surface: cardDark,
        onPrimary: Colors.white,
        onSurface: const Color(0xFFE8EDE9),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: slateDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFFE8EDE9),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: Color(0xFFE8EDE9)),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF23302B), width: 1),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.w300,
          letterSpacing: -1.0,
          color: Color(0xFFE8EDE9),
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: Color(0xFFE8EDE9),
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE8EDE9),
        ),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFD0DCD6)),
        bodyMedium: TextStyle(fontSize: 14, color: textMutedDark),
      ),
    );
  }
}
