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
        : Uint8List.fromList(utf8.encode(_text(report, format)));

    return _saver.save(
      fileName: _fileName(report, format),
      bytes: bytes,
      mimeType: format.mimeType,
    );
  }

  String _text(AnalyticsReport report, ReportFormat format) => switch (format) {
    ReportFormat.csv => _csv(report),
    ReportFormat.json => const JsonEncoder.withIndent(
      '  ',
    ).convert(report.toJson()),
    ReportFormat.pdf => throw StateError('PDF is rendered as bytes'),
  };

  String _fileName(AnalyticsReport report, ReportFormat format) {
    final slug = report.vehicleName
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^\w\-]'), '');
    final stamp = report.generatedAt.toIso8601String().split('T').first;
    return 'vehicle-care-$slug-$stamp.${format.extension}';
  }

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
