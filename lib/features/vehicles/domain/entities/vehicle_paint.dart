import 'package:flutter/material.dart';

import '../../../../core/theme/contrast.dart';

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

  /// Ink that stays legible **on** this paint, chosen by contrast ratio
  /// rather than a luminance threshold. See [Contrast.inkOn].
  Color get onColor => Contrast.inkOn(color);

  /// Hairline separating this paint from the surface behind it, in whichever
  /// ink already reads against it.
  Color get outline => onColor.withValues(alpha: 0.28);
}
