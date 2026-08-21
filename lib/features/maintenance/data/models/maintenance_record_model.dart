import '../../../../core/utils/json_x.dart';
import '../../domain/entities/consumable_part.dart';
import '../../domain/entities/maintenance_record.dart';
import '../../domain/entities/service_milestone.dart';

class MaintenanceRecordModel extends MaintenanceRecord {
  const MaintenanceRecordModel({
    required super.id,
    required super.vehicleId,
    required super.date,
    required super.odometer,
    required super.title,
    required super.tier,
    super.replacedParts,
    super.inspectedKeys,
    super.customItems,
    super.cost,
    super.workshopName,
    super.notes,
    super.milestoneOdometer,
  });

  factory MaintenanceRecordModel.fromEntity(MaintenanceRecord r) =>
      MaintenanceRecordModel(
        id: r.id,
        vehicleId: r.vehicleId,
        date: r.date,
        odometer: r.odometer,
        title: r.title,
        tier: r.tier,
        replacedParts: r.replacedParts,
        inspectedKeys: r.inspectedKeys,
        customItems: r.customItems,
        cost: r.cost,
        workshopName: r.workshopName,
        notes: r.notes,
        milestoneOdometer: r.milestoneOdometer,
      );

  factory MaintenanceRecordModel.fromJson(Map<String, dynamic> json) =>
      MaintenanceRecordModel(
        id: json['id'] as String,
        vehicleId: json['vehicleId'] as String? ?? '',
        date: JsonX.dateOr(json['date'], DateTime.now()),
        odometer: JsonX.intOr(json['odometer'], 0),
        title: json['title'] as String? ?? '',
        tier: JsonX.enumByName(
          json['tier'],
          ServiceTier.values,
          ServiceTier.minor,
        ),
        replacedParts: JsonX.stringList(
          json['replacedParts'],
        ).map(ConsumablePart.fromId).toList(growable: false),
        inspectedKeys: JsonX.stringList(json['inspectedKeys']),
        customItems: JsonX.stringList(json['customItems']),
        cost: JsonX.doubleOr(json['cost'], 0),
        workshopName: json['workshopName'] as String?,
        notes: json['notes'] as String?,
        milestoneOdometer: json['milestoneOdometer'] == null
            ? null
            : JsonX.intOr(json['milestoneOdometer'], 0),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'date': date.toIso8601String(),
    'odometer': odometer,
    'title': title,
    'tier': tier.name,
    'replacedParts': replacedParts.map((p) => p.id).toList(),
    'inspectedKeys': inspectedKeys,
    'customItems': customItems,
    'cost': cost,
    'workshopName': workshopName,
    'notes': notes,
    'milestoneOdometer': milestoneOdometer,
  };

  factory MaintenanceRecordModel.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) => MaintenanceRecordModel.fromJson({...data, 'id': documentId});

  Map<String, dynamic> toFirestore() => {
    ...toJson()..remove('id'),
    'updatedAt': DateTime.now().toIso8601String(),
  };
}
