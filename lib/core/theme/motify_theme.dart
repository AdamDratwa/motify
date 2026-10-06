import 'package:flutter/material.dart';

/// Motify's palette: a near-black terminal with neon accents. Exposed
/// directly (not only via ColorScheme) for the glow effects and status tags.
/// The native lock screen (LockActivity.kt) uses the same values — keep in sync.
abstract final class MotifyColors {
  static const background = Color(0xFF05080A);
  static const surface = Color(0xFF0A0F12);
  static const panel = Color(0xFF0D1417);
  static const panelHigh = Color(0xFF121B1F);
  static const panelHighest = Color(0xFF18242A);

  /// Primary neon green: progress, unlocked, actions.
  static const neon = Color(0xFF00FF9C);
  static const onNeon = Color(0xFF00170D);

  /// Secondary cyan: free windows, info.
  static const cyan = Color(0xFF00E5FF);

  /// Locked / errors.
  static const danger = Color(0xFFFF2E63);

  static const text = Color(0xFFD5FBEA);
  static const textDim = Color(0xFF6E9487);
  static const line = Color(0xFF1C3A31);
  static const lineDim = Color(0xFF12241F);
}

class MotifyTheme {
  static const fontFamily = 'JetBrainsMono';

  /// Neon glow for text drawn in [color].
  static List<Shadow> glow(Color color, {double blur = 12}) => [
        Shadow(color: color.withValues(alpha: 0.7), blurRadius: blur),
      ];

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: MotifyColors.neon,
      onPrimary: MotifyColors.onNeon,
      primaryContainer: Color(0xFF003D26),
      onPrimaryContainer: MotifyColors.neon,
      secondary: MotifyColors.cyan,
      onSecondary: Color(0xFF00161A),
      tertiary: MotifyColors.cyan,
      error: MotifyColors.danger,
      onError: Color(0xFF1A0008),
      errorContainer: Color(0xFF2A0711),
      onErrorContainer: Color(0xFFFFB3C4),
      surface: MotifyColors.surface,
      onSurface: MotifyColors.text,
      onSurfaceVariant: MotifyColors.textDim,
      surfaceContainerLowest: MotifyColors.background,
      surfaceContainerLow: MotifyColors.surface,
      surfaceContainer: MotifyColors.panel,
      surfaceContainerHigh: MotifyColors.panelHigh,
      surfaceContainerHighest: MotifyColors.panelHighest,
      outline: MotifyColors.line,
      outlineVariant: MotifyColors.lineDim,
    );

    const radius = BorderRadius.all(Radius.circular(4));
    const buttonText = TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: fontFamily,
    );

    return base.copyWith(
      scaffoldBackgroundColor: MotifyColors.background,
      textTheme: base.textTheme.apply(
        bodyColor: MotifyColors.text,
        displayColor: MotifyColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: MotifyColors.background,
        foregroundColor: MotifyColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: MotifyColors.neon,
        ),
      ),
      cardTheme: const CardThemeData(
        color: MotifyColors.panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: MotifyColors.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MotifyColors.neon,
          foregroundColor: MotifyColors.onNeon,
          disabledBackgroundColor: MotifyColors.panelHighest,
          shape: const RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MotifyColors.neon,
          side: const BorderSide(color: MotifyColors.neon),
          shape: const RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MotifyColors.neon,
          textStyle: buttonText,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: MotifyColors.neon,
        foregroundColor: MotifyColors.onNeon,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius),
        extendedTextStyle: buttonText,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: MotifyColors.surface,
        labelStyle: TextStyle(color: MotifyColors.textDim),
        hintStyle: TextStyle(color: MotifyColors.textDim),
        prefixIconColor: MotifyColors.textDim,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: MotifyColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: MotifyColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: MotifyColors.neon, width: 1.5),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: MotifyColors.neon,
        linearTrackColor: MotifyColors.panelHighest,
        circularTrackColor: MotifyColors.panelHighest,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? MotifyColors.onNeon
              : MotifyColors.textDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? MotifyColors.neon
              : MotifyColors.panelHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(MotifyColors.line),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: MotifyColors.textDim,
        textColor: MotifyColors.text,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MotifyColors.panelHighest,
        contentTextStyle: TextStyle(fontFamily: fontFamily, color: MotifyColors.text),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: MotifyColors.line),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MotifyColors.surface,
        dragHandleColor: MotifyColors.line,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          side: BorderSide(color: MotifyColors.line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: MotifyColors.lineDim),
    );
  }
}
