import '../../expenses/data/models/expense_model.dart';
import '../../fuel/data/models/fuel_log_model.dart';
import '../../maintenance/data/models/maintenance_record_model.dart';
import '../../maintenance/data/models/part_replacement_model.dart';
import '../domain/entities/vehicle_transfer_bundle.dart';
import 'models/vehicle_model.dart';

/// Rebuilds an imported bundle under freshly generated ids.
///
/// An import must never collide with what is already stored — the same file
/// imported twice has to produce two independent vehicles, not silently
/// overwrite the first. Every id is reissued and every foreign key is rewritten
/// to match: children point at the new vehicle, and a part replacement keeps
/// pointing at the service record it came from.
///
/// The rewrite runs through each model's JSON rather than its constructor on
/// purpose: JSON is the complete, canonical field set, so a field added to an
/// entity later travels through here automatically instead of being silently
/// dropped by a hand-copied constructor call.
class VehicleBundleRemapper {
  const VehicleBundleRemapper();

  VehicleTransferBundle call(
    VehicleTransferBundle bundle, {
    required String Function() newId,
  }) {
    final vehicleId = newId();

    // Old record id → new record id, so a replacement fitted during a service
    // still resolves to that service after the import.
    final recordIds = <String, String>{
      for (final record in bundle.records) record.id: newId(),
    };

    return VehicleTransferBundle(
      vehicle: VehicleModel.fromJson(
        VehicleModel.fromEntity(bundle.vehicle).toJson()..['id'] = vehicleId,
      ),
      records: [
        for (final record in bundle.records)
          MaintenanceRecordModel.fromJson(
            MaintenanceRecordModel.fromEntity(record).toJson()
              ..['id'] = recordIds[record.id] ?? newId()
              ..['vehicleId'] = vehicleId,
          ),
      ],
      replacements: [
        for (final replacement in bundle.replacements)
          PartReplacementModel.fromJson(
            PartReplacementModel.fromEntity(replacement).toJson()
              ..['id'] = newId()
              ..['vehicleId'] = vehicleId
              ..['maintenanceRecordId'] =
                  recordIds[replacement.maintenanceRecordId],
          ),
      ],
      fuelLogs: [
        for (final log in bundle.fuelLogs)
          FuelLogModel.fromJson(
            FuelLogModel.fromEntity(log).toJson()
              ..['id'] = newId()
              ..['vehicleId'] = vehicleId,
          ),
      ],
      expenses: [
        for (final expense in bundle.expenses)
          ExpenseModel.fromJson(
            ExpenseModel.fromEntity(expense).toJson()
              ..['id'] = newId()
              ..['vehicleId'] = vehicleId,
          ),
      ],
    );
  }
}
