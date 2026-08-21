import '../../../../core/utils/json_x.dart';
import '../../domain/entities/fuel_log.dart';
import '../../domain/entities/fuel_type.dart';

class FuelLogModel extends FuelLog {
  const FuelLogModel({
    required super.id,
    required super.vehicleId,
    required super.date,
    required super.odometer,
    required super.liters,
    required super.fuelType,
    required super.totalCost,
    super.isFullTank,
    super.stationName,
    super.notes,
  });

  factory FuelLogModel.fromEntity(FuelLog l) => FuelLogModel(
    id: l.id,
    vehicleId: l.vehicleId,
    date: l.date,
    odometer: l.odometer,
    liters: l.liters,
    fuelType: l.fuelType,
    totalCost: l.totalCost,
    isFullTank: l.isFullTank,
    stationName: l.stationName,
    notes: l.notes,
  );

  factory FuelLogModel.fromJson(Map<String, dynamic> json) => FuelLogModel(
    id: json['id'] as String,
    vehicleId: json['vehicleId'] as String? ?? '',
    date: JsonX.dateOr(json['date'], DateTime.now()),
    odometer: JsonX.intOr(json['odometer'], 0),
    liters: JsonX.doubleOr(json['liters'], 0),
    fuelType: FuelType.fromName(json['fuelType'] as String?),
    totalCost: JsonX.doubleOr(json['totalCost'], 0),
    isFullTank: JsonX.boolOr(json['isFullTank'], true),
    stationName: json['stationName'] as String?,
    notes: json['notes'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'date': date.toIso8601String(),
    'odometer': odometer,
    'liters': liters,
    'fuelType': fuelType.name,
    'totalCost': totalCost,
    'isFullTank': isFullTank,
    'stationName': stationName,
    'notes': notes,
  };

  factory FuelLogModel.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) => FuelLogModel.fromJson({...data, 'id': documentId});

  Map<String, dynamic> toFirestore() => {
    ...toJson()..remove('id'),
    'updatedAt': DateTime.now().toIso8601String(),
  };
}
