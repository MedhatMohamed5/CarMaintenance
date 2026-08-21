import 'package:equatable/equatable.dart';

import 'fuel_type.dart';

/// A single visit to the pump.
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

  /// Consumption can only be derived between two *full* fills — a partial fill
  /// leaves an unknown amount already in the tank.
  final bool isFullTank;

  final String? stationName;
  final String? notes;

  double get pricePerLiter => liters <= 0 ? 0 : totalCost / liters;

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
