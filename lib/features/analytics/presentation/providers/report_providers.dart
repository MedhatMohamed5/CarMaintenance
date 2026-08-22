import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/file_saver.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/analytics_report.dart';
import '../../domain/repositories/report_exporter.dart';
import 'analytics_providers.dart';

final reportExporterProvider = Provider<ReportExporter>(
  (ref) => FileReportExporter(ref.watch(fileSaverProvider)),
);

final analyticsReportProvider = Provider<AnalyticsReport?>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return null;

  final span = ref.watch(analyticsSpanProvider);
  final summary = ref.watch(analyticsSummaryProvider);
  final stats = ref.watch(analyticsFuelStatsProvider);

  final efficiencyByLogId = {
    for (final segment in stats.segments) segment.log.id: segment.efficiency,
  };

  final rows = <ReportRow>[
    for (final log in ref.watch(analyticsFuelLogsProvider))
      ReportRow(
        date: log.date,
        type: 'fuel',
        description: log.fuelType.name,
        odometer: log.odometer,
        amount: log.totalCost,
        quantity: log.liters,
        efficiency: efficiencyByLogId[log.id],
      ),
    for (final record in ref.watch(analyticsServicesProvider))
      ReportRow(
        date: record.date,
        type: 'service',
        description: record.title,
        odometer: record.odometer,
        amount: record.cost,
      ),
    for (final expense in ref.watch(analyticsExpensesProvider))
      ReportRow(
        date: expense.date,
        type: 'expense',
        description: expense.title,
        odometer: expense.odometer ?? 0,
        amount: expense.amount,
      ),
  ]..sort((a, b) => b.date.compareTo(a.date));

  return AnalyticsReport(
    vehicleName: vehicle.displayName,
    vehicleSubtitle: vehicle.subtitle,
    generatedAt: DateTime.now(),
    rangeStart: span.start,
    rangeEnd: span.end,
    currentOdometer: vehicle.currentOdometer,
    fuelCost: summary.fuelCost,
    serviceCost: summary.serviceCost,
    otherCost: summary.otherCost,
    distanceKm: summary.distanceKm,
    liters: summary.liters,
    avgEfficiency: summary.avgEfficiency,
    avgLitersPer100Km: summary.avgLitersPer100Km,
    costPerKm: summary.costPerKm,
    fuelCostPerKm: summary.fuelCostPerKm,
    partsCost: summary.partsCost,
    rows: rows,
    // Series are oldest-first so the PDF reads left to right.
    efficiencySeries: [
      for (final segment in stats.segments.reversed)
        ReportPoint(date: segment.date, value: segment.litersPer100Km),
    ],
    costPerKmSeries: [
      for (final segment in stats.segments.reversed)
        ReportPoint(date: segment.date, value: segment.costPerKm),
    ],
    spendSlices: [
      ReportSlice(
        label: 'Fuel',
        value: summary.fuelCost,
        colorValue: AppColors.cyan.toARGB32(),
      ),
      ReportSlice(
        label: 'Service',
        value: summary.serviceCost,
        colorValue: AppColors.amber.toARGB32(),
      ),
      ReportSlice(
        label: 'Parts',
        value: summary.partsCost,
        colorValue: AppColors.teal.toARGB32(),
      ),
      ReportSlice(
        label: 'Other',
        value: summary.otherCost,
        colorValue: AppColors.purple.toARGB32(),
      ),
    ].where((s) => s.value > 0).toList(growable: false),
  );
});

class ExportController extends AsyncNotifier<SavedFile?> {
  @override
  Future<SavedFile?> build() async => null;

  Future<void> export(ReportFormat format) async {
    final report = ref.read(analyticsReportProvider);
    if (report == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(reportExporterProvider).export(report, format),
    );
  }
}

final exportControllerProvider =
    AsyncNotifierProvider<ExportController, SavedFile?>(ExportController.new);
