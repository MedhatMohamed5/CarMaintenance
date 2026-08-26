import 'package:equatable/equatable.dart';

/// One upcoming service or wear item, dated from remaining kilometres and
/// the driver's measured daily pace.
class ForecastItem extends Equatable {
  const ForecastItem({
    required this.l10nKey,
    required this.remainingKm,
    required this.targetOdometer,
    required this.isOverdue,
    required this.colorValue,
    this.projectedDate,
    this.remainingFraction,
    this.iconKey,
  });

  final String l10nKey;
  final int remainingKm;
  final int targetOdometer;
  final bool isOverdue;
  final int colorValue;
  final DateTime? projectedDate;

  /// Life left, 0..1. Only set for wear items.
  final double? remainingFraction;
  final String? iconKey;

  bool get isPart => remainingFraction != null;

  @override
  List<Object?> get props => [
    l10nKey,
    remainingKm,
    targetOdometer,
    isOverdue,
    colorValue,
    projectedDate,
    remainingFraction,
    iconKey,
  ];
}

/// Full-history forecast for the active vehicle.
///
/// Built only from logged odometer points, fuel consumption and spend rates.
/// Nothing here is a calendar guess — if [hasEnoughData] is false the screen
/// must show the empty state instead of inventing numbers.
class VehicleForecast extends Equatable {
  const VehicleForecast({
    required this.hasEnoughData,
    required this.observationCount,
    required this.fuelLogCount,
    required this.avgDailyKm,
    required this.projectedMonthlyKm,
    required this.projectedYearlyKm,
    required this.litersPer100Km,
    required this.fuelCostPerKm,
    required this.monthlyFuelCost,
    required this.yearlyFuelCost,
    required this.monthlyLiters,
    required this.yearlyLiters,
    required this.monthlyMaintenanceCost,
    required this.yearlyMaintenanceCost,
    required this.monthlyOtherCost,
    required this.yearlyOtherCost,
    required this.monthlyPolicyCost,
    required this.yearlyPolicyCost,
    required this.services,
    required this.parts,
    this.spanDays = 0,
  });

  const VehicleForecast.empty({
    this.observationCount = 0,
    this.fuelLogCount = 0,
  }) : hasEnoughData = false,
       avgDailyKm = 0,
       projectedMonthlyKm = 0,
       projectedYearlyKm = 0,
       litersPer100Km = 0,
       fuelCostPerKm = 0,
       monthlyFuelCost = 0,
       yearlyFuelCost = 0,
       monthlyLiters = 0,
       yearlyLiters = 0,
       monthlyMaintenanceCost = 0,
       yearlyMaintenanceCost = 0,
       monthlyOtherCost = 0,
       yearlyOtherCost = 0,
       monthlyPolicyCost = 0,
       yearlyPolicyCost = 0,
       services = const [],
       parts = const [],
       spanDays = 0;

  final bool hasEnoughData;
  final int observationCount;
  final int fuelLogCount;
  final int spanDays;

  final double avgDailyKm;
  final double projectedMonthlyKm;
  final double projectedYearlyKm;

  final double litersPer100Km;
  final double fuelCostPerKm;

  final double monthlyFuelCost;
  final double yearlyFuelCost;
  final double monthlyLiters;
  final double yearlyLiters;

  final double monthlyMaintenanceCost;
  final double yearlyMaintenanceCost;

  /// Day-to-day expenses — parking, fines, washes, accessories — projected
  /// from their historical cost per kilometre. Insurance and licensing are
  /// **not** in here; see [monthlyPolicyCost].
  final double monthlyOtherCost;
  final double yearlyOtherCost;

  /// Insurance and licensing, amortised over the term each one buys.
  ///
  /// These are the only costs in the forecast that are not driven by distance.
  /// A policy costs the same whether the car is driven ten kilometres or ten
  /// thousand, so spreading it over kilometres — which is what the per-km
  /// `other` rate did — made a light month look cheap and a heavy one look
  /// ruinous, and dropped the charge to nothing in any month with no renewal
  /// in it. Divided by the months of cover it buys, the figure is what the
  /// driver actually has to set aside.
  final double monthlyPolicyCost;
  final double yearlyPolicyCost;

  final List<ForecastItem> services;
  final List<ForecastItem> parts;

  double get monthlyTotalCost =>
      monthlyFuelCost +
      monthlyMaintenanceCost +
      monthlyOtherCost +
      monthlyPolicyCost;

  double get yearlyTotalCost =>
      yearlyFuelCost +
      yearlyMaintenanceCost +
      yearlyOtherCost +
      yearlyPolicyCost;

  @override
  List<Object?> get props => [
    hasEnoughData,
    observationCount,
    fuelLogCount,
    spanDays,
    avgDailyKm,
    projectedMonthlyKm,
    projectedYearlyKm,
    litersPer100Km,
    fuelCostPerKm,
    monthlyFuelCost,
    yearlyFuelCost,
    monthlyLiters,
    yearlyLiters,
    monthlyMaintenanceCost,
    yearlyMaintenanceCost,
    monthlyOtherCost,
    yearlyOtherCost,
    monthlyPolicyCost,
    yearlyPolicyCost,
    services,
    parts,
  ];
}
