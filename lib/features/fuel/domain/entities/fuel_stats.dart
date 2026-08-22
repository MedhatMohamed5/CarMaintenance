import 'package:equatable/equatable.dart';

import '../fuel_math.dart';
import 'fuel_log.dart';
import 'fuel_type.dart';

// `safeRate` and every named formula come from FuelMath, so the guards and the
// arithmetic live in exactly one file.
export '../fuel_math.dart';

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
  double get efficiency =>
      FuelMath.kmPerLiter(liters: litersUsed, distanceKm: distanceKm);

  /// Currency per kilometre — lower is better.
  double get costPerKm =>
      FuelMath.costPerKm(totalCost: cost, distanceKm: distanceKm);

  /// Litres per 100 km, the metric most manufacturers quote.
  double get litersPer100Km =>
      FuelMath.litersPer100Km(liters: litersUsed, distanceKm: distanceKm);

  double get pricePerLiter =>
      FuelMath.pricePerLiter(totalCost: cost, liters: litersUsed);

  // ---- rolling metrics (everything measured so far) -----------------------

  /// `(cumulative litres / cumulative distance) * 100`.
  double get rollingLitersPer100Km => FuelMath.litersPer100Km(
    liters: cumulativeLiters,
    distanceKm: cumulativeDistanceKm,
  );

  double get rollingEfficiency => FuelMath.kmPerLiter(
    liters: cumulativeLiters,
    distanceKm: cumulativeDistanceKm,
  );

  double get rollingCostPerKm => FuelMath.costPerKm(
    totalCost: cumulativeCost,
    distanceKm: cumulativeDistanceKm,
  );

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

/// The stretch since the newest fill, measured against the vehicle's live
/// odometer rather than a closing fill.
///
/// This is what makes cost per kilometre move in real time: the numerator is
/// fixed the moment the tank is paid for, the denominator grows with every
/// odometer update, so the figure amortises downward until the next visit to
/// the pump.
class OpenTank extends Equatable {
  const OpenTank({
    required this.log,
    required this.currentOdometer,
    required this.liters,
    required this.cost,
  });

  /// The fill that opened this tank.
  final FuelLog log;

  /// The vehicle's master reading, which is free to move without a new fill.
  final int currentOdometer;

  /// Litres and cost paid at the opening fill, including any other fill logged
  /// at the same reading.
  final double liters;
  final double cost;

  int get startOdometer => log.odometer;

  /// `currentOdometer - odometerAtFillUp`, floored at zero so a back-dated
  /// entry can never produce a negative denominator.
  int get distanceKm => FuelMath.distanceBetween(log.odometer, currentOdometer);

  /// `totalFillCost / distanceOnThisTank` — falls as the odometer rises.
  double get costPerKm =>
      FuelMath.costPerKm(totalCost: cost, distanceKm: distanceKm);

  /// Consumption if this tank were already burnt: a pessimistic ceiling that
  /// decays toward the real figure as the distance accumulates.
  double get litersPer100Km =>
      FuelMath.litersPer100Km(liters: liters, distanceKm: distanceKm);

  double get efficiency =>
      FuelMath.kmPerLiter(liters: liters, distanceKm: distanceKm);

  double get pricePerLiter =>
      FuelMath.pricePerLiter(totalCost: cost, liters: liters);

  /// Nothing is measurable until the car has actually moved.
  bool get hasDistance => distanceKm > 0;

  DateTime get date => log.date;
  FuelType get fuelType => log.fuelType;

  @override
  List<Object?> get props => [log, currentOdometer, liters, cost];
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
    required this.liveDistanceKm,
    required this.liveLitersPer100Km,
    required this.liveCostPerKm,
    required this.openTank,
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
      liveDistanceKm = 0,
      liveLitersPer100Km = 0,
      liveCostPerKm = 0,
      openTank = null,
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

  /// **The accumulative span.** First fill to the vehicle's live odometer —
  /// the same distance the octane comparison attributes across the grades,
  /// because the segments telescope onto exactly this range.
  ///
  /// This is the denominator behind every headline fuel figure. It grows on
  /// every master-odometer update, not only when a fill is logged.
  final int liveDistanceKm;

  /// **Accumulative consumption**: *every* litre ever logged over
  /// [liveDistanceKm]. Never the last fill, never one tank.
  final double liveLitersPer100Km;

  /// **Accumulative fuel cost per kilometre**: *every* pound ever spent on fuel
  /// over [liveDistanceKm]. Same numerator basis and same denominator as the
  /// per-grade rows, so the header and the comparison always reconcile.
  final double liveCostPerKm;

  /// The stretch since the newest fill, or `null` when there are no logs.
  final OpenTank? openTank;

  final double totalLiters;
  final double totalCost;
  final int totalDistanceKm;

  /// Average kilometres per day derived from fuel history — the input the
  /// service predictor uses to turn a distance target into a date.
  final double avgDailyKm;

  final DateTime? firstLogDate;
  final DateTime? lastLogDate;

  bool get hasEfficiencyData => segments.isNotEmpty;

  /// Whether the live figures currently differ from the settled ones, i.e. the
  /// car has moved since the last fill.
  bool get hasOpenDistance => (openTank?.hasDistance ?? false);

  /// Settled accumulative consumption expressed as km per litre, for drivers
  /// who prefer that unit. Reciprocal of [avgLitersPer100Km].
  double get avgKmPerLiter => avgEfficiency;

  /// Accumulative consumption expressed as km per litre:
  /// `liveDistanceKm / totalLiters`.
  double get liveKmPerLiter =>
      FuelMath.kmPerLiter(liters: totalLiters, distanceKm: liveDistanceKm);

  /// Whether the accumulative figures have a denominator to divide by.
  bool get hasAccumulativeDistance => liveDistanceKm > 0;

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
    liveDistanceKm,
    liveLitersPer100Km,
    liveCostPerKm,
    openTank,
    totalLiters,
    totalCost,
    totalDistanceKm,
    avgDailyKm,
    firstLogDate,
    lastLogDate,
  ];
}
