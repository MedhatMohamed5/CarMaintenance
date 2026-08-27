import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Locale;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/analytics_report.dart';
import 'pdf_fonts.dart';

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
  static const PdfColor _ink = PdfColor.fromInt(0xFF15202B);
  static const PdfColor _body = PdfColor.fromInt(0xFF37474F);
  static const PdfColor _muted = PdfColor.fromInt(0xFF78909C);
  static const PdfColor _rule = PdfColor.fromInt(0xFFE3E9EF);
  static const PdfColor _hairline = PdfColor.fromInt(0xFFF0F4F7);
  static const PdfColor _band = PdfColor.fromInt(0xFFF7FAFC);
  static const PdfColor _accent = PdfColor.fromInt(0xFF00A5BF);
  static const PdfColor _accentSoft = PdfColor.fromInt(0xFFE4F6F9);
  static const PdfColor _green = PdfColor.fromInt(0xFF2E9E63);
  static const PdfColor _amber = PdfColor.fromInt(0xFFE0973E);
  static const PdfColor _violet = PdfColor.fromInt(0xFF7C6BD6);

  /// The header band and the plate badge.
  static const PdfColor _navy = PdfColor.fromInt(0xFF2B3A4E);
  static const PdfColor _navySoft = PdfColor.fromInt(0xFF3C4E66);

  /// Synthetic bold.
  ///
  /// **There is no bold outline to switch to.** Both bundled Arabic families
  /// are single variable-font files and the `pdf` package reads only their
  /// default instance, so `FontWeight.bold` has nothing to resolve to and a
  /// heading came out the same weight as body text. Painting the glyph and
  /// stroking its outline thickens it in place, which is how a PDF viewer fakes
  /// a missing weight — close enough to carry a hierarchy, and it costs no
  /// extra asset.
  static pw.TextStyle _bold(
    double size, {
    PdfColor color = _ink,
    double? letterSpacing,
  }) => pw.TextStyle(
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
    renderingMode: PdfTextRenderingMode.fillAndStroke,
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
        margin: const pw.EdgeInsets.fromLTRB(30, 30, 30, 40),
        header: (context) => _banner(report, l10n),
        footer: (context) => _footer(context, l10n),
        build: (context) => [
          _identityCard(report, l10n),
          pw.SizedBox(height: 14),
          _summaryGrid(report, l10n),
          pw.SizedBox(height: 22),
          _section(l10n.raw('reportSummary')),
          pw.SizedBox(height: 10),
          _panel(_costTable(report, l10n, rtl), padding: pw.EdgeInsets.zero),
          if (report.forecast != null) ...[
            pw.SizedBox(height: 24),
            _section(l10n.raw('reportForecast')),
            pw.SizedBox(height: 10),
            _forecastPanel(report.forecast!, report, l10n),
          ],
          if (report.spendSlices.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            _section(l10n.raw('reportSpendBreakdown')),
            pw.SizedBox(height: 12),
            _panel(_spendBreakdown(report)),
          ],
          if (report.efficiencySeries.length >= 2) ...[
            pw.SizedBox(height: 24),
            _section(
              '${l10n.raw('reportConsumptionTrend')} '
              '(${l10n.raw('litersShort')}/100${l10n.km})',
            ),
            pw.SizedBox(height: 10),
            _panel(_lineChart(report.efficiencySeries, _accent, 1)),
          ],
          if (report.costPerKmSeries.length >= 2) ...[
            pw.SizedBox(height: 24),
            _section(l10n.raw('reportCostTrend')),
            pw.SizedBox(height: 10),
            _panel(_lineChart(report.costPerKmSeries, _green, 2)),
          ],
          if (report.rows.isNotEmpty) ...[
            pw.SizedBox(height: 26),
            _section(
              '${l10n.raw('reportTransactions')} (${report.rows.length})',
            ),
            pw.SizedBox(height: 10),
            _panel(_rowsTable(report, l10n, rtl), padding: pw.EdgeInsets.zero),
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
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColor.fromInt(0xFFB9C6D6),
                ),
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
    pw.TextAlign? align,
  }) => pw.Directionality(
    textDirection: !forceLtr && _hasArabic(text)
        ? pw.TextDirection.rtl
        : pw.TextDirection.ltr,
    child: pw.Text(text, style: style, maxLines: maxLines, textAlign: align),
  );

  // ---- summary ---------------------------------------------------------

  /// The four figures that answer "what has this car cost me".
  pw.Widget _summaryGrid(AnalyticsReport report, AppLocalizations l10n) {
    final tiles = <List<String>>[
      [l10n.raw('totalSpend'), _money(report.totalCost, report)],
      [l10n.raw('costPerKm'), _dec2(report.costPerKm)],
      [
        '${l10n.raw('litersShort')}/100${l10n.km}',
        _dec2(report.avgLitersPer100Km),
      ],
      [l10n.raw('distance'), '${_int(report.distanceKm)} ${l10n.km}'],
    ];

    // **Never `CrossAxisAlignment.stretch` inside a `MultiPage`.** A stretched
    // row hands its children `minHeight == maxHeight == constraints.maxHeight`,
    // and a MultiPage measures its children against an unbounded height — so
    // the row demanded infinite height and the renderer threw "Widget won't fit
    // into the page" before a single byte was written. The tiles are given an
    // explicit height instead, which is what made them equal in the first place.
    const accents = [_accent, _green, _amber, _violet];

    return pw.Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 9),
          pw.Expanded(child: _tile(tiles[i][0], tiles[i][1], accents[i])),
        ],
      ],
    );
  }

  /// A metric card.
  ///
  /// **No fixed height, and the label never wraps.** An explicit height clipped
  /// the value out of the card the moment a label ran to two lines — which
  /// Arabic labels do at this width, so the top of the report lost figures in
  /// exactly the language the redesign was for. Every tile has the same
  /// structure and a one-line label, so they come out the same height without
  /// being forced to.
  pw.Widget _tile(String label, String value, PdfColor accent) => pw.Container(
    decoration: pw.BoxDecoration(
      color: _band,
      borderRadius: pw.BorderRadius.circular(7),
      border: pw.Border.all(color: _hairline),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        // A hairline of colour along the top edge. It is the only ornament on
        // the card, and it is what lets four grey boxes read as a set of
        // distinct figures rather than one undifferentiated block.
        pw.Container(
          height: 2.5,
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(7),
              topRight: pw.Radius.circular(7),
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(11, 9, 11, 11),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              _auto(
                label,
                maxLines: 1,
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  color: _muted,
                  letterSpacing: 0.3,
                ),
              ),
              pw.SizedBox(height: 5),
              _auto(
                value,
                maxLines: 1,
                forceLtr: true,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// Every figure the historical half of the report carries.
  ///
  /// Labels keep their units. `Fuel` and `L` alone read as a category and a
  /// symbol rather than a cost and a volume, and the row for fuel cost per
  /// kilometre had been dropped outright — both of which made the table look
  /// like it was reporting the wrong numbers.
  pw.Widget _costTable(
    AnalyticsReport report,
    AppLocalizations l10n,
    bool rtl,
  ) => _table(
    rtl: rtl,
    flex: const [3, 2],
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

  /// Projected spend, monthly beside yearly.
  ///
  /// Laid out as its own panel rather than another table row: these are the
  /// only forward-looking numbers in the document, and mixing them into the
  /// historical table would invite them to be read as money already spent.
  pw.Widget _forecastPanel(
    ReportForecast forecast,
    AnalyticsReport report,
    AppLocalizations l10n,
  ) {
    final lines = <List<String>>[
      [
        l10n.tabFuel,
        _money(forecast.monthlyFuelCost, report),
        _money(forecast.yearlyFuelCost, report),
      ],
      [
        l10n.maintenance,
        _money(forecast.monthlyMaintenanceCost, report),
        _money(forecast.yearlyMaintenanceCost, report),
      ],
      [
        l10n.raw('reportOther'),
        _money(forecast.monthlyOtherCost, report),
        _money(forecast.yearlyOtherCost, report),
      ],
      [
        l10n.raw('forecastPolicies'),
        _money(forecast.monthlyPolicyCost, report),
        _money(forecast.yearlyPolicyCost, report),
      ],
    ];

    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _rule, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(12, 9, 12, 9),
            decoration: const pw.BoxDecoration(color: _band),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 4,
                  child: _auto(
                    '${l10n.raw('reportDailyPace')}: '
                    '${_dec1(forecast.avgDailyKm)} ${l10n.km}',
                    maxLines: 1,
                    style: const pw.TextStyle(fontSize: 8.5, color: _body),
                  ),
                ),
                _headCell(l10n.raw('reportPerMonth')),
                _headCell(l10n.raw('reportPerYear')),
              ],
            ),
          ),
          for (final line in lines) _forecastRow(line, bold: false),
          _forecastRow([
            l10n.raw('forecastTotal'),
            _money(forecast.monthlyTotal, report),
            _money(forecast.yearlyTotal, report),
          ], bold: true),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.fromLTRB(12, 8, 12, 9),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _hairline)),
            ),
            child: _auto(
              l10n.raw('reportAmortisedNote'),
              maxLines: 3,
              style: const pw.TextStyle(fontSize: 7.5, color: _muted),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _headCell(String text) => pw.Expanded(
    flex: 3,
    child: _auto(
      text,
      align: pw.TextAlign.end,
      maxLines: 1,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: _muted,
      ),
    ),
  );

  pw.Widget _forecastRow(
    List<String> cells, {
    required bool bold,
  }) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: pw.BoxDecoration(
      color: bold ? _accentSoft : null,
      border: const pw.Border(top: pw.BorderSide(color: _hairline, width: 0.7)),
    ),
    child: pw.Row(
      children: [
        pw.Expanded(
          flex: 4,
          child: pw.Text(
            cells[0],
            style: pw.TextStyle(
              fontSize: 9,
              color: bold ? _ink : _body,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        for (var i = 1; i < cells.length; i++)
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              cells[i],
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 9,
                color: _ink,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
      ],
    ),
  );

  // ---- transactions ----------------------------------------------------

  pw.Widget _rowsTable(
    AnalyticsReport report,
    AppLocalizations l10n,
    bool rtl,
  ) => _table(
    rtl: rtl,
    flex: const [3, 2, 3, 5, 3, 2, 3],
    headers: [
      l10n.raw('date'),
      l10n.raw('reportType'),
      l10n.raw('reportCategory'),
      l10n.raw('reportDescription'),
      l10n.raw('reportOdometer'),
      l10n.raw('reportQuantity'),
      l10n.raw('amount'),
    ],
    rows: [
      for (final row in report.rows)
        [
          _date(row.date),
          _rowType(row.type, l10n),
          // Translated here, unlike the CSV: this column is read by a person.
          row.categoryLabel ?? '',
          row.description,
          _int(row.odometer),
          row.quantity == null ? '' : _dec2(row.quantity!),
          _dec2(row.amount),
        ],
    ],
    numeric: const {0, 4, 5, 6},
  );

  /// Row types are stored as stable English keys in the CSV and JSON exports;
  /// only the printed label is translated, so the machine-readable formats stay
  /// language-independent.
  static String _rowType(String type, AppLocalizations l10n) => switch (type) {
    'fuel' => l10n.raw('reportRowFuel'),
    'service' => l10n.raw('reportRowService'),
    'expense' => l10n.raw('reportRowExpense'),
    _ => type,
  };

  /// **Built from widgets, not from `TableHelper.fromTextArray`.**
  ///
  /// The helper takes strings, so every cell inherits the page's direction and
  /// nothing else. That is wrong for the one column that holds whatever the
  /// driver typed: an Arabic description inside an English report came out
  /// unshaped and reversed. Cells are widgets here, so each one carries its own
  /// direction via [_auto] while the table around it stays mirrored to the
  /// report's language.
  ///
  /// `Table` is also the one widget that ignores `Directionality` for column
  /// order, so the columns are reversed by hand for an RTL report and the
  /// numeric ones move to the left edge — where a line of Arabic ends.
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
        alignment: isNumeric == rtl
            ? pw.Alignment.centerLeft
            : pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: _auto(
          text,
          maxLines: 2,
          forceLtr: isNumeric,
          style: header
              ? pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                )
              : const pw.TextStyle(fontSize: 8.5, color: _body),
        ),
      );
    }

    return pw.Table(
      // The panel around the table draws the outer edge, so only the dividers
      // between rows belong here.
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _hairline, width: 0.6),
      ),
      columnWidths: {
        for (var i = 0; i < count; i++)
          i: pw.FlexColumnWidth(flex[source(i)].toDouble()),
      },
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: _band),
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
                ? const pw.BoxDecoration(color: _band)
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
          width: 128,
          height: 128,
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
                    style: const pw.TextStyle(fontSize: 8.5, color: _muted),
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
  pw.Widget _lineChart(List<ReportPoint> series, PdfColor color, int decimals) {
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
      height: 172,
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
              textStyle: const pw.TextStyle(fontSize: 7, color: _muted),
            ),
            yAxis: pw.FixedAxis(
              ticks,
              format: (v) => v.toDouble().toStringAsFixed(decimals),
              divisions: true,
              divisionsColor: _hairline,
              textStyle: const pw.TextStyle(fontSize: 7, color: _muted),
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
