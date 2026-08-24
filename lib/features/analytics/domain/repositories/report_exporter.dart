import '../../../../core/platform/file_saver.dart';
import '../entities/analytics_report.dart';

enum ReportFormat {
  csv('csv', 'text/csv'),
  json('json', 'application/json'),
  pdf('pdf', 'application/pdf');

  const ReportFormat(this.extension, this.mimeType);

  final String extension;
  final String mimeType;
}

abstract interface class ReportExporter {
  Future<SavedFile> export(AnalyticsReport report, ReportFormat format);
}
