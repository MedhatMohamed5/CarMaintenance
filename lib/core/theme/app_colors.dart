import 'package:flutter/material.dart';

/// Central colour palette. Every colour used across the app is defined here so
/// that light/dark themes stay perfectly in sync.
class AppColors {
  const AppColors._();

  // ── Brand / accent ramp ───────────────────────────────────────────────────
  static const Color cyan = Color(0xFF22D3EE);
  static const Color teal = Color(0xFF2DD4BF);
  static const Color green = Color(0xFF34D399);
  static const Color amber = Color(0xFFF59E0B);
  static const Color orange = Color(0xFFFB923C);
  static const Color red = Color(0xFFF87171);
  static const Color pink = Color(0xFFF472B6);
  static const Color blue = Color(0xFF3B82F6);
  static const Color indigo = Color(0xFF818CF8);
  static const Color purple = Color(0xFFA78BFA);

  // ── Dark surfaces ─────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0A0A0C);
  static const Color darkSurface = Color(0xFF141418);
  static const Color darkSurfaceHigh = Color(0xFF1C1C22);
  static const Color darkBorder = Color(0xFF2A2A32);
  static const Color darkTextPrimary = Color(0xFFF5F5F7);
  static const Color darkTextSecondary = Color(0xFF9A9AA6);

  // ── Light surfaces ────────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF4F5F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHigh = Color(0xFFEEF0F6);
  static const Color lightBorder = Color(0xFFDDE0EA);
  static const Color lightTextPrimary = Color(0xFF14141A);
  static const Color lightTextSecondary = Color(0xFF6B6B7B);

  /// Health ramp used by the consumable-parts visualiser and every progress bar.
  /// [t] is the *remaining* fraction of lifespan (1.0 = brand new).
  static Color health(double t) {
    if (t >= 0.60) return green;
    if (t >= 0.35) return teal;
    if (t >= 0.20) return amber;
    if (t >= 0.10) return orange;
    return red;
  }
}
