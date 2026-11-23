import 'package:flutter/material.dart';

/// Semantic spacing, corner radii, and accessible touch-target tokens.
class OpenetraSpacing {
  const OpenetraSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusPill = 999;

  static const double minTouchTarget = 48;
  static const double primaryTouchTarget = 68;
}

/// Restrained native-Flutter motion tokens honoring system reduced-motion.
class OpenetraMotion {
  const OpenetraMotion._();

  static const Duration instant = Duration.zero;
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration emphasized = Duration(milliseconds: 300);
  static const Duration pulse = Duration(milliseconds: 1600);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;

  static Duration resolve(
    BuildContext context,
    Duration target, {
    bool reducedMotion = false,
  }) {
    if (reducedMotion || MediaQuery.disableAnimationsOf(context)) {
      return Duration.zero;
    }
    return target;
  }
}

/// Complete WCAG-calibrated semantic color palette for both Dark (Deep
/// Aubergine) and Light (Warm White) Openetra themes.
@immutable
class OpenetraPalette extends ThemeExtension<OpenetraPalette> {
  const OpenetraPalette({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.onAccent,
    required this.border,
    required this.focus,
    required this.success,
    required this.warning,
    required this.error,
    required this.disabled,
    required this.info,
    required this.dialOrbFill,
  });

  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color onAccent;
  final Color border;
  final Color focus;
  final Color success;
  final Color warning;
  final Color error;
  final Color disabled;
  final Color info;
  final Color dialOrbFill;

  /// Deep Aubergine dark palette (WCAG AAA >= 7:1 body text).
  static const OpenetraPalette dark = OpenetraPalette(
    primary: Color(0xFFC7A6FF), // Refined Lavender
    secondary: Color(0xFFFF9A3C), // Warm Orange
    background: Color(0xFF120B1A), // Deep Aubergine
    surface: Color(0xFF1E132B), // Dark Plum
    surfaceElevated: Color(0xFF2B1C3D), // Layered Plum
    textPrimary: Color(0xFFF8F5FF), // Soft White (>15:1)
    textSecondary: Color(0xFFCEC4E0), // Muted Lavender-Grey (>10:1)
    onAccent: Color(0xFF120B1A), // Deep Aubergine on orange/lavender
    border: Color(0xFF53416B), // Refined plum hairline
    focus: Color(0xFFC7A6FF),
    success: Color(0xFF6FE3A8),
    warning: Color(0xFFFFB84D),
    error: Color(0xFFFF6B6B),
    disabled: Color(0xFF6D5E82),
    info: Color(0xFFA5D8FF),
    dialOrbFill: Color(0xFF241634),
  );

  /// Warm White daylight palette for low-vision users (WCAG AAA >= 7:1 text).
  static const OpenetraPalette light = OpenetraPalette(
    primary: Color(0xFF5D27B8), // Deep Brand Violet (>8.2:1 on Warm White)
    secondary: Color(0xFFB84F00), // Deep Warm Orange (>5.0:1 on Warm White)
    background: Color(0xFFFFFDF9), // Warm White
    surface: Color(0xFFF4EEFB), // Soft Lavender Tint
    surfaceElevated: Color(0xFFFFFFFF), // Pure Elevated Card
    textPrimary: Color(0xFF230A36), // Deep Aubergine (>15:1)
    textSecondary: Color(0xFF4B3661), // Accessible Plum (>8.8:1)
    onAccent: Color(0xFFFFFDF9), // Warm White on deep violet/orange
    border: Color(0xFFC4B3DC), // Soft Plum Border
    focus: Color(0xFF5D27B8),
    success: Color(0xFF126E42), // Accessible Deep Green (>6.1:1)
    warning: Color(0xFF9E5200), // Accessible Deep Amber (>5.5:1)
    error: Color(0xFFB71C1C), // Accessible Deep Red (>6.4:1)
    disabled: Color(0xFF8B7E9E),
    info: Color(0xFF155A9C), // Accessible Deep Blue (>6.8:1)
    dialOrbFill: Color(0xFFFFFFFF),
  );

  @override
  OpenetraPalette copyWith({
    Color? primary,
    Color? secondary,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? onAccent,
    Color? border,
    Color? focus,
    Color? success,
    Color? warning,
    Color? error,
    Color? disabled,
    Color? info,
    Color? dialOrbFill,
  }) {
    return OpenetraPalette(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      onAccent: onAccent ?? this.onAccent,
      border: border ?? this.border,
      focus: focus ?? this.focus,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      disabled: disabled ?? this.disabled,
      info: info ?? this.info,
      dialOrbFill: dialOrbFill ?? this.dialOrbFill,
    );
  }

  @override
  OpenetraPalette lerp(ThemeExtension<OpenetraPalette>? other, double t) {
    if (other is! OpenetraPalette) return this;
    return OpenetraPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      border: Color.lerp(border, other.border, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      info: Color.lerp(info, other.info, t)!,
      dialOrbFill: Color.lerp(dialOrbFill, other.dialOrbFill, t)!,
    );
  }
}

/// Openetra brand design system: Deep Aubergine, Violet, Refined Lavender,
/// Warm Orange, and Warm White calibrated for WCAG AAA readability.
class OpenetraTheme {
  // Legacy dark constants retained for backward compatibility.
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

  /// Resolves the active semantic palette (Dark or Light) from [BuildContext].
  static OpenetraPalette paletteOf(BuildContext context) {
    final ext = Theme.of(context).extension<OpenetraPalette>();
    if (ext != null) return ext;
    return Theme.of(context).brightness == Brightness.light
        ? OpenetraPalette.light
        : OpenetraPalette.dark;
  }

  static ThemeData buildDarkTheme() => _buildTheme(
        brightness: Brightness.dark,
        palette: OpenetraPalette.dark,
      );

  static ThemeData buildLightTheme() => _buildTheme(
        brightness: Brightness.light,
        palette: OpenetraPalette.light,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required OpenetraPalette palette,
  }) {
    final colorScheme = brightness == Brightness.dark
        ? ColorScheme.dark(
            primary: palette.primary,
            onPrimary: palette.onAccent,
            secondary: palette.secondary,
            onSecondary: palette.onAccent,
            surface: palette.surface,
            onSurface: palette.textPrimary,
            error: palette.error,
            onError: palette.onAccent,
            outline: palette.border,
          )
        : ColorScheme.light(
            primary: palette.primary,
            onPrimary: palette.onAccent,
            secondary: palette.secondary,
            onSecondary: palette.onAccent,
            surface: palette.surface,
            onSurface: palette.textPrimary,
            error: palette.error,
            onError: palette.onAccent,
            outline: palette.border,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      colorScheme: colorScheme,
      extensions: [palette],
      textTheme: TextTheme(
        displaySmall: TextStyle(
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: palette.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: palette.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          height: 1.45,
          color: palette.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          height: 1.45,
          color: palette.textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: palette.textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: palette.textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
          color: palette.textSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
      ),
      cardTheme: CardTheme(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OpenetraSpacing.radiusMd),
          side: BorderSide(color: palette.border, width: 1.5),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OpenetraSpacing.radiusLg),
          side: BorderSide(color: palette.border, width: 1.5),
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 16,
          height: 1.45,
          color: palette.textSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        labelStyle: TextStyle(color: palette.textSecondary, fontSize: 16),
        hintStyle: TextStyle(color: palette.textSecondary, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: OpenetraSpacing.lg,
          vertical: OpenetraSpacing.md,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OpenetraSpacing.radiusMd),
          borderSide: BorderSide(color: palette.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OpenetraSpacing.radiusMd),
          borderSide: BorderSide(color: palette.focus, width: 2.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OpenetraSpacing.radiusMd),
          borderSide: BorderSide(color: palette.error, width: 2),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.secondary,
        inactiveTrackColor: palette.border,
        thumbColor: palette.primary,
        overlayColor: palette.primary.withOpacity(0.18),
        valueIndicatorColor: palette.surfaceElevated,
        valueIndicatorTextStyle: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, OpenetraSpacing.primaryTouchTarget),
          backgroundColor: palette.surfaceElevated,
          foregroundColor: palette.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OpenetraSpacing.radiusMd),
            side: BorderSide(color: palette.border, width: 1.5),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          minimumSize: const Size(
            OpenetraSpacing.minTouchTarget,
            OpenetraSpacing.minTouchTarget,
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: OpenetraSpacing.xl,
      ),
    );
  }
}
