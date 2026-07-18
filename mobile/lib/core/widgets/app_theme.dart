import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color primary  = Color(0xFF0055FF); // --color-primary
  static const Color accent   = Color(0xFF00C8FF); // --color-accent

  // ── Dark tokens ───────────────────────────────────────────────────────────
  static const Color bgDark          = Color(0xFF0A0A14);
  static const Color surfaceDark     = Color(0xFF13131F);
  static const Color surfRaisedDark  = Color(0xFF1C1C2E);
  static const Color borderDark      = Color(0xFF2A2A3A);
  static const Color textPrimDark    = Color(0xFFFFFFFF);
  static const Color textSecDark     = Color(0xFF8888AA);
  static const Color textDisDark     = Color(0xFF444455);

  // ── Light tokens ──────────────────────────────────────────────────────────
  static const Color bgLight         = Color(0xFFF5F5F7);
  static const Color surfaceLight    = Color(0xFFFFFFFF);
  static const Color surfRaisedLight = Color(0xFFEFEFEF);
  static const Color borderLight     = Color(0xFFE0E0E8);
  static const Color textPrimLight   = Color(0xFF0A0A14);
  static const Color textSecLight    = Color(0xFF555566);
  static const Color textDisLight    = Color(0xFFAAAABC);

  // ── Text themes ───────────────────────────────────────────────────────────
  static TextTheme _textTheme(Color textColor, Color secondaryColor) {
    return GoogleFonts.interTextTheme().copyWith(
      displayLarge:  GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.5),
      displayMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.5),
      titleLarge:    GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: textColor, letterSpacing: -0.3),
      titleMedium:   GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
      bodyLarge:     GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
      bodyMedium:    GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: textColor),
      bodySmall:     GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: secondaryColor),
      labelSmall:    GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: secondaryColor, letterSpacing: 1.0),
    );
  }

  // ── Shared builder ────────────────────────────────────────────────────────
  static ThemeData _build({
    required ColorScheme cs,
    required Color bg,
    required Color surface,
    required Color surfRaised,
    required Color border,
    required Color textPrim,
    required Color textSec,
    required Color textDis,
  }) {
    return ThemeData(
      useMaterial3:            true,
      colorScheme:             cs,
      scaffoldBackgroundColor: bg,
      hintColor:               textDis,
      textTheme:               _textTheme(textPrim, textSec),
      dividerColor:            border,
      cardTheme: CardThemeData(
        color:     surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:  bg,
        surfaceTintColor: Colors.transparent,
        elevation:        0,
        titleTextStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: textPrim),
        iconTheme:        IconThemeData(color: textPrim),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: surfRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: textSec),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation:       0,
          shadowColor:     Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ── Light ─────────────────────────────────────────────────────────────────
  static ThemeData light() {
    final cs = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary:   primary,
      secondary: accent,
      surface:   surfaceLight,
      onSurface: textPrimLight,
    );
    return _build(
      cs:        cs,
      bg:        bgLight,
      surface:   surfaceLight,
      surfRaised: surfRaisedLight,
      border:    borderLight,
      textPrim:  textPrimLight,
      textSec:   textSecLight,
      textDis:   textDisLight,
    );
  }

  // ── Dark ──────────────────────────────────────────────────────────────────
  static ThemeData dark() {
    final cs = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary:   primary,
      secondary: accent,
      surface:   surfaceDark,
      onSurface: textPrimDark,
    );
    return _build(
      cs:        cs,
      bg:        bgDark,
      surface:   surfaceDark,
      surfRaised: surfRaisedDark,
      border:    borderDark,
      textPrim:  textPrimDark,
      textSec:   textSecDark,
      textDis:   textDisDark,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static BoxDecoration cardDecoration(BuildContext context) {
    final dark = isDark(context);
    return BoxDecoration(
      color: dark ? surfaceDark : surfaceLight,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: dark ? borderDark : borderLight),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.30 : 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration surfaceRaisedDecoration(BuildContext context) {
    final dark = isDark(context);
    return BoxDecoration(
      color: dark ? surfRaisedDark : surfRaisedLight,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: dark ? borderDark : borderLight),
    );
  }
}
