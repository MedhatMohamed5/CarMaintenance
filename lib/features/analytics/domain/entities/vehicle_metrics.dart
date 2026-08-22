import 'package:equatable/equatable.dart';

import '../../../fuel/domain/entities/fuel_stats.dart';

/// Every headline figure in the app, computed once from the vehicle's full
/// history.
///
/// **One source, one answer.** Home, the fuel tab, the analytics grid and the
/// exported report all read this object, so a number cannot say 12.68 on one
/// screen and 11.20 on the next. Nothing here is scoped to the latest fill, to
/// one tank, or to a date range: the denominator is always the tracked
/// distance the vehicle has covered under the app's watch, and the numerators
/// are always the complete log history.
class VehicleMetrics extends Equatable {
  const VehicleMetrics({
    required this.trackedDistanceKm,
    required this.fuelDistanceKm,
    required this.totalLiters,
    required this.fuelCost,
    required this.serviceCost,
    required this.partsCost,
    required this.otherCost,
    required this.fillCount,
    required this.serviceCount,
    required this.expenseCount,
    required this.firstLogDate,
    required this.lastLogDate,
    required this.avgDailyKm,
    this.byFuelType = const [],
  });

  const VehicleMetrics.empty()
    : trackedDistanceKm = 0,
      fuelDistanceKm = 0,
      totalLiters = 0,
      fuelCost = 0,
      serviceCost = 0,
      partsCost = 0,
      otherCost = 0,
      fillCount = 0,
      serviceCount = 0,
      expenseCount = 0,
      firstLogDate = null,
      lastLogDate = null,
      avgDailyKm = 0,
      byFuelType = const [];

  /// `currentOdometer - initialOdometer`, floored at zero. Ownership distance:
  /// the denominator for total cost of ownership, which includes services and
  /// expenses logged outside any fuel entry.
  final int trackedDistanceKm;

  /// First fill to the current odometer — the distance fuel can actually
  /// account for, and the denominator behind every **fuel** figure: economy,
  /// fuel cost per kilometre, and each grade in the octane comparison.
  ///
  /// Kept distinct from [trackedDistanceKm] on purpose: consumption cannot
  /// claim kilometres driven on fuel the app has no record of.
  final int fuelDistanceKm;

  /// Litres across every fill ever logged.
  final double totalLiters;

  final double fuelCost;
  final double serviceCost;
  final double partsCost;
  final double otherCost;

  final int fillCount;
  final int serviceCount;
  final int expenseCount;

  final DateTime? firstLogDate;
  final DateTime? lastLogDate;

  /// Kilometres per day, used to turn a distance target into a date.
  final double avgDailyKm;

  /// The same accumulative maths split by fuel grade, straight from the fuel
  /// engine: every litre and every pound of that grade, over the distance it
  /// actually powered. Best economy first.
  final List<FuelTypeStats> byFuelType;

  /// The lowest accumulative consumption any grade achieved, in L/100 km.
  double get bestLitersPer100Km {
    final measured = byFuelType
        .map((t) => t.avgLitersPer100Km)
        .where((v) => v > 0)
        .toList();
    if (measured.isEmpty) return 0;
    return measured.reduce((a, b) => a < b ? a : b);
  }

  // ---- money ----------------------------------------------------------

  /// `fuel + service + parts + other`.
  double get totalSpend => fuelCost + serviceCost + partsCost + otherCost;

  /// Everything the car has cost, per kilometre driven.
  double get totalCostPerKm =>
      FuelMath.costPerKm(totalCost: totalSpend, distanceKm: trackedDistanceKm);

  /// Fuel alone, over the distance fuel accounts for. Same numerator and
  /// denominator basis as the octane comparison rows.
  double get fuelCostPerKm =>
      FuelMath.costPerKm(totalCost: fuelCost, distanceKm: fuelDistanceKm);

  double get serviceCostPerKm =>
      FuelMath.costPerKm(totalCost: serviceCost, distanceKm: trackedDistanceKm);

  double get partsCostPerKm =>
      FuelMath.costPerKm(totalCost: partsCost, distanceKm: trackedDistanceKm);

  double get otherCostPerKm =>
      FuelMath.costPerKm(totalCost: otherCost, distanceKm: trackedDistanceKm);

  // ---- economy --------------------------------------------------------

  /// Accumulative consumption: every litre ever logged over [fuelDistanceKm].
  /// The primary, European metric.
  double get litersPer100Km =>
      FuelMath.litersPer100Km(liters: totalLiters, distanceKm: fuelDistanceKm);

  /// The same figure as kilometres per litre.
  double get kmPerLiter =>
      FuelMath.kmPerLiter(liters: totalLiters, distanceKm: fuelDistanceKm);

  /// Blended pump price across every fill.
  double get avgPricePerLiter =>
      FuelMath.pricePerLiter(totalCost: fuelCost, liters: totalLiters);

  // ---- state ----------------------------------------------------------

  /// Whether there is a denominator to divide by. Every rate above returns
  /// `0.0` rather than `NaN` when this is false, so callers may format
  /// unconditionally and use this only to choose wording.
  bool get hasDistance => trackedDistanceKm > 0;

  /// Whether fuel history covers any distance yet.
  bool get hasFuelDistance => fuelDistanceKm > 0;

  bool get hasFuelData => fillCount > 0 && totalLiters > 0;

  bool get isEmpty => fillCount == 0 && serviceCount == 0 && expenseCount == 0;

  @override
  List<Object?> get props => [
    trackedDistanceKm,
    fuelDistanceKm,
    totalLiters,
    fuelCost,
    serviceCost,
    partsCost,
    otherCost,
    fillCount,
    serviceCount,
    expenseCount,
    firstLogDate,
    lastLogDate,
    avgDailyKm,
    byFuelType,
  ];
}
