import 'package:flutter/material.dart';

/// Design tokens for Mercury's dark UI. Cool slate surfaces layered from
/// darkest (server rail) to lightest (message hover), with a violet accent.
abstract final class MercuryColors {
  static const rail = Color(0xFF0E1015);
  static const sidebar = Color(0xFF15171E);
  static const surface = Color(0xFF1B1E26);
  static const surfaceRaised = Color(0xFF232733);
  static const surfaceHover = Color(0xFF262A36);
  static const border = Color(0xFF2C3140);

  static const accent = Color(0xFF7C6CF2);
  static const accentSoft = Color(0x337C6CF2);
  static const success = Color(0xFF3DD68C);
  static const warning = Color(0xFFF2B84B);
  static const danger = Color(0xFFF2545B);

  static const textPrimary = Color(0xFFE8EAF0);
  static const textSecondary = Color(0xFFA3A9B8);
  static const textMuted = Color(0xFF6E7586);

  static const ownBubble = Color(0xFF262445);
  static const bubble = Color(0xFF20232D);
  static const codeBackground = Color(0xFF12141A);
}

abstract final class MercuryTheme {
  static ThemeData dark({Color? accent, Color? surface}) {
    final effectiveAccent = accent ?? MercuryColors.accent;
    final effectiveSurface = surface ?? MercuryColors.surface;

    final scheme = ColorScheme.fromSeed(
      seedColor: effectiveAccent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: effectiveAccent,
      surface: effectiveSurface,
      onSurface: MercuryColors.textPrimary,
      error: MercuryColors.danger,
      outlineVariant: MercuryColors.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: effectiveSurface,
      visualDensity: VisualDensity.standard,
    );

    const fontFallbacks = [
      'Segoe UI Emoji',
      'Apple Color Emoji',
      'Noto Color Emoji',
      'Segoe UI',
      'Roboto',
      'Helvetica Neue',
      'Arial',
      'sans-serif',
    ];

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: MercuryColors.textPrimary,
        displayColor: MercuryColors.textPrimary,
        fontFamilyFallback: fontFallbacks,
      ),
      dividerTheme: const DividerThemeData(
        color: MercuryColors.border,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: MercuryColors.rail,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: MercuryColors.border),
        ),
        textStyle: const TextStyle(
          color: MercuryColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        waitDuration: const Duration(milliseconds: 400),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: MercuryColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: MercuryColors.border),
        ),
        textStyle: const TextStyle(
          color: MercuryColors.textPrimary,
          fontSize: 14,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MercuryColors.surfaceRaised,
        contentTextStyle: const TextStyle(color: MercuryColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MercuryColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: MercuryColors.sidebar,
        surfaceTintColor: Colors.transparent,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: MercuryColors.textSecondary),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(MercuryColors.border),
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(6),
      ),
    );
  }
}
