import '../../../../core/storage/hive_boxes.dart';
import '../../../../core/storage/json_box.dart';
import '../models/maintenance_record_model.dart';
import '../models/part_replacement_model.dart';

/// Two boxes, one data source: services and the part replacements they imply
/// are always written together, so they share a transactional entry point.
class MaintenanceLocalDataSource {
  MaintenanceLocalDataSource()
    : records = JsonBox<MaintenanceRecordModel>(
        boxName: HiveBoxes.maintenance,
        fromJson: MaintenanceRecordModel.fromJson,
        toJson: (v) => v.toJson(),
        idOf: (v) => v.id,
      ),
      replacements = JsonBox<PartReplacementModel>(
        boxName: HiveBoxes.partReplacements,
        fromJson: PartReplacementModel.fromJson,
        toJson: (v) => v.toJson(),
        idOf: (v) => v.id,
      );

  final JsonBox<MaintenanceRecordModel> records;
  final JsonBox<PartReplacementModel> replacements;
}
