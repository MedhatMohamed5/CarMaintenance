import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bundled families used by the theme and the splash.
///
/// CanvasKit and skwasm cannot see CSS `@font-face` or system fonts, so Arabic
/// has to live in a [FontLoader]-registered family before the first [Text]
/// paints — otherwise the engine draws tofu until a CDN fallback arrives.
class AppFonts {
  const AppFonts._();

  static const String family = 'Cairo';

  static const List<String> fallback = [
    'Noto Sans Arabic',
    'Roboto',
    'sans-serif',
  ];

  static const String cairoAsset = 'assets/fonts/Cairo-VF.ttf';
  static const String notoSansArabicAsset =
      'assets/fonts/NotoSansArabic-VF.ttf';
  static const String robotoAsset = 'assets/fonts/Roboto-Regular.ttf';

  /// Primary family plus web-safe fallbacks, applied to any [TextStyle].
  static TextStyle apply(TextStyle? style) => (style ?? const TextStyle())
      .copyWith(fontFamily: family, fontFamilyFallback: fallback);

  static TextTheme applyTheme(TextTheme theme) {
    TextStyle? wrap(TextStyle? style) => style == null ? null : apply(style);
    return TextTheme(
      displayLarge: wrap(theme.displayLarge),
      displayMedium: wrap(theme.displayMedium),
      displaySmall: wrap(theme.displaySmall),
      headlineLarge: wrap(theme.headlineLarge),
      headlineMedium: wrap(theme.headlineMedium),
      headlineSmall: wrap(theme.headlineSmall),
      titleLarge: wrap(theme.titleLarge),
      titleMedium: wrap(theme.titleMedium),
      titleSmall: wrap(theme.titleSmall),
      bodyLarge: wrap(theme.bodyLarge),
      bodyMedium: wrap(theme.bodyMedium),
      bodySmall: wrap(theme.bodySmall),
      labelLarge: wrap(theme.labelLarge),
      labelMedium: wrap(theme.labelMedium),
      labelSmall: wrap(theme.labelSmall),
    );
  }

  /// Registers the bundled files with Skia before [runApp] on web, where
  /// CanvasKit otherwise paints the splash with the default Latin-only face.
  static Future<void> ensureLoaded() async {
    if (!kIsWeb) return;
    await Future.wait([
      _load(family, cairoAsset),
      _load('Noto Sans Arabic', notoSansArabicAsset),
      _load('Roboto', robotoAsset),
    ]);
  }

  static Future<void> _load(String familyName, String asset) async {
    final loader = FontLoader(familyName);
    loader.addFont(rootBundle.load(asset));
    await loader.load();
  }
}
