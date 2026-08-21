import 'package:equatable/equatable.dart';

import 'fuel_log.dart';
import 'fuel_type.dart';

/// One measured stretch of driving between two full-tank fills.
class FuelSegment extends Equatable {
  const FuelSegment({
    required this.log,
    required this.previousOdometer,
    required this.distanceKm,
    required this.litersUsed,
    required this.cost,
  });

  /// The fill that *closed* the segment — its grade is what the car ran on.
  final FuelLog log;
  final int previousOdometer;
  final int distanceKm;
  final double litersUsed;
  final double cost;

  /// km per litre — higher is better.
  double get efficiency => litersUsed <= 0 ? 0 : distanceKm / litersUsed;

  /// Currency per kilometre — lower is better.
  double get costPerKm => distanceKm <= 0 ? 0 : cost / distanceKm;

  /// Litres per 100 km, the metric most manufacturers quote.
  double get litersPer100Km =>
      distanceKm <= 0 ? 0 : (litersUsed / distanceKm) * 100;

  DateTime get date => log.date;
  FuelType get fuelType => log.fuelType;

  @override
  List<Object?> get props => [
    log,
    previousOdometer,
    distanceKm,
    litersUsed,
    cost,
  ];
}

/// Aggregate efficiency figures for one fuel grade, used by the octane
/// comparison card.
class FuelTypeStats extends Equatable {
  const FuelTypeStats({
    required this.fuelType,
    required this.segments,
    required this.avgEfficiency,
    required this.avgCostPerKm,
    required this.avgPricePerLiter,
    required this.totalDistanceKm,
    required this.totalLiters,
    required this.totalCost,
  });

  final FuelType fuelType;
  final int segments;
  final double avgEfficiency;
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
    required this.bestEfficiency,
    required this.worstEfficiency,
    required this.latestEfficiency,
    required this.avgCostPerKm,
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
      bestEfficiency = 0,
      worstEfficiency = 0,
      latestEfficiency = 0,
      avgCostPerKm = 0,
      totalLiters = 0,
      totalCost = 0,
      totalDistanceKm = 0,
      avgDailyKm = 0,
      firstLogDate = null,
      lastLogDate = null;

  /// Newest first.
  final List<FuelSegment> segments;
  final List<FuelTypeStats> byFuelType;

  final double avgEfficiency;
  final double bestEfficiency;
  final double worstEfficiency;
  final double latestEfficiency;
  final double avgCostPerKm;

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
    bestEfficiency,
    worstEfficiency,
    latestEfficiency,
    avgCostPerKm,
    totalLiters,
    totalCost,
    totalDistanceKm,
    avgDailyKm,
    firstLogDate,
    lastLogDate,
  ];
}
