import 'package:flutter/material.dart';

import 'app_fonts.dart';

class AppTypography {
  const AppTypography._();

  // Arabic is cursive: any letter spacing breaks the joins and throws the
  // caret off, so it gets none.
  static TextTheme textTheme(
    Color primary,
    Color secondary, {
    bool arabic = false,
  }) {
    final base = Typography.material2021().black.apply(
      fontFamily: AppFonts.family,
    );

    final themed = AppFonts.applyTheme(
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
    return arabic ? _withoutSpacing(themed) : themed;
  }

  static TextTheme _withoutSpacing(TextTheme t) {
    TextStyle? flat(TextStyle? style) => style?.copyWith(letterSpacing: 0);
    return t.copyWith(
      displayLarge: flat(t.displayLarge),
      displayMedium: flat(t.displayMedium),
      displaySmall: flat(t.displaySmall),
      headlineLarge: flat(t.headlineLarge),
      headlineMedium: flat(t.headlineMedium),
      headlineSmall: flat(t.headlineSmall),
      titleLarge: flat(t.titleLarge),
      titleMedium: flat(t.titleMedium),
      titleSmall: flat(t.titleSmall),
      bodyLarge: flat(t.bodyLarge),
      bodyMedium: flat(t.bodyMedium),
      bodySmall: flat(t.bodySmall),
      labelLarge: flat(t.labelLarge),
      labelMedium: flat(t.labelMedium),
      labelSmall: flat(t.labelSmall),
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
