import 'package:equatable/equatable.dart';

import 'fuel_type.dart';

/// A single visit to the pump.
///
/// Cost, volume and unit price are one triangle: any two determine the third.
/// The log stores litres and total cost — the two figures a receipt actually
/// prints — and derives the price, so a rounded price can never drift the
/// stored total away from what was paid.
class FuelLog extends Equatable {
  const FuelLog({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.liters,
    required this.fuelType,
    required this.totalCost,
    this.isFullTank = true,
    this.stationName,
    this.notes,
  });

  final String id;
  final String vehicleId;
  final DateTime date;
  final int odometer;
  final double liters;
  final FuelType fuelType;
  final double totalCost;

  /// Whether the tank was topped right up. Purely descriptive: the
  /// accumulative engine measures partial and full fills alike, and this flag
  /// only drives the "partial fill" badge in the log list.
  final bool isFullTank;

  final String? stationName;
  final String? notes;

  /// Derived, never stored. Zero rather than `NaN`/`Infinity` on a zero-volume
  /// entry, so it is always safe to format.
  double get pricePerLiter {
    if (liters <= 0) return 0;
    final price = totalCost / liters;
    return price.isFinite && price > 0 ? price : 0;
  }

  bool get isPartialFill => !isFullTank;

  /// A fill with no volume and no cost carries no information beyond its
  /// odometer reading.
  bool get hasVolume => liters > 0;

  FuelLog copyWith({
    DateTime? date,
    int? odometer,
    double? liters,
    FuelType? fuelType,
    double? totalCost,
    bool? isFullTank,
    String? stationName,
    String? notes,
  }) => FuelLog(
    id: id,
    vehicleId: vehicleId,
    date: date ?? this.date,
    odometer: odometer ?? this.odometer,
    liters: liters ?? this.liters,
    fuelType: fuelType ?? this.fuelType,
    totalCost: totalCost ?? this.totalCost,
    isFullTank: isFullTank ?? this.isFullTank,
    stationName: stationName ?? this.stationName,
    notes: notes ?? this.notes,
  );

  @override
  List<Object?> get props => [
    id,
    vehicleId,
    date,
    odometer,
    liters,
    fuelType,
    totalCost,
    isFullTank,
    stationName,
    notes,
  ];
}
