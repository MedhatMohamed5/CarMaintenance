import 'package:equatable/equatable.dart';

import 'fuel_log.dart';
import 'fuel_type.dart';

/// Division that can never yield `NaN`, `Infinity` or a negative rate.
///
/// Every ratio in this file routes through it: a duplicated odometer reading,
/// a zero-litre correction entry or a back-dated log must degrade to `0`, not
/// poison a chart axis or a progress bar.
double safeRate(num numerator, num denominator) {
  if (denominator <= 0) return 0;
  final value = numerator / denominator;
  return value.isFinite && value > 0 ? value.toDouble() : 0;
}

/// One measured stretch of driving between two consecutive fills.
///
/// Segments are produced for **every** interval that covers real distance,
/// partial or full. The litres poured in at the closing fill are the litres
/// attributed to the interval it closes; when an interval covers no distance
/// (duplicate reading, correction entry) its litres and cost roll forward into
/// the next one rather than being discarded.
class FuelSegment extends Equatable {
  const FuelSegment({
    required this.log,
    required this.previousOdometer,
    required this.distanceKm,
    required this.litersUsed,
    required this.cost,
    required this.cumulativeDistanceKm,
    required this.cumulativeLiters,
    required this.cumulativeCost,
    this.mergedFills = 1,
  });

  /// The fill that *closed* the interval — its grade is what the car ran on.
  final FuelLog log;
  final int previousOdometer;
  final int distanceKm;

  /// Litres attributed to this interval, including any rolled forward.
  final double litersUsed;
  final double cost;

  /// Running totals up to and including this segment — the inputs to the
  /// accumulative average.
  final int cumulativeDistanceKm;
  final double cumulativeLiters;
  final double cumulativeCost;

  /// How many fills fed this interval. Greater than one when zero-distance
  /// entries were rolled forward into it.
  final int mergedFills;

  // ---- instant metrics (this interval only) -------------------------------

  /// km per litre — higher is better.
  double get efficiency => safeRate(distanceKm, litersUsed);

  /// Currency per kilometre — lower is better.
  double get costPerKm => safeRate(cost, distanceKm);

  /// Litres per 100 km, the metric most manufacturers quote.
  double get litersPer100Km => safeRate(litersUsed * 100, distanceKm);

  double get pricePerLiter => safeRate(cost, litersUsed);

  // ---- rolling metrics (everything measured so far) -----------------------

  /// `(cumulative litres / cumulative distance) * 100`.
  double get rollingLitersPer100Km =>
      safeRate(cumulativeLiters * 100, cumulativeDistanceKm);

  double get rollingEfficiency =>
      safeRate(cumulativeDistanceKm, cumulativeLiters);

  double get rollingCostPerKm =>
      safeRate(cumulativeCost, cumulativeDistanceKm);

  DateTime get date => log.date;
  FuelType get fuelType => log.fuelType;
  bool get isFullTank => log.isFullTank;

  @override
  List<Object?> get props => [
    log,
    previousOdometer,
    distanceKm,
    litersUsed,
    cost,
    cumulativeDistanceKm,
    cumulativeLiters,
    cumulativeCost,
    mergedFills,
  ];
}

/// Aggregate efficiency figures for one fuel grade, used by the octane
/// comparison card.
class FuelTypeStats extends Equatable {
  const FuelTypeStats({
    required this.fuelType,
    required this.segments,
    required this.avgEfficiency,
    required this.avgLitersPer100Km,
    required this.avgCostPerKm,
    required this.avgPricePerLiter,
    required this.totalDistanceKm,
    required this.totalLiters,
    required this.totalCost,
  });

  final FuelType fuelType;
  final int segments;
  final double avgEfficiency;
  final double avgLitersPer100Km;
  final double avgCostPerKm;
  final double avgPricePerLiter;
  final int totalDistanceKm;
  final double totalLiters;
  final double totalCost;

  @override
  List<Object?> get props => [
    fuelType,
    segments,
    avgEfficiency,
    avgLitersPer100Km,
    avgCostPerKm,
    avgPricePerLiter,
    totalDistanceKm,
    totalLiters,
    totalCost,
  ];
}

/// Everything the fuel tab and the dashboard need, computed once.
class FuelStats extends Equatable {
  const FuelStats({
    required this.segments,
    required this.byFuelType,
    required this.avgEfficiency,
    required this.avgLitersPer100Km,
    required this.bestEfficiency,
    required this.worstEfficiency,
    required this.latestEfficiency,
    required this.latestLitersPer100Km,
    required this.avgCostPerKm,
    required this.avgPricePerLiter,
    required this.measuredDistanceKm,
    required this.measuredLiters,
    required this.totalLiters,
    required this.totalCost,
    required this.totalDistanceKm,
    required this.avgDailyKm,
    required this.firstLogDate,
    required this.lastLogDate,
  });

  const FuelStats.empty()
    : segments = const [],
      byFuelType = const [],
      avgEfficiency = 0,
      avgLitersPer100Km = 0,
      bestEfficiency = 0,
      worstEfficiency = 0,
      latestEfficiency = 0,
      latestLitersPer100Km = 0,
      avgCostPerKm = 0,
      avgPricePerLiter = 0,
      measuredDistanceKm = 0,
      measuredLiters = 0,
      totalLiters = 0,
      totalCost = 0,
      totalDistanceKm = 0,
      avgDailyKm = 0,
      firstLogDate = null,
      lastLogDate = null;

  /// Newest first.
  final List<FuelSegment> segments;
  final List<FuelTypeStats> byFuelType;

  /// Accumulative average: `measuredDistanceKm / measuredLiters`.
  final double avgEfficiency;

  /// Accumulative average: `(measuredLiters / measuredDistanceKm) * 100`.
  final double avgLitersPer100Km;

  final double bestEfficiency;
  final double worstEfficiency;
  final double latestEfficiency;
  final double latestLitersPer100Km;
  final double avgCostPerKm;

  /// Blended pump price across every fill, measurable or not.
  final double avgPricePerLiter;

  /// Distance and litres that actually fed the rolling average — everything
  /// after the first fill, which only anchors the odometer.
  final int measuredDistanceKm;
  final double measuredLiters;

  final double totalLiters;
  final double totalCost;
  final int totalDistanceKm;

  /// Average kilometres per day derived from fuel history — the input the
  /// service predictor uses to turn a distance target into a date.
  final double avgDailyKm;

  final DateTime? firstLogDate;
  final DateTime? lastLogDate;

  bool get hasEfficiencyData => segments.isNotEmpty;

  /// Change of the latest segment against the running average, as a signed
  /// fraction (+0.08 = 8% better than usual).
  double get latestVsAverage => avgEfficiency <= 0
      ? 0
      : (latestEfficiency - avgEfficiency) / avgEfficiency;

  @override
  List<Object?> get props => [
    segments,
    byFuelType,
    avgEfficiency,
    avgLitersPer100Km,
    bestEfficiency,
    worstEfficiency,
    latestEfficiency,
    latestLitersPer100Km,
    avgCostPerKm,
    avgPricePerLiter,
    measuredDistanceKm,
    measuredLiters,
    totalLiters,
    totalCost,
    totalDistanceKm,
    avgDailyKm,
    firstLogDate,
    lastLogDate,
  ];
}
