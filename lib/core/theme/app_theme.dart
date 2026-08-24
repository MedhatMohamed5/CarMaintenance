import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_typography.dart';

/// Extra design tokens that Material's [ThemeData] has no slot for.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.surfaceHigh,
    required this.border,
    required this.textSecondary,
    required this.cardRadius,
    required this.gutter,
    required this.glowOpacity,
  });

  final Color surfaceHigh;
  final Color border;
  final Color textSecondary;
  final double cardRadius;
  final double gutter;

  /// How strongly accent glows bleed behind cards — dialled down in light mode
  /// where a glow reads as smudge rather than depth.
  final double glowOpacity;

  @override
  AppTokens copyWith({
    Color? surfaceHigh,
    Color? border,
    Color? textSecondary,
    double? cardRadius,
    double? gutter,
    double? glowOpacity,
  }) => AppTokens(
    surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    border: border ?? this.border,
    textSecondary: textSecondary ?? this.textSecondary,
    cardRadius: cardRadius ?? this.cardRadius,
    gutter: gutter ?? this.gutter,
    glowOpacity: glowOpacity ?? this.glowOpacity,
  );

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      border: Color.lerp(border, other.border, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      cardRadius: _lerp(cardRadius, other.cardRadius, t),
      gutter: _lerp(gutter, other.gutter, t),
      glowOpacity: _lerp(glowOpacity, other.glowOpacity, t),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// Convenience accessors so widgets read `context.tokens` / `context.colors`.
extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  const AppTheme._();

  static const double cardRadius = 22;
  static const double gutter = 16;

  static ThemeData light() => _build(
    brightness: Brightness.light,
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    surfaceHigh: AppColors.lightSurfaceHigh,
    border: AppColors.lightBorder,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    glowOpacity: 0.10,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceHigh: AppColors.darkSurfaceHigh,
    border: AppColors.darkBorder,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    glowOpacity: 0.22,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceHigh,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required double glowOpacity,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.cyan,
      onPrimary: const Color(0xFF04222A),
      secondary: AppColors.green,
      onSecondary: const Color(0xFF03231A),
      tertiary: AppColors.purple,
      onTertiary: const Color(0xFF1A1030),
      error: AppColors.red,
      onError: const Color(0xFF2B0A0A),
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceHigh,
      outline: border,
      outlineVariant: border,
    );

    final textTheme = AppTypography.textTheme(textPrimary, textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      fontFamily: AppFonts.family,
      fontFamilyFallback: AppFonts.fallback,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        side: BorderSide(color: border),
        labelStyle: textTheme.labelMedium!,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        hintStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.cyan, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.cyan,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppFadePageTransitionsBuilder(),
          TargetPlatform.iOS: AppFadePageTransitionsBuilder(),
          TargetPlatform.macOS: AppFadePageTransitionsBuilder(),
          TargetPlatform.linux: AppFadePageTransitionsBuilder(),
          TargetPlatform.windows: AppFadePageTransitionsBuilder(),
          TargetPlatform.fuchsia: AppFadePageTransitionsBuilder(),
        },
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppTokens(
          surfaceHigh: surfaceHigh,
          border: border,
          textSecondary: textSecondary,
          cardRadius: cardRadius,
          gutter: gutter,
          glowOpacity: glowOpacity,
        ),
      ],
    );
  }
}

/// Single-layer fade used by Material [PageRoute]s that do not go through
/// GoRouter's [pageBuilder]. Avoids Android's snapshot zoom and iOS's
/// stacked parallax, both of which paint two routes for the whole duration.
class AppFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const AppFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      child: child,
    );
  }
}
