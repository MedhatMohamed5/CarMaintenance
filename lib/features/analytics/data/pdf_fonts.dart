import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/theme/app_fonts.dart';

/// The typefaces the PDF renderer draws with.
///
/// **Why the report used to print `?` for every Arabic character.** A
/// `pw.Document` with no theme falls back to the PDF base-14 fonts — Helvetica
/// and friends — which are Latin-1 only. They have no Arabic glyphs and no
/// `cmap` entries above `0xFF`, so a vehicle nickname or an expense note
/// written in Arabic had nothing to map to. The old builder papered over that
/// by transliterating everything outside Latin-1 into `?` before it reached the
/// page, which is why the question marks were so uniform.
///
/// Embedding the app's own bundled families fixes the cause: the same Cairo the
/// UI draws with, with Noto Sans Arabic behind it for anything Cairo happens
/// not to cover. Both are already in `pubspec.yaml`, so this adds no asset
/// weight to the bundle — only to the generated file, which now carries subset
/// glyph data.
///
/// Loaded once and cached: parsing a variable font is not free, and a user
/// exporting three formats in a row should pay for it once.
class PdfFonts {
  const PdfFonts._({
    required this.base,
    required this.bold,
    required this.fallback,
  });

  final pw.Font base;
  final pw.Font bold;
  final List<pw.Font> fallback;

  static PdfFonts? _cached;

  /// The theme every page is built under.
  ///
  /// `bold` is deliberately the same face as `base`. Both bundled Arabic
  /// families ship as single variable-font files, and the `pdf` package reads
  /// a variable font's default instance rather than interpolating an axis — so
  /// there is no separate bold outline to hand it. Weight is carried by size,
  /// colour and spacing in the layout instead of by a heavier stroke, which is
  /// why the section headings below lean on those.
  pw.ThemeData get theme =>
      pw.ThemeData.withFont(base: base, bold: bold, fontFallback: fallback);

  static Future<PdfFonts> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    final cairo = pw.Font.ttf(await rootBundle.load(AppFonts.cairoAsset));
    final noto = pw.Font.ttf(
      await rootBundle.load(AppFonts.notoSansArabicAsset),
    );
    final roboto = pw.Font.ttf(await rootBundle.load(AppFonts.robotoAsset));

    return _cached = PdfFonts._(
      base: cairo,
      bold: cairo,
      // Order matters: Arabic coverage first, then a Latin face for anything
      // Cairo lacks. A glyph missing from every fallback still drops out, but
      // it drops out alone rather than taking the run with it.
      fallback: [noto, roboto],
    );
  }
}
