import '../../../../core/utils/json_x.dart';
import '../../domain/entities/fuel_log.dart';
import '../../domain/entities/fuel_price_defaults.dart';
import '../../domain/entities/fuel_type.dart';
import '../../domain/fuel_math.dart';

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

  factory FuelLogModel.fromJson(Map<String, dynamic> json) {
    final amounts = _resolveAmounts(json);
    return FuelLogModel(
      id: json['id'] as String,
      vehicleId: json['vehicleId'] as String? ?? '',
      date: JsonX.dateOr(json['date'], DateTime.now()),
      odometer: JsonX.intOr(json['odometer'], 0),
      liters: amounts.liters,
      fuelType: FuelType.fromName(json['fuelType'] as String?),
      totalCost: amounts.totalCost,
      isFullTank: JsonX.boolOr(json['isFullTank'], true),
      stationName: json['stationName'] as String?,
      notes: json['notes'] as String?,
    );
  }

  /// Litres and total cost remain the stored pair. An optional `pricePerLiter`
  /// only fills a missing side of the triangle on import — never overwrites
  /// historical receipts that already have both figures.
  static ({double liters, double totalCost}) _resolveAmounts(
    Map<String, dynamic> json,
  ) {
    var liters = JsonX.doubleOr(json['liters'], 0);
    if (liters <= 0) {
      liters = JsonX.doubleOr(json['cubicMeters'], 0);
    }
    var totalCost = JsonX.doubleOr(json['totalCost'], 0);
    final unitPrice =
        JsonX.doubleOrNull(json['pricePerLiter']) ??
        JsonX.doubleOrNull(json['pricePerCubicMeter']);
    if (unitPrice == null || unitPrice <= 0 || !unitPrice.isFinite) {
      return (liters: liters, totalCost: totalCost);
    }

    if (liters <= 0 && totalCost > 0) {
      liters = FuelMath.liters(totalCost: totalCost, pricePerLiter: unitPrice);
    } else if (totalCost <= 0 && liters > 0) {
      totalCost = FuelMath.totalCost(liters: liters, pricePerLiter: unitPrice);
    }

    return (liters: liters, totalCost: totalCost);
  }

  /// Injects the grade's default unit price when the document omitted one.
  ///
  /// Complete logs (litres + cost already present) ignore this; [fromJson]
  /// will not recompute stored amounts from the fallback.
  static Map<String, dynamic> withFallbackUnitPrice(
    Map<String, dynamic> json,
    FuelPriceDefaults defaults,
  ) {
    final existing =
        JsonX.doubleOrNull(json['pricePerLiter']) ??
        JsonX.doubleOrNull(json['pricePerCubicMeter']);
    if (existing != null && existing > 0 && existing.isFinite) return json;
    final fallback = defaults.priceOf(
      FuelType.fromName(json['fuelType'] as String?),
    );
    if (fallback == null) return json;
    return {...json, 'pricePerLiter': fallback};
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'date': date.toIso8601String(),
    'odometer': odometer,
    'liters': liters,
    'fuelType': fuelType.name,
    'totalCost': totalCost,
    'pricePerLiter': pricePerLiter,
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
