import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/platform/file_saver.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../data/file_report_exporter.dart';
import '../../domain/entities/analytics_report.dart';
import '../../domain/repositories/report_exporter.dart';
import 'analytics_providers.dart';
import 'forecast_providers.dart';

final reportExporterProvider = Provider<ReportExporter>(
  (ref) => FileReportExporter(ref.watch(fileSaverProvider)),
);

final analyticsReportProvider = Provider<AnalyticsReport?>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return null;

  // The report carries its own language: the exporter runs without a
  // `BuildContext`, so it cannot reach `Localizations.of` when it needs a label.
  final l10n = AppLocalizations(ref.watch(localeProvider));
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
        category: log.fuelType.name,
        categoryLabel: l10n.raw(log.fuelType.l10nKey),
        description: l10n.raw(log.fuelType.l10nKey),
        odometer: log.odometer,
        amount: log.totalCost,
        quantity: log.liters,
        efficiency: efficiencyByLogId[log.id],
      ),
    for (final record in ref.watch(analyticsServicesProvider))
      ReportRow(
        date: record.date,
        // Two stable keys, not one. A spreadsheet built on this export should
        // be able to total repairs without reading the description column in
        // whatever language the report was generated in.
        type: record.tier.isCorrective ? 'repair' : 'service',
        category: record.tier.name,
        categoryLabel: l10n.raw(record.tier.l10nKey),
        description: record.title,
        odometer: record.odometer,
        amount: record.cost,
      ),
    for (final expense in ref.watch(analyticsExpensesProvider))
      ReportRow(
        date: expense.date,
        type: 'expense',
        category: expense.category.name,
        categoryLabel: l10n.raw(expense.category.l10nKey),
        description: expense.title,
        odometer: expense.odometer ?? 0,
        amount: expense.amount,
      ),
  ]..sort((a, b) => b.date.compareTo(a.date));

  final forecast = ref.watch(vehicleForecastProvider);

  return AnalyticsReport(
    localeTag: l10n.locale.languageCode,
    currencyLabel: l10n.currency,
    plateNumber: vehicle.plateNumber,
    vehicleImage: _decodeImage(vehicle.imageBase64),
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
    forecast: forecast.hasEnoughData
        ? ReportForecast(
            avgDailyKm: forecast.avgDailyKm,
            monthlyKm: forecast.projectedMonthlyKm,
            yearlyKm: forecast.projectedYearlyKm,
            monthlyFuelCost: forecast.monthlyFuelCost,
            yearlyFuelCost: forecast.yearlyFuelCost,
            monthlyLiters: forecast.monthlyLiters,
            monthlyMaintenanceCost: forecast.monthlyMaintenanceCost,
            yearlyMaintenanceCost: forecast.yearlyMaintenanceCost,
            monthlyOtherCost: forecast.monthlyOtherCost,
            yearlyOtherCost: forecast.yearlyOtherCost,
            monthlyPolicyCost: forecast.monthlyPolicyCost,
            yearlyPolicyCost: forecast.yearlyPolicyCost,
          )
        : null,
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
        label: l10n.tabFuel,
        value: summary.fuelCost,
        colorValue: AppColors.cyan.toARGB32(),
      ),
      ReportSlice(
        label: l10n.raw('scheduledMaintenance'),
        value: summary.serviceCost,
        colorValue: AppColors.amber.toARGB32(),
      ),
      ReportSlice(
        label: l10n.raw('unscheduledRepairs'),
        value: summary.repairCost,
        colorValue: AppColors.red.toARGB32(),
      ),
      ReportSlice(
        label: l10n.raw('reportParts'),
        value: summary.partsCost,
        colorValue: AppColors.teal.toARGB32(),
      ),
      ReportSlice(
        label: l10n.raw('operationalExpenses'),
        value: summary.otherCost,
        colorValue: AppColors.purple.toARGB32(),
      ),
    ].where((s) => s.value > 0).toList(growable: false),
  );
});

/// The stored photo as bytes, or null if it cannot be read.
///
/// A photo saved by an older build, or truncated in transit, should cost the
/// user a missing picture — not a failed export.
Uint8List? _decodeImage(String? base64Data) {
  if (base64Data == null || base64Data.isEmpty) return null;
  try {
    return base64Decode(base64Data);
  } on FormatException {
    return null;
  }
}

class ExportController extends AsyncNotifier<SavedFile?> {
  @override
  Future<SavedFile?> build() async => null;

  Future<void> export(ReportFormat format) async {
    final report = ref.read(analyticsReportProvider);
    if (report == null) return;

    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(reportExporterProvider).export(report, format),
    );
    state = result;

    // **Opened after the state has settled, and never allowed to undo it.**
    // Exporting is finished the moment the bytes are on disk; handing the file
    // to a viewer is a courtesy on top. Folding the open into the guarded call
    // would have let a device with no PDF reader turn a successful export into
    // a visible failure, so the result is published first and the open is
    // attempted against it.
    final saved = result.valueOrNull;
    if (saved?.path == null) return;
    await ref
        .read(fileOpenerProvider)
        .open(saved!.path!, mimeType: format.mimeType);
  }
}

final exportControllerProvider =
    AsyncNotifierProvider<ExportController, SavedFile?>(ExportController.new);
