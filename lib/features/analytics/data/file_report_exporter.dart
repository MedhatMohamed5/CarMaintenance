import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/platform/file_saver.dart';
import '../domain/entities/analytics_report.dart';
import '../domain/repositories/report_exporter.dart';
import 'pdf_report_builder.dart';

class FileReportExporter implements ReportExporter {
  const FileReportExporter(this._saver, {PdfReportBuilder? pdfBuilder})
    : _pdf = pdfBuilder ?? const PdfReportBuilder();

  final FileSaver _saver;
  final PdfReportBuilder _pdf;

  @override
  Future<SavedFile> export(AnalyticsReport report, ReportFormat format) async {
    // PDF is bytes end to end; CSV and JSON are text encoded on the way out.
    final bytes = format == ReportFormat.pdf
        ? await _pdf.build(report)
        : _encode(_text(report, format), format);

    return _saver.save(
      fileName: _fileName(report, format),
      bytes: bytes,
      mimeType: format.mimeType,
    );
  }

  /// Text as bytes, with a byte-order mark only where it is needed.
  ///
  /// **Excel does not detect UTF-8 in a `.csv` on its own.** With no BOM it
  /// decodes the file using the system codepage — Windows-1252 on an English
  /// install — so every Arabic character arrives as a run of mojibake. That is
  /// why the problem showed up on an English Windows and not an Arabic one:
  /// codepage 1256 happens to survive some of it. The three-byte mark is the
  /// documented way to tell Excel the file is Unicode, and every other CSV
  /// reader skips it.
  ///
  /// JSON deliberately gets none. RFC 8259 requires UTF-8 without a BOM, and
  /// several parsers fail on the mark rather than ignoring it — including
  /// Dart's own `jsonDecode`, which would break the vehicle-transfer import
  /// that reads these files back.
  Uint8List _encode(String text, ReportFormat format) {
    final body = utf8.encode(text);
    if (format != ReportFormat.csv) return Uint8List.fromList(body);
    return Uint8List.fromList([..._utf8Bom, ...body]);
  }

  static const List<int> _utf8Bom = [0xEF, 0xBB, 0xBF];

  String _text(AnalyticsReport report, ReportFormat format) => switch (format) {
    ReportFormat.csv => _csv(report),
    ReportFormat.json => const JsonEncoder.withIndent(
      '  ',
    ).convert(report.toJson()),
    ReportFormat.pdf => throw StateError('PDF is rendered as bytes'),
  };

  /// A name no earlier export can collide with.
  ///
  /// **Stamped from the clock at save time, not from
  /// [AnalyticsReport.generatedAt].** That field is filled inside a Riverpod
  /// `Provider`, which caches until one of its dependencies changes — so two
  /// exports minutes apart carry the same `generatedAt`, and a name built from
  /// it repeats even at second precision. The saver writes whatever name it is
  /// handed, so a repeated name is a silently overwritten file.
  ///
  /// **The clock alone is not fine enough.** Two exports measured back to back
  /// landed on the same millisecond and produced the same name, so a counter
  /// carries the uniqueness and the timestamp carries the meaning: the reader
  /// gets a name they can sort and recognise, and the file is safe regardless
  /// of how coarse the platform clock turns out to be.
  String _fileName(AnalyticsReport report, ReportFormat format) {
    final now = DateTime.now();
    final tie = (_sequence++ % 36).toRadixString(36);
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}'
        '-${_two(now.hour)}${_two(now.minute)}${_two(now.second)}'
        '-${now.millisecond.toString().padLeft(3, '0')}$tie';
    return 'vehicle-care-${_slug(report.vehicleName)}-$stamp'
        '.${format.extension}';
  }

  /// Bumped on every export for the life of the process. It only has to break
  /// ties inside a single millisecond, so wrapping at 36 keeps the suffix to
  /// one character; across launches the timestamp has long since moved on.
  static int _sequence = 0;

  /// The vehicle name, reduced to something every file system accepts.
  ///
  /// Arabic names used to reduce to nothing: `\w` is ASCII-only in Dart, so
  /// every letter was stripped and the file came out as `vehicle-care--…`.
  /// Arabic letters and digits are kept; only characters a path cannot carry
  /// are dropped, and a name that survives as nothing falls back to `vehicle`
  /// rather than leaving a double dash.
  static String _slug(String name) {
    final collapsed = name.trim().replaceAll(RegExp(r'\s+'), '-');
    final buffer = StringBuffer();
    for (final rune in collapsed.runes) {
      final char = String.fromCharCode(rune);
      final keep =
          RegExp(r'[A-Za-z0-9\-_]').hasMatch(char) ||
          (rune >= 0x0600 && rune <= 0x06FF) ||
          (rune >= 0x0750 && rune <= 0x077F) ||
          (rune >= 0xFB50 && rune <= 0xFEFF);
      if (keep) buffer.write(char);
    }
    final slug = buffer.toString().replaceAll(RegExp(r'-{2,}'), '-');
    return slug.isEmpty ? 'vehicle' : slug;
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  String _csv(AnalyticsReport report) {
    final buffer = StringBuffer()
      ..writeln(_line(['Vehicle', report.vehicleName]))
      ..writeln(_line(['Details', report.vehicleSubtitle]))
      ..writeln(_line(['Odometer', '${report.currentOdometer}']))
      ..writeln(
        _line([
          'Range',
          '${_date(report.rangeStart)} - ${_date(report.rangeEnd)}',
        ]),
      )
      ..writeln(_line(['Generated', _date(report.generatedAt)]))
      ..writeln()
      ..writeln(_line(['Fuel cost', report.fuelCost.toStringAsFixed(2)]))
      ..writeln(_line(['Service cost', report.serviceCost.toStringAsFixed(2)]))
      ..writeln(_line(['Other cost', report.otherCost.toStringAsFixed(2)]))
      ..writeln(_line(['Total cost', report.totalCost.toStringAsFixed(2)]))
      ..writeln(_line(['Distance km', '${report.distanceKm}']))
      ..writeln(_line(['Litres', report.liters.toStringAsFixed(2)]))
      ..writeln(
        _line([
          'Avg consumption L/100km',
          report.avgLitersPer100Km.toStringAsFixed(2),
        ]),
      )
      ..writeln(
        _line(['Avg efficiency km/L', report.avgEfficiency.toStringAsFixed(2)]),
      )
      ..writeln(_line(['Parts cost', report.partsCost.toStringAsFixed(2)]))
      ..writeln(
        _line(['Fuel cost per km', report.fuelCostPerKm.toStringAsFixed(2)]),
      )
      ..writeln(_line(['Cost per km', report.costPerKm.toStringAsFixed(2)]))
      ..writeln()
      ..writeln(
        _line([
          'Date',
          'Type',
          'Category',
          'Description',
          'Odometer',
          'Amount',
          'Quantity',
          'Efficiency',
        ]),
      );

    for (final row in report.rows) {
      buffer.writeln(
        _line([
          _date(row.date),
          row.type,
          // The stable key, not the printed label: a CSV is read by a machine
          // or by someone filtering a spreadsheet, and neither wants the column
          // to change spelling with the app's language.
          row.category ?? '',
          row.description,
          '${row.odometer}',
          row.amount.toStringAsFixed(2),
          row.quantity?.toStringAsFixed(2) ?? '',
          row.efficiency?.toStringAsFixed(2) ?? '',
        ]),
      );
    }

    return buffer.toString();
  }

  String _line(List<String> cells) => cells.map(_cell).join(',');

  String _cell(String value) {
    final escaped = value.replaceAll('"', '""');
    return escaped.contains(RegExp('[,"\n]')) ? '"$escaped"' : escaped;
  }

  String _date(DateTime d) => d.toIso8601String().split('T').first;
}
