import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/entities/analytics_report.dart';

/// Renders an [AnalyticsReport] as a print-ready PDF.
///
/// Charts are drawn as **vector** graphics by the `pdf` package rather than
/// screenshotted from the live widget tree. That keeps the builder pure — no
/// `BuildContext`, no `RepaintBoundary`, no frame to wait for — so it runs off
/// the UI thread, produces a file a tenth the size, and stays sharp at any
/// zoom.
///
/// Labels are English, matching the CSV and JSON exports. The bundled base-14
/// fonts have no Arabic coverage, so free text the user typed is passed through
/// [_latin] and anything unrenderable becomes `?` instead of a tofu box.
class PdfReportBuilder {
  const PdfReportBuilder();

  static const PdfColor _ink = PdfColor.fromInt(0xFF16202C);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7A8C);
  static const PdfColor _rule = PdfColor.fromInt(0xFFD8E0E8);
  static const PdfColor _band = PdfColor.fromInt(0xFFF3F6F9);
  static const PdfColor _accent = PdfColor.fromInt(0xFF00B8D4);
  static const PdfColor _green = PdfColor.fromInt(0xFF2ECC71);

  Future<Uint8List> build(AnalyticsReport report) async {
    final document = pw.Document(
      title: 'Vehicle Care report',
      author: 'Vehicle Care',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 34, 34, 40),
        header: (context) =>
            context.pageNumber == 1 ? pw.SizedBox() : _runningHeader(report),
        footer: _footer,
        build: (context) => [
          _title(report),
          pw.SizedBox(height: 18),
          _summaryGrid(report),
          pw.SizedBox(height: 18),
          _costTable(report),
          if (report.spendSlices.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('Where the money went'),
            pw.SizedBox(height: 10),
            _spendChart(report),
          ],
          if (report.efficiencySeries.length >= 2) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('Fuel consumption trend (L/100km)'),
            pw.SizedBox(height: 10),
            _lineChart(report.efficiencySeries, _accent, 1),
          ],
          if (report.costPerKmSeries.length >= 2) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('Cost per kilometre trend'),
            pw.SizedBox(height: 10),
            _lineChart(report.costPerKmSeries, _green, 2),
          ],
          if (report.rows.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            _sectionTitle('Transactions (${report.rows.length})'),
            pw.SizedBox(height: 10),
            _rowsTable(report),
          ],
        ],
      ),
    );

    return document.save();
  }

  // ---- page furniture --------------------------------------------------

  pw.Widget _title(AnalyticsReport report) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _latin(report.vehicleName),
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                _latin(report.vehicleSubtitle),
                style: const pw.TextStyle(fontSize: 10, color: _muted),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'VEHICLE CARE',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _accent,
                  letterSpacing: 1.6,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Generated ${_date(report.generatedAt)}',
                style: const pw.TextStyle(fontSize: 9, color: _muted),
              ),
              pw.Text(
                '${_date(report.rangeStart)} - ${_date(report.rangeEnd)}',
                style: const pw.TextStyle(fontSize: 9, color: _muted),
              ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Container(height: 2, color: _accent),
    ],
  );

  pw.Widget _runningHeader(AnalyticsReport report) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.only(bottom: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _rule)),
    ),
    child: pw.Text(
      '${_latin(report.vehicleName)}  ·  Vehicle Care report',
      style: const pw.TextStyle(fontSize: 9, color: _muted),
    ),
  );

  pw.Widget _footer(pw.Context context) => pw.Container(
    alignment: pw.Alignment.centerRight,
    margin: const pw.EdgeInsets.only(top: 10),
    child: pw.Text(
      'Page ${context.pageNumber} of ${context.pagesCount}',
      style: const pw.TextStyle(fontSize: 9, color: _muted),
    ),
  );

  pw.Widget _sectionTitle(String text) => pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    ),
  );

  // ---- summary ---------------------------------------------------------

  /// The four figures that answer "what has this car cost me".
  pw.Widget _summaryGrid(AnalyticsReport report) {
    final tiles = <List<String>>[
      ['Total spend', _money(report.totalCost)],
      ['Cost per km', report.costPerKm.toStringAsFixed(2)],
      ['Consumption', '${report.avgLitersPer100Km.toStringAsFixed(2)} L/100km'],
      ['Tracked distance', '${_int(report.distanceKm)} km'],
    ];

    return pw.Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 12,
              ),
              decoration: pw.BoxDecoration(
                color: _band,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: _rule),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    tiles[i][0].toUpperCase(),
                    style: const pw.TextStyle(fontSize: 7, color: _muted),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    tiles[i][1],
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  pw.Widget _costTable(AnalyticsReport report) => _table(
    headers: const ['Metric', 'Value'],
    rows: [
      ['Odometer', '${_int(report.currentOdometer)} km'],
      ['Tracked distance', '${_int(report.distanceKm)} km'],
      ['Fuel cost', _money(report.fuelCost)],
      ['Service cost', _money(report.serviceCost)],
      ['Parts cost', _money(report.partsCost)],
      ['Other cost', _money(report.otherCost)],
      ['Total cost', _money(report.totalCost)],
      ['Litres', report.liters.toStringAsFixed(2)],
      ['Consumption L/100km', report.avgLitersPer100Km.toStringAsFixed(2)],
      ['Efficiency km/L', report.avgEfficiency.toStringAsFixed(2)],
      ['Fuel cost per km', report.fuelCostPerKm.toStringAsFixed(2)],
      ['Total cost per km', report.costPerKm.toStringAsFixed(2)],
    ],
    alignRight: const {1},
  );

  pw.Widget _rowsTable(AnalyticsReport report) => _table(
    headers: const ['Date', 'Type', 'Description', 'Odometer', 'Qty', 'Amount'],
    rows: [
      for (final row in report.rows)
        [
          _date(row.date),
          row.type,
          _latin(row.description),
          _int(row.odometer),
          row.quantity?.toStringAsFixed(2) ?? '',
          row.amount.toStringAsFixed(2),
        ],
    ],
    alignRight: const {3, 4, 5},
  );

  pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    Set<int> alignRight = const {},
  }) => pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    border: null,
    headerDecoration: const pw.BoxDecoration(color: _band),
    headerStyle: pw.TextStyle(
      fontSize: 8.5,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    ),
    cellStyle: const pw.TextStyle(fontSize: 8.5, color: _ink),
    cellHeight: 18,
    headerPadding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    // Zebra striping instead of grid lines: fewer marks, same scannability.
    oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
    rowDecoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.5)),
    ),
    cellAlignments: {
      for (var i = 0; i < headers.length; i++)
        i: alignRight.contains(i)
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
    },
  );

  // ---- charts ----------------------------------------------------------

  /// Horizontal bars for the spend split. A bar chart beats a pie here: the
  /// categories are few, the labels are long, and lengths compare better than
  /// angles.
  pw.Widget _spendChart(AnalyticsReport report) {
    final max = report.spendSlices
        .map((s) => s.value)
        .fold<double>(0, (a, b) => a > b ? a : b);
    if (max <= 0) return pw.SizedBox();

    return pw.Column(
      children: [
        for (final slice in report.spendSlices)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 7),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(
                  width: 62,
                  child: pw.Text(
                    slice.label,
                    style: const pw.TextStyle(fontSize: 9, color: _ink),
                  ),
                ),
                // Two weighted flex boxes rather than a stacked overlay: the
                // pdf layout engine has no fractional sizing, and integer flex
                // gives an exact proportion at any page width.
                pw.Expanded(
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: _flexOf(slice.value, max),
                        child: pw.Container(
                          height: 13,
                          color: PdfColor.fromInt(slice.colorValue),
                        ),
                      ),
                      pw.Expanded(
                        flex: 1000 - _flexOf(slice.value, max),
                        child: pw.Container(height: 13, color: _band),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.SizedBox(
                  width: 68,
                  child: pw.Text(
                    _money(slice.value),
                    textAlign: pw.TextAlign.right,
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
      height: 168,
      padding: const pw.EdgeInsets.only(top: 6, right: 6),
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
            divisionsColor: _rule,
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
    );
  }

  // ---- formatting ------------------------------------------------------

  static String _money(double v) => v.toStringAsFixed(2);

  static String _int(int v) {
    final digits = v.abs().toString();
    final buffer = StringBuffer(v < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.year}';

  static String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}';

  /// The base-14 PDF fonts cover Latin-1 only. Anything outside it — Arabic
  /// vehicle nicknames, emoji in a note — becomes `?` rather than a tofu box or
  /// a font-lookup failure mid-render.
  static String _latin(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      buffer.write(rune <= 0xFF ? String.fromCharCode(rune) : '?');
    }
    return buffer.toString().trim();
  }
}
