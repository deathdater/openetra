import 'package:flutter/material.dart';

/// Openetra brand design system: Deep Aubergine, Dark Plum, Refined Lavender,
/// and Warm Orange calibrated for WCAG AAA (>= 7:1) readability and calm focus.
class OpenetraTheme {
  static const Color background = Color(0xFF120B1A); // Deep Aubergine
  static const Color surface = Color(0xFF1E132B); // Dark Plum
  static const Color surfaceElevated = Color(0xFF2B1C3D); // Layered Plum
  static const Color primaryText = Color(0xFFF8F5FF); // Soft White (>15:1)
  static const Color secondaryText = Color(0xFFCEC4E0); // Muted Lavender-Grey (>10:1)
  static const Color accentLavender = Color(0xFFC7A6FF); // Primary Refined Lavender
  static const Color accent = Color(0xFFFF9A3C); // Secondary Warm Orange
  static const Color accentText = Color(0xFF120B1A); // Deep Aubergine on accent
  static const Color hazardCritical = Color(0xFFFF6B6B); // Accessible muted red
  static const Color hazardWarning = Color(0xFFFFB84D); // Warm amber
  static const Color okGreen = Color(0xFF6FE3A8); // Accessible muted green
  static const Color border = Color(0xFF53416B); // Refined plum hairline

  static ThemeData buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accentLavender,
        onPrimary: accentText,
        secondary: accent,
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
          letterSpacing: -0.2,
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
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: border, width: 1.5),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
