import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/utils/formatters.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../fuel/domain/entities/fuel_log.dart';
import '../../../fuel/domain/entities/fuel_stats.dart';
import '../../../fuel/domain/entities/fuel_type.dart';
import '../../../fuel/presentation/providers/fuel_providers.dart';
import '../../../maintenance/domain/entities/maintenance_record.dart';
import '../../../maintenance/presentation/providers/maintenance_providers.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import 'vehicle_metrics_provider.dart';

/// The preset periods, in the order the chips show them. "All" leads and is
/// the default: the screen opens on the same lifetime figures as Home.
enum AnalyticsRange {
  allTime(0),
  lastMonth(1),
  last3Months(3),
  last6Months(6),
  last9Months(9),
  lastYear(12);

  const AnalyticsRange(this.months);

  /// Calendar months back from today; `0` for the whole history.
  final int months;
}

class DateSpan {
  const DateSpan({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) => !date.isBefore(start) && !date.isAfter(end);

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
    required this.repairCost,
    required this.partsCost,
    required this.otherCost,
    required this.distanceKm,
    required this.liters,
    required this.avgEfficiency,
    required this.avgLitersPer100Km,
    required this.liveLitersPer100Km,
    required this.costPerKm,
    required this.fuelCostPerKm,
    required this.fillCount,
    required this.serviceCount,
    required this.expenseCount,
    required this.dailyKm,
  });

  const AnalyticsSummary.empty()
    : fuelCost = 0,
      serviceCost = 0,
      repairCost = 0,
      partsCost = 0,
      otherCost = 0,
      distanceKm = 0,
      liters = 0,
      avgEfficiency = 0,
      avgLitersPer100Km = 0,
      liveLitersPer100Km = 0,
      costPerKm = 0,
      fuelCostPerKm = 0,
      fillCount = 0,
      serviceCount = 0,
      expenseCount = 0,
      dailyKm = 0;

  final double fuelCost;

  /// Maintenance: the preventive schedule and routine upkeep.
  final double serviceCost;

  /// Unscheduled repairs.
  final double repairCost;

  final double partsCost;

  /// Operational only — nothing mechanical.
  final double otherCost;

  /// Distance driven: initial to current odometer for the whole history, the
  /// odometer's movement across the period otherwise.
  final int distanceKm;
  final double liters;

  /// Kilometres per litre — the secondary, optional unit.
  final double avgEfficiency;

  /// Litres per 100 km — the primary metric, settled at the last fill.
  final double avgLitersPer100Km;

  /// The same figure carried forward to the vehicle's live odometer.
  final double liveLitersPer100Km;

  /// Every cost stream over [distanceKm].
  final double costPerKm;

  /// Fuel alone over the distance that fuel powered.
  final double fuelCostPerKm;

  final int fillCount;
  final int serviceCount;
  final int expenseCount;

  /// Kilometres per day across the same span as [distanceKm].
  final double dailyKm;

  double get totalCost =>
      fuelCost + serviceCost + repairCost + partsCost + otherCost;

  bool get isEmpty => fillCount == 0 && serviceCount == 0 && expenseCount == 0;
}

class AnalyticsRangeNotifier extends Notifier<AnalyticsRange> {
  @override
  AnalyticsRange build() => AnalyticsRange.allTime;

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
  // Calendar months, not a day count: "one month" from 9 October starts on 9
  // September, whatever the months in between hold. A day the target month
  // lacks — 31 March back one month — lands on its last day rather than
  // spilling into the month after.
  final month = DateTime(now.year, now.month - range.months);
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  return DateSpan(
    start: DateTime(
      month.year,
      month.month,
      now.day > lastDay ? lastDay : now.day,
    ),
    end: end,
  );
});

final analyticsFuelLogsProvider = Provider<List<FuelLog>>((ref) {
  final span = ref.watch(analyticsSpanProvider);
  final logs = ref.watch(fuelLogsProvider);
  return logs.where((l) => span.contains(l.date)).toList(growable: false);
});

/// Whether the period is the whole history — "All", with no custom dates.
///
/// That one keeps the lifetime figures Home and the fuel tab show, to the
/// digit; every other period is measured on its own.
final analyticsIsWholeHistoryProvider = Provider<bool>(
  (ref) =>
      ref.watch(analyticsCustomSpanProvider) == null &&
      ref.watch(analyticsRangeProvider) == AnalyticsRange.allTime,
);

/// The closed tanks opened inside the period, newest first.
///
/// **Taken from the whole-history engine, not recomputed on the period's
/// fills.** Running the engine on a filtered list cut the tanks at the edges:
/// the last fill in the period became an "open" tank measured against today's
/// odometer — months of driving for a past period — and fell out of the
/// trend, while the first fill lost the tank before it. Selecting finished
/// tanks by the day their fill was bought keeps every tank exactly as the
/// fuel tab measures it.
final analyticsSegmentsProvider = Provider<List<FuelSegment>>((ref) {
  final span = ref.watch(analyticsSpanProvider);
  return ref
      .watch(fuelStatsProvider)
      .segments
      .where((s) => span.contains(s.date))
      .toList(growable: false);
});

final analyticsExpensesProvider = Provider<List<Expense>>((ref) {
  final span = ref.watch(analyticsSpanProvider);
  final expenses = ref.watch(expensesProvider);
  return expenses.where((e) => span.contains(e.date)).toList(growable: false);
});

final analyticsServicesProvider = Provider<List<MaintenanceRecord>>((ref) {
  final span = ref.watch(analyticsSpanProvider);
  // Completed only: a booking is money not yet spent, and charting it as
  // spend would show a cost peak in a month nothing has been paid for.
  final records = ref.watch(completedRecordsProvider);
  return records.where((r) => span.contains(r.date)).toList(growable: false);
});

/// The windowed history, split the way every total is.
final analyticsScheduledServicesProvider = Provider<List<MaintenanceRecord>>(
  (ref) => ref
      .watch(analyticsServicesProvider)
      .where((r) => r.tier.isMaintenance)
      .toList(growable: false),
);

final analyticsRepairsProvider = Provider<List<MaintenanceRecord>>(
  (ref) => ref
      .watch(analyticsServicesProvider)
      .where((r) => r.tier.isCorrective)
      .toList(growable: false),
);

/// Headline analytics figures, **for the period the driver picked**.
///
/// The analytics screen and the exported report both read this, and every
/// figure on them follows the period — the cards, the charts' reference lines
/// and the report's summary alike. It used to be whole-history whatever the
/// period said, so choosing three months redrew the trend and left four cards
/// and a donut on the lifetime totals beside it.
///
/// "All" keeps the lifetime figures straight off [vehicleMetricsProvider], so
/// it agrees with Home and the fuel tab to the digit. Those two screens are
/// lifetime by design and do not read this.
final analyticsSummaryProvider = Provider<AnalyticsSummary>((ref) {
  if (ref.watch(analyticsIsWholeHistoryProvider)) {
    final metrics = ref.watch(vehicleMetricsProvider);
    return AnalyticsSummary(
      fuelCost: metrics.fuelCost,
      serviceCost: metrics.serviceCost,
      repairCost: metrics.repairCost,
      partsCost: metrics.partsCost,
      otherCost: metrics.otherCost,
      distanceKm: metrics.trackedDistanceKm,
      liters: metrics.totalLiters,
      avgEfficiency: metrics.kmPerLiter,
      avgLitersPer100Km: metrics.litersPer100Km,
      liveLitersPer100Km: metrics.litersPer100Km,
      costPerKm: metrics.totalCostPerKm,
      fuelCostPerKm: metrics.fuelCostPerKm,
      fillCount: metrics.fillCount,
      serviceCount: metrics.serviceCount,
      expenseCount: metrics.expenseCount,
      dailyKm: ref.watch(dailyPaceProvider),
    );
  }

  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return const AnalyticsSummary.empty();
  final span = ref.watch(analyticsSpanProvider);
  final now = DateTime.now();

  // ---- money: everything paid inside the period, split as Home splits it --
  final fills = ref.watch(analyticsFuelLogsProvider);
  // De-duplicated like the lifetime totals: a milestone logged twice is
  // billed once.
  final services = ref
      .watch(billableServiceRecordsProvider)
      .where((r) => span.contains(r.date))
      .toList(growable: false);
  final expenses = ref.watch(analyticsExpensesProvider);
  // Repairs filed under the retired expense category count as repairs, as
  // they do in the lifetime split.
  final legacyRepairs = expenses
      .where((e) => e.category.isMechanical)
      .fold<double>(0, (s, e) => s + e.amount);

  double sum<T>(Iterable<T> items, double Function(T) of) =>
      items.fold<double>(0, (s, item) => s + of(item));

  final fuelCost = sum(fills, (l) => l.totalCost);
  // Maintenance: the schedule and the routine upkeep between its stops.
  final serviceCost = sum(
    services.where((r) => r.tier.isMaintenance),
    (r) => r.cost,
  );
  final repairCost =
      sum(services.where((r) => r.tier.isCorrective), (r) => r.cost) +
      legacyRepairs;
  // Standalone only: a part fitted during a service is inside its cost.
  final partsCost = sum(
    ref
        .watch(partReplacementsProvider)
        .where((p) => p.maintenanceRecordId == null && span.contains(p.date)),
    (p) => p.cost ?? 0,
  );
  final otherCost = sum(expenses, (e) => e.amount) - legacyRepairs;

  // ---- distance: how far the odometer moved across the period ------------
  final travel = _PeriodTravel.of(
    origin: (vehicle.createdAt, vehicle.initialOdometer),
    readings: [
      // Only when it says when it was read: an undated current reading would
      // land on the day the car was added and claim all its distance there.
      if (vehicle.odometerUpdatedAt case final readAt?)
        (readAt, vehicle.currentOdometer),
      for (final l in ref.watch(fuelLogsProvider)) (l.date, l.odometer),
      for (final r in ref.watch(completedRecordsProvider)) (r.date, r.odometer),
      for (final p in ref.watch(partReplacementsProvider)) (p.date, p.odometer),
      for (final e in ref.watch(expensesProvider))
        if (e.odometer != null) (e.date, e.odometer!),
    ],
    start: span.start,
    end: span.end.isAfter(now) ? now : span.end,
  );

  // ---- fuel: the tanks bought inside the period ---------------------------
  // The tank still running counts only while the period reaches today: its
  // distance is measured against today's odometer, which a past period has
  // no claim on.
  final tanks = ref.watch(analyticsSegmentsProvider);
  var tankLiters = sum(tanks, (s) => s.litersUsed);
  var tankCost = sum(tanks, (s) => s.cost);
  var tankDistance = tanks.fold<int>(0, (s, t) => s + t.distanceKm);
  final open = ref.watch(fuelStatsProvider).openTank;
  if (open != null &&
      open.hasDistance &&
      span.contains(open.date) &&
      !span.end.isBefore(now)) {
    tankLiters += open.liters;
    tankCost += open.cost;
    tankDistance += open.distanceKm;
  }
  final litersPer100Km = FuelMath.litersPer100Km(
    liters: tankLiters,
    distanceKm: tankDistance,
  );

  final totalCost = fuelCost + serviceCost + repairCost + partsCost + otherCost;

  return AnalyticsSummary(
    fuelCost: fuelCost,
    serviceCost: serviceCost,
    repairCost: repairCost,
    partsCost: partsCost,
    otherCost: otherCost,
    distanceKm: travel.distanceKm,
    liters: sum(fills, (l) => l.liters),
    avgEfficiency: FuelMath.kmPerLiter(
      liters: tankLiters,
      distanceKm: tankDistance,
    ),
    avgLitersPer100Km: litersPer100Km,
    liveLitersPer100Km: litersPer100Km,
    costPerKm: FuelMath.costPerKm(
      totalCost: totalCost,
      distanceKm: travel.distanceKm,
    ),
    fuelCostPerKm: FuelMath.costPerKm(
      totalCost: tankCost,
      distanceKm: tankDistance,
    ),
    fillCount: fills.length,
    // Repairs included: a period whose only entry is a breakdown still has
    // something to show.
    serviceCount: services.length,
    expenseCount: expenses.length,
    dailyKm: FuelMath.kmPerDay(
      distanceKm: travel.distanceKm,
      days: travel.days,
    ),
  );
});

/// How far the odometer moved across a period, from every dated reading the
/// app holds: fills, services, part changes, expenses that noted one, and the
/// vehicle's own first and latest readings.
///
/// **Interpolated at the edges.** Readings rarely fall on the first and last
/// day of a period, and taking the nearest one outside it would bill the
/// period for driving done before it began — a car added a year ago with its
/// next reading inside the last three months would be charged the whole year.
/// The odometer at each edge is read off the straight line between the
/// readings either side of it, the best estimate the history allows.
class _PeriodTravel {
  const _PeriodTravel(this.distanceKm, this.days);

  final int distanceKm;
  final int days;

  /// [origin] is the reading the car was added with. **It always counts, zero
  /// included**, and is never dated after anything else: it is where the
  /// lifetime distance starts, so a period covering the whole history has to
  /// start there too. Dropping a zero — as the other readings rightly do,
  /// since there a zero means "not noted" — started such a period at the first
  /// fill instead, and it came out short of "All" by however far the car went
  /// before it.
  static _PeriodTravel of({
    required (DateTime, int) origin,
    required List<(DateTime, int)> readings,
    required DateTime start,
    required DateTime end,
  }) {
    final usable = readings.where((r) => r.$2 > 0).toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    final originDate = usable.isNotEmpty && usable.first.$1.isBefore(origin.$1)
        ? usable.first.$1
        : origin.$1;
    usable.insert(0, (originDate, origin.$2));
    if (usable.isEmpty || !end.isAfter(start)) return const _PeriodTravel(0, 1);

    // A back-dated or mistyped reading must not run the odometer backwards
    // and produce a negative stretch: each reading is at least the one
    // before it.
    final timeline = <(DateTime, int)>[];
    for (final r in usable) {
      final floor = timeline.isEmpty ? 0 : timeline.last.$2;
      timeline.add((r.$1, r.$2 < floor ? floor : r.$2));
    }

    /// The odometer at [t], or null when no reading is that old.
    double? at(DateTime t) {
      (DateTime, int)? before;
      (DateTime, int)? after;
      for (final r in timeline) {
        if (!r.$1.isAfter(t)) {
          before = r;
        } else {
          after = r;
          break;
        }
      }
      if (before == null) return null;
      if (after == null) return before.$2.toDouble();
      final span = after.$1.difference(before.$1).inSeconds;
      if (span <= 0) return before.$2.toDouble();
      final fraction = t.difference(before.$1).inSeconds / span;
      return before.$2 + (after.$2 - before.$2) * fraction;
    }

    // No reading before the period opens — the car was added inside it — so
    // it starts where the first reading in it does.
    final startOdo = at(start);
    final firstInside = timeline.where(
      (r) => !r.$1.isBefore(start) && !r.$1.isAfter(end),
    );
    final from =
        startOdo ??
        (firstInside.isEmpty ? null : firstInside.first.$2.toDouble());
    final to = at(end);
    if (from == null || to == null) return const _PeriodTravel(0, 1);

    final measuredFrom = startOdo != null || firstInside.isEmpty
        ? start
        : firstInside.first.$1;
    final days = DateX.daysBetween(measuredFrom, end);
    final distance = (to - from).round();
    return _PeriodTravel(distance < 0 ? 0 : distance, days < 1 ? 1 : days);
  }
}

/// Efficiency series in whichever unit the driver has selected.
///
/// The engine always hands over L/100 km; the metric converts at the last
/// moment, so switching units redraws the chart without touching the maths.
final fuelEfficiencyTrendProvider = Provider<List<ChartPoint>>((ref) {
  final segments = ref.watch(analyticsSegmentsProvider);
  if (segments.isEmpty) return const [];

  final metric = ref.watch(fuelMetricProvider);
  final ordered = segments.reversed.toList(growable: false);
  return List<ChartPoint>.generate(
    ordered.length,
    (i) => ChartPoint(
      x: i.toDouble(),
      y: double.parse(metric.of(ordered[i].litersPer100Km).toStringAsFixed(2)),
      date: ordered[i].date,
      label: ordered[i].fuelType.l10nKey,
      colorValue: _fuelColor(ordered[i].fuelType),
    ),
    growable: false,
  );
});

final costPerKmTrendProvider = Provider<List<ChartPoint>>((ref) {
  final segments = ref.watch(analyticsSegmentsProvider);
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

  // Four classes of spend, then the operational categories underneath them.
  // Repairs are their own arc rather than a share of maintenance: the point of
  // this chart is what the car costs and why, and "the schedule" and "it broke"
  // are different answers.
  final entries = <(String, double, int)>[
    ('tabFuel', summary.fuelCost, 0xFF22D3EE),
    ('scheduledMaintenance', summary.serviceCost, 0xFFF59E0B),
    ('unscheduledRepairs', summary.repairCost, 0xFFF87171),
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
    // Repairs filed under the retired category already have their own arc, in
    // the repair total. Counting them here as well would draw the same money
    // twice and leave the ring adding up to more than the spend it describes.
    if (e.category.isMechanical) continue;
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

/// Fuel spend in the period by grade: what was paid at the pump for each.
final fuelTypeBreakdownProvider = Provider<List<DonutSlice>>((ref) {
  final byType = <FuelType, double>{};
  for (final log in ref.watch(analyticsFuelLogsProvider)) {
    byType[log.fuelType] = (byType[log.fuelType] ?? 0) + log.totalCost;
  }
  if (byType.isEmpty) return const [];

  final total = byType.values.fold<double>(0, (s, v) => s + v);
  final slices =
      byType.entries
          .map(
            (e) => DonutSlice(
              labelKey: e.key.l10nKey,
              value: e.value,
              share: total <= 0 ? 0 : e.value / total,
              colorValue: _fuelColor(e.key),
            ),
          )
          .toList()
        // Largest spend first, like every other donut.
        ..sort((a, b) => b.value.compareTo(a.value));
  return List.unmodifiable(slices);
});

final analyticsHasDataProvider = Provider<bool>(
  (ref) =>
      ref.watch(selectedVehicleProvider) != null &&
      !ref.watch(analyticsSummaryProvider).isEmpty,
);

int _fuelColor(FuelType type) => switch (type) {
  FuelType.octane80 => 0xFFFB923C,
  FuelType.octane92 => 0xFF34D399,
  FuelType.octane95 => 0xFF22D3EE,
  FuelType.diesel => 0xFFF59E0B,
  FuelType.naturalGas => 0xFFA78BFA,
};
