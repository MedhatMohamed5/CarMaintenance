import '../../../../core/utils/json_x.dart';
import '../../../maintenance/domain/entities/part_setting.dart';
import '../../domain/entities/vehicle.dart';

/// Serialisation layer for [Vehicle].
///
/// `toJson`/`fromJson` are the canonical form used by Hive **and** Firestore —
/// `toFirestore`/`fromFirestore` only differ in where the id lives, so swapping
/// a remote source in later needs no changes to the entity.
class VehicleModel extends Vehicle {
  const VehicleModel({
    required super.id,
    required super.make,
    required super.model,
    required super.year,
    required super.initialOdometer,
    required super.currentOdometer,
    required super.createdAt,
    super.nickname,
    super.plateNumber,
    super.purchaseDate,
    super.licenseExpiry,
    super.insuranceExpiry,
    super.tankCapacityLiters,
    super.colorValue,
    super.imageBase64,
    super.imageUrl,
    super.partLifespanOverridesKm,
    super.partSettings,
    super.odometerUpdatedAt,
  });

  factory VehicleModel.fromEntity(Vehicle v) => VehicleModel(
    id: v.id,
    make: v.make,
    model: v.model,
    year: v.year,
    initialOdometer: v.initialOdometer,
    currentOdometer: v.currentOdometer,
    createdAt: v.createdAt,
    nickname: v.nickname,
    plateNumber: v.plateNumber,
    purchaseDate: v.purchaseDate,
    licenseExpiry: v.licenseExpiry,
    insuranceExpiry: v.insuranceExpiry,
    tankCapacityLiters: v.tankCapacityLiters,
    colorValue: v.colorValue,
    imageBase64: v.imageBase64,
    imageUrl: v.imageUrl,
    partLifespanOverridesKm: v.partLifespanOverridesKm,
    partSettings: v.partSettings,
    odometerUpdatedAt: v.odometerUpdatedAt,
  );

  factory VehicleModel.fromJson(Map<String, dynamic> json) => VehicleModel(
    id: json['id'] as String,
    make: json['make'] as String? ?? '',
    model: json['model'] as String? ?? '',
    year: JsonX.intOr(json['year'], DateTime.now().year),
    initialOdometer: JsonX.intOr(json['initialOdometer'], 0),
    currentOdometer: JsonX.intOr(json['currentOdometer'], 0),
    createdAt: JsonX.dateOr(json['createdAt'], DateTime.now()),
    nickname: json['nickname'] as String?,
    plateNumber: json['plateNumber'] as String?,
    purchaseDate: JsonX.date(json['purchaseDate']),
    licenseExpiry: JsonX.date(json['licenseExpiry']),
    insuranceExpiry: JsonX.date(json['insuranceExpiry']),
    tankCapacityLiters: JsonX.doubleOrNull(json['tankCapacityLiters']),
    colorValue: JsonX.doubleOrNull(json['colorValue'])?.toInt(),
    imageBase64: json['imageBase64'] as String?,
    imageUrl: json['imageUrl'] as String?,
    partLifespanOverridesKm: JsonX.intMap(json['partLifespanOverridesKm']),
    partSettings: _settingsFromJson(json['partSettings']),
    odometerUpdatedAt: JsonX.date(json['odometerUpdatedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'make': make,
    'model': model,
    'year': year,
    'initialOdometer': initialOdometer,
    'currentOdometer': currentOdometer,
    'createdAt': createdAt.toIso8601String(),
    'nickname': nickname,
    'plateNumber': plateNumber,
    'purchaseDate': purchaseDate?.toIso8601String(),
    'licenseExpiry': licenseExpiry?.toIso8601String(),
    'insuranceExpiry': insuranceExpiry?.toIso8601String(),
    'tankCapacityLiters': tankCapacityLiters,
    'colorValue': colorValue,
    'imageBase64': imageBase64,
    'imageUrl': imageUrl,
    'partLifespanOverridesKm': partLifespanOverridesKm,
    'partSettings': {
      for (final e in partSettings.entries) e.key: e.value.toJson(),
    },
    'odometerUpdatedAt': odometerUpdatedAt?.toIso8601String(),
  };

  static Map<String, PartSetting> _settingsFromJson(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final e in value.entries)
        if (e.value is Map)
          '${e.key}': PartSetting.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          ),
    };
  }

  /// Firestore document → model. The document id is authoritative.
  factory VehicleModel.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) => VehicleModel.fromJson({...data, 'id': documentId});

  /// Model → Firestore document. The id lives in the document path, so it is
  /// dropped from the payload and an `updatedAt` marker is stamped for sync.
  Map<String, dynamic> toFirestore() => {
    ...toJson()..remove('id'),
    'updatedAt': DateTime.now().toIso8601String(),
  };
}
