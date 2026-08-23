import '../../../expenses/domain/entities/expense.dart';
import '../../../fuel/domain/entities/fuel_log.dart';
import '../../../maintenance/domain/entities/maintenance_record.dart';
import '../../../maintenance/domain/entities/part_replacement.dart';
import 'vehicle.dart';

/// Everything one vehicle owns, in a single transportable object: the profile
/// (document expiry dates and per-part settings included, they live on
/// [Vehicle]) plus every child record keyed to it.
///
/// This is the unit both export and import work in, so a file written by one
/// and read by the other cannot disagree about what "a vehicle's data" means.
class VehicleTransferBundle {
  const VehicleTransferBundle({
    required this.vehicle,
    this.records = const [],
    this.replacements = const [],
    this.fuelLogs = const [],
    this.expenses = const [],
  });

  final Vehicle vehicle;
  final List<MaintenanceRecord> records;
  final List<PartReplacement> replacements;
  final List<FuelLog> fuelLogs;
  final List<Expense> expenses;

  /// Replacements the user logged on their own, outside any service.
  ///
  /// The rest are derived from a service record and are rebuilt by the
  /// repository when that record is saved, so importing them too would fit the
  /// same part twice.
  List<PartReplacement> get standaloneReplacements => replacements
      .where((r) => r.maintenanceRecordId == null)
      .toList(growable: false);

  int get entryCount =>
      records.length +
      standaloneReplacements.length +
      fuelLogs.length +
      expenses.length;
}
