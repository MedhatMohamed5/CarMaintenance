import 'package:flutter/material.dart';

/// Picks legible ink for a given surface.
///
/// Threshold tests on luminance (`> 0.5`) fail on mid-tones: silver sits at
/// 0.4999 and gets white ink on a near-white body. Comparing the WCAG contrast
/// ratio of both candidates instead is decisive at every tone and needs no
/// per-colour special case.
class Contrast {
  const Contrast._();

  /// Near-black ink, dark enough to read on any light surface.
  static const Color darkInk = Color(0xFF14141A);

  static const Color lightInk = Color(0xFFFFFFFF);

  /// WCAG contrast ratio between two opaque colours: 1.0 is identical, 21.0 is
  /// black on white.
  static double ratio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Whichever of [darkInk] / [lightInk] reads better on [surface].
  static Color inkOn(Color surface) =>
      ratio(surface, darkInk) >= ratio(surface, lightInk) ? darkInk : lightInk;

  /// `true` when [surface] and [ink] clear the WCAG AA threshold for body text.
  static bool isLegible(Color surface, Color ink) => ratio(surface, ink) >= 4.5;
}
