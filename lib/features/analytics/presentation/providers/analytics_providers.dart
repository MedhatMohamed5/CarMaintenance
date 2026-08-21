import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../fuel/domain/entities/fuel_log.dart';
import '../../../fuel/domain/entities/fuel_stats.dart';
import '../../../fuel/domain/entities/fuel_type.dart';
import '../../../fuel/presentation/providers/fuel_providers.dart';
import '../../../maintenance/domain/entities/maintenance_record.dart';
import '../../../maintenance/presentation/providers/maintenance_providers.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';

enum AnalyticsRange {
  last3Months(90),
  last6Months(180),
  lastYear(365),
  allTime(0);

  const AnalyticsRange(this.days);

  final int days;
}

class DateSpan {
  const DateSpan({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) =>
      !date.isBefore(start) && !date.isAfter(end);

  DateSpan copyWith({DateTime? start, DateTime? end}) =>
      DateSpan(start: start ?? this.start, end: end ?? this.end);
}

class ChartPoint {
  const ChartPoint({
    required this.x,
    required this.y,
    required this.date,
    this.label = '',
    this.colorValue,
  });

  final double x;
  final double y;
  final DateTime date;
  final String label;
  final int? colorValue;
}

class DonutSlice {
  const DonutSlice({
    required this.labelKey,
    required this.value,
    required this.share,
    required this.colorValue,
  });

  final String labelKey;
  final double value;
  final double share;
  final int colorValue;
}

class AnalyticsSummary {
  const AnalyticsSummary({
    required this.fuelCost,
    required this.serviceCost,
    required this.otherCost,
    required this.distanceKm,
    required this.liters,
    required this.avgEfficiency,
    required this.costPerKm,
    required this.fillCount,
    required this.serviceCount,
    required this.expenseCount,
  });

  const AnalyticsSummary.empty()
    : fuelCost = 0,
      serviceCost = 0,
      otherCost = 0,
      distanceKm = 0,
      liters = 0,
      avgEfficiency = 0,
      costPerKm = 0,
      fillCount = 0,
      serviceCount = 0,
      expenseCount = 0;

  final double fuelCost;
  final double serviceCost;
  final double otherCost;
  final int distanceKm;
  final double liters;
  final double avgEfficiency;
  final double costPerKm;
  final int fillCount;
  final int serviceCount;
  final int expenseCount;

  double get totalCost => fuelCost + serviceCost + otherCost;

  bool get isEmpty =>
      fillCount == 0 && serviceCount == 0 && expenseCount == 0;
}

class AnalyticsRangeNotifier extends Notifier<AnalyticsRange> {
  @override
  AnalyticsRange build() => AnalyticsRange.last6Months;

  void set(AnalyticsRange range) {
    state = range;
    ref.read(analyticsCustomSpanProvider.notifier).state = null;
  }
}

final analyticsRangeProvider =
    NotifierProvider<AnalyticsRangeNotifier, AnalyticsRange>(
      AnalyticsRangeNotifier.new,
    );

final analyticsCustomSpanProvider = StateProvider<DateSpan?>((ref) => null);

final analyticsSpanProvider = Provider<DateSpan>((ref) {
  final custom = ref.watch(analyticsCustomSpanProvider);
  if (custom != null) return custom;

  final range = ref.watch(analyticsRangeProvider);
  final now = DateTime.now();
  final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

  if (range == AnalyticsRange.allTime) {
    return DateSpan(start: DateTime.fromMillisecondsSinceEpoch(0), end: end);
  }
  return DateSpan(
    start: DateTime(now.year, now.month, now.day - range.days),
    end: end,
  );
});

final analyticsFuelLogsProvider = Provider<List<FuelLog>>((ref) {
  final span = ref.watch(analyticsSpanProvider);
  final logs = ref.watch(fuelLogsProvider);
  return logs.where((l) => span.contains(l.date)).toList(growable: false);
});

final analyticsFuelStatsProvider = Provider<FuelStats>((ref) {
  final logs = ref.watch(analyticsFuelLogsProvider);
  if (logs.isEmpty) return const FuelStats.empty();
  return ref.watch(calculateFuelStatsProvider)(logs);
});

final analyticsExpensesProvider = Provider<List<Expense>>((ref) {
  final span = ref.watch(analyticsSpanProvider);
  final expenses = ref.watch(expensesProvider);
  return expenses.where((e) => span.contains(e.date)).toList(growable: false);
});

final analyticsServicesProvider = Provider<List<MaintenanceRecord>>((ref) {
  final span = ref.watch(analyticsSpanProvider);
  final records =
      ref.watch(maintenanceRecordsProvider);
  return records.where((r) => span.contains(r.date)).toList(growable: false);
});

final analyticsSummaryProvider = Provider<AnalyticsSummary>((ref) {
  final stats = ref.watch(analyticsFuelStatsProvider);
  final expenses = ref.watch(analyticsExpensesProvider);
  final services = ref.watch(analyticsServicesProvider);
  final logs = ref.watch(analyticsFuelLogsProvider);

  final serviceCost = services.fold<double>(0, (s, r) => s + r.cost);
  final otherCost = expenses.fold<double>(0, (s, e) => s + e.amount);
  final measuredDistance = stats.segments.fold<int>(
    0,
    (s, x) => s + x.distanceKm,
  );
  final total = stats.totalCost + serviceCost + otherCost;

  return AnalyticsSummary(
    fuelCost: stats.totalCost,
    serviceCost: serviceCost,
    otherCost: otherCost,
    distanceKm: measuredDistance,
    liters: stats.totalLiters,
    avgEfficiency: stats.avgEfficiency,
    costPerKm: measuredDistance <= 0 ? 0 : total / measuredDistance,
    fillCount: logs.length,
    serviceCount: services.length,
    expenseCount: expenses.length,
  );
});

final fuelEfficiencyTrendProvider = Provider<List<ChartPoint>>((ref) {
  final segments = ref.watch(analyticsFuelStatsProvider).segments;
  if (segments.isEmpty) return const [];

  final ordered = segments.reversed.toList(growable: false);
  return List<ChartPoint>.generate(
    ordered.length,
    (i) => ChartPoint(
      x: i.toDouble(),
      y: double.parse(ordered[i].efficiency.toStringAsFixed(2)),
      date: ordered[i].date,
      label: ordered[i].fuelType.l10nKey,
      colorValue: _fuelColor(ordered[i].fuelType),
    ),
    growable: false,
  );
});

final costPerKmTrendProvider = Provider<List<ChartPoint>>((ref) {
  final segments = ref.watch(analyticsFuelStatsProvider).segments;
  if (segments.isEmpty) return const [];

  final ordered = segments.reversed.toList(growable: false);
  return List<ChartPoint>.generate(
    ordered.length,
    (i) => ChartPoint(
      x: i.toDouble(),
      y: double.parse(ordered[i].costPerKm.toStringAsFixed(3)),
      date: ordered[i].date,
    ),
    growable: false,
  );
});

final odometerTrendProvider = Provider<List<ChartPoint>>((ref) {
  final logs = [...ref.watch(analyticsFuelLogsProvider)]
    ..sort((a, b) => a.date.compareTo(b.date));
  if (logs.isEmpty) return const [];

  return List<ChartPoint>.generate(
    logs.length,
    (i) => ChartPoint(
      x: i.toDouble(),
      y: logs[i].odometer.toDouble(),
      date: logs[i].date,
    ),
    growable: false,
  );
});

final monthlySpendTrendProvider = Provider<List<ChartPoint>>((ref) {
  final byMonth = <DateTime, double>{};

  void add(DateTime date, double amount) {
    final key = DateTime(date.year, date.month);
    byMonth[key] = (byMonth[key] ?? 0) + amount;
  }

  for (final log in ref.watch(analyticsFuelLogsProvider)) {
    add(log.date, log.totalCost);
  }
  for (final record in ref.watch(analyticsServicesProvider)) {
    add(record.date, record.cost);
  }
  for (final expense in ref.watch(analyticsExpensesProvider)) {
    add(expense.date, expense.amount);
  }

  final keys = byMonth.keys.toList()..sort();
  return List<ChartPoint>.generate(
    keys.length,
    (i) => ChartPoint(x: i.toDouble(), y: byMonth[keys[i]]!, date: keys[i]),
    growable: false,
  );
});

final expenseDonutProvider = Provider<List<DonutSlice>>((ref) {
  final summary = ref.watch(analyticsSummaryProvider);
  final total = summary.totalCost;
  if (total <= 0) return const [];

  final entries = <(String, double, int)>[
    ('tabFuel', summary.fuelCost, 0xFF22D3EE),
    ('maintenance', summary.serviceCost, 0xFFF59E0B),
    ...ref
        .watch(analyticsCategorySharesProvider)
        .map((s) => (s.labelKey, s.value, s.colorValue)),
  ];

  final slices =
      entries
          .where((e) => e.$2 > 0)
          .map(
            (e) => DonutSlice(
              labelKey: e.$1,
              value: e.$2,
              share: e.$2 / total,
              colorValue: e.$3,
            ),
          )
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

  return List.unmodifiable(slices);
});

final analyticsCategorySharesProvider = Provider<List<DonutSlice>>((ref) {
  final expenses = ref.watch(analyticsExpensesProvider);
  if (expenses.isEmpty) return const [];

  final totals = <ExpenseCategory, double>{};
  for (final e in expenses) {
    totals[e.category] = (totals[e.category] ?? 0) + e.amount;
  }
  final grand = totals.values.fold<double>(0, (s, v) => s + v);

  final slices =
      totals.entries
          .map(
            (e) => DonutSlice(
              labelKey: e.key.l10nKey,
              value: e.value,
              share: grand <= 0 ? 0 : e.value / grand,
              colorValue: e.key.colorValue,
            ),
          )
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

  return List.unmodifiable(slices);
});

final fuelTypeBreakdownProvider = Provider<List<DonutSlice>>((ref) {
  final byType = ref.watch(analyticsFuelStatsProvider).byFuelType;
  if (byType.isEmpty) return const [];

  final total = byType.fold<double>(0, (s, t) => s + t.totalCost);
  return List.unmodifiable(
    byType.map(
      (t) => DonutSlice(
        labelKey: t.fuelType.l10nKey,
        value: t.totalCost,
        share: total <= 0 ? 0 : t.totalCost / total,
        colorValue: _fuelColor(t.fuelType),
      ),
    ),
  );
});

final analyticsHasDataProvider = Provider<bool>(
  (ref) =>
      ref.watch(selectedVehicleProvider) != null &&
      !ref.watch(analyticsSummaryProvider).isEmpty,
);

int _fuelColor(FuelType type) => switch (type) {
  FuelType.octane92 => 0xFF34D399,
  FuelType.octane95 => 0xFF22D3EE,
  FuelType.diesel => 0xFFF59E0B,
};
