import 'package:flutter/material.dart';

/// WCAG AAA high-contrast dark theme optimized for low-vision & TalkBack users.
class OpenetraTheme {
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF111418);
  static const Color surfaceElevated = Color(0xFF1A2028);
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFE0E6ED);
  static const Color accent = Color(0xFFFFD600);
  static const Color accentText = Color(0xFF000000);
  static const Color hazardCritical = Color(0xFFFF5252);
  static const Color hazardWarning = Color(0xFFFFAB00);
  static const Color okGreen = Color(0xFF69F0AE);
  static const Color border = Color(0xFF4A5568);

  static ThemeData buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: accentText,
        secondary: okGreen,
        onSecondary: accentText,
        surface: surface,
        onSurface: primaryText,
        error: hazardCritical,
        onError: accentText,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: primaryText,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: primaryText,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: primaryText,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          height: 1.4,
          color: primaryText,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          height: 1.4,
          color: secondaryText,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: primaryText,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 68),
          backgroundColor: surfaceElevated,
          foregroundColor: primaryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: border, width: 1.5),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
