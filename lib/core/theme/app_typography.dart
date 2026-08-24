import 'package:flutter/material.dart';

import 'app_fonts.dart';

class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(Color primary, Color secondary) {
    final base = Typography.material2021().black.apply(
      fontFamily: AppFonts.family,
    );

    return AppFonts.applyTheme(
      base
          .copyWith(
            displaySmall: base.displaySmall?.copyWith(
              fontSize: 32,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
            headlineMedium: base.headlineMedium?.copyWith(
              fontSize: 26,
              height: 1.18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
            headlineSmall: base.headlineSmall?.copyWith(
              fontSize: 22,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
            titleLarge: base.titleLarge?.copyWith(
              fontSize: 19,
              height: 1.25,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            titleMedium: base.titleMedium?.copyWith(
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
            titleSmall: base.titleSmall?.copyWith(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
            bodyLarge: base.bodyLarge?.copyWith(
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
            bodyMedium: base.bodyMedium?.copyWith(
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
            bodySmall: base.bodySmall?.copyWith(
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: secondary,
            ),
            labelLarge: base.labelLarge?.copyWith(
              fontSize: 15,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
            labelMedium: base.labelMedium?.copyWith(
              fontSize: 12.5,
              height: 1.25,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
            labelSmall: base.labelSmall?.copyWith(
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: secondary,
            ),
          )
          .apply(bodyColor: primary, displayColor: primary),
    );
  }

  /// Tabular figures for odometer / money readouts so digits never jitter
  /// while a counter animates.
  static TextStyle numeric(TextStyle? base) => AppFonts.apply(base).copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
