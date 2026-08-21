import '../../../../core/utils/json_x.dart';
import '../../domain/entities/consumable_part.dart';
import '../../domain/entities/part_replacement.dart';

class PartReplacementModel extends PartReplacement {
  const PartReplacementModel({
    required super.id,
    required super.vehicleId,
    required super.part,
    required super.odometer,
    required super.date,
    super.cost,
    super.notes,
    super.maintenanceRecordId,
  });

  factory PartReplacementModel.fromEntity(PartReplacement r) =>
      PartReplacementModel(
        id: r.id,
        vehicleId: r.vehicleId,
        part: r.part,
        odometer: r.odometer,
        date: r.date,
        cost: r.cost,
        notes: r.notes,
        maintenanceRecordId: r.maintenanceRecordId,
      );

  factory PartReplacementModel.fromJson(Map<String, dynamic> json) =>
      PartReplacementModel(
        id: json['id'] as String,
        vehicleId: json['vehicleId'] as String? ?? '',
        part: ConsumablePart.fromId(json['part'] as String?),
        odometer: JsonX.intOr(json['odometer'], 0),
        date: JsonX.dateOr(json['date'], DateTime.now()),
        cost: JsonX.doubleOrNull(json['cost']),
        notes: json['notes'] as String?,
        maintenanceRecordId: json['maintenanceRecordId'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'part': part.id,
    'odometer': odometer,
    'date': date.toIso8601String(),
    'cost': cost,
    'notes': notes,
    'maintenanceRecordId': maintenanceRecordId,
  };

  factory PartReplacementModel.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) => PartReplacementModel.fromJson({...data, 'id': documentId});

  Map<String, dynamic> toFirestore() => {
    ...toJson()..remove('id'),
    'updatedAt': DateTime.now().toIso8601String(),
  };
}
