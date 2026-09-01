import 'package:flutter/material.dart';

/// Dark is the only theme, chosen deliberately rather than flipped from a
/// light palette: surfaces are near-black, ink is layered, and the accent is
/// the one saturated colour so the spend line owns the eye.
class YumekoColors {
  static const background = Color(0xFF0E0E11);
  static const surface = Color(0xFF17171C);
  static const surfaceHigh = Color(0xFF20202A);
  static const accent = Color(0xFFB39DFF);
  static const ink = Color(0xFFECECF1);
  static const inkMuted = Color(0xFF9A9AA8);
  static const debit = Color(0xFFFF8A8A);
  static const credit = Color(0xFF7BE0A8);
}

final yumekoTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: YumekoColors.background,
  colorScheme: const ColorScheme.dark(
    primary: YumekoColors.accent,
    onPrimary: Color(0xFF1A1030),
    surface: YumekoColors.surface,
    onSurface: YumekoColors.ink,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: YumekoColors.background,
    foregroundColor: YumekoColors.ink,
    elevation: 0,
    centerTitle: false,
  ),
  cardTheme: const CardThemeData(
    color: YumekoColors.surface,
    elevation: 0,
    margin: EdgeInsets.zero,
  ),
  dividerTheme: const DividerThemeData(color: Color(0xFF26262F), space: 1),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: YumekoColors.ink),
    bodySmall: TextStyle(color: YumekoColors.inkMuted),
    titleMedium: TextStyle(color: YumekoColors.ink),
    labelLarge: TextStyle(color: YumekoColors.ink),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: YumekoColors.surfaceHigh,
    contentTextStyle: TextStyle(color: YumekoColors.ink),
  ),
);
