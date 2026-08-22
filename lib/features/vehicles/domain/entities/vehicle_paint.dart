import 'package:flutter/material.dart';

enum VehiclePaint {
  black(l10nKey: 'paintBlack', colorValue: 0xFF14141A, accentValue: 0xFF9AA3B2),
  white(l10nKey: 'paintWhite', colorValue: 0xFFF3F5F8, accentValue: 0xFF7DD3FC),
  silver(
    l10nKey: 'paintSilver',
    colorValue: 0xFFB6BCC6,
    accentValue: 0xFFB6BCC6,
  ),
  navy(l10nKey: 'paintNavy', colorValue: 0xFF1E3A6E, accentValue: 0xFF3B82F6),
  red(l10nKey: 'paintRed', colorValue: 0xFFB3261E, accentValue: 0xFFF87171),
  olive(l10nKey: 'paintOlive', colorValue: 0xFF4B5320, accentValue: 0xFF84CC16),
  bronze(
    l10nKey: 'paintBronze',
    colorValue: 0xFF7A5230,
    accentValue: 0xFFD9A066,
  );

  const VehiclePaint({
    required this.l10nKey,
    required this.colorValue,
    required this.accentValue,
  });

  final String l10nKey;
  final int colorValue;

  /// Body colours make poor UI accents — black vanishes on a dark theme and
  /// white blows out on a light one. Each paint therefore carries a legible
  /// companion tone used for cards, bars and glows.
  final int accentValue;

  Color get color => Color(colorValue);

  Color get accent => Color(accentValue);

  /// What a brand-new vehicle starts on: the head of the palette, so the
  /// selection matches the first swatch the user sees rather than an arbitrary
  /// entry in the middle of the row.
  static VehiclePaint get defaultPaint => VehiclePaint.values.first;

  static VehiclePaint fromValue(int? value) => VehiclePaint.values.firstWhere(
    (p) => p.colorValue == value,
    orElse: () => defaultPaint,
  );

  static Color accentFor(int? value) =>
      value == null ? defaultPaint.accent : fromValue(value).accent;

  /// Near-black ink, dark enough to read on any light body.
  static const Color _darkInk = Color(0xFF14141A);

  /// Ink that stays legible **on** this paint.
  ///
  /// Picked by **contrast ratio**, not by a luminance threshold. Silver sits at
  /// luminance 0.4999 — a hair under any `> 0.5` test — so a threshold handed
  /// it white ink on a near-white disc and the tick vanished. Comparing both
  /// candidates instead gives silver dark ink by a factor of five, and needs no
  /// per-colour special case.
  Color get onColor =>
      _contrast(color, _darkInk) >= _contrast(color, const Color(0xFFFFFFFF))
      ? _darkInk
      : const Color(0xFFFFFFFF);

  /// Hairline separating this paint from the surface behind it, in whichever
  /// ink already reads against it.
  Color get outline => onColor.withValues(alpha: 0.28);

  /// WCAG contrast ratio between two opaque colours: 1.0 is identical, 21.0 is
  /// black on white.
  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }
}
