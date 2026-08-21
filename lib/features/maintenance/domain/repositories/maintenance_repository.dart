import '../entities/consumable_part.dart';
import '../entities/maintenance_record.dart';
import '../entities/part_replacement.dart';

abstract interface class MaintenanceRepository {
  /// Newest first.
  Stream<List<MaintenanceRecord>> watchRecords(String vehicleId);

  List<MaintenanceRecord> getRecords(String vehicleId);

  /// The existing log for a periodic milestone, if the phase was already
  /// closed. Used to make logging idempotent.
  MaintenanceRecord? findByMilestone(String vehicleId, int milestoneOdometer);

  Stream<List<PartReplacement>> watchReplacements(String vehicleId);

  List<PartReplacement> getReplacements(String vehicleId);

  /// Saves the service **and** derives a [PartReplacement] for each part it
  /// replaced, so logging a service is the single action that resets health.
  Future<void> saveService(MaintenanceRecord record);

  Future<void> deleteRecord(String id);

  /// Resets one part on its own, without a full service entry.
  Future<void> resetPart({
    required String vehicleId,
    required ConsumablePart part,
    required int odometer,
    DateTime? date,
    double? cost,
    String? notes,
  });

  Future<void> deleteForVehicle(String vehicleId);
}
