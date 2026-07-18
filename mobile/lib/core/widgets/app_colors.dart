import 'package:flutter/material.dart';

/// Static semantic and crowd-density color constants.
/// Use these wherever Theme.of(context) is not available
/// (e.g., CustomPainter, static helpers).
class AppColors {
  AppColors._();

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22CC88);
  static const Color warning = Color(0xFFFFB800);
  static const Color danger  = Color(0xFFFF4455);

  // ── Crowd density ─────────────────────────────────────────────────────────
  static const Color crowdEmpty    = Color(0xFF22CC88);
  static const Color crowdLow      = Color(0xFF88DD44);
  static const Color crowdModerate = Color(0xFFFFB800);
  static const Color crowdHigh     = Color(0xFFFF7722);
  static const Color crowdFull     = Color(0xFFFF4455);

  /// Returns the crowd color for [density] in [0, 1].
  static Color forDensity(double density) {
    if (density < 0.20) return crowdEmpty;
    if (density < 0.40) return crowdLow;
    if (density < 0.60) return crowdModerate;
    if (density < 0.80) return crowdHigh;
    return crowdFull;
  }

  /// Returns a Portuguese label for [density] in [0, 1].
  static String crowdLabel(double density) {
    if (density < 0.20) return 'Vazio';
    if (density < 0.40) return 'Baixo';
    if (density < 0.60) return 'Moderado';
    if (density < 0.80) return 'Alto';
    return 'Lotado';
  }
}
