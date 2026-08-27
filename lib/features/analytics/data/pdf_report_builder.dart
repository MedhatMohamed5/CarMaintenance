import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Locale;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/analytics_report.dart';
import 'pdf_fonts.dart';

/// One headline figure, or one slice of the monthly bill.
class _Kpi {
  const _Kpi({
    required this.label,
    required this.value,
    required this.accent,
    this.amount = 0,
    this.yearly = '',
  });

  final String label;

  /// Already formatted for print.
  final String value;

  final PdfColor accent;

  /// The raw figure, for anything that has to compare shares. Zero on a tile
  /// that only ever displays.
  final double amount;

  /// The same figure over a year, already formatted. Empty on a tile that has
  /// no yearly reading.
  final String yearly;
}

/// A run of ledger rows that belong together.
class _RowGroup {
  const _RowGroup({
    required this.title,
    required this.rows,
    required this.showQuantity,
  });

  final String title;
  final List<ReportRow> rows;

  /// Litres only mean something for fuel. Carried per group so a table of
  /// services does not print an empty column.
  final bool showQuantity;
}

/// Renders an [AnalyticsReport] as a print-ready PDF.
///
/// Charts are drawn as **vector** graphics by the `pdf` package rather than
/// screenshotted from the live widget tree. That keeps the builder pure — no
/// `BuildContext`, no `RepaintBoundary`, no frame to wait for — so it runs off
/// the UI thread, produces a file a tenth the size, and stays sharp at any
/// zoom.
///
/// **The report speaks the app's language.** Labels used to be hard-coded
/// English and any Arabic the user had typed was flattened to `?`, because the
/// document carried no font with Arabic coverage. It now loads the app's own
/// bundled families ([PdfFonts]) and reads its strings from
/// [AnalyticsReport.localeTag], so an Arabic export is Arabic throughout —
/// headings, table columns and the driver's own notes alike.
class PdfReportBuilder {
  const PdfReportBuilder();

  // A single ramp, warm-neutral, so the page reads as one document rather than
  // a scatter of accent colours. Category colours still come from the data.
  static const PdfColor _ink = PdfColor.fromInt(0xFF0F172A);

  /// Body copy and table cells.
  static const PdfColor _body = PdfColor.fromInt(0xFF1E293B);

  /// Labels and captions. **Still dark.** This was a pale blue-grey, which
  /// looked considered on screen and printed as barely-there on paper — the
  /// axis ticks, the KPI captions and the legend all faded out together. Slate
  /// 600 reads as secondary against [_ink] without giving up contrast.
  static const PdfColor _muted = PdfColor.fromInt(0xFF475569);
  static const PdfColor _rule = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor _hairline = PdfColor.fromInt(0xFFEEF2F6);

  /// Card ground.
  static const PdfColor _band = PdfColor.fromInt(0xFFF8FAFC);

  static const PdfColor _accent = PdfColor.fromInt(0xFF00A5BF);
  static const PdfColor _accentSoft = PdfColor.fromInt(0xFFE4F6F9);
  static const PdfColor _green = PdfColor.fromInt(0xFF2E9E63);
  static const PdfColor _amber = PdfColor.fromInt(0xFFE0973E);
  static const PdfColor _violet = PdfColor.fromInt(0xFF7C6BD6);

  /// The header band and the plate badge. Slate rather than the blue-grey it
  /// was: at this size a warm navy reads as faded, while slate stays crisp
  /// against white and lets the accent colours carry the only real hue on the
  /// page.
  static const PdfColor _navy = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor _navySoft = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor _navyInk = PdfColor.fromInt(0xFFCBD5E1);

  /// The heaviest weight this document can honestly draw.
  ///
  /// **Not synthetic bold. That experiment is over.** Both bundled Arabic
  /// families are single variable-font files and the `pdf` package reads only
  /// their default instance, so `FontWeight.bold` has nothing to resolve to.
  /// Faking it with `fillAndStroke` — fill the glyph, stroke its outline —
  /// widened every letter by half the stroke on each side, and at heading sizes
  /// neighbouring glyphs grew into each other: `r` and `e` closed up into
  /// something like `n`, `o` and `r` into `m`, and "Vehicle report" came off the
  /// page reading "Vehicle nepromt". The stroke also painted black, which put a
  /// dark outline around white text on the slate banner.
  ///
  /// Weight is carried by size, colour and spacing instead. It is less emphatic
  /// than a real bold face and it is legible, which is the trade worth making.
  /// A genuine bold would need a static Cairo Bold in `assets/fonts/`.
  static pw.TextStyle _bold(
    double size, {
    PdfColor color = _ink,
    double? letterSpacing,
  }) => pw.TextStyle(
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
    renderingMode: PdfTextRenderingMode.fill,
  );

  /// Text on a dark ground: solid fill, no stroke, no outline.
  static pw.TextStyle _light(
    double size, {
    PdfColor color = PdfColors.white,
    double? letterSpacing,
  }) => pw.TextStyle(
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
    renderingMode: PdfTextRenderingMode.fill,
  );

  Future<Uint8List> build(AnalyticsReport report) async {
    final l10n = AppLocalizations(Locale(report.localeTag));
    final fonts = await PdfFonts.load();

    // Arabic shaping in the `pdf` package hangs off the page's text direction:
    // it only joins letters and reorders runs when the direction is RTL.
    // Setting it here covers every widget on the page, so no call site has to
    // remember — which is exactly how the old builder would have drifted.
    final rtl = l10n.isArabic;

    final document = pw.Document(
      title: l10n.raw('reportTitle'),
      author: l10n.appTitle,
      theme: fonts.theme,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: fonts.theme,
        textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 34),
        header: (context) => _banner(report, l10n),
        footer: (context) => _footer(context, l10n),
        build: (context) => [
          // **Deliberate breaks, not wherever a widget stops fitting.**
          // MultiPage otherwise splits mid-subject, which put the KPI cards at
          // the foot of one page and the charts orphaned at the head of the
          // next. NewPage moves each break to where the subject changes: who
          // the car is, what it is projected to cost, then the ledger behind
          // both. Anything genuinely taller than a page still flows on.
          //
          // Every heading below travels with its content through [_block], so a
          // section title can never be stranded alone at the foot of a page.

          // ---- 1. profile and headline figures ----
          _identityCard(report, l10n),
          pw.SizedBox(height: 12),
          _kpiRow(report, l10n),
          pw.SizedBox(height: 16),
          _section(l10n.raw('reportSummary')),
          pw.SizedBox(height: 8),
          _costTable(report, l10n, rtl),

          // ---- 2. forecast and charts ----
          if (report.forecast != null || report.spendSlices.isNotEmpty)
            pw.NewPage(),
          if (report.forecast != null) ...[
            _block(
              l10n.raw('reportForecast'),
              _panel(
                _amortisedBreakdown(report.forecast!, report, l10n),
                padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 10),
              ),
            ),
            pw.SizedBox(height: 14),
          ],
          if (report.spendSlices.isNotEmpty) ...[
            _block(
              l10n.raw('reportSpendBreakdown'),
              _panel(_spendBreakdown(report)),
            ),
            pw.SizedBox(height: 14),
          ],
          // The two trends sit side by side rather than stacked. Full width
          // each, they pushed the forecast onto a page of its own and left the
          // second chart stranded at the head of the next.
          if (_hasTrends(report))
            _block(
              l10n.raw('reportCostTrend'),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (report.efficiencySeries.length >= 2)
                    pw.Expanded(
                      child: _panel(
                        _trend(
                          '${l10n.raw('litersShort')}/100${l10n.km}',
                          report.efficiencySeries,
                          _accent,
                          1,
                        ),
                        padding: const pw.EdgeInsets.fromLTRB(10, 9, 10, 7),
                      ),
                    ),
                  if (report.efficiencySeries.length >= 2 &&
                      report.costPerKmSeries.length >= 2)
                    pw.SizedBox(width: 10),
                  if (report.costPerKmSeries.length >= 2)
                    pw.Expanded(
                      child: _panel(
                        _trend(
                          l10n.raw('costPerKm'),
                          report.costPerKmSeries,
                          _green,
                          2,
                        ),
                        padding: const pw.EdgeInsets.fromLTRB(10, 9, 10, 7),
                      ),
                    ),
                ],
              ),
            ),

          // ---- 3. the ledger ----
          if (report.rows.isNotEmpty) ...[
            pw.NewPage(),
            // Split by kind rather than one merged ledger: a fuel row carries
            // litres, a service row carries none, and a column empty two rows
            // in three reads as missing data rather than as one that does not
            // apply. The heading rides with the table's first rows so a group
            // never opens on a page of its own.
            for (var i = 0; i < _groups(report, l10n).length; i++) ...[
              if (i > 0) pw.SizedBox(height: 16),
              _section(
                '${_groups(report, l10n)[i].title} '
                '(${_groups(report, l10n)[i].rows.length})',
              ),
              pw.SizedBox(height: 8),
              _rowsTable(_groups(report, l10n)[i], l10n, rtl),
            ],
          ],
        ],
      ),
    );

    return document.save();
  }

  // ---- page furniture --------------------------------------------------

  /// The dark band that opens every page.
  ///
  /// Repeated as the page header rather than printed once, so a report that
  /// runs to three pages still identifies itself on page three. Its height is
  /// fixed and the page margin is set to clear it.
  pw.Widget _banner(
    AnalyticsReport report,
    AppLocalizations l10n,
  ) => pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(18, 14, 18, 14),
    margin: const pw.EdgeInsets.only(bottom: 16),
    decoration: pw.BoxDecoration(
      color: _navy,
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _auto(
                l10n.raw('reportTitle'),
                maxLines: 1,
                style: _bold(15, color: PdfColors.white),
              ),
              pw.SizedBox(height: 5),
              _auto(
                '${l10n.raw('reportGenerated')} ${_date(report.generatedAt)}',
                maxLines: 1,
                style: const pw.TextStyle(fontSize: 8.5, color: _navyInk),
              ),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: _navySoft,
            borderRadius: pw.BorderRadius.circular(20),
          ),
          child: _auto(
            l10n.appTitle,
            maxLines: 1,
            style: _bold(9, color: PdfColors.white, letterSpacing: 0.4),
          ),
        ),
      ],
    ),
  );

  /// The vehicle's identity card: photo, name, odometer, plate.
  ///
  /// The photo is the one piece of the report that is the driver's own, and it
  /// is what makes the page read as *their* car rather than a form. It is
  /// optional throughout — no photo simply collapses the column away rather
  /// than leaving a grey rectangle.
  pw.Widget _identityCard(AnalyticsReport report, AppLocalizations l10n) {
    final image = report.vehicleImage;

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _band,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _hairline),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (image != null) ...[
            pw.ClipRRect(
              horizontalRadius: 8,
              verticalRadius: 8,
              child: pw.Image(
                pw.MemoryImage(image),
                width: 104,
                height: 68,
                fit: pw.BoxFit.cover,
              ),
            ),
            pw.SizedBox(width: 14),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _auto(report.vehicleName, maxLines: 2, style: _bold(17)),
                pw.SizedBox(height: 4),
                _auto(
                  report.vehicleSubtitle,
                  maxLines: 1,
                  style: const pw.TextStyle(fontSize: 9.5, color: _muted),
                ),
                pw.SizedBox(height: 6),
                _auto(
                  '${l10n.raw('reportOdometer')}: '
                  '${_int(report.currentOdometer)} ${l10n.km}',
                  maxLines: 1,
                  style: const pw.TextStyle(fontSize: 9, color: _body),
                ),
              ],
            ),
          ),
          if (report.plateNumber != null &&
              report.plateNumber!.trim().isNotEmpty) ...[
            pw.SizedBox(width: 12),
            _plate(report.plateNumber!),
          ],
        ],
      ),
    );
  }

  /// A number plate, drawn rather than described.
  pw.Widget _plate(String number) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border.all(color: _navy, width: 1.4),
    ),
    child: _auto(
      number,
      maxLines: 1,
      forceLtr: true,
      style: _bold(13, color: _navy, letterSpacing: 1.2),
    ),
  );

  pw.Widget _footer(pw.Context context, AppLocalizations l10n) => pw.Container(
    alignment: pw.Alignment.centerRight,
    margin: const pw.EdgeInsets.only(top: 12),
    child: pw.Text(
      l10n.fmt('reportPage', {
        'n': context.pageNumber,
        'total': context.pagesCount,
      }),
      style: const pw.TextStyle(fontSize: 8.5, color: _muted),
    ),
  );

  /// Section heading.
  ///
  /// A dot of colour, the label, and a hairline running out to the page edge.
  /// The rule is what does the work: it closes the heading off from the section
  /// above without needing a heavier weight to separate them.
  ///
  /// Both bundled Arabic families are single variable-font files and the `pdf`
  /// package reads only their default instance, so there is no heavier outline
  /// to set a heading in. Hierarchy comes from the rule, the size and the
  /// colour rather than from stroke weight.
  pw.Widget _section(String text) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Container(
        width: 6,
        height: 6,
        decoration: const pw.BoxDecoration(
          color: _accent,
          shape: pw.BoxShape.circle,
        ),
      ),
      pw.SizedBox(width: 8),
      _auto(
        text,
        maxLines: 1,
        style: pw.TextStyle(
          fontSize: 11.5,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
          letterSpacing: 0.2,
        ),
      ),
      pw.SizedBox(width: 10),
      pw.Expanded(child: pw.Container(height: 0.8, color: _hairline)),
    ],
  );

  /// A heading and the thing it names, moved as one.
  ///
  /// `MultiPage` breaks between any two widgets in the list, so a heading at
  /// the foot of a page and its chart at the head of the next was always
  /// possible — and looked like a mistake every time it happened. A `Container`
  /// is not a `SpanningWidget`, so wrapping the pair makes the break happen
  /// before the heading instead of after it.
  ///
  /// Only for fixed-height content. A table must stay unwrapped so it can span
  /// pages; see [_table].
  pw.Widget _block(String title, pw.Widget child) => pw.Container(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      mainAxisSize: pw.MainAxisSize.min,
      children: [_section(title), pw.SizedBox(height: 10), child],
    ),
  );

  /// Wraps a section's content in a soft panel.
  ///
  /// Tables and charts used to sit straight on the page, so the only thing
  /// separating one section from the next was vertical space. A light frame
  /// gives each block an edge, which is most of what makes a document look
  /// composed rather than stacked.
  pw.Widget _panel(pw.Widget child, {pw.EdgeInsets? padding}) => pw.Container(
    width: double.infinity,
    padding: padding ?? const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(8),
      border: pw.Border.all(color: _hairline),
    ),
    child: child,
  );

  // ---- text direction --------------------------------------------------

  /// Whether a string carries Arabic script.
  ///
  /// Covers Arabic, its supplement and extended blocks, and the presentation
  /// forms, so a name typed on any keyboard is recognised.
  static bool _hasArabic(String value) => value.runes.any(
    (r) =>
        (r >= 0x0600 && r <= 0x06FF) ||
        (r >= 0x0750 && r <= 0x077F) ||
        (r >= 0x08A0 && r <= 0x08FF) ||
        (r >= 0xFB50 && r <= 0xFDFF) ||
        (r >= 0xFE70 && r <= 0xFEFF),
  );

  /// A run of text that carries **its own** direction rather than the page's.
  ///
  /// **Why the page direction is not enough.** The `pdf` package only joins
  /// Arabic letters and reorders a run when the direction in scope is RTL. Set
  /// it once on the page and an English report is LTR throughout — so a vehicle
  /// nickname or an expense note the driver typed in Arabic arrived unshaped
  /// and in logical order, which reads as reversed. The report's language and
  /// the language of the data inside it are simply two different questions.
  ///
  /// Numbers take [forceLtr]: a figure, a date or an odometer reading is Latin
  /// digits in both languages, and mirroring one reads as a mistake rather than
  /// a translation.
  static pw.Widget _auto(
    String text, {
    pw.TextStyle? style,
    int? maxLines,
    bool forceLtr = false,
    bool shrink = false,
    pw.TextAlign? align,
  }) {
    final body = pw.Text(
      text,
      style: style,
      maxLines: maxLines,
      textAlign: align,
    );

    return pw.Directionality(
      textDirection: !forceLtr && _hasArabic(text)
          ? pw.TextDirection.rtl
          : pw.TextDirection.ltr,
      // `scaleDown` only acts when the text genuinely does not fit, so a figure
      // that has room is untouched and one that would overrun its column is
      // made to fit instead of painting over the cell beside it.
      child: shrink
          ? pw.FittedBox(fit: pw.BoxFit.scaleDown, child: body)
          : body,
    );
  }

  // ---- summary ---------------------------------------------------------

  /// The three figures the report exists to answer.
  ///
  /// **Three, not the four this used to carry.** Odometer and tracked distance
  /// moved into the identity card and the summary table, where they belong:
  /// they describe the car, not what it costs. What is left is the money
  /// question in its three tenses — what has been spent, what a kilometre
  /// consumes now, and what next month is projected to take.
  pw.Widget _kpiRow(AnalyticsReport report, AppLocalizations l10n) {
    final forecast = report.forecast;

    final tiles = <_Kpi>[
      _Kpi(
        label: l10n.raw('totalSpend'),
        value: _money(report.totalCost, report),
        accent: _accent,
      ),
      _Kpi(
        label: '${l10n.raw('litersShort')}/100${l10n.km}',
        value: _dec2(report.avgLitersPer100Km),
        accent: _amber,
      ),
      _Kpi(
        label: l10n.raw('reportPerMonth'),
        value: forecast == null ? '—' : _money(forecast.monthlyTotal, report),
        accent: _green,
      ),
    ];

    return pw.Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 10),
          pw.Expanded(child: _tile(tiles[i])),
        ],
      ],
    );
  }

  pw.Widget _tile(_Kpi kpi) => pw.Container(
    decoration: pw.BoxDecoration(
      color: _band,
      borderRadius: pw.BorderRadius.circular(8),
      border: pw.Border.all(color: _hairline),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        // A hairline of colour along the top edge. It is the only ornament on
        // the card, and it is what lets three grey boxes read as three distinct
        // figures rather than one undifferentiated block.
        pw.Container(
          height: 3,
          decoration: pw.BoxDecoration(
            color: kpi.accent,
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(8),
              topRight: pw.Radius.circular(8),
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // Held to one line: an explicit card height once clipped the
              // value out of view when an Arabic label wrapped, so the label
              // never wraps and the card sizes itself instead.
              _auto(
                kpi.label,
                maxLines: 1,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: _muted,
                  letterSpacing: 0.3,
                ),
              ),
              pw.SizedBox(height: 6),
              _auto(kpi.value, maxLines: 1, forceLtr: true, style: _bold(15)),
            ],
          ),
        ),
      ],
    ),
  );

  static bool _hasTrends(AnalyticsReport report) =>
      report.efficiencySeries.length >= 2 || report.costPerKmSeries.length >= 2;

  /// A trend with its own caption, so two of them side by side each say what
  /// they are measuring without a shared heading having to name both.
  pw.Widget _trend(
    String caption,
    List<ReportPoint> series,
    PdfColor color,
    int decimals,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      _auto(
        caption,
        maxLines: 1,
        style: const pw.TextStyle(fontSize: 8, color: _muted),
      ),
      pw.SizedBox(height: 4),
      _lineChart(series, color, decimals, height: 96),
    ],
  );

  // ---- amortisation ----------------------------------------------------

  /// Recurring cost beside amortised cost, as bars.
  ///
  /// The distinction is the point of the section and a table cannot carry it:
  /// fuel and servicing are what *driving* costs, while insurance and licensing
  /// are owed whether the car moves or not. Drawn as shares of one monthly
  /// figure, the bars say how much of the bill is already fixed before the key
  /// is turned — which is the number that decides whether a month is
  /// affordable.
  pw.Widget _amortisedBreakdown(
    ReportForecast forecast,
    AnalyticsReport report,
    AppLocalizations l10n,
  ) {
    final parts = <_Kpi>[
      _Kpi(
        label: l10n.tabFuel,
        value: _money(forecast.monthlyFuelCost, report),
        yearly: _money(forecast.yearlyFuelCost, report),
        accent: _accent,
        amount: forecast.monthlyFuelCost,
      ),
      _Kpi(
        label: l10n.maintenance,
        value: _money(forecast.monthlyMaintenanceCost, report),
        yearly: _money(forecast.yearlyMaintenanceCost, report),
        accent: _amber,
        amount: forecast.monthlyMaintenanceCost,
      ),
      _Kpi(
        label: l10n.raw('reportOther'),
        value: _money(forecast.monthlyOtherCost, report),
        yearly: _money(forecast.yearlyOtherCost, report),
        accent: _violet,
        amount: forecast.monthlyOtherCost,
      ),
      _Kpi(
        label: l10n.raw('forecastPolicies'),
        value: _money(forecast.monthlyPolicyCost, report),
        yearly: _money(forecast.yearlyPolicyCost, report),
        accent: _green,
        amount: forecast.monthlyPolicyCost,
      ),
    ];

    final total = forecast.monthlyTotal;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: _auto(
                  '${l10n.raw('reportDailyPace')}: '
                  '${_dec1(forecast.avgDailyKm)} ${l10n.km}',
                  maxLines: 1,
                  style: const pw.TextStyle(fontSize: 8.5, color: _body),
                ),
              ),
              pw.SizedBox(
                width: 92,
                child: _auto(
                  l10n.raw('reportPerMonth'),
                  align: pw.TextAlign.end,
                  maxLines: 1,
                  style: _bold(8, color: _muted),
                ),
              ),
              pw.SizedBox(
                width: 96,
                child: _auto(
                  l10n.raw('reportPerYear'),
                  align: pw.TextAlign.end,
                  maxLines: 1,
                  style: _bold(8, color: _muted),
                ),
              ),
            ],
          ),
        ),
        for (final part in parts)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 7),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 7,
                      height: 7,
                      decoration: pw.BoxDecoration(
                        color: part.accent,
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                    pw.SizedBox(width: 7),
                    pw.Expanded(
                      child: _auto(
                        part.label,
                        maxLines: 1,
                        style: const pw.TextStyle(fontSize: 9, color: _body),
                      ),
                    ),
                    _auto(
                      total <= 0
                          ? ''
                          : '${(part.amount / total * 100).round()}%   ',
                      maxLines: 1,
                      forceLtr: true,
                      style: const pw.TextStyle(fontSize: 8.5, color: _body),
                    ),
                    pw.SizedBox(
                      width: 92,
                      child: _auto(
                        part.value,
                        align: pw.TextAlign.end,
                        maxLines: 1,
                        forceLtr: true,
                        style: _bold(9),
                      ),
                    ),
                    pw.SizedBox(
                      width: 96,
                      child: _auto(
                        part.yearly,
                        align: pw.TextAlign.end,
                        maxLines: 1,
                        forceLtr: true,
                        style: const pw.TextStyle(fontSize: 8.5, color: _body),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),
                _meter(part.amount, total, part.accent),
              ],
            ),
          ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 7),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _rule, width: 0.7)),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: _auto(
                  l10n.raw('forecastTotal'),
                  maxLines: 1,
                  style: _bold(10),
                ),
              ),
              pw.SizedBox(
                width: 92,
                child: _auto(
                  _money(forecast.monthlyTotal, report),
                  align: pw.TextAlign.end,
                  maxLines: 1,
                  forceLtr: true,
                  style: _bold(11),
                ),
              ),
              pw.SizedBox(
                width: 96,
                child: _auto(
                  _money(forecast.yearlyTotal, report),
                  align: pw.TextAlign.end,
                  maxLines: 1,
                  forceLtr: true,
                  style: _bold(9, color: _body),
                ),
              ),
            ],
          ),
        ),
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 3),
          padding: const pw.EdgeInsets.fromLTRB(9, 6, 9, 7),
          decoration: pw.BoxDecoration(
            color: _accentSoft,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: _auto(
            l10n.raw('reportAmortisedNote'),
            maxLines: 2,
            style: const pw.TextStyle(fontSize: 7.5, color: _body),
          ),
        ),
      ],
    );
  }

  /// One share of the monthly total, drawn as a filled track.
  pw.Widget _meter(double value, double total, PdfColor color) {
    final share = total <= 0
        ? 0
        : (value / total * 1000).round().clamp(0, 1000);

    return pw.ClipRRect(
      horizontalRadius: 3,
      verticalRadius: 3,
      child: pw.Row(
        children: [
          if (share > 0)
            pw.Expanded(
              flex: share,
              child: pw.Container(height: 7, color: color),
            ),
          if (share < 1000)
            pw.Expanded(
              flex: 1000 - share,
              child: pw.Container(height: 7, color: _hairline),
            ),
        ],
      ),
    );
  }

  pw.Widget _costTable(
    AnalyticsReport report,
    AppLocalizations l10n,
    bool rtl,
  ) => _table(
    rtl: rtl,
    flex: const [5, 3],
    headers: [l10n.raw('reportMetric'), l10n.raw('reportValue')],
    rows: [
      [
        l10n.raw('reportOdometer'),
        '${_int(report.currentOdometer)} ${l10n.km}',
      ],
      [
        l10n.raw('reportTrackedDistance'),
        '${_int(report.distanceKm)} ${l10n.km}',
      ],
      [l10n.raw('reportFuelCost'), _money(report.fuelCost, report)],
      [l10n.raw('reportServiceCost'), _money(report.serviceCost, report)],
      [l10n.raw('reportPartsCost'), _money(report.partsCost, report)],
      [l10n.raw('reportOtherCost'), _money(report.otherCost, report)],
      [l10n.raw('reportTotalCost'), _money(report.totalCost, report)],
      [l10n.raw('reportLitres'), _dec2(report.liters)],
      [l10n.raw('reportConsumption'), _dec2(report.avgLitersPer100Km)],
      [l10n.raw('reportEfficiency'), _dec2(report.avgEfficiency)],
      [l10n.raw('reportFuelCostPerKm'), _dec2(report.fuelCostPerKm)],
      [l10n.raw('reportCostPerKm'), _dec2(report.costPerKm)],
    ],
    numeric: const {1},
  );

  // ---- forecast --------------------------------------------------------

  // ---- transactions ----------------------------------------------------

  /// The ledger, split by what each row actually is.
  ///
  /// One merged table forced every kind through the same columns, so two rows
  /// in three carried an empty `Qty` — which reads as missing data rather than
  /// as a column that does not apply. Empty kinds are dropped entirely rather
  /// than printing a heading over nothing.
  List<_RowGroup> _groups(AnalyticsReport report, AppLocalizations l10n) {
    List<ReportRow> of(String type) =>
        report.rows.where((r) => r.type == type).toList(growable: false);

    return [
      for (final spec in [
        (type: 'service', title: l10n.maintenanceHistory, quantity: false),
        (type: 'fuel', title: l10n.tabFuel, quantity: true),
        (type: 'expense', title: l10n.expenses, quantity: false),
      ])
        if (of(spec.type).isNotEmpty)
          _RowGroup(
            title: spec.title,
            rows: of(spec.type),
            showQuantity: spec.quantity,
          ),
    ];
  }

  pw.Widget _rowsTable(_RowGroup group, AppLocalizations l10n, bool rtl) =>
      _table(
        rtl: rtl,
        flex: group.showQuantity
            ? const [3, 3, 5, 3, 2, 3]
            : const [3, 3, 6, 3, 3],
        headers: [
          l10n.raw('date'),
          l10n.raw('reportCategory'),
          l10n.raw('reportDescription'),
          l10n.raw('reportOdometer'),
          if (group.showQuantity) l10n.raw('reportQuantity'),
          l10n.raw('amount'),
        ],
        rows: [
          for (final row in group.rows)
            [
              _date(row.date),
              // Translated here, unlike the CSV: this column is read by a
              // person. Falls back to the row's kind when there is no
              // sub-kind, so the cell is never blank.
              row.categoryLabel ?? _rowType(row.type, l10n),
              row.description,
              _int(row.odometer),
              if (group.showQuantity)
                row.quantity == null ? '' : _dec2(row.quantity!),
              _dec2(row.amount),
            ],
        ],
        numeric: group.showQuantity ? const {0, 3, 4, 5} : const {0, 3, 4},
      );

  /// Row types are stable English keys in the CSV and JSON exports; only the
  /// printed label is translated, so the machine-readable formats stay
  /// language-independent.
  static String _rowType(String type, AppLocalizations l10n) => switch (type) {
    'fuel' => l10n.raw('reportRowFuel'),
    'service' => l10n.raw('reportRowService'),
    'expense' => l10n.raw('reportRowExpense'),
    _ => type,
  };

  static const double _headerRowHeight = 24;
  static const double _dataRowHeight = 22;

  pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    required List<int> flex,
    required bool rtl,
    Set<int> numeric = const {},
  }) {
    final count = headers.length;
    // Source column for each rendered position.
    int source(int position) => rtl ? count - 1 - position : position;

    pw.Widget cell(String text, int column, {required bool header}) {
      final isNumeric = numeric.contains(column);
      return pw.Container(
        // An explicit height rather than whatever the tallest cell settles on:
        // rows of differing height read as an uneven table even when every cell
        // is correctly padded, and it is what keeps a long label from
        // squeezing the row it sits in.
        height: header ? _headerRowHeight : _dataRowHeight,
        alignment: isNumeric == rtl
            ? pw.Alignment.centerLeft
            : pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10),
        child: _auto(
          text,
          // One line, and a figure shrinks rather than runs past its column.
          // `pw.Text` does not clip to its box, so a label wider than its cell
          // simply painted over the next one — which is how "Parts cost" and
          // "Other cost" ended up on top of their own values.
          maxLines: 1,
          shrink: isNumeric,
          forceLtr: isNumeric,
          style: header
              ? _light(8.5, letterSpacing: 0.2)
              : const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey900),
        ),
      );
    }

    return pw.Table(
      // **The table draws its own edge and is never wrapped in a panel.**
      // `Container` is not a `SpanningWidget`, so a decorated box around a
      // table cannot break across pages: three ledger tables stopped fitting
      // together and each jumped whole to a page of its own, and a vehicle with
      // more history than one page holds would have produced a widget the
      // engine cannot place at all — the same "won't fit into the page"
      // exception that once broke the export outright. Bare, the table spans
      // pages and repeats its header on each.
      border: const pw.TableBorder(
        top: pw.BorderSide(color: _rule, width: 0.7),
        bottom: pw.BorderSide(color: _rule, width: 0.7),
        horizontalInside: pw.BorderSide(color: _hairline, width: 0.6),
      ),
      columnWidths: {
        for (var i = 0; i < count; i++)
          i: pw.FlexColumnWidth(flex[source(i)].toDouble()),
      },
      children: [
        pw.TableRow(
          repeat: true,
          // Solid slate behind white text. A pale header band and dark ink read
          // as just another row at this size; the contrast is what tells the
          // eye where the table starts, and `repeat` carries it onto every page
          // the table spans.
          decoration: const pw.BoxDecoration(color: _navySoft),
          children: [
            for (var i = 0; i < count; i++)
              cell(headers[source(i)], source(i), header: true),
          ],
        ),
        for (var r = 0; r < rows.length; r++)
          pw.TableRow(
            // Alternating highlight, so the eye tracks along a row without a
            // rule under every cell.
            decoration: r.isOdd
                ? const pw.BoxDecoration(color: PdfColors.grey100)
                : const pw.BoxDecoration(color: PdfColors.white),
            children: [
              for (var i = 0; i < count; i++)
                cell(rows[r][source(i)], source(i), header: false),
            ],
          ),
      ],
    );
  }

  // ---- charts ----------------------------------------------------------

  /// Horizontal bars for the spend split. A bar chart beats a pie here: the
  /// categories are few, the labels are long, and lengths compare better than
  /// angles.
  /// The breakdown, as a donut beside its legend and bars.
  ///
  /// The donut answers "what shape is this spend" at a glance; the bars beside
  /// it keep the exact figures, which a ring cannot carry. Neither alone was
  /// enough — a ring with no numbers is decoration, and bars alone gave no
  /// sense of the whole.
  pw.Widget _spendBreakdown(AnalyticsReport report) {
    if (report.spendSlices.isEmpty) return pw.SizedBox();

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(
          width: 96,
          height: 96,
          child: pw.Chart(
            grid: pw.PieGrid(),
            datasets: [
              for (final slice in report.spendSlices)
                pw.PieDataSet(
                  value: slice.value,
                  color: PdfColor.fromInt(slice.colorValue),
                  // A ring, not a pie: the hole keeps the eye on the arc
                  // lengths instead of the wedge points.
                  innerRadius: 26,
                  legend: null,
                  borderColor: PdfColors.white,
                  borderWidth: 1.6,
                ),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(child: _spendChart(report)),
      ],
    );
  }

  pw.Widget _spendChart(AnalyticsReport report) {
    final max = report.spendSlices
        .map((s) => s.value)
        .fold<double>(0, (a, b) => a > b ? a : b);
    if (max <= 0) return pw.SizedBox();

    // Share of the whole, not of the longest bar. The bar lengths already
    // compare the categories against each other; the percentage answers the
    // different question of how much of the total each one took.
    final total = report.spendSlices
        .map((s) => s.value)
        .fold<double>(0, (a, b) => a + b);

    return pw.Column(
      children: [
        for (final slice in report.spendSlices)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(
                  width: 78,
                  child: _auto(
                    slice.label,
                    maxLines: 1,
                    style: const pw.TextStyle(fontSize: 9, color: _body),
                  ),
                ),
                // Two weighted flex boxes rather than a stacked overlay: the
                // pdf layout engine has no fractional sizing, and integer flex
                // gives an exact proportion at any page width.
                pw.Expanded(
                  child: pw.ClipRRect(
                    horizontalRadius: 3,
                    verticalRadius: 3,
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: _flexOf(slice.value, max),
                          child: pw.Container(
                            height: 14,
                            color: PdfColor.fromInt(slice.colorValue),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1000 - _flexOf(slice.value, max),
                          child: pw.Container(height: 14, color: _hairline),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.SizedBox(
                  width: 34,
                  child: _auto(
                    total <= 0 ? '' : '${(slice.value / total * 100).round()}%',
                    align: pw.TextAlign.end,
                    maxLines: 1,
                    forceLtr: true,
                    style: const pw.TextStyle(fontSize: 8.5, color: _body),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.SizedBox(
                  width: 88,
                  child: _auto(
                    _money(slice.value, report),
                    align: pw.TextAlign.end,
                    maxLines: 1,
                    forceLtr: true,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Bar width as a flex weight out of 1000, floored so the smallest category
  /// is still a visible sliver and capped so the remainder never goes negative.
  static int _flexOf(double value, double max) =>
      (value / max * 1000).round().clamp(20, 1000);

  /// A vector line chart with a padded, rounded y-axis so the series never
  /// touches the frame and the gridlines land on readable numbers.
  pw.Widget _lineChart(
    List<ReportPoint> series,
    PdfColor color,
    int decimals, {
    double height = 172,
  }) {
    final values = series.map((p) => p.value).toList();
    var min = values.reduce((a, b) => a < b ? a : b);
    var max = values.reduce((a, b) => a > b ? a : b);
    if (max - min < 0.0001) {
      // A flat series still deserves a readable band rather than a zero-height
      // axis that would divide by zero downstream.
      min = min - 1;
      max = max + 1;
    }
    final pad = (max - min) * 0.15;
    min = (min - pad).clamp(0, double.infinity).toDouble();
    max = max + pad;

    final ticks = <double>[
      for (var i = 0; i <= 4; i++) min + (max - min) * i / 4,
    ];

    return pw.Container(
      height: height,
      padding: const pw.EdgeInsets.only(top: 8, right: 6),
      // The axes carry Latin digits and slash-separated dates whichever
      // language the report is in, so the chart is pinned LTR even on an RTL
      // page — a mirrored numeric axis reads as a mistake, not a translation.
      child: pw.Directionality(
        textDirection: pw.TextDirection.ltr,
        child: pw.Chart(
          grid: pw.CartesianGrid(
            xAxis: pw.FixedAxis(
              [for (var i = 0; i < series.length; i++) i],
              marginStart: 8,
              ticks: true,
              format: (v) {
                // Only label the ends and the middle; a dated tick under every
                // point turns into mush on a narrow axis.
                final i = v.toInt();
                final isEdge =
                    i == 0 || i == series.length - 1 || i == series.length ~/ 2;
                return isEdge ? _shortDate(series[i].date) : '';
              },
              textStyle: const pw.TextStyle(fontSize: 7.5, color: _body),
            ),
            yAxis: pw.FixedAxis(
              ticks,
              format: (v) => v.toDouble().toStringAsFixed(decimals),
              divisions: true,
              divisionsColor: _hairline,
              textStyle: const pw.TextStyle(fontSize: 7.5, color: _body),
            ),
          ),
          datasets: [
            pw.LineDataSet(
              legend: null,
              drawSurface: true,
              surfaceOpacity: 0.14,
              drawPoints: series.length <= 24,
              pointSize: 2,
              lineWidth: 1.4,
              color: color,
              data: [
                for (var i = 0; i < series.length; i++)
                  pw.PointChartValue(i.toDouble(), series[i].value),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- formatting ------------------------------------------------------

  /// **The same [Fmt] the screens use, not a private copy.**
  ///
  /// The builder had its own `toStringAsFixed` helpers, so a figure that read
  /// `12,000.00` in the app printed `12000.00` in the report — the separators
  /// were simply absent from a file people hand to someone else. Routing
  /// through `Fmt` means the two can no longer disagree, and its digit locale is
  /// pinned to `en`, so grouping stays Latin in an Arabic report exactly as it
  /// does on screen.
  static const String _digits = 'en';

  static String _money(double v, AnalyticsReport report) =>
      report.currencyLabel.isEmpty
      ? Fmt.dec2(v, _digits)
      : '${Fmt.dec2(v, _digits)} ${report.currencyLabel}';

  static String _dec1(double v) => Fmt.dec1(v, _digits);

  static String _dec2(double v) => Fmt.dec2(v, _digits);

  static String _int(int v) => Fmt.int0(v, _digits);

  /// Formatted here rather than through `Fmt.date`.
  ///
  /// `DateFormat` needs `initializeDateFormatting`, which the app calls at
  /// bootstrap inside a guard that swallows failures — so a boot where that
  /// step failed would still run, and the export alone would throw. The layout
  /// is the same `dd-MM-yyyy` the app shows; only the dependency is dropped.
  /// Numbers have no such requirement: `NumberFormat` with an explicit locale
  /// needs no initialisation, which is why those do go through [Fmt].
  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.year}';

  static String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}';
}
